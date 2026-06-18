import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bridge_controller.dart';

/// 文件服务 - 处理文件读写操作
class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  static const int _defaultChunkSize = 64 * 1024; // 64KB 每块

  // 流式文件操作会话
  final Map<String, _FileStreamSession> _fileStreamSessions = {};
  int _sessionIdCounter = 1;

  /// 保存文件（一次性写入）
  Future<void> saveFile(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      final base64Data = payload['base64Data'] as String?;
      final fileName = payload['fileName'] as String?;
      final filePath = payload['filePath'] as String?;

      if (base64Data == null || base64Data.isEmpty) {
        _sendResponse('saveFile', {'success': false, 'error': 'Base64 data is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      if (fileName == null || fileName.isEmpty) {
        _sendResponse('saveFile', {'success': false, 'error': 'File name is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) {
        _sendResponse('saveFile', {'success': false, 'error': 'Storage permission denied'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final bytes = base64Decode(base64Data);

      String fullPath;
      if (filePath != null && filePath.isNotEmpty) {
        fullPath = filePath;
      } else {
        const publicDownloadDir = '/storage/emulated/0/Download';
        final targetDir = Directory('$publicDownloadDir/trip-route-track');
        await targetDir.create(recursive: true);
        fullPath = '${targetDir.path}/$fileName';
      }

      final file = File(fullPath);
      await file.writeAsBytes(bytes);

      _sendResponse('saveFile', {'success': true, 'path': fullPath},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      _sendResponse('saveFile', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  /// 读取文件（一次性读取）
  Future<void> readFile(String filePath,
      {String? bridgeId, String? sessionId}) async {
    try {
      if (filePath.isEmpty) {
        _sendResponse('readFile', {'success': false, 'error': 'File path is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) {
        _sendResponse('readFile', {'success': false, 'error': 'Storage permission denied'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        _sendResponse('readFile', {'success': false, 'error': 'File not found'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      _sendResponse('readFile', {'success': true, 'base64Data': base64Data},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      _sendResponse('readFile', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  /// 流式保存文件 - 开始
  Future<void> saveFileStreamStart(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      final fileName = payload['fileName'] as String?;
      final totalSize = payload['totalSize'] as int?;
      final filePath = payload['filePath'] as String?;

      if (fileName == null || fileName.isEmpty) {
        _sendResponse('saveFileStreamStart', {'success': false, 'error': 'File name is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) {
        _sendResponse('saveFileStreamStart', {'success': false, 'error': 'Storage permission denied'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final streamSessionId = _generateSessionId();

      String fullPath;
      if (filePath != null && filePath.isNotEmpty) {
        fullPath = filePath;
      } else {
        const publicDownloadDir = '/storage/emulated/0/Download';
        final targetDir = Directory('$publicDownloadDir/trip-route-track');
        await targetDir.create(recursive: true);
        fullPath = '${targetDir.path}/$fileName';
      }

      final tempFile = File('$fullPath.tmp');
      await tempFile.create(recursive: true);

      _fileStreamSessions[streamSessionId] = _FileStreamSession(
        type: _FileStreamType.write,
        filePath: fullPath,
        tempFilePath: '$fullPath.tmp',
        totalSize: totalSize ?? 0,
        bytesWritten: 0,
        chunkSize: _defaultChunkSize,
      );

      _sendResponse('saveFileStreamStart', {
        'success': true,
        'sessionId': streamSessionId,
        'chunkSize': _defaultChunkSize,
      }, bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      _sendResponse('saveFileStreamStart', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  /// 流式保存文件 - 写入数据块
  Future<void> saveFileStreamChunk(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      final streamSessionId = payload['sessionId'] as String?;
      final chunkIndex = payload['chunkIndex'] as int?;
      final base64Data = payload['base64Data'] as String?;

      if (streamSessionId == null || streamSessionId.isEmpty) {
        _sendResponse('saveFileStreamChunk', {'success': false, 'error': 'Session ID is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final session = _fileStreamSessions[streamSessionId];
      if (session == null) {
        _sendResponse('saveFileStreamChunk', {'success': false, 'error': 'Session not found'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      if (base64Data == null || base64Data.isEmpty) {
        _sendResponse('saveFileStreamChunk', {'success': false, 'error': 'Base64 data is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final bytes = base64Decode(base64Data);
      final tempFilePath = session.tempFilePath;
      if (tempFilePath == null) {
        _sendResponse('saveFileStreamChunk', {'success': false, 'error': 'Temp file path not set'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }
      
      final file = File(tempFilePath);
      await file.writeAsBytes(bytes, mode: FileMode.append);
      session.bytesWritten += bytes.length;

      _sendResponse('saveFileStreamChunk', {'success': true},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      _sendResponse('saveFileStreamChunk', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  /// 流式保存文件 - 结束
  Future<void> saveFileStreamEnd(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      final streamSessionId = payload['sessionId'] as String?;

      if (streamSessionId == null || streamSessionId.isEmpty) {
        _sendResponse('saveFileStreamEnd', {'success': false, 'error': 'Session ID is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final session = _fileStreamSessions[streamSessionId];
      if (session == null) {
        _sendResponse('saveFileStreamEnd', {'success': false, 'error': 'Session not found'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      try {
        final tempFilePath = session.tempFilePath;
        if (tempFilePath == null) {
          _sendResponse('saveFileStreamEnd', {'success': false, 'error': 'Temp file path not set'},
              bridgeId: bridgeId, sessionId: sessionId);
          return;
        }
        
        final tempFile = File(tempFilePath);
        final finalFile = File(session.filePath);
        
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tempFile.rename(session.filePath);

        _sendResponse('saveFileStreamEnd', {'success': true, 'path': session.filePath},
            bridgeId: bridgeId, sessionId: sessionId);
      } finally {
        _fileStreamSessions.remove(streamSessionId);
      }
    } catch (e) {
      _sendResponse('saveFileStreamEnd', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
      final streamSessionId = payload['sessionId'] as String?;
      if (streamSessionId != null) {
        _fileStreamSessions.remove(streamSessionId);
      }
    }
  }

  /// 流式读取文件 - 开始
  Future<void> readFileStreamStart(String filePath,
      {String? bridgeId, String? sessionId}) async {
    try {
      if (filePath.isEmpty) {
        _sendResponse('readFileStreamStart', {'success': false, 'error': 'File path is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) {
        _sendResponse('readFileStreamStart', {'success': false, 'error': 'Storage permission denied'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        _sendResponse('readFileStreamStart', {'success': false, 'error': 'File not found'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final fileSize = await file.length();
      final streamSessionId = _generateSessionId();

      _fileStreamSessions[streamSessionId] = _FileStreamSession(
        type: _FileStreamType.read,
        filePath: filePath,
        totalSize: fileSize,
        bytesWritten: 0,
        chunkSize: _defaultChunkSize,
      );

      _sendResponse('readFileStreamStart', {
        'success': true,
        'sessionId': streamSessionId,
        'totalSize': fileSize,
        'chunkSize': _defaultChunkSize,
      }, bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      _sendResponse('readFileStreamStart', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  /// 流式读取文件 - 获取数据块
  Future<void> readFileStreamChunk(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      final streamSessionId = payload['sessionId'] as String?;
      final chunkIndex = payload['chunkIndex'] as int?;

      if (streamSessionId == null || streamSessionId.isEmpty) {
        _sendResponse('readFileStreamChunk', {'success': false, 'error': 'Session ID is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final session = _fileStreamSessions[streamSessionId];
      if (session == null) {
        _sendResponse('readFileStreamChunk', {'success': false, 'error': 'Session not found'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      if (chunkIndex == null) {
        _sendResponse('readFileStreamChunk', {'success': false, 'error': 'Chunk index is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final file = File(session.filePath);
      final start = chunkIndex * session.chunkSize;
      final end = start + session.chunkSize;

      if (start >= session.totalSize) {
        _sendResponse('readFileStreamChunk', {
          'success': true,
          'base64Data': '',
          'isLastChunk': true,
        }, bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final bytes = await file.readAsBytes();
      final actualEnd = end < bytes.length ? end : bytes.length;
      final chunkBytes = bytes.sublist(start, actualEnd);
      final base64Data = base64Encode(chunkBytes);
      final isLastChunk = actualEnd >= bytes.length;

      _sendResponse('readFileStreamChunk', {
        'success': true,
        'base64Data': base64Data,
        'isLastChunk': isLastChunk,
      }, bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      _sendResponse('readFileStreamChunk', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  /// 流式读取文件 - 结束
  Future<void> readFileStreamEnd(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      final streamSessionId = payload['sessionId'] as String?;

      if (streamSessionId == null || streamSessionId.isEmpty) {
        _sendResponse('readFileStreamEnd', {'success': false, 'error': 'Session ID is required'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      _fileStreamSessions.remove(streamSessionId);

      _sendResponse('readFileStreamEnd', {'success': true},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      _sendResponse('readFileStreamEnd', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  /// 检查并请求存储权限
  Future<bool> _checkAndRequestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkVersion = androidInfo.version.sdkInt;
        
        if (sdkVersion >= 33) {
          return await _requestAndroid13StoragePermission();
        }
      }
      
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      
      final result = await Permission.storage.request();
      return result.isGranted;
    } catch (e) {
      print('[FileService] Error checking storage permission: $e');
      return false;
    }
  }

  /// 请求Android 13+存储权限
  Future<bool> _requestAndroid13StoragePermission() async {
    try {
      // 使用 photos 和 videos 权限替代 photos.read/write
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;
      
      if (photosStatus.isGranted && videosStatus.isGranted) {
        return true;
      }
      
      final photosResult = await Permission.photos.request();
      final videosResult = await Permission.videos.request();
      
      return photosResult.isGranted && videosResult.isGranted;
    } catch (e) {
      print('[FileService] Error requesting Android 13 storage permission: $e');
      return false;
    }
  }

  /// 生成会话ID
  String _generateSessionId() {
    return 'stream_${DateTime.now().millisecondsSinceEpoch}_${_sessionIdCounter++}';
  }

  /// 发送响应消息
  void _sendResponse(String type, Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) {
    BridgeController().sendMessage(type, payload, bridgeId: bridgeId, sessionId: sessionId);
  }
}

/// 流式文件操作类型枚举
enum _FileStreamType {
  read,
  write,
}

/// 流式文件操作会话信息
class _FileStreamSession {
  final _FileStreamType type;
  final String filePath;
  final String? tempFilePath;
  final int totalSize;
  int bytesWritten;
  final int chunkSize;

  _FileStreamSession({
    required this.type,
    required this.filePath,
    this.tempFilePath,
    required this.totalSize,
    required this.bytesWritten,
    required this.chunkSize,
  });
}