import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileLogService {
  static final FileLogService _instance = FileLogService._internal();
  factory FileLogService() => _instance;
  FileLogService._internal();

  File? _logFile;
  String? _logFilePath;
  final List<String> _logBuffer = [];
  static const int _maxBufferSize = 100;
  static const int _maxLogFileSize = 5 * 1024 * 1024;

  String? get logFilePath => _logFilePath;

  Future<void> init() async {
    await _initLogFile();
    _redirectPrint();
    _setupExceptionHandler();
  }

  Future<void> _initLogFile() async {
    try {
      final directory = await _getLogDirectory();
      if (directory == null) {
        print('[FileLog] Failed to get log directory');
        return;
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'app_log_$timestamp.txt';
      _logFile = File('${directory.path}/$fileName');
      _logFilePath = _logFile!.path;

      await _logFile!.writeAsString(
        '=== App Log Started at ${DateTime.now().toIso8601String()} ===\n\n',
        mode: FileMode.write,
      );

      print('[FileLog] Log file initialized: $_logFilePath');

      await _cleanupOldLogs(directory);
    } catch (e) {
      print('[FileLog] Failed to initialize log file: $e');
    }
  }

  Future<Directory?> _getLogDirectory() async {
    try {
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Download/log');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      }

      final appDir = await getExternalStorageDirectory();
      if (appDir != null) {
        final logDir = Directory('${appDir.path}/logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        return logDir;
      }

      final dir = await getApplicationDocumentsDirectory();
      return dir;
    } catch (e) {
      print('[FileLog] Error getting log directory: $e');
      return null;
    }
  }

  Future<void> _cleanupOldLogs(Directory directory) async {
    try {
      final files = directory.listSync().whereType<File>().where((f) {
        final name = f.path.split('/').last;
        return name.startsWith('app_log_') && name.endsWith('.txt');
      }).toList();

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (files.length > 10) {
        for (var i = 10; i < files.length; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      print('[FileLog] Error cleaning up old logs: $e');
    }
  }

  void _redirectPrint() {
    debugPrint = (String? message, {int? wrapWidth}) {
      final timestamp = DateTime.now().toIso8601String();
      final formattedMessage = '[$timestamp] $message';
      _writeLog(formattedMessage);
    };
  }

  void _setupExceptionHandler() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final timestamp = DateTime.now().toIso8601String();
      final errorMessage = '[$timestamp] FLUTTER ERROR: ${details.exceptionAsString()}';
      _writeLog(errorMessage);
      if (details.stack != null) {
        _writeLog('[$timestamp] StackTrace: ${details.stack}');
      }
      originalOnError?.call(details);
    };

    final originalOnPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      final timestamp = DateTime.now().toIso8601String();
      final errorMessage = '[$timestamp] PLATFORM ERROR: $error';
      _writeLog(errorMessage);
      _writeLog('[$timestamp] StackTrace: $stackTrace');
      return originalOnPlatformError?.call(error, stackTrace) ?? false;
    };
  }

  Future<void> _writeLog(String message) async {
    _logBuffer.add(message);

    if (_logBuffer.length >= _maxBufferSize) {
      await _flushBuffer();
    }

    if (_logFile != null) {
      try {
        final stat = await _logFile!.stat();
        if (stat.size >= _maxLogFileSize) {
          await _rotateLogFile();
        }

        await _logFile!.writeAsString('$message\n', mode: FileMode.append);
      } catch (e) {
        print('[FileLog] Failed to write to file: $e');
      }
    }

    print('[FileLog] $message');
  }

  Future<void> _flushBuffer() async {
    if (_logFile != null && _logBuffer.isNotEmpty) {
      try {
        final content = _logBuffer.join('\n') + '\n';
        await _logFile!.writeAsString(content, mode: FileMode.append);
        _logBuffer.clear();
      } catch (e) {
        print('[FileLog] Failed to flush buffer: $e');
      }
    }
  }

  Future<void> _rotateLogFile() async {
    if (_logFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final oldPath = _logFile!.path;
      final newPath = oldPath.replaceAll('.txt', '_old_$timestamp.txt');
      await _logFile!.rename(newPath);

      _logFile = File(oldPath);
      await _logFile!.writeAsString(
        '=== Log Rotated at ${DateTime.now().toIso8601String()} ===\n\n',
        mode: FileMode.write,
      );
    } catch (e) {
      print('[FileLog] Failed to rotate log file: $e');
    }
  }

  Future<void> log(String tag, String message) async {
    final timestamp = DateTime.now().toIso8601String();
    await _writeLog('[$timestamp] [$tag] $message');
  }

  Future<void> logError(String tag, String message, [dynamic error, dynamic stackTrace]) async {
    final timestamp = DateTime.now().toIso8601String();
    await _writeLog('[$timestamp] [$tag] ERROR: $message');
    if (error != null) {
      await _writeLog('[$timestamp] [$tag] Error Details: $error');
    }
    if (stackTrace != null) {
      await _writeLog('[$timestamp] [$tag] StackTrace: $stackTrace');
    }
  }

  Future<void> flush() async {
    await _flushBuffer();
  }

  Future<String?> getLogContent() async {
    if (_logFile == null) return null;
    try {
      return await _logFile!.readAsString();
    } catch (e) {
      print('[FileLog] Failed to read log file: $e');
      return null;
    }
  }
}
