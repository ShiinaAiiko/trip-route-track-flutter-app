import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:i18n/i18n_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bridge/flutter_bridge.dart' hide UpdateCheckCallback, UpdateCheckingCallback;
import 'callbacks.dart';
import 'version_info.dart';

/// App 更新服务
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _packagesUrl = 'https://trip.aiiko.club/packages/?format=json';
  static const int _downloadProgressNotificationId = 10001; // 下载进度通知
  static const int _installPromptNotificationId = 10002; // 安装提示通知

  bool _isDownloading = false;
  bool _shouldStopDownload = false;
  bool _waitingForInstall = false;
  String? _currentVersion;
  String? _downloadPath;
  http.Client? _downloadClient;

  bool get isDownloading => _isDownloading;
  bool get waitingForInstall => _waitingForInstall;
  String? get downloadPath => _downloadPath;
  String? get currentVersion => _currentVersion;

  AppUpdateProgressCallback? _onProgress;
  AppUpdateCompleteCallback? _onComplete;
  AppUpdateInstallRequestCallback? _onInstallRequest;
  UpdateCheckCallback? _onUpdateCheck;
  UpdateCheckingCallback? _onUpdateChecking;

  // 设置回调
  void setProgressCallback(AppUpdateProgressCallback callback) => _onProgress = callback;
  void setCompleteCallback(AppUpdateCompleteCallback callback) => _onComplete = callback;
  void setInstallRequestCallback(AppUpdateInstallRequestCallback callback) => _onInstallRequest = callback;
  void setUpdateCheckCallback(UpdateCheckCallback callback) => _onUpdateCheck = callback;
  void setUpdateCheckingCallback(UpdateCheckingCallback callback) => _onUpdateChecking = callback;
  
  // 通知点击回调 - 使用通用的通知点击回调注册机制
  void setNotificationTappedCallback(VoidCallback callback) {
    BridgeController().notificationService.registerNotificationClickCallback(_downloadProgressNotificationId, callback);
  }
  
  void setInstallNotificationTappedCallback(VoidCallback callback) {
    BridgeController().notificationService.registerNotificationClickCallback(_installPromptNotificationId, callback);
  }

  // 清除回调
  void clearProgressCallback() => _onProgress = null;
  void clearCompleteCallback() => _onComplete = null;
  void clearInstallRequestCallback() => _onInstallRequest = null;
  void clearUpdateCheckCallback() => _onUpdateCheck = null;
  void clearUpdateCheckingCallback() => _onUpdateChecking = null;
  void clearNotificationTappedCallback() {
    BridgeController().notificationService.unregisterNotificationClickCallback(_downloadProgressNotificationId);
  }
  void clearInstallNotificationTappedCallback() {
    BridgeController().notificationService.unregisterNotificationClickCallback(_installPromptNotificationId);
  }

  /// 初始化服务
  Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    await _cleanupOldApks();
  }

  /// 请求通知权限
  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    }
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 清理旧的 APK 文件
  Future<void> _cleanupOldApks() async {
    try {
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (e) {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) return;

      print('[UpdateService] Cleaning up old APK files in ${dir.path}');

      final files = dir.listSync();
      final regex = RegExp(r'trip-route-track_(\d+\.\d+\.\d+)\.apk', caseSensitive: false);

      for (final file in files) {
        if (file is File && file.path.endsWith('.apk')) {
          final fileName = file.path.split('/').last;
          final match = regex.firstMatch(fileName);

          if (match != null) {
            final apkVersion = match.group(1);
            if (apkVersion != null && _currentVersion != null) {
              final versionComparison = _compareVersion(apkVersion, _currentVersion!);
              if (versionComparison > 0) {
                print('[UpdateService] Keeping APK: $fileName');
                continue;
              }
            }
          }
          try {
            await file.delete();
            print('[UpdateService] Deleted APK: $fileName');
          } catch (e) {
            print('[UpdateService] Failed to delete APK: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('[UpdateService] Failed to clean up old APKs: $e');
    }
  }

  /// 检查是否存在已下载的 APK
  Future<File?> _checkExistingApk(String version) async {
    try {
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (e) {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) return null;

      final apkPath = '${dir.path}/trip-route-track_$version.apk';
      final file = File(apkPath);

      if (await file.exists()) {
        final fileSize = await file.length();
        print('[UpdateService] Found existing APK: $apkPath (size: $fileSize bytes)');
        return file;
      }
      return null;
    } catch (e) {
      print('[UpdateService] Failed to check existing APK: $e');
      return null;
    }
  }

  /// 检查新版本
  Future<void> checkNewVersion({bool showCheckingNotification = true}) async {
    try {
      print('[UpdateService] Checking new version...');
      
      if (showCheckingNotification) {
        _onUpdateChecking?.call();
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('[UpdateService] Current version: $currentVersion');

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(_packagesUrl));
        final response = await client.send(request);
        print('[UpdateService] Response status: ${response.statusCode}');

        if (response.statusCode != 200) {
          print('[UpdateService] Request failed');
          _onUpdateCheck?.call(null, currentVersion, showCheckingNotification);
          return;
        }

        final body = await response.stream.bytesToString();
        print('[UpdateService] Response body length: ${body.length}');

        final latestVersion = _parseLatestVersion(body);
        print('[UpdateService] Parsed latest version: $latestVersion');

        if (latestVersion == null) {
          print('[UpdateService] Failed to parse version');
          _onUpdateCheck?.call(null, currentVersion, showCheckingNotification);
          return;
        }

        final versionComparison = _compareVersion(latestVersion, currentVersion);
        print('[UpdateService] Compare $latestVersion vs $currentVersion = $versionComparison');

        if (versionComparison > 0) {
          final apkUrl = 'https://trip.aiiko.club/packages/trip-route-track-v$latestVersion-arm64-v8a.apk';
          print('[UpdateService] New version available: $apkUrl');
          _onUpdateCheck?.call(
            VersionInfo(version: latestVersion, downloadUrl: apkUrl),
            currentVersion,
            showCheckingNotification,
          );
        } else {
          print('[UpdateService] No new version');
          _onUpdateCheck?.call(null, currentVersion, showCheckingNotification);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('[UpdateService] Check version failed: $e');
      final packageInfo = await PackageInfo.fromPlatform();
      _onUpdateCheck?.call(null, packageInfo.version, showCheckingNotification);
    }
  }

  /// 解析最新版本
  String? _parseLatestVersion(String jsonBody) {
    print('[UpdateService] Parsing JSON for versions');
    try {
      final List<dynamic> files = json.decode(jsonBody);
      print('[UpdateService] Found ${files.length} files');

      final regex = RegExp(r'trip-route-track-v(\d+\.\d+\.\d+)-arm64-v8a\.apk', caseSensitive: false);

      String? latestVersion;
      for (final file in files) {
        if (file is Map<String, dynamic>) {
          final name = file['name'] as String?;
          if (name != null) {
            final match = regex.firstMatch(name);
            if (match != null) {
              final version = match.group(1);
              print('[UpdateService] Matched version: $version from $name');

              if (version != null) {
                if (latestVersion == null || _compareVersion(version, latestVersion) > 0) {
                  latestVersion = version;
                }
              }
            }
          }
        }
      }

      print('[UpdateService] Selected latest version: $latestVersion');
      return latestVersion;
    } catch (e) {
      print('[UpdateService] Failed to parse JSON: $e');
      return null;
    }
  }

  /// 比较版本号
  int _compareVersion(String v1, String v2) {
    final parts1 = v1.split('.').map((e) {
      final match = RegExp(r'^(\d+)').firstMatch(e);
      return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
    }).toList();
    final parts2 = v2.split('.').map((e) {
      final match = RegExp(r'^(\d+)').firstMatch(e);
      return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
    }).toList();

    for (var i = 0; i < parts1.length && i < parts2.length; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }

    if (parts1.length > parts2.length) return 1;
    if (parts1.length < parts2.length) return -1;

    return 0;
  }

  /// 停止下载
  Future<void> stopUpdate() async {
    _shouldStopDownload = true;
    _downloadClient?.close();
    try {
      await BridgeController().notificationService.cancelNotification(_downloadProgressNotificationId);
    } catch (e) {
      print('[UpdateService] Failed to cancel notification: $e');
    }
    if (_downloadPath != null) {
      try {
        final file = File(_downloadPath!);
        if (await file.exists()) {
          await file.delete();
          print('[UpdateService] Deleted partial download: $_downloadPath');
        }
      } catch (e) {
        print('[UpdateService] Failed to delete partial download: $e');
      }
    }
    _isDownloading = false;
    _downloadPath = null;
    _waitingForInstall = false;
    _shouldStopDownload = false;
  }

  /// 开始安装
  Future<void> installUpdate(I18nService i18nService) async {
    if (_downloadPath == null) {
      print('[UpdateService] No APK to install');
      return;
    }
    try {
      const platform = MethodChannel('flutter_bridge');
      await platform.invokeMethod('installApk', {
        'path': _downloadPath,
      });
      print('[UpdateService] Install APK called successfully');
    } catch (e) {
      print('[UpdateService] Install APK failed: $e');
      rethrow;
    }
  }

  /// 开始下载更新
  Future<void> startDownload({
    required String downloadUrl,
    required String version,
    required I18nService i18nService,
    bool autoInstall = false,
  }) async {
    if (_isDownloading) {
      print('[UpdateService] Already downloading, skipping...');
      return;
    }

    // 先检查是否已经有完整的APK文件
    final existingApk = await _checkExistingApk(version);
    if (existingApk != null) {
      // 有完整APK，直接进入安装流程
      print('[UpdateService] Found complete APK, skipping download');
      _isDownloading = true;
      _waitingForInstall = true;
      _downloadPath = existingApk.path;
      final fileSize = await existingApk.length();
      
      // 请求通知权限并显示安装提示通知
      await _requestNotificationPermission();
      await _showInstallPromptNotification(i18nService);
      _onProgress?.call(100, fileSize, fileSize);
      _onComplete?.call(true, null);
      _onInstallRequest?.call();
      
      if (autoInstall) {
        await Future.delayed(const Duration(milliseconds: 500));
        await installUpdate(i18nService);
      }
      return;
    }

    // 没有完整APK，清理可能存在的不完整文件，重新下载
    await _cleanupVersionApk(version);
    
    _isDownloading = true;
    _shouldStopDownload = false;
    _waitingForInstall = false;
    
    // 请求通知权限
    await _requestNotificationPermission();

    _downloadClient = http.Client();

    try {
      // 请求存储权限（Android 10+ 可能需要）
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await _downloadClient!.send(request);

      if (_shouldStopDownload) {
        print('[UpdateService] Download stopped by user');
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;

      // 使用外部存储目录，Android 才能访问到
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (e) {
        dir = await getApplicationDocumentsDirectory();
      }

      _downloadPath = '${dir!.path}/trip-route-track_$version.apk';
      print('[UpdateService] Downloading to: $_downloadPath');

      final file = File(_downloadPath!);
      final sink = file.openWrite();

      var received = 0;

      await _showProgressNotification(i18nService, version, 0, 0, total);

      await for (final chunk in response.stream) {
        if (_shouldStopDownload) {
          await sink.close();
          await file.delete();
          print('[UpdateService] Download stopped during transfer');
          return;
        }
        await sink.addStream(Stream.value(chunk));
        received += chunk.length;

        final progress = total > 0 ? ((received / total) * 100).round() : 0;

        if (progress < 100) {
          await _showProgressNotification(i18nService, version, progress, received, total);
        } else {
          // 到达100%，显示安装提示通知
          _waitingForInstall = true;
          await _showInstallPromptNotification(i18nService);
        }

        _onProgress?.call(progress, received, total);
      }

      await sink.close();
      print('[UpdateService] Download complete, file size: ${await file.length()} bytes');

      // 确保状态和通知都是安装提示
      if (!_waitingForInstall) {
        _waitingForInstall = true;
        await _showInstallPromptNotification(i18nService);
      }

      _onComplete?.call(true, null);
      _onInstallRequest?.call();

      if (autoInstall) {
        await Future.delayed(const Duration(milliseconds: 500));
        await installUpdate(i18nService);
      }
    } catch (e, stackTrace) {
      print('[UpdateService] Download failed: $e');
      print('[UpdateService] Stack trace: $stackTrace');
      await _showErrorNotification(i18nService, e.toString());
      _onComplete?.call(false, e.toString());
    } finally {
      _downloadClient?.close();
      _downloadClient = null;
      if (!_waitingForInstall) {
        _isDownloading = false;
      }
    }
  }

  /// 清理指定版本的APK文件
  Future<void> _cleanupVersionApk(String version) async {
    try {
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (e) {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) return;

      final apkPath = '${dir.path}/trip-route-track_$version.apk';
      final file = File(apkPath);

      if (await file.exists()) {
        await file.delete();
        print('[UpdateService] Deleted existing APK: $apkPath');
      }
    } catch (e) {
      print('[UpdateService] Failed to cleanup version APK: $e');
    }
  }

  /// 显示进度通知
  Future<void> _showProgressNotification(
    I18nService i18nService,
    String version,
    int progress,
    int receivedBytes,
    int totalBytes,
  ) async {
    try {
      final receivedStr = _formatBytes(receivedBytes);
      final totalStr = _formatBytes(totalBytes);
      
      await BridgeController().notificationService.showProgressNotification(
        title: i18nService.t('update_download_notification_title'),
        body: '$receivedStr / $totalStr',
        progress: progress,
        id: _downloadProgressNotificationId,
        channelId: 'update_channel',
        channelName: i18nService.t('update_channel_name'),
        channelDescription: i18nService.t('update_channel_description'),
      );
    } catch (e) {
      print('[UpdateService] Failed to show progress notification: $e');
    }
  }

  /// 显示安装提示通知
  Future<void> _showInstallPromptNotification(I18nService i18nService) async {
    try {
      print('[UpdateService] Showing install prompt notification');
      
      // 先取消下载进度通知
      print('[UpdateService] Canceling download progress notification');
      await BridgeController().notificationService.cancelNotification(_downloadProgressNotificationId);
      
      await BridgeController().notificationService.showNotification(
        title: i18nService.t('update_download_complete_notification_title'),
        body: i18nService.t('update_install_prompt'),
        id: _installPromptNotificationId,
        ongoing: true,
      );
    } catch (e) {
      print('[UpdateService] Failed to show install prompt notification: $e');
    }
  }

  /// 显示错误通知
  Future<void> _showErrorNotification(I18nService i18nService, String error) async {
    try {
      await BridgeController().notificationService.showNotification(
        title: i18nService.t('update_download_failed'),
        body: error,
        id: _downloadProgressNotificationId,
        ongoing: false,
      );
    } catch (e) {
      print('[UpdateService] Failed to show error notification: $e');
    }
  }
}
