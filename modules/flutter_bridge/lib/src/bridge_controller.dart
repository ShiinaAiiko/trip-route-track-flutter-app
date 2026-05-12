import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'bridge_message.dart';
import 'services/keep_awake_service.dart';
import 'services/background_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';

typedef MessageHandler = void Function(BridgeMessage message);
typedef FlutterMethodCallHandler = void Function(MethodCall call);

class BridgeController {
  static final BridgeController _instance = BridgeController._internal();
  factory BridgeController() => _instance;
  BridgeController._internal();

  final KeepAwakeService _keepAwakeService = KeepAwakeService();
  final BackgroundService _backgroundService = BackgroundService();
  final LanguageService _languageService = LanguageService();

  MethodChannel? _channel;
  StreamSubscription<Position>? _positionSubscription;
  final Map<String, List<MessageHandler>> _messageHandlers = {};
  FlutterMethodCallHandler? _externalHandler;

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

  Future<void> init() async {
    await _languageService.init();
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
      // 申请 GPS 权限
      final status = await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) {
          sendMessage('notification', {
            'title': 'GPS 权限未授权',
            'message': '请在设置中开启位置权限',
            'type': 'warning',
          });
          return;
        }
      }

      // 检查位置服务是否开启
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        sendMessage('notification', {
          'title': 'GPS 服务未开启',
          'message': '请在设置中开启定位服务',
          'type': 'warning',
        });
        return;
      }

      // 启动位置更新
      _startLocationUpdatesInternal();

      // 发送安卓系统通知
      NotificationService().showNotification(
        title: 'GPS 已开启',
        body: '位置追踪功能已启动',
        id: 1,
      );
    } else {
      // 停止位置更新
      _stopLocationUpdates();

      // 发送安卓系统通知
      NotificationService().showNotification(
        title: 'GPS 已关闭',
        body: '位置追踪功能已停止',
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
      // 后台定位配置 - 使用我们自己的后台服务来管理前台通知
      androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
        // 不使用 geolocator 的前台服务通知，我们自己管理
      );
    } else {
      // 前台定位配置
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

        // 后台定位时更新定位次数
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
          'title': 'GPS 错误',
          'message': '位置获取失败: $error',
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
      NotificationService().showNotification(
        title: '屏幕常亮已开启',
        body: '屏幕将保持常亮状态',
        id: 2,
      );
    } else {
      NotificationService().showNotification(
        title: '屏幕常亮已关闭',
        body: '屏幕将自动熄灭',
        id: 2,
      );
    }
  }

  Future<void> _handleEnableBackgroundLocation(bool enable) async {
    if (enable) {
      // 检查 enableLocation 是否为 true
      if (!_enableLocation) {
        NotificationService().showNotification(
          title: '后台定位无法开启',
          body: '请先开启定位功能',
          id: 3,
        );
        _enableBackgroundLocation = false;
        return;
      }

      // Android 10+ 需要先申请前台定位权限，再申请后台定位权限
      // 第一步：确保前台定位权限已获取
      var foregroundStatus = await Permission.locationWhenInUse.status;
      if (foregroundStatus.isDenied) {
        foregroundStatus = await Permission.locationWhenInUse.request();
        if (!foregroundStatus.isGranted) {
          NotificationService().showNotification(
            title: '前台定位权限未授权',
            body: '请先允许前台定位权限',
            id: 3,
          );
          _enableBackgroundLocation = false;
          return;
        }
      }

      // 第二步：申请后台定位权限
      var backgroundStatus = await Permission.locationAlways.status;
      if (backgroundStatus.isDenied) {
        backgroundStatus = await Permission.locationAlways.request();
        if (!backgroundStatus.isGranted) {
          NotificationService().showNotification(
            title: '后台定位权限未授权',
            body: '请在设置中开启后台定位权限',
            id: 3,
          );
          _enableBackgroundLocation = false;
          return;
        }
      }

      // 更新状态并重新启动位置更新以支持后台定位
      _enableBackgroundLocation = true;
      _backgroundLocationCount = 0;
      _backgroundStartTime = DateTime.now().millisecondsSinceEpoch;
      
      // Android 13+ 需要通知权限来显示前台服务通知
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      
      // 启动后台任务以保持定位服务在后台运行
      try {
        await _backgroundService.start();
      } catch (e) {
        print('Failed to start background service: $e');
        NotificationService().showNotification(
          title: '后台服务启动失败',
          body: '无法启动后台定位服务',
          id: 5,
        );
        _enableBackgroundLocation = false;
        return;
      }
      
      if (_enableLocation) {
        _startLocationUpdatesInternal();
      }

      // 启动常驻通知定时器（更新 Android 后台服务的通知）
      _startBackgroundNotificationTimer();
    } else {
      _enableBackgroundLocation = false;
      
      // 停止常驻通知定时器
      _stopBackgroundNotificationTimer();
      
      // 取消常驻通知
      NotificationService().cancelNotification(3);
      
      // 停止后台任务
      await _backgroundService.stop();
      
      // 如果 enableLocation 仍然为 true，重启前台定位
      if (_enableLocation) {
        _startLocationUpdatesInternal();
      }

      NotificationService().showNotification(
        title: '后台定位已关闭',
        body: '应用在后台时将停止定位',
        id: 4,
      );
    }
  }

  void _startBackgroundNotificationTimer() {
    // 每秒更新一次通知
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
    
    final String durationText = '已开启${minutes}分${seconds.toString().padLeft(2, '0')}秒';
    final String countText = '已记录${_backgroundLocationCount}个定位';
    
    // 使用后台服务更新通知（而不是 Flutter 的 NotificationService）
    _backgroundService.updateNotification(
      taskTitle: '已开启后台定位',
      taskDesc: '$durationText，$countText',
    );
  }

  Future<void> _handleLoadMessage() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      sendMessage('appConfig', {
        'version': packageInfo.version,
        'system': 'Flutter App',
      });
    } catch (e) {
      sendMessage('appConfig', {
        'version': 'unknown',
        'system': 'Flutter App',
      });
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
      taskTitle: '正在后台定位',
      taskDesc: '行程已持续${formatDuration()} | 已获取$_backgroundLocationCount次定位 | 速度${(speedKmh * 10).round() / 10}km/h | 海拔${(altitudeM * 10).round() / 10}米',
    );
  }

  void dispose() {
    _positionSubscription?.cancel();
    _messageHandlers.clear();
  }
}
