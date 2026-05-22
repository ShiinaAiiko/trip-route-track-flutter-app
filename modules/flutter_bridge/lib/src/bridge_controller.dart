import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:i18n/i18n.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'bridge_message.dart';
import 'services/keep_awake_service.dart';
import 'services/background_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/vehicle_service.dart';
import 'services/update_service.dart';
import 'services/log_service.dart';

typedef MessageHandler = void Function(BridgeMessage message);
typedef FlutterMethodCallHandler = void Function(MethodCall call);
typedef StatusBarChangeHandler = void Function(String type);
typedef UpdateCheckCallback = void Function(VersionInfo? versionInfo, String currentVersion, bool showCheckingNotification);
typedef UpdateCheckingCallback = void Function();
typedef LocalWebResourcesUpdateProgressCallback = void Function(int progress, String stage, int receivedBytes, int totalBytes);
typedef LocalWebResourcesUpdateCompleteCallback = void Function(bool success, String? error);
typedef SwitchResourcesCallback = void Function(String host);

class BridgeController {
  static final BridgeController _instance = BridgeController._internal();
  factory BridgeController() => _instance;
  BridgeController._internal();

  final KeepAwakeService _keepAwakeService = KeepAwakeService();
  final BackgroundService _backgroundService = BackgroundService();
  final LanguageService _languageService = LanguageService();
  final VehicleService _vehicleService = VehicleService();
  final I18nService _i18nService = I18nService();
  final UpdateService _updateService = UpdateService();
  final LogService _logService = LogService();

  String? _pendingUpdateVersion;

  MethodChannel? _channel;
  StreamSubscription<Position>? _positionSubscription;
  final Map<String, List<MessageHandler>> _messageHandlers = {};
  FlutterMethodCallHandler? _externalHandler;
  StatusBarChangeHandler? _statusBarChangeHandler;
  StreamSubscription<Map<String, dynamic>>? _carDataSubscription;
  UpdateCheckCallback? _updateCheckCallback;
  UpdateCheckingCallback? _updateCheckingCallback;
  LocalWebResourcesUpdateProgressCallback? _localWebResourcesUpdateProgressCallback;
  LocalWebResourcesUpdateCompleteCallback? _localWebResourcesUpdateCompleteCallback;
  SwitchResourcesCallback? _switchResourcesCallback;

  bool _enableLocation = false;
  bool _enableBackgroundLocation = false;
  int _backgroundLocationCount = 0;
  int _backgroundStartTime = 0;
  
  // 通知自动关闭定时器映射（key: notificationId, value: Timer）
  final Map<int, Timer> _notificationTimers = {};
  double _currentSpeed = 0;
  double _currentAltitude = 0;
  Timer? _backgroundNotificationTimer;
  int _notificationIdCounter = 1;

  bool get enableLocation => _enableLocation;
  bool get enableBackgroundLocation => _enableBackgroundLocation;
  bool get keepScreenOn => _keepAwakeService.isKeepAwake;
  bool get enableBackgroundTasks => _backgroundService.enableBackgroundTasks;
  String get currentLanguage => _languageService.currentLanguage;
  LanguageService get languageService => _languageService;
  VehicleService get vehicleService => _vehicleService;
  I18nService get i18nService => _i18nService;
  UpdateService get updateService => _updateService;
  LogService get logService => _logService;

  Future<void> init() async {
    await _checkAndResetResourcesOnUpdate();
    await _i18nService.init();
    await _languageService.init();
    await _vehicleService.init();
    await _updateService.init();
    await _logService.init();
    _setupCarDataListener();
  }

  Future<void> _checkAndResetResourcesOnUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      final prefs = await SharedPreferences.getInstance();
      final lastVersion = prefs.getString(_prefsKeyLastVersion);
      
      if (lastVersion != currentVersion) {
        print('[Bridge] App updated from version $lastVersion to $currentVersion');
        
        // 删除旧的静态资源目录
        final dir = await getApplicationDocumentsDirectory();
        final staticDir = Directory('${dir.path}/static_resources');
        if (await staticDir.exists()) {
          await staticDir.delete(recursive: true);
          print('[Bridge] Deleted old static resources directory');
        }
        
        // 清除自定义域名设置
        _customHost = null;
        await prefs.remove(_prefsKeyCustomHost);
        print('[Bridge] Reset custom host to default');
        
        // 保存新版本号
        await prefs.setString(_prefsKeyLastVersion, currentVersion);
        print('[Bridge] Saved new version: $currentVersion');
      }
    } catch (e) {
      print('[Bridge] Error checking version or resetting resources: $e');
    }
  }

  void _setupCarDataListener() {
    _carDataSubscription = _vehicleService.carDataStream?.listen((data) {
      sendMessage('carData', data);
    });
  }

  void setChannel(MethodChannel? channel) {
    _channel = channel;
    _channel?.setMethodCallHandler(_handleMethodCall);
  }

  void setExternalHandler(FlutterMethodCallHandler? handler) {
    _externalHandler = handler;
  }

  void on(String type, MessageHandler handler) {
    _messageHandlers.putIfAbsent(type, () => []);
    _messageHandlers[type]!.add(handler);
  }

  void off(String type, MessageHandler handler) {
    _messageHandlers[type]?.remove(handler);
  }

  void setStatusBarChangeHandler(StatusBarChangeHandler handler) {
    _statusBarChangeHandler = handler;
  }

  void setUpdateCheckCallback(UpdateCheckCallback callback) {
    _updateCheckCallback = callback;
  }

  void setUpdateCheckingCallback(UpdateCheckingCallback callback) {
    _updateCheckingCallback = callback;
  }

  void setLocalWebResourcesUpdateProgressCallback(LocalWebResourcesUpdateProgressCallback callback) {
    _localWebResourcesUpdateProgressCallback = callback;
  }

  void setLocalWebResourcesUpdateCompleteCallback(LocalWebResourcesUpdateCompleteCallback? callback) {
    _localWebResourcesUpdateCompleteCallback = callback;
  }

  void setSwitchResourcesCallback(SwitchResourcesCallback? callback) {
    _switchResourcesCallback = callback;
  }

  void handleWebMessage(String messageString) {
    _handleWebMessage(messageString);
  }

  void _dispatchMessage(BridgeMessage message) {
    final handlers = _messageHandlers[message.type];
    if (handlers != null) {
      for (final handler in handlers) {
        handler(message);
      }
    }
  }

  Future<void> sendMessage(String type, dynamic payload, {String? bridgeId}) async {
    if (_channel == null) return;

    final message = BridgeMessage(
      type: type,
      payload: payload,
      bridgeId: bridgeId,
    );
    final jsonString = jsonEncode(message.toJson());

    await _channel?.invokeMethod('postMessage', {
      'message': jsonString,
    });
  }

  Future<void> _handleEnableLocation(bool enable) async {
    if (enable) {
      final status = await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) {
          sendMessage('gpsPermissionDenied', {
            'title': _i18nService.t('gps_permission_denied'),
            'message': '',
            'type': 'warning',
            'notification': true,
            'module': 'location',
          });
          return;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        sendMessage('gpsServiceDisabled', {
          'title': _i18nService.t('gps_service_disabled'),
          'message': '',
          'type': 'warning',
          'notification': true,
          'module': 'location',
        });
        return;
      }

      _startLocationUpdatesInternal();

      sendMessage('locationEnabled', {
        'title': _i18nService.t('location_enabled'),
        'message': '',
        'type': 'success',
        'notification': true,
        'module': 'location',
      });
    } else {
      _stopLocationUpdates();

      sendMessage('locationDisabled', {
        'title': _i18nService.t('location_disabled'),
        'message': '',
        'type': 'info',
        'notification': true,
        'module': 'location',
      });
    }
  }

  void _startLocationUpdatesInternal() {
    if (_positionSubscription != null) {
      _positionSubscription!.cancel();
    }

    AndroidSettings androidSettings;

    if (_enableBackgroundLocation) {
      androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
      );
    } else {
      androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: Duration(seconds: 1),
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: androidSettings,
    ).listen(
      (Position position) {
        _currentSpeed = position.speed;
        _currentAltitude = position.altitude;

        if (_enableBackgroundLocation) {
          _backgroundLocationCount++;
        } else if (_backgroundService.isRunning) {
          _backgroundLocationCount++;
        }

        sendMessage('location', {
          'coords': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'altitude': position.altitude,
            'accuracy': position.accuracy,
            'heading': position.heading,
            'speed': position.speed,
          },
          'timestamp': position.timestamp.millisecondsSinceEpoch,
        });
      },
      onError: (error) {
        sendMessage('gpsError', {
          'title': _i18nService.t('gps_error'),
          'message': 'Location failed: $error',
          'type': 'error',
          'notification': true,
          'module': 'location',
        });
      },
    );
  }

  void _stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _handleKeepScreenOn(bool enable) {
    _keepAwakeService.setKeepAwake(enable);
    
    if (enable) {
      sendMessage('screenKeptOn', {
        'title': _i18nService.t('screen_kept_on'),
        'message': '',
        'type': 'success',
        'notification': true,
        'module': 'keepAwake',
      });
    } else {
      sendMessage('screenKeptOff', {
        'title': _i18nService.t('screen_kept_off'),
        'message': '',
        'type': 'info',
        'notification': true,
        'module': 'keepAwake',
      });
    }
  }

  Future<void> _handleEnableBackgroundLocation(bool enable) async {
    if (enable) {
      if (!_enableLocation) {
        sendMessage('backgroundLocationEnableFailed', {
          'title': _i18nService.t('background_location_enable_failed'),
          'message': _i18nService.t('foreground_location_first'),
          'type': 'error',
          'notification': true,
          'module': 'backgroundLocation',
        });
        _enableBackgroundLocation = false;
        return;
      }

      var foregroundStatus = await Permission.locationWhenInUse.status;
      if (foregroundStatus.isDenied) {
        foregroundStatus = await Permission.locationWhenInUse.request();
        if (!foregroundStatus.isGranted) {
          sendMessage('backgroundLocationEnableFailed', {
            'title': _i18nService.t('background_location_enable_failed'),
            'message': _i18nService.t('foreground_location_permission_denied'),
            'type': 'error',
            'notification': true,
            'module': 'backgroundLocation',
          });
          _enableBackgroundLocation = false;
          return;
        }
      }

      var backgroundStatus = await Permission.locationAlways.status;
      if (backgroundStatus.isDenied) {
        backgroundStatus = await Permission.locationAlways.request();
        if (!backgroundStatus.isGranted) {
          sendMessage('backgroundLocationEnableFailed', {
            'title': _i18nService.t('background_location_enable_failed'),
            'message': _i18nService.t('background_location_permission_denied'),
            'type': 'error',
            'notification': true,
            'module': 'backgroundLocation',
          });
          _enableBackgroundLocation = false;
          return;
        }
      }

      _enableBackgroundLocation = true;
      _backgroundLocationCount = 0;
      _backgroundStartTime = DateTime.now().millisecondsSinceEpoch;
      
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      
      try {
        await _backgroundService.start();
      } catch (e) {
        print('Failed to start background service: $e');
        sendMessage('backgroundServiceStartFailed', {
          'title': _i18nService.t('background_service_start_failed'),
          'message': '',
          'type': 'error',
          'notification': true,
          'module': 'backgroundLocation',
        });
        _enableBackgroundLocation = false;
        return;
      }
      
      if (_enableLocation) {
        _startLocationUpdatesInternal();
      }

      _startBackgroundNotificationTimer();
    } else {
      _enableBackgroundLocation = false;
      
      _stopBackgroundNotificationTimer();
      // 取消通知（id=3 是 Flutter 端创建的，id=1 是原生端 BackgroundService 创建的）
      // NotificationService().cancelNotification(3);
      // NotificationService().cancelNotification(1);
      await _backgroundService.stop();
      
      if (_enableLocation) {
        _startLocationUpdatesInternal();
      }

      sendMessage('backgroundLocationDisabled', {
        'title': _i18nService.t('background_location_disabled'),
        'message': '',
        'type': 'info',
        'notification': true,
        'module': 'backgroundLocation',
      });
    }
  }

  void _startBackgroundNotificationTimer() {
    _stopBackgroundNotificationTimer();
    _backgroundNotificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateBackgroundNotification();
    });
  }

  void _stopBackgroundNotificationTimer() {
    _backgroundNotificationTimer?.cancel();
    _backgroundNotificationTimer = null;
  }

  Future<void> _updateBackgroundNotification() async {
    if (!_enableBackgroundLocation) return;

    final int elapsed = DateTime.now().millisecondsSinceEpoch - _backgroundStartTime;
    final int minutes = (elapsed ~/ 1000) ~/ 60;
    final int seconds = (elapsed ~/ 1000) % 60;
    
    final durationText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    _backgroundService.updateNotification(
      taskTitle: _i18nService.t('background_location_title'),
      taskDesc: _i18nService.t('background_location_content', {'duration': durationText, 'count': '$_backgroundLocationCount'}),
    );
  }

Future<void> _handleLoadMessage() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      sendMessage('appConfig', {
        'version': packageInfo.version,       // 例如 "1.0.5"
        'buildNumber': packageInfo.buildNumber, // 例如 "11372"
        'fullVersion': '${packageInfo.version}+${packageInfo.buildNumber}', // 组合版
        'system': 'Flutter App',
      });
    } catch (e) {
      sendMessage('appConfig', {
        'version': 'unknown',
        'buildNumber': 'unknown',
        'fullVersion':'unknown',
        'system': 'Flutter App',
      });
    }
  }

  void _handleSetStatusBar(String type) {
    switch (type) {
      case 'system':
        // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
        );
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
        );
        break;
      case 'light':
        // 使用 manual 模式，确保底部导航栏可见且有背景色
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
        );
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );
        break;
      case 'dark':
        // 使用 manual 模式，确保底部导航栏可见且有背景色
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
        );
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );
        break;
      case 'transparent':
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.black.withOpacity(0.5),
            statusBarIconBrightness: Brightness.light,
          ),
        );
        break;
      case 'hide':
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        break;
      case 'transparent-light':
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        );
        break;
      case 'transparent-dark':
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        );
        break;
    }
    _statusBarChangeHandler?.call(type);
  }

  void _handleGetThemeColor({String? bridgeId}) {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    sendMessage('getThemeColor', brightness == Brightness.dark ? 'dark' : 'light', bridgeId: bridgeId);
  }

  void _handleGetStatusBarData({String? bridgeId}) {
    final mediaQuery = MediaQueryData.fromWindow(WidgetsBinding.instance.window);
    final statusBarHeight = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final viewPaddingTop = mediaQuery.viewPadding.top;
    final viewPaddingBottom = mediaQuery.viewPadding.bottom;
    final viewInsetsTop = mediaQuery.viewInsets.top;
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final size = WidgetsBinding.instance.window.physicalSize;
    final devicePixelRatio = WidgetsBinding.instance.window.devicePixelRatio;
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    
    final statusBarData = {
      'statusBarHeight': statusBarHeight,
      'bottomPadding': bottomPadding,
      'viewPaddingTop': viewPaddingTop,
      'viewPaddingBottom': viewPaddingBottom,
      'viewInsetsTop': viewInsetsTop,
      'viewInsetsBottom': viewInsetsBottom,
      'screenWidth': size.width / devicePixelRatio,
      'screenHeight': size.height / devicePixelRatio,
      'physicalWidth': size.width,
      'physicalHeight': size.height,
      'devicePixelRatio': devicePixelRatio,
      'isDarkMode': brightness == Brightness.dark,
      'safeAreaTop': statusBarHeight,
      'safeAreaBottom': bottomPadding,
    };
    sendMessage('getStatusBarData', statusBarData, bridgeId: bridgeId);
  }

  Future<void> _handleCheckNewVersion({bool showCheckingNotification = true}) async {
    print('Starting checkNewVersion... (showCheckingNotification: $showCheckingNotification)');
    if (showCheckingNotification) {
      _updateCheckingCallback?.call();
    }
    final versionInfo = await _updateService.checkNewVersion();
    print('versionInfo: $versionInfo');

    if (versionInfo != null) {
      _pendingUpdateVersion = versionInfo.version;
      print('Sending updateAvailable message');

      sendMessage('updateAvailable', {
        'version': versionInfo.version,
        'downloadUrl': versionInfo.downloadUrl,
      });
      
      _updateCheckCallback?.call(versionInfo, _updateService.currentVersion ?? 'unknown', showCheckingNotification);
    } else {
      print('Sending updateNotAvailable message');
      sendMessage('updateNotAvailable', {
        'currentVersion': _updateService.currentVersion ?? 'unknown',
      });
      
      _updateCheckCallback?.call(null, _updateService.currentVersion ?? 'unknown', showCheckingNotification);
    }
  }

  void startUpdate(String downloadUrl, String version) {
    _updateService.downloadAndInstall(
      downloadUrl: downloadUrl,
      version: version,
      i18nService: _i18nService,
      onProgress: (received, total) {
        sendMessage('updateProgress', {
          'received': received,
          'total': total,
          'progress': total > 0 ? ((received / total) * 100).round() : 0,
        });
      },
      onComplete: () {
        sendMessage('updateComplete', {
          'version': version,
        });
      },
      onError: (error) {
        sendMessage('updateError', {
          'error': error,
        });
      },
    );
  }

  Future<void> skipUpdate(String version) async {
    sendMessage('skipVersion', version);
  }

  static const String _prefsKeyCustomHost = 'custom_host';
  static const String _prefsKeyLastVersion = 'last_app_version';
  String? _customHost;

  Future<void> _handleSwitchResources(String host, {String? bridgeId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customHost = host;
      await prefs.setString(_prefsKeyCustomHost, host);
      _switchResourcesCallback?.call(host);
      sendMessage('switchResources', {'success': true, 'host': host}, bridgeId: bridgeId);
    } catch (e) {
      sendMessage('switchResources', {'success': false, 'error': e.toString()}, bridgeId: bridgeId);
    }
  }

  Future<String?> getCustomHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKeyCustomHost);
  }

  Future<void> _handleUpdateLocalWebResources(String downloadUrl, {String? bridgeId}) async {
    try {
      print('[Bridge] Starting download: $downloadUrl');
      _localWebResourcesUpdateProgressCallback?.call(0, 'downloading', 0, 0);
      sendMessage('updateLocalWebResourcesDownloading', {'progress': 0}, bridgeId: bridgeId);

      final client = http.Client();
      final response = await client.send(http.Request('GET', Uri.parse(downloadUrl)));
      final total = response.contentLength ?? 0;
      var received = 0;
      final bytes = <int>[];
      
      print('[Bridge] Total content length: $total bytes');

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        final progress = total > 0 ? ((received / total) * 100).round() : 0;
        print('[Bridge] Download progress: $progress% ($received/$total)');
        _localWebResourcesUpdateProgressCallback?.call(progress, 'downloading', received, total);
        sendMessage('updateLocalWebResourcesDownloading', {'progress': progress}, bridgeId: bridgeId);
      }

      client.close();
      
      print('[Bridge] Download complete');
      _localWebResourcesUpdateProgressCallback?.call(100, 'downloading', total, total);
      sendMessage('updateLocalWebResourcesDownloading', {'progress': 100}, bridgeId: bridgeId);

      _localWebResourcesUpdateProgressCallback?.call(0, 'extracting', 0, 0);
      sendMessage('updateLocalWebResourcesExtracting', {'progress': 0}, bridgeId: bridgeId);

      final dir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${dir.path}/temp_update');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
      final totalFiles = archive.files.where((f) => f.isFile).length;
      var extractedFiles = 0;

      for (final file in archive) {
        if (file.isFile) {
          String fileName = file.name;
          if (fileName.startsWith('./')) {
            fileName = fileName.substring(2);
          }
          final filePath = '${tempDir.path}/$fileName';
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
          extractedFiles++;
          final progress = ((extractedFiles / totalFiles) * 100).round();
          _localWebResourcesUpdateProgressCallback?.call(progress, 'extracting', 0, 0);
          sendMessage('updateLocalWebResourcesExtracting', {'progress': progress}, bridgeId: bridgeId);
        }
      }

      _localWebResourcesUpdateProgressCallback?.call(100, 'extracting', 0, 0);
      sendMessage('updateLocalWebResourcesExtracting', {'progress': 100}, bridgeId: bridgeId);

      final staticDir = Directory('${dir.path}/static_resources');
      if (await staticDir.exists()) {
        await staticDir.delete(recursive: true);
      }
      await tempDir.rename(staticDir.path);

      _localWebResourcesUpdateCompleteCallback?.call(true, null);
      sendMessage('updateLocalWebResourcesCompleted', {'success': true}, bridgeId: bridgeId);
    } catch (e) {
      _localWebResourcesUpdateCompleteCallback?.call(false, e.toString());
      sendMessage('updateLocalWebResourcesCompleted', {'success': false, 'error': e.toString()}, bridgeId: bridgeId);
    }
  }

  Future<Directory?> getStaticResourcesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final staticDir = Directory('${dir.path}/static_resources');
    if (await staticDir.exists()) {
      return staticDir;
    }
    return null;
  }

  Future<void> _handleRestartApp() async {
    const MethodChannel channel = MethodChannel('flutter_bridge');
    await channel.invokeMethod('restartApp');
  }

  Future<void> restartApp() async {
    await _handleRestartApp();
  }

  Future<void> quitApp() async {
    await _handleQuitApp();
  }

  Future<void> _handleQuitApp() async {
    const MethodChannel channel = MethodChannel('flutter_bridge');
    await channel.invokeMethod('quitApp');
  }

  Future<void> _handleSendNotification(Map<String, dynamic> payload, {String? bridgeId}) async {
    try {
      final id = payload['id'] is int ? payload['id'] : (payload['id'] is String ? int.tryParse(payload['id']) : null) ?? _notificationIdCounter++;
      final title = payload['title']?.toString() ?? '';
      final body = payload['body']?.toString() ?? '';
      final ongoing = payload['ongoing'] as bool? ?? false;
      final closable = payload['closable'] as bool? ?? true;
      final autoCloseTimeout = payload['autoCloseTimeout'] as int?;
      final channelId = payload['channelId']?.toString() ?? 'trip_route_channel';
      final channelName = payload['channelName']?.toString() ?? 'Trip Route';
      final channelDescription = payload['channelDescription']?.toString() ?? 'Trip Route Track Notifications';
      final priority = _parsePriority(payload['priority']);
      final sound = payload['sound'];
      final vibrate = payload['vibrate'] as bool? ?? true;
      final badge = payload['badge'] as int?;
      final clickActionType = payload['clickActionType']?.toString();
      final clickActionUrl = payload['clickActionUrl']?.toString();
      final extra = payload['extra'] as Map<String, dynamic>?;

      // 如果同一个 id 的通知已存在且有自动关闭定时器，先取消定时器（续期）
      if (_notificationTimers.containsKey(id)) {
        _notificationTimers[id]!.cancel();
        _notificationTimers.remove(id);
      }

      final AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: priority,
        priority: Priority.defaultPriority,
        ticker: 'ticker',
        ongoing: ongoing,
        autoCancel: !ongoing && closable,
        channelShowBadge: true,
        onlyAlertOnce: true,
        vibrationPattern: vibrate ? null : Int64List(0),
        number: badge,
      );

      await NotificationService().showNotification(
        title: title,
        body: body,
        id: id,
        ongoing: ongoing,
        androidDetails: androidNotificationDetails,
      );

      // 设置新的自动关闭定时器
      if (autoCloseTimeout != null && autoCloseTimeout > 0 && !ongoing) {
        final timer = Timer(Duration(milliseconds: autoCloseTimeout), () {
          NotificationService().cancelNotification(id);
          _notificationTimers.remove(id);
        });
        _notificationTimers[id] = timer;
      }

      sendMessage('sendNotification', {'success': true, 'id': id}, bridgeId: bridgeId);
    } catch (e) {
      sendMessage('sendNotification', {'success': false, 'error': e.toString()}, bridgeId: bridgeId);
    }
  }

  Importance _parsePriority(dynamic priority) {
    switch (priority) {
      case 'min':
        return Importance.min;
      case 'low':
        return Importance.low;
      case 'high':
        return Importance.high;
      case 'max':
        return Importance.max;
      default:
        return Importance.defaultImportance;
    }
  }

  Future<void> _handleCancelNotification(dynamic id, {String? bridgeId}) async {
    try {
      int? notificationId;
      if (id is int) {
        notificationId = id;
      } else if (id is String) {
        notificationId = int.tryParse(id);
      }

      if (notificationId != null) {
        await NotificationService().cancelNotification(notificationId);
        sendMessage('cancelNotification', {'success': true}, bridgeId: bridgeId);
      } else {
        sendMessage('cancelNotification', {'success': false, 'error': 'Invalid notification ID'}, bridgeId: bridgeId);
      }
    } catch (e) {
      sendMessage('cancelNotification', {'success': false, 'error': e.toString()}, bridgeId: bridgeId);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWebMessage':
        _handleWebMessage(call.arguments as String);
        break;
    }
    _externalHandler?.call(call);
  }

  void _handleWebMessage(String messageString) {
    try {
      final Map<String, dynamic> json = jsonDecode(messageString) as Map<String, dynamic>;
      final message = BridgeMessage.fromJson(json);
      
      // 提取 bridgeId
      final bridgeId = message.bridgeId;
      
      print('message.type ${message.type}');
      switch (message.type) {
        case 'load':
          _handleLoadMessage();
          break;
        case 'enableLocation':
          _enableLocation = message.payload as bool;
          _handleEnableLocation(_enableLocation);
          _dispatchMessage(message);
          break;
        case 'keepScreenOn':
          final keepOn = message.payload as bool;
          _handleKeepScreenOn(keepOn);
          _dispatchMessage(message);
          break;
        case 'enableBackgroundLocation':
          _enableBackgroundLocation = message.payload as bool;
          _handleEnableBackgroundLocation(_enableBackgroundLocation);
          _dispatchMessage(message);
          break;
        case 'enableBackgroundTasks':
          final enable = message.payload as bool;
          _backgroundService.setEnableBackgroundTasks(enable);
          if (enable) {
            _backgroundStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            _backgroundLocationCount = 0;
          }
          _dispatchMessage(message);
          break;
        case 'setLanguage':
          final lang = message.payload as String?;
          if (lang != null) {
            _languageService.setLanguage(lang);
            _i18nService.setLanguage(lang);
          }
          _dispatchMessage(message);
          break;
        case 'enableCarData':
          final enableCar = message.payload as bool;
          if (enableCar) {
            _vehicleService.startCarDataUpdates();
          } else {
            _vehicleService.stopCarDataUpdates();
          }
          _dispatchMessage(message);
          break;
        case 'getCarData':
          _vehicleService.requestCarData();
          _dispatchMessage(message);
          break;
        case 'setStatusBar':
          final statusType = message.payload as String?;
          if (statusType != null) {
            _handleSetStatusBar(statusType);
          }
          _dispatchMessage(message);
          break;
        case 'getStatusBarData':
          _handleGetStatusBarData(bridgeId: bridgeId);
          _dispatchMessage(message);
          break;
        case 'getThemeColor':
          _handleGetThemeColor(bridgeId: bridgeId);
          _dispatchMessage(message);
          break;
        case 'checkNewVersion':
          final showCheckingNotification = message.payload is Map
              ? (message.payload as Map)['showCheckingNotification'] as bool? ?? true
              : true;
          _handleCheckNewVersion(showCheckingNotification: showCheckingNotification);
          _dispatchMessage(message);
          break;
        case 'switchResources':
          final host = message.payload as String?;
          if (host != null) {
            _handleSwitchResources(host, bridgeId: bridgeId);
          }
          _dispatchMessage(message);
          break;
        case 'updateLocalWebResources':
          final url = message.payload as String?;
          if (url != null) {
            _handleUpdateLocalWebResources(url, bridgeId: bridgeId);
          }
          _dispatchMessage(message);
          break;
        case 'restartApp':
          _handleRestartApp();
          _dispatchMessage(message);
          break;
        case 'quitApp':
          _handleQuitApp();
          _dispatchMessage(message);
          break;
        case 'sendNotification':
          if (message.payload is Map) {
            _handleSendNotification(message.payload as Map<String, dynamic>, bridgeId: bridgeId);
          }
          _dispatchMessage(message);
          break;
        case 'cancelNotification':
          final cancelId = message.payload;
          _handleCancelNotification(cancelId, bridgeId: bridgeId);
          _dispatchMessage(message);
          break;
        case 'thirdPartyLogin':
          final type = message.payload as String?;
          if (type != null) {
            _handleThirdPartyLogin(type, bridgeId: bridgeId);
          }
          _dispatchMessage(message);
          break;
        default:
          _dispatchMessage(message);
      }
    } catch (e) {
      print('Failed to handle web message: $e');
    }
  }

  void startLocationUpdates({
    required Function(Position) onPositionChange,
    Function(String)? onError,
  }) {
    if (_positionSubscription != null) {
      _positionSubscription!.cancel();
    }

    print('gps1 startLocationUpdates');

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: Duration(seconds: 1),
      ),
    ).listen(
      (Position position) {
        _currentSpeed = position.speed;
        _currentAltitude = position.altitude;

        if (_backgroundService.isRunning) {
          _backgroundLocationCount++;
        }
    print('gps1 sendMessage location $position');

        sendMessage('location', {
          'coords': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'altitude': position.altitude,
            'accuracy': position.accuracy,
            'heading': position.heading,
            'speed': position.speed,
          },
          'timestamp': position.timestamp.millisecondsSinceEpoch,
        });

        onPositionChange(position);
      },
      onError: (error) {
        onError?.call(error.toString());
      },
    );
  }

  void stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void updateBackgroundNotification() {
    if (!_backgroundService.isRunning) return;

    final duration = DateTime.now().millisecondsSinceEpoch ~/ 1000 - _backgroundStartTime;
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    final speedKmh = (_currentSpeed * 3600) / 1000;
    final altitudeM = _currentAltitude;

    String formatDuration() {
      final parts = <String>[];
      if (hours > 0) parts.add('${hours}h');
      if (minutes > 0) parts.add('${minutes}m');
      if (seconds > 0) parts.add('${seconds}s');
      return parts.isEmpty ? '0s' : parts.join(' ');
    }

    _backgroundService.updateNotification(
      taskTitle: _i18nService.t('background_tracking_title'),
      taskDesc: _i18nService.t('background_tracking_content', {
        'duration': formatDuration(),
        'count': '$_backgroundLocationCount',
        'speed': '${(speedKmh * 10).round() / 10}',
        'altitude': '${(altitudeM * 10).round() / 10}',
      }),
    );
  }

  // ================================
  // 应用生命周期事件
  // ================================
  
  /// App 刚启动打开事件
  void sendAppStartEvent() {
    sendMessage('appStart', {});
  }
  
  /// 重新回到 App 事件（前台可见且可交互）
  void sendAppResumeEvent() {
    sendMessage('appResume', {});
  }
  
  /// 离开 App 进入后台事件
  void sendAppPauseEvent() {
    sendMessage('appPause', {});
  }
  
  /// App 进入非活动状态（比如收到电话、弹出对话框）
  void sendAppInactiveEvent() {
    sendMessage('appInactive', {});
  }
  
  /// App 完全隐藏事件
  void sendAppHiddenEvent() {
    sendMessage('appHidden', {});
  }
  
  /// 通用的应用生命周期状态变化事件
  void sendAppLifecycleChangeEvent(String state) {
    sendMessage('appLifecycleChange', {'state': state});
  }
  
  // 第三方登录类型
  static const String loginTypeGoogle = 'google';
  static const String loginTypeQq = 'qq';
  static const String loginTypeGithub = 'github';

  // 第三方登录处理
  Future<void> _handleThirdPartyLogin(String type, {String? bridgeId}) async {
    print('[Bridge] Third party login requested: $type');
    
    try {
      const MethodChannel channel = MethodChannel('flutter_bridge');
      final result = await channel.invokeMethod('thirdPartyLogin', {'type': type});
      
      print('[Bridge] Third party login result: $result');
      
      final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result as Map);
      final bool success = resultMap['success'] as bool;
      
      if (success) {
        sendMessage('thirdPartyLogin', {
          'success': true,
          'data': {
            'type': type,
            'idToken': resultMap['idToken'],
            'accessToken': resultMap['accessToken'],
            'user': {
              'id': resultMap['userId'],
              'name': resultMap['userName'],
              'email': resultMap['userEmail'],
              'avatar': resultMap['userAvatar'],
            },
          },
        }, bridgeId: bridgeId);
      } else {
        sendMessage('thirdPartyLogin', {
          'success': false,
          'error': resultMap['error'] as String? ?? 'Login failed',
        }, bridgeId: bridgeId);
      }
    } catch (e) {
      print('[Bridge] Third party login error: $e');
      sendMessage('thirdPartyLogin', {
        'success': false,
        'error': e.toString(),
      }, bridgeId: bridgeId);
    }
  }

  void dispose() {
    _positionSubscription?.cancel();
    _carDataSubscription?.cancel();
    _vehicleService.dispose();
    _messageHandlers.clear();
  }
}
