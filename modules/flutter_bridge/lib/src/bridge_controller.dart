import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:i18n/i18n.dart';
import 'bridge_message.dart';
import 'services/keep_awake_service.dart';
import 'services/background_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/vehicle_service.dart';

typedef MessageHandler = void Function(BridgeMessage message);
typedef FlutterMethodCallHandler = void Function(MethodCall call);
typedef StatusBarChangeHandler = void Function(String type);

class BridgeController {
  static final BridgeController _instance = BridgeController._internal();
  factory BridgeController() => _instance;
  BridgeController._internal();

  final KeepAwakeService _keepAwakeService = KeepAwakeService();
  final BackgroundService _backgroundService = BackgroundService();
  final LanguageService _languageService = LanguageService();
  final VehicleService _vehicleService = VehicleService();
  final I18nService _i18nService = I18nService();

  MethodChannel? _channel;
  StreamSubscription<Position>? _positionSubscription;
  final Map<String, List<MessageHandler>> _messageHandlers = {};
  FlutterMethodCallHandler? _externalHandler;
  StatusBarChangeHandler? _statusBarChangeHandler;
  StreamSubscription<Map<String, dynamic>>? _carDataSubscription;

  bool _enableLocation = false;
  bool _enableBackgroundLocation = false;
  int _backgroundLocationCount = 0;
  int _backgroundStartTime = 0;
  double _currentSpeed = 0;
  double _currentAltitude = 0;
  Timer? _backgroundNotificationTimer;

  bool get enableLocation => _enableLocation;
  bool get enableBackgroundLocation => _enableBackgroundLocation;
  bool get keepScreenOn => _keepAwakeService.isKeepAwake;
  bool get enableBackgroundTasks => _backgroundService.enableBackgroundTasks;
  String get currentLanguage => _languageService.currentLanguage;
  LanguageService get languageService => _languageService;
  VehicleService get vehicleService => _vehicleService;
  I18nService get i18nService => _i18nService;

  Future<void> init() async {
    await _i18nService.init();
    await _languageService.init();
    await _vehicleService.init();
    _setupCarDataListener();
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

  Future<void> sendMessage(String type, dynamic payload) async {
    if (_channel == null) return;

    final message = BridgeMessage(type: type, payload: payload);
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
          sendMessage('notification', {
            'title': _i18nService.t('gps_permission_denied'),
            'message': '',
            'type': 'warning',
          });
          return;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        sendMessage('notification', {
          'title': _i18nService.t('gps_service_disabled'),
          'message': '',
          'type': 'warning',
        });
        return;
      }

      _startLocationUpdatesInternal();

      NotificationService().showNotificationWithAutoClose(
        title: _i18nService.t('location_enabled'),
        body: '',
        id: 1,
      );
    } else {
      _stopLocationUpdates();

      NotificationService().showNotificationWithAutoClose(
        title: _i18nService.t('location_disabled'),
        body: '',
        id: 1,
      );
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
        sendMessage('notification', {
          'title': _i18nService.t('gps_error'),
          'message': 'Location failed: $error',
          'type': 'error',
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
      NotificationService().showNotificationWithAutoClose(
        title: _i18nService.t('screen_kept_on'),
        body: '',
        id: 2,
      );
    } else {
      NotificationService().showNotificationWithAutoClose(
        title: _i18nService.t('screen_kept_off'),
        body: '',
        id: 2,
      );
    }
  }

  Future<void> _handleEnableBackgroundLocation(bool enable) async {
    if (enable) {
      if (!_enableLocation) {
        NotificationService().showNotificationWithAutoClose(
          title: _i18nService.t('background_location_enable_failed'),
          body: _i18nService.t('foreground_location_first'),
          id: 3,
        );
        _enableBackgroundLocation = false;
        return;
      }

      var foregroundStatus = await Permission.locationWhenInUse.status;
      if (foregroundStatus.isDenied) {
        foregroundStatus = await Permission.locationWhenInUse.request();
        if (!foregroundStatus.isGranted) {
          NotificationService().showNotification(
            title: _i18nService.t('background_location_enable_failed'),
            body: _i18nService.t('foreground_location_permission_denied'),
            id: 3,
          );
          _enableBackgroundLocation = false;
          return;
        }
      }

      var backgroundStatus = await Permission.locationAlways.status;
      if (backgroundStatus.isDenied) {
        backgroundStatus = await Permission.locationAlways.request();
        if (!backgroundStatus.isGranted) {
          NotificationService().showNotification(
            title: _i18nService.t('background_location_enable_failed'),
            body: _i18nService.t('background_location_permission_denied'),
            id: 3,
          );
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
        NotificationService().showNotification(
          title: _i18nService.t('background_service_start_failed'),
          body: '',
          id: 5,
        );
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
      NotificationService().cancelNotification(3);
      NotificationService().cancelNotification(1);
      await _backgroundService.stop();
      
      if (_enableLocation) {
        _startLocationUpdatesInternal();
      }

      NotificationService().showNotificationWithAutoClose(
        title: _i18nService.t('background_location_disabled'),
        body: '',
        id: 4,
      );
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

  void _handleGetThemeColor() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    sendMessage('getThemeColor', brightness == Brightness.dark ? 'dark' : 'light');
  }

  void _handleGetStatusBarData() {
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
    sendMessage('getStatusBarData', statusBarData);
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
          _handleKeepScreenOn(message.payload as bool);
          _dispatchMessage(message);
          break;
        case 'enableBackgroundLocation':
          _enableBackgroundLocation = message.payload as bool;
          _handleEnableBackgroundLocation(_enableBackgroundLocation);
          _dispatchMessage(message);
          break;
        case 'enableBackgroundTasks':
          _backgroundService.setEnableBackgroundTasks(message.payload as bool);
          if (message.payload as bool) {
            _backgroundStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            _backgroundLocationCount = 0;
          }
          _dispatchMessage(message);
          break;
        case 'setLanguage':
          _languageService.setLanguage(message.payload as String);
          _i18nService.setLanguage(message.payload as String);
          _dispatchMessage(message);
          break;
        case 'enableCarData':
          if (message.payload == true) {
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
          _handleSetStatusBar(message.payload as String);
          _dispatchMessage(message);
          break;
        case 'getStatusBarData':
          _handleGetStatusBarData();
          _dispatchMessage(message);
          break;
        case 'getThemeColor':
          _handleGetThemeColor();
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

  void dispose() {
    _positionSubscription?.cancel();
    _carDataSubscription?.cancel();
    _vehicleService.dispose();
    _messageHandlers.clear();
  }
}
