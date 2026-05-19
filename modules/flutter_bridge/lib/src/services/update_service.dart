import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:i18n/i18n_service.dart';
import 'notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _packagesUrl = 'https://trip.aiiko.club/packages/';
  static const int _downloadNotificationId = 1001;

  bool _isDownloading = false;
  String? _currentVersion;
  String? _downloadPath;

  bool get isDownloading => _isDownloading;
  String? get currentVersion => _currentVersion;

  Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    // 启动时清理旧的 APK 文件
    await _cleanupOldApks();
  }

  Future<void> _cleanupOldApks() async {
    try {
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (e) {
        dir = await getApplicationDocumentsDirectory();
      }
      
      if (dir == null) return;
      
      print('Cleaning up old APK files in ${dir.path}');
      
      final files = dir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.apk')) {
          try {
            print('Deleting old APK: ${file.path}');
            await file.delete();
          } catch (e) {
            print('Failed to delete old APK: $e');
          }
        }
      }
    } catch (e) {
      print('Failed to clean up old APKs: $e');
    }
  }

  Future<VersionInfo?> checkNewVersion() async {
    try {
      print('UpdateService: checking new version...');
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('UpdateService: current version $currentVersion');
      
      print('UpdateService: requesting $_packagesUrl');
      
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(_packagesUrl));
        final response = await client.send(request);
        print('UpdateService: response status ${response.statusCode}');
        
        if (response.statusCode != 200) {
          print('UpdateService: request failed');
          return null;
        }

        final body = await response.stream.bytesToString();
        print('UpdateService: response body length ${body.length}');
        print('UpdateService: response body preview: ${body.substring(0, body.length > 500 ? 500 : body.length)}');
        
        final latestVersion = _parseLatestVersion(body);
        print('UpdateService: parsed latest version $latestVersion');

        if (latestVersion == null) {
          print('UpdateService: failed to parse version');
          return null;
        }

        final versionComparison = _compareVersion(latestVersion, currentVersion);
        print('UpdateService: compare $latestVersion vs $currentVersion = $versionComparison');

        if (versionComparison > 0) {
          final apkUrl = 'https://trip.aiiko.club/packages/trip-route-track-v$latestVersion-arm64-v8a.apk';
          print('UpdateService: new version available: $apkUrl');
          return VersionInfo(
            version: latestVersion,
            downloadUrl: apkUrl,
          );
        }

        print('UpdateService: no new version');
        return null;
      } finally {
        client.close();
      }
    } catch (e) {
      print('Check version failed: $e');
      return null;
    }
  }

  String? _parseLatestVersion(String html) {
    print('UpdateService: parsing HTML for versions');
    // 匹配 trip-route-track-v1.0.5-arm64-v8a.apk 格式
    final regex = RegExp(r'trip-route-track-v(\d+\.\d+\.\d+)[^<]*\.apk', caseSensitive: false);
    
    final allMatches = regex.allMatches(html).toList();
    print('UpdateService: found ${allMatches.length} possible versions');

    String? latestVersion;
    for (final match in allMatches) {
      final version = match.group(1);
      print('UpdateService: matched version: $version');
      
      if (version != null) {
        if (latestVersion == null || _compareVersion(version, latestVersion) > 0) {
          latestVersion = version;
        }
      }
    }

    print('UpdateService: selected latest version: $latestVersion');
    return latestVersion;
  }

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

  Future<void> downloadAndInstall({
    required String downloadUrl,
    required String version,
    Function(int received, int total)? onProgress,
    Function()? onComplete,
    Function(String error)? onError,
    required I18nService i18nService,
  }) async {
    if (_isDownloading) {
      return;
    }

    _isDownloading = true;

    // 重置下载完成标志
    NotificationService().setDownloadComplete(false);

    // 设置通知点击回调
    NotificationService().setDownloadNotificationCallback(
      () => _installApk(i18nService),
    );

    // 下载前清理旧的 APK 文件
    await _cleanupOldApks();

    final client = http.Client();

    try {
      // 请求存储权限（Android 10+ 可能需要）
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

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
      print('Downloading to: $_downloadPath');

      final file = File(_downloadPath!);
      final sink = file.openWrite();

      var received = 0;

      await NotificationService().showProgressNotification(
        title: i18nService.t('update_download_notification_title'),
        body: i18nService.t('update_download_notification_content', {'version': version}),
        progress: 0,
        id: _downloadNotificationId,
        channelId: 'update_channel',
        channelName: i18nService.t('update_channel_name'),
        channelDescription: i18nService.t('update_channel_description'),
      );

      await for (final chunk in response.stream) {
        await sink.addStream(Stream.value(chunk));
        received += chunk.length;

        final progress = total > 0 ? ((received / total) * 100).round() : 0;

        await NotificationService().showProgressNotification(
          title: i18nService.t('update_download_notification_title'),
          body: i18nService.t('update_download_progress', {'progress': '$progress'}),
          progress: progress,
          id: _downloadNotificationId,
          channelId: 'update_channel',
          channelName: i18nService.t('update_channel_name'),
          channelDescription: i18nService.t('update_channel_description'),
        );

        onProgress?.call(received, total);
      }

      await sink.close();
      print('Download complete, file size: ${await file.length()} bytes');

      // 设置下载完成标志，允许点击通知安装
      NotificationService().setDownloadComplete(true);

      await NotificationService().showNotification(
        title: i18nService.t('update_download_complete_notification_title'),
        body: i18nService.t('update_download_complete_notification_content'),
        id: _downloadNotificationId,
        ongoing: false,
      );

      onComplete?.call();

      // 下载完成后立即触发安装
      await Future.delayed(const Duration(milliseconds: 500));
      await _installApk(i18nService);
    } catch (e, stackTrace) {
      print('Download failed: $e');
      print('Stack trace: $stackTrace');
      await NotificationService().showNotificationWithAutoClose(
        title: i18nService.t('update_download_failed'),
        body: e.toString(),
        id: _downloadNotificationId,
      );
      onError?.call(e.toString());
    } finally {
      client.close();
      _isDownloading = false;
    }
  }

  Future<void> _installApk(I18nService i18nService) async {
    if (_downloadPath == null) {
      print('Install APK: _downloadPath is null');
      return;
    }

    final file = File(_downloadPath!);
    if (!await file.exists()) {
      print('Install APK: file not found at $_downloadPath');
      return;
    }

    final fileSize = await file.length();
    print('Install APK: file exists, size: $fileSize bytes');

    try {
      const platform = MethodChannel('flutter_bridge');
      print('Install APK: calling native installApk with path: $_downloadPath');
      await platform.invokeMethod('installApk', {
        'path': _downloadPath,
      });
      print('Install APK: native call returned successfully');
    } catch (e, stackTrace) {
      print('Install APK failed: $e');
      print('Stack trace: $stackTrace');
    }
  }

  String getDownloadPath() {
    return _downloadPath ?? '';
  }
}

class VersionInfo {
  final String version;
  final String downloadUrl;

  VersionInfo({
    required this.version,
    required this.downloadUrl,
  });
}