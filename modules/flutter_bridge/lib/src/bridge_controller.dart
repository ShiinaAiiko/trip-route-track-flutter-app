import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:i18n/i18n.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nyanya_webview/nyanya_webview.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:tencent_kit/tencent_kit.dart';
import 'package:app_update/app_update.dart' as app_update;
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'bridge_message.dart';
import 'services/keep_awake_service.dart';
import 'services/background_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/vehicle_service.dart';
import 'services/log_service.dart';
import 'services/engine_manager.dart';
import 'services/deep_link_service.dart';
import 'services/file_service.dart';

typedef MessageHandler = void Function(BridgeMessage message);
typedef FlutterMethodCallHandler = void Function(MethodCall call);
typedef StatusBarChangeHandler = void Function(String type);
typedef UpdateCheckCallback = void Function(app_update.VersionInfo? versionInfo,
    String currentVersion, bool showCheckingNotification);
typedef UpdateCheckingCallback = void Function();
typedef LocalWebResourcesUpdateProgressCallback = void Function(
    int progress, String stage, int receivedBytes, int totalBytes);
typedef LocalWebResourcesUpdateCompleteCallback = void Function(
    bool success, String? error);
typedef SwitchResourcesCallback = void Function(String host);
typedef CloseLocalServerCallback = void Function();
typedef StartAppUpdateCallback = void Function(String downloadUrl, String version);

class BridgeController {
  static final BridgeController _instance = BridgeController._internal();
  factory BridgeController() => _instance;
  BridgeController._internal();

  final KeepAwakeService _keepAwakeService = KeepAwakeService();
  final BackgroundService _backgroundService = BackgroundService();
  final LanguageService _languageService = LanguageService();
  final VehicleService _vehicleService = VehicleService();
  final I18nService _i18nService = I18nService();
  final app_update.UpdateService _appUpdateService = app_update.UpdateService();
  final LogService _logService = LogService();
  final NotificationService _notificationService = NotificationService();
  final FileService _fileService = FileService();
  
  // 音频播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentAudioBridgeId;
  String? _currentAudioSessionId;

  String? _pendingUpdateVersion;

  // MethodChannel? _channel;
  // final Map<String, MethodChannel> _channels = {};
  IWebViewCommunication? _communication;
  final Map<String, IWebViewCommunication> _communications = {};
  StreamSubscription<Position>? _positionSubscription;
  final Map<String, List<MessageHandler>> _messageHandlers = {};
  FlutterMethodCallHandler? _externalHandler;
  StatusBarChangeHandler? _statusBarChangeHandler;
  StreamSubscription<Map<String, dynamic>>? _carDataSubscription;
  UpdateCheckCallback? _updateCheckCallback;
  UpdateCheckingCallback? _updateCheckingCallback;
  LocalWebResourcesUpdateProgressCallback?
      _localWebResourcesUpdateProgressCallback;
  LocalWebResourcesUpdateCompleteCallback?
      _localWebResourcesUpdateCompleteCallback;
  SwitchResourcesCallback? _switchResourcesCallback;
  CloseLocalServerCallback? _closeLocalServerCallback;
  StartAppUpdateCallback? _startAppUpdateCallback;

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

  // GPS心跳检测定时器（10秒超时）
  Timer? _locationHeartbeatTimer;
  static const int _locationHeartbeatTimeoutSeconds = 10;

  bool get enableLocation => _enableLocation;
  bool get enableBackgroundLocation => _enableBackgroundLocation;
  bool get keepScreenOn => _keepAwakeService.isKeepAwake;
  bool get enableBackgroundTasks => _backgroundService.enableBackgroundTasks;
  String get currentLanguage => _languageService.currentLanguage;
  LanguageService get languageService => _languageService;
  VehicleService get vehicleService => _vehicleService;
  I18nService get i18nService => _i18nService;
  app_update.UpdateService get appUpdateService => _appUpdateService;
  LogService get logService => _logService;
  NotificationService get notificationService => _notificationService;

  /// 获取应用版本类型（android 或 byd）
  /// 通过 Android 的 BuildConfig.VERSION_TYPE 获取
  Future<String?> getVersionType() async {
    try {
      const MethodChannel channel = MethodChannel('app_info');
      return await channel.invokeMethod<String>('getVersionType');
    } catch (e) {
      print('[Bridge] Failed to get version type: $e');
      return null;
    }
  }

  Future<void> init() async {
    await _checkAndResetResourcesOnUpdate();
    await _i18nService.init();
    await _languageService.init();
    await _vehicleService.init();
    await _appUpdateService.init();
    await _logService.init();
    _setupCarDataListener();
    _setupVehicleDataListeners();
    _setupNotificationClickCallback();
    _setupDeepLinkListener();
  }

  void _setupNotificationClickCallback() {
    NotificationService().setNotificationClickCallback((payload) {
      final clickActionType = payload['clickActionType'];
      final clickActionUrl = payload['clickActionUrl'];
      if (clickActionUrl != null && clickActionUrl.isNotEmpty) {
        sendMessage(
          'notificationClickAction',
          {
            'clickActionType': clickActionType ?? '',
            'clickActionUrl': clickActionUrl,
          },
        );
      }
    });
  }

  void _setupDeepLinkListener() {
    DeepLinkService().init(callback: (data) {
      print('[Bridge] Deep link received: $data');

      // 提取 OAuth 回调参数
      final url = data['url'] as String?;
      final queryParameters = data['queryParameters'] as Map<String, dynamic>?;

      if (url != null) {
        sendMessage(
          'deepLink',
          {
            'url': url,
            'queryParameters': queryParameters ?? {},
          },
        );
      }
    });
  }

  Future<void> _checkAndResetResourcesOnUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion =
          '${packageInfo.version}+${packageInfo.buildNumber}';

      final prefs = await SharedPreferences.getInstance();
      final lastVersion = prefs.getString(_prefsKeyLastVersion);

      if (lastVersion != currentVersion) {
        print(
            '[Bridge] App updated from version $lastVersion to $currentVersion');

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

  /// 订阅列表，用于管理单个分类的数据监听
  List<StreamSubscription<dynamic>> _vehicleDataSubscriptions = [];

  /// 设置单个分类数据监听，将数据转发给前端
  void _setupVehicleDataListeners() {
    // 车速
    _vehicleDataSubscriptions.add(
      _vehicleService.services.speed.speedDataStream.listen((data) {
        sendMessage('carSpeed', data.toJson());
      })
    );
    // 行驶数据
    _vehicleDataSubscriptions.add(
      _vehicleService.services.statistic.statisticDataStream.listen((data) {
        sendMessage('carStatistic', data.toJson());
      })
    );
    // 仪表
    _vehicleDataSubscriptions.add(
      _vehicleService.services.instrument.instrumentDataStream.listen((data) {
        sendMessage('carInstrument', data.toJson());
      })
    );
    // 门锁
    _vehicleDataSubscriptions.add(
      _vehicleService.services.door.doorDataStream.listen((data) {
        sendMessage('carDoor', data.toJson());
      })
    );
    // 车辆设置
    _vehicleDataSubscriptions.add(
      _vehicleService.services.vehicleset.vehicleSettingDataStream.listen((data) {
        sendMessage('carVehicleSet', data.toJson());
      })
    );
    // 发动机
    _vehicleDataSubscriptions.add(
      _vehicleService.services.engine.engineDataStream.listen((data) {
        sendMessage('carEngine', data.toJson());
      })
    );
    // 全景摄像头
    _vehicleDataSubscriptions.add(
      _vehicleService.services.panorama.panoramaDataStream.listen((data) {
        sendMessage('carPanorama', data.toJson());
      })
    );
    // 空调
    _vehicleDataSubscriptions.add(
      _vehicleService.services.ac.acDataStream.listen((data) {
        sendMessage('carAc', data.toJson());
      })
    );
    // 传感器
    _vehicleDataSubscriptions.add(
      _vehicleService.services.sensor.sensorDataStream.listen((data) {
        sendMessage('carSensor', data.toJson());
      })
    );
    // 时间
    _vehicleDataSubscriptions.add(
      _vehicleService.services.time.timeDataStream.listen((data) {
        sendMessage('carTime', data.toJson());
      })
    );
    // 能量模式
    _vehicleDataSubscriptions.add(
      _vehicleService.services.energyMode.energyModeDataStream.listen((data) {
        sendMessage('carEnergyMode', data.toJson());
      })
    );
    // 雷达
    _vehicleDataSubscriptions.add(
      _vehicleService.services.radar.radarDataStream.listen((data) {
        sendMessage('carRadar', data.toJson());
      })
    );
    // 轮胎
    _vehicleDataSubscriptions.add(
      _vehicleService.services.tyre.tyreDataStream.listen((data) {
        sendMessage('carTyre', data.toJson());
      })
    );
    // 空气质量
    _vehicleDataSubscriptions.add(
      _vehicleService.services.airQuality.airQualityDataStream.listen((data) {
        sendMessage('carAirQuality', data.toJson());
      })
    );
    // 充电
    _vehicleDataSubscriptions.add(
      _vehicleService.services.charge.chargeDataStream.listen((data) {
        sendMessage('carCharge', data.toJson());
      })
    );
    // 媒体
    _vehicleDataSubscriptions.add(
      _vehicleService.services.media.mediaDataStream.listen((data) {
        sendMessage('carMedia', data.toJson());
      })
    );
    // 车身状态
    _vehicleDataSubscriptions.add(
      _vehicleService.services.bodyStatus.bodyStatusDataStream.listen((data) {
        sendMessage('carBodyStatus', data.toJson());
      })
    );
    // 车灯
    _vehicleDataSubscriptions.add(
      _vehicleService.services.light.lightDataStream.listen((data) {
        sendMessage('carLight', data.toJson());
      })
    );
  }

  /// 取消所有单个分类数据监听
  void _disposeVehicleDataListeners() {
    for (var subscription in _vehicleDataSubscriptions) {
      subscription.cancel();
    }
    _vehicleDataSubscriptions.clear();
  }

// void setChannel(MethodChannel? channel, {String? sessionId}) {
//     _channel = channel;
//     if (sessionId != null && channel != null) {
//       _channels[sessionId] = channel;
//       print('[Bridge] Registered channel for session: $sessionId');
  // void setChannel(dynamic channel, {String? sessionId}) {
  //   if (channel is MethodChannel) {
  //     _channel = channel;
  //     if (sessionId != null) {
  //       _channels[sessionId] = channel;
  //       print('[Bridge] Registered channel for session: $sessionId');
  //     }
  //   } else {
  //     print(
  //         '[Bridge] Ignoring non-MethodChannel channel for session: $sessionId');
  //   }
  //   // _channel?.setMethodCallHandler(_handleMethodCall);
  // }

  void setCommunication(IWebViewCommunication? communication,
      {String? sessionId}) {
    _communication = communication;
    if (sessionId != null && communication != null) {
      _communications[sessionId] = communication;
      print('[Bridge] Registered communication for session: $sessionId');
    }
    if (communication != null) {
      communication.setMessageHandler((message) {
        print('[FlutterBridge] communication->Received message: $message');
        handleWebMessage(message, sessionId: sessionId);
      });
    }
  }

  void removeCommunication(String sessionId) {
    final communication = _communications.remove(sessionId);
    if (communication != null) {
      // 调用 shutdown 清理资源
      try {
        communication.shutdown();
      } catch (e) {
        print(
            '[Bridge] Error shutting down communication for session $sessionId: $e');
      }
      print('[Bridge] Removed communication for session: $sessionId');
    }
    // 如果移除的是当前使用的 _communication，也清理
    if (_communication != null &&
        _communications.values.contains(_communication) == false) {
      // 保持 _communication 不变，除非它已经不再 _communications 中
    }
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

  void setLocalWebResourcesUpdateProgressCallback(
      LocalWebResourcesUpdateProgressCallback callback) {
    _localWebResourcesUpdateProgressCallback = callback;
  }

  void setLocalWebResourcesUpdateCompleteCallback(
      LocalWebResourcesUpdateCompleteCallback? callback) {
    _localWebResourcesUpdateCompleteCallback = callback;
  }

  void setSwitchResourcesCallback(SwitchResourcesCallback? callback) {
    _switchResourcesCallback = callback;
  }

  void setCloseLocalServerCallback(CloseLocalServerCallback? callback) {
    _closeLocalServerCallback = callback;
  }

  void setStartAppUpdateCallback(StartAppUpdateCallback? callback) {
    _startAppUpdateCallback = callback;
  }

  void _dispatchMessage(BridgeMessage message) {
    final handlers = _messageHandlers[message.type];
    if (handlers != null) {
      for (final handler in handlers) {
        handler(message);
      }
    }
  }

  Future<void> handleWebMessage(String messageString,
      {String? sessionId}) async {
    print(
        '[FlutterBridge] handleWebMessage from session: $sessionId, message: $messageString');

    await _handleWebMessage(messageString, sessionId: sessionId);
  }

  Future<void> sendMessage(String type, dynamic payload,
      {String? bridgeId, String? sessionId}) async {
    // 优先使用 communication
    IWebViewCommunication? targetCommunication = _communication;
    if (sessionId != null && _communications.containsKey(sessionId)) {
      targetCommunication = _communications[sessionId];
    }
    // print("[FlutterBridge] sendMessage type=> $type, sessionId=>  $sessionId");

    if (targetCommunication != null) {
      final message = BridgeMessage(
        type: type,
        payload: payload,
        bridgeId: bridgeId,
        sessionId: sessionId,
      );
      final jsonString = jsonEncode(message.toJson());

      print(
          "[FlutterBridge] sendMessage type=> $type, payload=> $payload, sessionId=> $sessionId");

      await targetCommunication.postMessage(jsonString);
      return;
    }

    // // 如果没有 communication，尝试使用 channel（向后兼容）
    // MethodChannel? targetChannel = _channel;
    // if (sessionId != null && _channels.containsKey(sessionId)) {
    //   targetChannel = _channels[sessionId];
    // }
    // if (targetChannel == null) {
    //   print(
    //       '[Bridge] sendMessage: No channel or communication available for session: $sessionId');
    //   return;
    // }

    // final message = BridgeMessage(
    //   type: type,
    //   payload: payload,
    //   bridgeId: bridgeId,
    //   sessionId: sessionId,
    // );
    // final jsonString = jsonEncode(message.toJson());

    // await targetChannel.invokeMethod('postMessage', {
    //   'message': jsonString,
    // });
  }

  // ============ 车辆数据统一接口处理方法 ============

  /// 处理车辆数据获取请求
  Future<void> _handleVehicleGet(String category,
      {String? bridgeId, String? sessionId}) async {
    print('[BridgeController] _handleVehicleGet category: $category');
    switch (category) {
      case 'speed':
        final data = await _vehicleService.services.speed.get();
        sendMessage('carSpeed', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'statistic':
        final data = await _vehicleService.services.statistic.get();
        sendMessage('carStatistic', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'instrument':
        final data = await _vehicleService.services.instrument.get();
        sendMessage('carInstrument', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'door':
        final data = await _vehicleService.services.door.get();
        sendMessage('carDoor', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'vehicleSetting':
        final data = await _vehicleService.services.vehicleset.get();
        sendMessage('carVehicleSet', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'engine':
        final data = await _vehicleService.services.engine.get();
        sendMessage('carEngine', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'panorama':
        final data = await _vehicleService.services.panorama.get();
        sendMessage('carPanorama', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'ac':
        final data = await _vehicleService.services.ac.get();
        sendMessage('carAc', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'sensor':
        final data = await _vehicleService.services.sensor.get();
        sendMessage('carSensor', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'time':
        final data = await _vehicleService.services.time.get();
        sendMessage('carTime', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'energyMode':
        final data = await _vehicleService.services.energyMode.get();
        sendMessage('carEnergyMode', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'radar':
        final data = await _vehicleService.services.radar.get();
        sendMessage('carRadar', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'tyre':
        final data = await _vehicleService.services.tyre.get();
        sendMessage('carTyre', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'airQuality':
        final data = await _vehicleService.services.airQuality.get();
        sendMessage('carAirQuality', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'charge':
        final data = await _vehicleService.services.charge.get();
        sendMessage('carCharge', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'media':
        final data = await _vehicleService.services.media.get();
        sendMessage('carMedia', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'bodyStatus':
        final data = await _vehicleService.services.bodyStatus.get();
        sendMessage('carBodyStatus', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      case 'light':
        final data = await _vehicleService.services.light.get();
        sendMessage('carLight', data.toJson(),
            bridgeId: bridgeId, sessionId: sessionId);
        break;
      default:
        print(
            '[BridgeController] _handleVehicleGet unknown category: $category');
    }
  }

  /// 处理车辆数据分类字段获取请求
  Future<void> _handleCarGetField(String category, String? field,
      {String? bridgeId, String? sessionId}) async {
    print(
        '[BridgeController] _handleCarGetField category: $category, field: $field');

    switch (category) {
      case 'engine':
        final MethodChannel channel = MethodChannel('byd_vehicle');
        try {
          final result = await channel.invokeMethod('getCarGetField', {
            'category': category,
            'field': field,
          });
          sendMessage('carGetField', {
            'category': category,
            'field': field,
            'value': result,
          }, bridgeId: bridgeId, sessionId: sessionId);
        } catch (e) {
          print('[BridgeController] _handleCarGetField error: $e');
          sendMessage('carGetField', {
            'category': category,
            'field': field,
            'value': null,
            'error': e.toString(),
          }, bridgeId: bridgeId, sessionId: sessionId);
        }
        break;
      default:
        print(
            '[BridgeController] _handleCarGetField unknown category: $category');
    }
  }

  /// 处理车辆数据监听请求
  Future<void> _handleVehicleEnableListener(
      String category, bool enabled) async {
    print(
        '[BridgeController] _handleVehicleEnableListener category: $category, enabled: $enabled');
    switch (category) {
      case 'speed':
        await _vehicleService.services.speed.enableListener(enabled);
        break;
      case 'statistic':
        await _vehicleService.services.statistic.enableListener(enabled);
        break;
      case 'instrument':
        await _vehicleService.services.instrument.enableListener(enabled);
        break;
      case 'door':
        await _vehicleService.services.door.enableListener(enabled);
        break;
      case 'vehicleSetting':
        await _vehicleService.services.vehicleset.enableListener(enabled);
        break;
      case 'engine':
        await _vehicleService.services.engine.enableListener(enabled);
        break;
      case 'panorama':
        await _vehicleService.services.panorama.enableListener(enabled);
        break;
      case 'ac':
        await _vehicleService.services.ac.enableListener(enabled);
        break;
      case 'sensor':
        await _vehicleService.services.sensor.enableListener(enabled);
        break;
      case 'time':
        await _vehicleService.services.time.enableListener(enabled);
        break;
      case 'energyMode':
        await _vehicleService.services.energyMode.enableListener(enabled);
        break;
      case 'radar':
        await _vehicleService.services.radar.enableListener(enabled);
        break;
      case 'tyre':
        await _vehicleService.services.tyre.enableListener(enabled);
        break;
      case 'airQuality':
        await _vehicleService.services.airQuality.enableListener(enabled);
        break;
      case 'charge':
        await _vehicleService.services.charge.enableListener(enabled);
        break;
      case 'media':
        await _vehicleService.services.media.enableListener(enabled);
        break;
      case 'bodyStatus':
        await _vehicleService.services.bodyStatus.enableListener(enabled);
        break;
      case 'light':
        await _vehicleService.services.light.enableListener(enabled);
        break;
      case 'all':
        await _vehicleService.services.speed.enableListener(enabled);
        await _vehicleService.services.statistic.enableListener(enabled);
        await _vehicleService.services.instrument.enableListener(enabled);
        await _vehicleService.services.door.enableListener(enabled);
        await _vehicleService.services.vehicleset.enableListener(enabled);
        await _vehicleService.services.engine.enableListener(enabled);
        await _vehicleService.services.panorama.enableListener(enabled);
        await _vehicleService.services.ac.enableListener(enabled);
        await _vehicleService.services.sensor.enableListener(enabled);
        await _vehicleService.services.time.enableListener(enabled);
        await _vehicleService.services.energyMode.enableListener(enabled);
        await _vehicleService.services.radar.enableListener(enabled);
        await _vehicleService.services.tyre.enableListener(enabled);
        await _vehicleService.services.airQuality.enableListener(enabled);
        await _vehicleService.services.charge.enableListener(enabled);
        await _vehicleService.services.media.enableListener(enabled);
        await _vehicleService.services.bodyStatus.enableListener(enabled);
        await _vehicleService.services.light.enableListener(enabled);
        break;
      default:
        print(
            '[BridgeController] _handleVehicleEnableListener unknown category: $category');
    }
  }

  /// 处理车辆数据设置请求
  Future<void> _handleVehicleSet(String type, String field, dynamic value,
      {String? bridgeId, String? sessionId}) async {
    print(
        '[BridgeController] _handleVehicleSet type: $type, field: $field, value: $value');
    bool success = false;
    switch (type) {
      case 'speed':
        print('[BridgeController] speed 不支持 set 操作');
        break;
      case 'statistic':
        print('[BridgeController] statistic 不支持 set 操作');
        break;
      case 'instrument':
        success = await _vehicleService.services.instrument.set(field, value);
        break;
      case 'door':
        print('[BridgeController] door 不支持 set 操作');
        break;
      case 'vehicleSetting':
        success = await _vehicleService.services.vehicleset.set(field, value);
        break;
      case 'engine':
        print('[BridgeController] engine 不支持 set 操作');
        break;
      case 'panorama':
        print('[BridgeController] panorama 不支持 set 操作');
        break;
      case 'ac':
        success = await _vehicleService.services.ac.set(field, value);
        break;
      case 'sensor':
        print('[BridgeController] sensor 不支持 set 操作');
        break;
      case 'time':
        success = await _vehicleService.services.time.set(field, value);
        break;
      case 'energyMode':
        print('[BridgeController] energyMode 不支持 set 操作');
        break;
      case 'radar':
        print('[BridgeController] radar 不支持 set 操作');
        break;
      case 'tyre':
        print('[BridgeController] tyre 不支持 set 操作');
        break;
      case 'airQuality':
        print('[BridgeController] airQuality 不支持 set 操作');
        break;
      case 'charge':
        print('[BridgeController] charge 不支持 set 操作');
        break;
      case 'media':
        success = await _vehicleService.services.media.set(field, value);
        break;
      case 'bodyStatus':
        print('[BridgeController] bodyStatus 不支持 set 操作');
        break;
      case 'light':
        print('[BridgeController] light 不支持 set 操作');
        break;
      default:
        print('[BridgeController] _handleVehicleSet unknown type: $type');
    }
    sendMessage('setResult', {'success': success, 'field': field},
        bridgeId: bridgeId, sessionId: sessionId);
  }

  Future<void> _handleEnableLocation(bool enable, {String? sessionId}) async {
    if (enable) {
      final status = await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) {
          sendMessage(
              'gpsPermissionDenied',
              {
                'title': _i18nService.t('gps_permission_denied'),
                'message': '',
                'type': 'warning',
                'notification': true,
                'module': 'location',
              },
              sessionId: sessionId);
          return;
        }
      }

      // ============ 以下是原有的服务检测代码，已注释保留 ============
      /*
      // 添加调试日志
      final locationPermission = await Permission.locationWhenInUse.status;
      final backgroundPermission = await Permission.locationAlways.status;
      print('[LOCATION1] Permission status: whenInUse=$locationPermission, always=$backgroundPermission');
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('[LOCATION1] Service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('[LOCATION1] Service disabled, trying to open settings');
        // 尝试引导用户开启系统位置服务
        final bool? settingsResult = await Geolocator.openLocationSettings();
        print('[LOCATION1] Settings opened result: $settingsResult');
        
        // 再次检查服务是否已开启（带重试机制）
        int retryCount = 0;
        const maxRetries = 3;
        while (!serviceEnabled && retryCount < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 500));
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          retryCount++;
          print('[LOCATION1] Service enabled after retry $retryCount: $serviceEnabled');
        }
        
        // 如果仍然检测不到服务开启，但用户已经打开过设置页面，尝试信任用户的操作
        // 某些设备（如小米）的系统服务检测可能不准确
        if (!serviceEnabled && settingsResult == true) {
          print('[LOCATION1] Service detection failed but settings opened, trusting user action');
          serviceEnabled = true; // 信任用户已经开启了服务
        }
        
        if (!serviceEnabled) {
          sendMessage('gpsServiceDisabled', {
            'title': _i18nService.t('gps_service_disabled'),
            'message': '',
            'type': 'warning',
            'notification': true,
            'module': 'location',
          }, sessionId: sessionId);
          return;
        }
      }
      */
      // ============ 服务检测代码结束 ============

      _startLocationUpdatesInternal(sessionId: sessionId);

      sendMessage(
          'locationEnabled',
          {
            'title': _i18nService.t('location_enabled'),
            'message': '',
            'type': 'success',
            'notification': true,
            'module': 'location',
          },
          sessionId: sessionId);
    } else {
      _stopLocationUpdates();

      sendMessage(
          'locationDisabled',
          {
            'title': _i18nService.t('location_disabled'),
            'message': '',
            'type': 'info',
            'notification': true,
            'module': 'location',
          },
          sessionId: sessionId);
    }
  }

  Future<void> _handleGetCurrentLocation(
      {String? bridgeId, String? sessionId}) async {
    try {
      final status = await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) {
          sendMessage(
              'gpsPermissionDenied',
              {
                'title': _i18nService.t('gps_permission_denied'),
                'message': '',
                'type': 'warning',
                'notification': true,
                'module': 'location',
              },
              sessionId: sessionId);
          return;
        }
      }

      // 先尝试获取最后已知位置（快速响应）
      try {
        final lastKnownPosition = await Geolocator.getLastKnownPosition();
        if (lastKnownPosition != null) {
          // 立即返回缓存位置，快速响应前端
          sendMessage(
              'getCurrentLocation',
              {
                'coords': {
                  'latitude': lastKnownPosition.latitude,
                  'longitude': lastKnownPosition.longitude,
                  'altitude': lastKnownPosition.altitude,
                  'altitudeAccuracy': lastKnownPosition.altitudeAccuracy,
                  'accuracy': lastKnownPosition.accuracy,
                  'heading': lastKnownPosition.heading,
                  'speed': lastKnownPosition.speed,
                },
                'timestamp': lastKnownPosition.timestamp.millisecondsSinceEpoch,
                'isCached': true, // 标记为缓存位置
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
        }
      } catch (e) {
        print('[Bridge] getLastKnownPosition failed: $e');
      }

      // 然后异步获取精确位置（更新前端）
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(Duration(seconds: 8));

        sendMessage(
            'getCurrentLocation',
            {
              'coords': {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'altitude': position.altitude,
                'altitudeAccuracy': position.altitudeAccuracy,
                'accuracy': position.accuracy,
                'heading': position.heading,
                'speed': position.speed,
              },
              'timestamp': position.timestamp.millisecondsSinceEpoch,
              'isCached': false, // 标记为精确位置
            },
            bridgeId: bridgeId,
            sessionId: sessionId);
      } on TimeoutException {
        // 高精度定位超时，尝试使用中等精度
        print('[Bridge] High accuracy location timeout, trying medium accuracy');
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(Duration(seconds: 5));

          sendMessage(
              'getCurrentLocation',
              {
                'coords': {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'altitude': position.altitude,
                  'altitudeAccuracy': position.altitudeAccuracy,
                  'accuracy': position.accuracy,
                  'heading': position.heading,
                  'speed': position.speed,
                },
                'timestamp': position.timestamp.millisecondsSinceEpoch,
                'isCached': false,
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
        } catch (e) {
          print('[Bridge] Medium accuracy location also failed: $e');
          // 如果之前已经返回了缓存位置，这里不需要再发送错误
          // 如果没有缓存位置，才发送错误
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown == null) {
            sendMessage(
                'gpsError',
                {
                  'title': _i18nService.t('gps_error'),
                  'message': 'getCurrentLocation timeout and no cached location',
                  'type': 'error',
                  'notification': true,
                  'module': 'location',
                },
                bridgeId: bridgeId,
                sessionId: sessionId);
          }
        }
      }
    } catch (e) {
      sendMessage(
          'gpsError',
          {
            'title': _i18nService.t('gps_error'),
            'message': 'getCurrentLocation failed: $e',
            'type': 'error',
            'notification': true,
            'module': 'location',
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
    }
  }

  bool _isBydPermissionType(String type) {
    return type.startsWith('byd');
  }

  String _mapToBydPermissionString(String type) {
    switch (type) {
      case 'bydAcCommon':
        return 'android.permission.BYDAUTO_AC_COMMON';
      case 'bydBodyworkCommon':
        return 'android.permission.BYDAUTO_BODYWORK_COMMON';
      case 'bydEngineCommon':
        return 'android.permission.BYDAUTO_ENGINE_COMMON';
      case 'bydTyreCommon':
        return 'android.permission.BYDAUTO_TYRE_COMMON';
      case 'bydInstrumentCommon':
        return 'android.permission.BYDAUTO_INSTRUMENT_COMMON';
      case 'bydDoorlockCommon':
        return 'android.permission.BYDAUTO_DOORLOCK_COMMON';
      case 'bydPanoramaCommon':
        return 'android.permission.BYDAUTO_PANORAMA_COMMON';
      case 'bydVehiclesetCommon':
        return 'android.permission.BYDAUTO_VEHICLESET_COMMON';
      case 'bydSpeedGet':
        return 'android.permission.BYDAUTO_SPEED_GET';
      case 'bydStatisticGet':
        return 'android.permission.BYDAUTO_STATISTIC_GET';
      case 'bydTyreGet':
        return 'android.permission.BYDAUTO_TYRE_GET';
      case 'bydEngineGet':
        return 'android.permission.BYDAUTO_ENGINE_GET';
      case 'bydEnergyGet':
        return 'android.permission.BYDAUTO_ENERGY_GET';
      case 'bydChargeGet':
        return 'android.permission.BYDAUTO_CHARGE_GET';
      default:
        return type;
    }
  }

  Permission _mapPermissionType(String type) {
    switch (type) {
      case 'location':
        return Permission.locationWhenInUse;
      case 'locationAlways':
        return Permission.locationAlways;
      case 'notification':
        return Permission.notification;
      case 'storage':
        return Permission.storage;
      case 'camera':
        return Permission.camera;
      case 'microphone':
        return Permission.microphone;
      case 'photos':
        return Permission.photos;
      case 'contacts':
        return Permission.contacts;
      case 'calendar':
        return Permission.calendar;
      case 'sensors':
        return Permission.sensors;
      case 'sms':
        return Permission.sms;
      case 'phone':
        return Permission.phone;
      case 'bluetooth':
        return Permission.bluetooth;
      case 'activityRecognition':
        return Permission.activityRecognition;
      case 'mediaLibrary':
        return Permission.mediaLibrary;
      case 'systemAlertWindow':
        return Permission.systemAlertWindow;
      default:
        throw ArgumentError('Unknown permission type: $type');
    }
  }

  String _mapPermissionStatus(PermissionStatus status) {
    if (status.isGranted) return 'granted';
    if (status.isDenied) return 'denied';
    if (status.isPermanentlyDenied) return 'permanentlyDenied';
    if (status.isRestricted) return 'restricted';
    if (status.isLimited) return 'limited';
    if (status.isProvisional) return 'provisional';
    return 'denied';
  }

  Future<void> _handleCheckPermissions(dynamic permissions,
      {String? bridgeId, String? sessionId}) async {
    try {
      final List<String> permissionTypes =
          (permissions as List<dynamic>).cast<String>();
      final Map<String, String> results = {};

      final List<String> standardPermissions = [];
      final List<String> bydPermissions = [];

      for (final type in permissionTypes) {
        if (_isBydPermissionType(type)) {
          bydPermissions.add(type);
        } else {
          standardPermissions.add(type);
        }
      }

      // 处理标准权限
      for (final type in standardPermissions) {
        try {
          final permission = _mapPermissionType(type);
          final status = await permission.status;
          results[type] = _mapPermissionStatus(status);
        } catch (e) {
          results[type] = 'denied';
        }
      }

      // 处理BYD权限
      if (bydPermissions.isNotEmpty) {
        try {
          final bydResults =
              await _vehicleService.checkBydPermissions(bydPermissions);
          results.addAll(bydResults);
        } catch (e) {
          for (final type in bydPermissions) {
            results[type] = 'denied';
          }
        }
      }

      sendMessage('checkPermissions', results,
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      sendMessage('checkPermissions', {},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  Future<void> _handleRequestPermissions(dynamic permissions,
      {String? bridgeId, String? sessionId}) async {
    try {
      final List<String> permissionTypes =
          (permissions as List<dynamic>).cast<String>();
      final Map<String, String> results = {};
      bool allGranted = true;

      final List<String> standardPermissions = [];
      final List<String> bydPermissions = [];
 
      for (final type in permissionTypes) {
        if (_isBydPermissionType(type)) {
          bydPermissions.add(type);
        } else {
          standardPermissions.add(type);
        }
      }

      // 处理标准权限
      if (standardPermissions.isNotEmpty) {
        final List<Permission> validPermissions = [];
        final List<String> validPermissionTypes = [];

        // 先收集有效的权限
        for (final type in standardPermissions) {
          try {
            validPermissions.add(_mapPermissionType(type));
            validPermissionTypes.add(type);
          } catch (e) {
            results[type] = 'denied';
            allGranted = false;
          }
        }

        // 请求有效的权限
        if (validPermissions.isNotEmpty) {
          final requestResults = await validPermissions.request();
          for (int i = 0; i < validPermissionTypes.length; i++) {
            final type = validPermissionTypes[i];
            final permission = validPermissions[i];
            if (requestResults.containsKey(permission)) {
              final status = requestResults[permission]!;
              final statusStr = _mapPermissionStatus(status);
              results[type] = statusStr;
              if (statusStr != 'granted') {
                allGranted = false;
              }
            }
          }
        }
      }

      // 处理BYD权限
      if (bydPermissions.isNotEmpty) {
        try {
          await _vehicleService.requestBydPermissions();
          // 请求后再次检查权限状态
          final bydResults =
              await _vehicleService.checkBydPermissions(bydPermissions);
          results.addAll(bydResults);
          // 检查BYD权限是否全部授予
          for (final entry in bydResults.entries) {
            if (entry.value != 'granted') {
              allGranted = false;
              break;
            }
          }
        } catch (e) {
          for (final type in bydPermissions) {
            results[type] = 'denied';
            allGranted = false;
          }
        }
      }

      sendMessage(
          'requestPermissions', {'success': allGranted, 'results': results},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      sendMessage('requestPermissions',
          {'success': false, 'results': <String, String>{}},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  Future<void> _startLocationUpdatesInternal({String? sessionId}) async {
    // 取消之前的GPS心跳定时器
    _locationHeartbeatTimer?.cancel();

    if (_positionSubscription != null) {
      _positionSubscription!.cancel();
    }

    AndroidSettings androidSettings;

    if (_enableBackgroundLocation) {
      androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
      );
    } else {
      androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
      );
    }

    // 关键：在订阅定位流之前就启动心跳检测
    // 确保即使定位流阻塞，也能被检测到并重启
    _resetLocationHeartbeatTimer(sessionId: sessionId);

    // 预检查：尝试获取一次位置
    // 如果预检查失败（超时或错误），走重启流程，不启动定位流
    bool preCheckSuccess = await _attemptQuickPositionCheck(sessionId: sessionId);
    if (!preCheckSuccess) {
      print('[Location] Pre-check failed, scheduling restart...');
      return; // 不启动定位流，让心跳超时后重启
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

        // 重置GPS心跳定时器（20秒内收到GPS定位则续期）
        _resetLocationHeartbeatTimer(sessionId: sessionId);

        sendMessage(
            'location',
            {
              'coords': {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'altitude': position.altitude,
                'altitudeAccuracy': position.altitudeAccuracy,
                'accuracy': position.accuracy,
                'heading': position.heading,
                'speed': position.speed,
              },
              'timestamp': position.timestamp.millisecondsSinceEpoch,
            },
            sessionId: sessionId);
      },
      onError: (error) {
        sendMessage(
            'gpsError',
            {
              'title': _i18nService.t('gps_error'),
              'message': 'Location failed: $error',
              'type': 'warning',
              'notification': true,
              'module': 'location',
            },
            sessionId: sessionId);
        
        _resetLocationHeartbeatTimer(sessionId: sessionId, timeoutSeconds: 3);
      },
      onDone: () {
        if (_enableLocation) {
          _resetLocationHeartbeatTimer(sessionId: sessionId, timeoutSeconds: 3);
        }
      },
    );
  }

  void _stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationHeartbeatTimer?.cancel();
    _locationHeartbeatTimer = null;
  }

  /// 重置GPS心跳定时器
  /// 只要指定时间内拿到一次GPS定位，就自动续期
  /// [timeoutSeconds] 超时时间，默认为 _locationHeartbeatTimeoutSeconds (20秒)
  void _resetLocationHeartbeatTimer({String? sessionId, int? timeoutSeconds}) {
    _locationHeartbeatTimer?.cancel();
    final timeout = timeoutSeconds ?? _locationHeartbeatTimeoutSeconds;
    _locationHeartbeatTimer = Timer(
      Duration(seconds: timeout),
      () {
        print('[LocationHeartbeat] GPS定位超时，${timeout}秒内无有效定位，重建定位连接...');
        if (_enableLocation) {
          _startLocationUpdatesInternal(sessionId: sessionId);
        }
      },
    );
  }

  /// 预检查：尝试获取一次高精度位置
  /// 用于在启动持续定位流之前进行健康检查
  /// 返回 true 表示检查成功，false 表示失败（超时或错误）
  Future<bool> _attemptQuickPositionCheck({String? sessionId}) async {
    try {
      print('[LocationPreCheck] Starting position pre-check...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
      print('[LocationPreCheck] Pre-check succeeded: ${position.latitude}, ${position.longitude}');
      
      // 预检查成功，立即发送一次位置
      sendMessage(
          'location',
          {
            'coords': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'altitude': position.altitude,
              'altitudeAccuracy': position.altitudeAccuracy,
              'accuracy': position.accuracy,
              'heading': position.heading,
              'speed': position.speed,
            },
            'timestamp': position.timestamp.millisecondsSinceEpoch,
            'isCached': false,
          },
          sessionId: sessionId);
      return true;
    } catch (e) {
      // 预检查失败，记录日志并发送错误消息
      print('[LocationPreCheck] Pre-check failed: $e');
      sendMessage(
          'gpsError',
          {
            'title': _i18nService.t('gps_error'),
            'message': 'GPS signal unavailable, retrying...',
            'type': 'warning',
            'notification': true,
            'module': 'location',
          },
          sessionId: sessionId);
      return false;
    }
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

  Future<void> _handleEnableBackgroundLocation(bool enable,
      {String? sessionId}) async {
    if (enable) {
      if (!_enableLocation) {
        sendMessage(
            'backgroundLocationEnableFailed',
            {
              'title': _i18nService.t('background_location_enable_failed'),
              'message': _i18nService.t('foreground_location_first'),
              'type': 'error',
              'notification': true,
              'module': 'backgroundLocation',
            },
            sessionId: sessionId);
        _enableBackgroundLocation = false;
        return;
      }

      var foregroundStatus = await Permission.locationWhenInUse.status;
      if (foregroundStatus.isDenied) {
        foregroundStatus = await Permission.locationWhenInUse.request();
        if (!foregroundStatus.isGranted) {
          sendMessage(
              'backgroundLocationEnableFailed',
              {
                'title': _i18nService.t('background_location_enable_failed'),
                'message':
                    _i18nService.t('foreground_location_permission_denied'),
                'type': 'error',
                'notification': true,
                'module': 'backgroundLocation',
              },
              sessionId: sessionId);
          _enableBackgroundLocation = false;
          return;
        }
      }

      var backgroundStatus = await Permission.locationAlways.status;
      if (backgroundStatus.isDenied) {
        backgroundStatus = await Permission.locationAlways.request();
        if (!backgroundStatus.isGranted) {
          sendMessage(
              'backgroundLocationEnableFailed',
              {
                'title': _i18nService.t('background_location_enable_failed'),
                'message':
                    _i18nService.t('background_location_permission_denied'),
                'type': 'error',
                'notification': true,
                'module': 'backgroundLocation',
              },
              sessionId: sessionId);
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
        sendMessage(
            'backgroundServiceStartFailed',
            {
              'title': _i18nService.t('background_service_start_failed'),
              'message': '',
              'type': 'error',
              'notification': true,
              'module': 'backgroundLocation',
            },
            sessionId: sessionId);
        _enableBackgroundLocation = false;
        return;
      }

      if (_enableLocation) {
        _startLocationUpdatesInternal(sessionId: sessionId);
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
        _startLocationUpdatesInternal(sessionId: sessionId);
      }

      sendMessage(
          'backgroundLocationDisabled',
          {
            'title': _i18nService.t('background_location_disabled'),
            'message': '',
            'type': 'info',
            'notification': true,
            'module': 'backgroundLocation',
          },
          sessionId: sessionId);
    }
  }

  void _startBackgroundNotificationTimer() {
    _stopBackgroundNotificationTimer();
    _backgroundNotificationTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateBackgroundNotification();
    });
  }

  void _stopBackgroundNotificationTimer() {
    _backgroundNotificationTimer?.cancel();
    _backgroundNotificationTimer = null;
  }

  Future<void> _updateBackgroundNotification() async {
    if (!_enableBackgroundLocation) return;

    final int elapsed =
        DateTime.now().millisecondsSinceEpoch - _backgroundStartTime;
    final int minutes = (elapsed ~/ 1000) ~/ 60;
    final int seconds = (elapsed ~/ 1000) % 60;

    final durationText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    _backgroundService.updateNotification(
      taskTitle: _i18nService.t('background_location_title'),
      taskDesc: _i18nService.t('background_location_content',
          {'duration': durationText, 'count': '$_backgroundLocationCount'}),
    );
  }

  Future<void> _handleLoadMessage({String? sessionId}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final engine = await EngineManager().getSelectedEngine();
      final engineManager = EngineManager();
      final webViewVersion = await engineManager.getWebViewVersion();
      final deviceInfoPlugin = DeviceInfoPlugin();

      // 根据系统 WebView 版本决定可选内核
      // 版本 >= 85: gecko 和 system 都可选
      // 版本 < 85: 只能使用 gecko
      final List<String> availableEngines;
      if (webViewVersion >= 85) {
        availableEngines = [
          'gecko',
          'system',
        ];
      } else {
        availableEngines = ['gecko'];
      }

      // 获取设备信息
      String? deviceModel;
      String? deviceBrand;
      String? androidVersion;
      String? sdkInt;
      String? hardware;
      String? board;
      String? manufacturer;
      String? cpuAbi;
      List<String>? supportedAbis;
      String? display;
      String? fingerprint;
      String? bootloader;
      String? baseOS;
      String? securityPatch;
      String? codename;
      String? gpuRenderer;
      String? gpuVendor;
      String? gpuVersion;
      String? deviceType;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        
        // 尝试获取更详细的设备型号
        // 红米K80至尊版这类设备需要组合多个字段
        String model = androidInfo.model ?? '';
        String product = androidInfo.product ?? '';
        String device = androidInfo.device ?? '';
        
        // 优先使用 model，如果不够详细则尝试组合
        deviceModel = model.isNotEmpty ? model : 
                      (product.isNotEmpty ? product : 
                      (device.isNotEmpty ? device : 'unknown'));
        
        // 如果 model 只是简单型号（如 "23127PN5BC"），尝试从 fingerprint 中提取更详细的信息
        if (model.length <= 12 && androidInfo.fingerprint != null) {
          final fingerprint = androidInfo.fingerprint!;
          // fingerprint 格式通常是: brand/product/device:version/build_id:type/timestamp
          final parts = fingerprint.split('/');
          if (parts.length >= 3) {
            String extractedModel = parts[1]; // 通常 product 字段包含更详细的型号
            // 尝试去除数字后缀，获取更友好的型号名
            extractedModel = extractedModel.replaceAll(RegExp(r'_\d+$'), '');
            if (extractedModel.length > 4 && !extractedModel.contains(model)) {
              deviceModel = '$model ($extractedModel)';
            }
          }
        }
        
        deviceBrand = androidInfo.brand;
        androidVersion = androidInfo.version.release;
        sdkInt = androidInfo.version.sdkInt.toString();
        hardware = androidInfo.hardware;
        board = androidInfo.board;
        manufacturer = androidInfo.manufacturer;
        supportedAbis = androidInfo.supportedAbis;
        cpuAbi = androidInfo.supportedAbis.isNotEmpty ? androidInfo.supportedAbis.first : null;
        display = androidInfo.display;
        fingerprint = androidInfo.fingerprint;
        bootloader = androidInfo.bootloader;
        baseOS = androidInfo.version.baseOS;
        securityPatch = androidInfo.version.securityPatch;
        codename = androidInfo.version.codename;
        deviceType = androidInfo.systemFeatures.contains('android.hardware.type.watch')
            ? 'watch'
            : androidInfo.systemFeatures.contains('android.hardware.type.automotive')
                ? 'automotive'
                : androidInfo.systemFeatures.contains('android.hardware.type.television')
                    ? 'tv'
                    : 'phone';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceModel = iosInfo.model;
        deviceBrand = 'Apple';
        androidVersion = iosInfo.systemVersion;
        hardware = iosInfo.utsname.machine;
        manufacturer = 'Apple';
        display = '${iosInfo.name} ${iosInfo.systemVersion}';
        deviceType = iosInfo.model.toLowerCase().contains('ipad') ? 'tablet' : 'phone';
      }

      // 尝试获取 GPU 信息（通过 OpenGL）
      try {
        final glRenderer = await _getGLRenderer();
        if (glRenderer != null) {
          final parts = glRenderer.split('|');
          if (parts.length >= 3) {
            gpuVendor = parts[0];
            gpuRenderer = parts[1];
            gpuVersion = parts[2];
          }
        }
      } catch (e) {
        print('[NYANYA-WEBVIEW] Failed to get GPU info: $e');
      }

      // 获取版本类型（android 或 byd）
      final versionType = await getVersionType();

      sendMessage('appConfig', {
        'version': packageInfo.version, // 例如 "1.0.5"
        'buildNumber': packageInfo.buildNumber, // 例如 "11372"
        'fullVersion':
            '${packageInfo.version}+${packageInfo.buildNumber}', // 组合版
        'versionType': versionType ?? 'android', // 版本类型：android（普通版）或 byd（比亚迪车机版）
        'system': 'Flutter App',
        'engine': engine.name,
        'sessionId': sessionId,
        'webViewVersion': webViewVersion,
        'availableEngines': availableEngines,
        'packageName': packageInfo.packageName, // 包名（应用ID）
        // 设备信息
        'deviceModel': deviceModel,
        'deviceBrand': deviceBrand,
        'manufacturer': manufacturer,
        'deviceType': deviceType,
        // Android 系统信息
        'androidVersion': androidVersion,
        'sdkInt': sdkInt,
        'hardware': hardware,
        'board': board,
        'display': display,
        'fingerprint': fingerprint,
        'bootloader': bootloader,
        'baseOS': baseOS,
        'securityPatch': securityPatch,
        'codename': codename,
        // CPU 信息
        'cpuAbi': cpuAbi,
        'supportedAbis': supportedAbis,
        // GPU 信息
        'gpuVendor': gpuVendor,
        'gpuRenderer': gpuRenderer,
        'gpuVersion': gpuVersion,
      });
    } catch (e) {
      sendMessage('appConfig', {
        'version': 'unknown',
        'buildNumber': 'unknown',
        'fullVersion': 'unknown',
        'system': 'Flutter App',
        'engine': 'unknown',
        'sessionId': sessionId,
        'webViewVersion': 0,
        'availableEngines': ['gecko'], // 默认只提供 gecko 作为备选
        'packageName': 'unknown',
        'deviceModel': 'unknown',
        'deviceBrand': 'unknown',
        'manufacturer': 'unknown',
        'deviceType': 'unknown',
        'androidVersion': 'unknown',
        'sdkInt': 'unknown',
        'hardware': 'unknown',
        'board': 'unknown',
        'display': 'unknown',
        'fingerprint': 'unknown',
        'bootloader': 'unknown',
        'baseOS': 'unknown',
        'securityPatch': 'unknown',
        'codename': 'unknown',
        'cpuAbi': 'unknown',
        'supportedAbis': ['unknown'],
        'gpuVendor': 'unknown',
        'gpuRenderer': 'unknown',
        'gpuVersion': 'unknown',
      });
    }
  }

  /// 获取 OpenGL 渲染器信息
  Future<String?> _getGLRenderer() async {
    try {
      // 使用 Android 原生方法获取 GPU 信息
      if (Platform.isAndroid) {
        const MethodChannel channel = MethodChannel('nyanya_gl_info');
        final String? result = await channel.invokeMethod('getGLInfo');
        return result;
      }
    } catch (e) {
      print('[NYANYA-WEBVIEW] Failed to get GL info: $e');
    }
    return null;
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

  void _handleGetThemeColor({String? bridgeId, String? sessionId}) {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    sendMessage(
        'getThemeColor', brightness == Brightness.dark ? 'dark' : 'light',
        bridgeId: bridgeId, sessionId: sessionId);
  }

  void _handleGetStatusBarData({String? bridgeId, String? sessionId}) {
    final mediaQuery =
        MediaQueryData.fromWindow(WidgetsBinding.instance.window);
    final statusBarHeight = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final viewPaddingTop = mediaQuery.viewPadding.top;
    final viewPaddingBottom = mediaQuery.viewPadding.bottom;
    final viewInsetsTop = mediaQuery.viewInsets.top;
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final size = WidgetsBinding.instance.window.physicalSize;
    final devicePixelRatio = WidgetsBinding.instance.window.devicePixelRatio;
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

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
    sendMessage('getStatusBarData', statusBarData,
        bridgeId: bridgeId, sessionId: sessionId);
  }

  Future<void> _handleCheckNewVersion(
      {bool showCheckingNotification = true, String? sessionId}) async {
    print(
        'Starting checkNewVersion... (showCheckingNotification: $showCheckingNotification)');
    _appUpdateService.setUpdateCheckingCallback(() {
      if (showCheckingNotification) {
        _updateCheckingCallback?.call();
      }
    });
    _appUpdateService.setUpdateCheckCallback((versionInfo, currentVersion, shouldShowChecking) {
      print('versionInfo: $versionInfo');

      if (versionInfo != null) {
        _pendingUpdateVersion = versionInfo.version;
        print('Sending updateAvailable message');

        sendMessage(
            'updateAvailable',
            {
              'version': versionInfo.version,
              'downloadUrl': versionInfo.downloadUrl,
            },
            sessionId: sessionId);

        _updateCheckCallback?.call(versionInfo,
            currentVersion, shouldShowChecking);
      } else {
        print('Sending updateNotAvailable message');
        sendMessage(
            'updateNotAvailable',
            {
              'currentVersion': currentVersion,
            },
            sessionId: sessionId);

        _updateCheckCallback?.call(null,
            currentVersion, shouldShowChecking);
      }
    });
    await _appUpdateService.checkNewVersion(showCheckingNotification: showCheckingNotification);
  }

  void _handleUpdateAppNewVersion(String downloadUrl, String version) {
    print('[NYANYA-BRIDGE] Starting direct app update with URL: $downloadUrl, version: $version');
    // 直接调用回调，让 main.dart 处理下载流程
    _startAppUpdateCallback?.call(downloadUrl, version);
  }

  void startUpdate(String downloadUrl, String version) {
    _appUpdateService.setProgressCallback((progress, receivedBytes, totalBytes) {
      sendMessage('updateProgress', {
        'received': receivedBytes,
        'total': totalBytes,
        'progress': progress,
      });
    });
    _appUpdateService.setCompleteCallback((success, error) {
      if (success) {
        sendMessage('updateComplete', {
          'version': version,
        });
      } else if (error != null) {
        sendMessage('updateError', {
          'error': error,
        });
      }
    });
    _appUpdateService.startDownload(
      downloadUrl: downloadUrl,
      version: version,
      i18nService: _i18nService,
      autoInstall: false,
    );
  }

  Future<void> skipUpdate(String version) async {
    sendMessage('skipVersion', version);
  }

  static const String _prefsKeyCustomHost = 'custom_host';
  static const String _prefsKeyLastVersion = 'last_app_version';
  String? _customHost;

  Future<void> _handleSwitchResources(String host,
      {String? bridgeId, String? sessionId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customHost = host;
      await prefs.setString(_prefsKeyCustomHost, host);
      _switchResourcesCallback?.call(host);
      sendMessage('switchResources', {'success': true, 'host': host},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      sendMessage('switchResources', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  Future<String?> getCustomHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKeyCustomHost);
  }

  Future<void> _handleUpdateLocalWebResources(String downloadUrl,
      {String? bridgeId, String? sessionId}) async {
    try {
      print('[Bridge] Starting download: $downloadUrl');
      _localWebResourcesUpdateProgressCallback?.call(0, 'downloading', 0, 0);
      sendMessage('updateLocalWebResourcesDownloading', {'progress': 0},
          bridgeId: bridgeId, sessionId: sessionId);

      final client = http.Client();
      final response =
          await client.send(http.Request('GET', Uri.parse(downloadUrl)));
      final total = response.contentLength ?? 0;
      var received = 0;
      final bytes = <int>[];

      print('[Bridge] Total content length: $total bytes');

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        final progress = total > 0 ? ((received / total) * 100).round() : 0;
        print('[Bridge] Download progress: $progress% ($received/$total)');
        _localWebResourcesUpdateProgressCallback?.call(
            progress, 'downloading', received, total);
        sendMessage(
            'updateLocalWebResourcesDownloading', {'progress': progress},
            bridgeId: bridgeId, sessionId: sessionId);
      }

      client.close();

      print('[Bridge] Download complete');
      _localWebResourcesUpdateProgressCallback?.call(
          100, 'downloading', total, total);
      sendMessage('updateLocalWebResourcesDownloading', {'progress': 100},
          bridgeId: bridgeId, sessionId: sessionId);

      _localWebResourcesUpdateProgressCallback?.call(0, 'extracting', 0, 0);
      sendMessage('updateLocalWebResourcesExtracting', {'progress': 0},
          bridgeId: bridgeId, sessionId: sessionId);

      final dir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${dir.path}/temp_update');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      final archive =
          TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
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
          _localWebResourcesUpdateProgressCallback?.call(
              progress, 'extracting', 0, 0);
          sendMessage(
              'updateLocalWebResourcesExtracting', {'progress': progress},
              bridgeId: bridgeId, sessionId: sessionId);
        }
      }

      _localWebResourcesUpdateProgressCallback?.call(100, 'extracting', 0, 0);
      sendMessage('updateLocalWebResourcesExtracting', {'progress': 100},
          bridgeId: bridgeId, sessionId: sessionId);

      final staticDir = Directory('${dir.path}/static_resources');
      if (await staticDir.exists()) {
        await staticDir.delete(recursive: true);
      }
      await tempDir.rename(staticDir.path);

      _localWebResourcesUpdateCompleteCallback?.call(true, null);
      sendMessage('updateLocalWebResourcesCompleted', {'success': true},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      _localWebResourcesUpdateCompleteCallback?.call(false, e.toString());
      sendMessage('updateLocalWebResourcesCompleted',
          {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
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

  Future<void> closeLocalServer() async {
    await _handleCloseLocalServer();
  }

  Future<void> _handleCloseLocalServer() async {
    print('[NYANYA-BRIDGE] Closing local server...');
    try {
      // 调用注册的回调来关闭本地服务器
      _closeLocalServerCallback?.call();
      print('[NYANYA-BRIDGE] Close local server callback called');
    } catch (e) {
      print('[NYANYA-BRIDGE] Failed to close local server: $e');
    }
  }

  Future<void> _handleOpenAppSettings() async {
    await openAppSettings();
  }

  Future<void> _handleSendNotification(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      int id;
      if (payload['id'] is int) {
        id = payload['id'];
      } else if (payload['id'] is String) {
        final stringId = payload['id'] as String;
        // 尝试解析为数字，如果失败则使用字符串哈希值（与取消方法保持一致）
        id = int.tryParse(stringId) ?? stringId.hashCode;
      } else {
        id = _notificationIdCounter++;
      }
      final title = payload['title']?.toString() ?? '';
      final body = payload['body']?.toString() ?? '';
      final ongoing = payload['ongoing'] as bool? ?? false;
      final closable = payload['closable'] as bool? ?? true;
      final autoCloseTimeout = payload['autoCloseTimeout'] as int?;
      final channelId =
          payload['channelId']?.toString() ?? 'trip_route_channel';
      final channelName = payload['channelName']?.toString() ?? 'Trip Route';
      final channelDescription = payload['channelDescription']?.toString() ??
          'Trip Route Track Notifications';
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

      final AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
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
        clickActionType: clickActionType,
        clickActionUrl: clickActionUrl,
      );

      // 设置新的自动关闭定时器
      if (autoCloseTimeout != null && autoCloseTimeout > 0 && !ongoing) {
        final timer = Timer(Duration(milliseconds: autoCloseTimeout), () {
          NotificationService().cancelNotification(id);
          _notificationTimers.remove(id);
        });
        _notificationTimers[id] = timer;
      }

      sendMessage('sendNotification', {'success': true, 'id': id},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      sendMessage('sendNotification', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
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

  Future<void> _handleCancelNotification(dynamic id,
      {String? bridgeId, String? sessionId}) async {
    try {
      int notificationId;
      if (id is int) {
        notificationId = id;
      } else if (id is String) {
        final stringId = id as String;
        // 尝试解析为数字，如果失败则使用字符串哈希值（与创建/更新保持一致）
        notificationId = int.tryParse(stringId) ?? stringId.hashCode;
      } else {
        sendMessage('cancelNotification',
            {'success': false, 'error': 'Invalid notification ID'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      await NotificationService().cancelNotification(notificationId);
      sendMessage('cancelNotification', {'success': true},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      sendMessage(
          'cancelNotification', {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  Future<void> _handleSendProgressNotification(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      int id;
      if (payload['id'] is int) {
        id = payload['id'];
      } else if (payload['id'] is String) {
        final stringId = payload['id'] as String;
        // 尝试解析为数字，如果失败则使用字符串哈希值
        id = int.tryParse(stringId) ?? stringId.hashCode;
      } else {
        id = _notificationIdCounter++;
      }
      final title = payload['title']?.toString() ?? '';
      final body = payload['body']?.toString() ?? '';
      final progress = payload['progress'] as int? ?? 0;
      final channelId =
          payload['channelId']?.toString() ?? 'trip_route_channel';
      final channelName = payload['channelName']?.toString() ?? 'Trip Route';
      final channelDescription = payload['channelDescription']?.toString() ??
          'Trip Route Track Notifications';
      final clickActionType = payload['clickActionType']?.toString();
      final clickActionUrl = payload['clickActionUrl']?.toString();

      await NotificationService().showProgressNotification(
        title: title,
        body: body,
        progress: progress,
        id: id,
        channelId: channelId,
        channelName: channelName,
        channelDescription: channelDescription,
        clickActionType: clickActionType,
        clickActionUrl: clickActionUrl,
      );

      sendMessage('sendProgressNotification', {'success': true, 'id': id},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      sendMessage('sendProgressNotification',
          {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  Future<void> _handleUpdateProgressNotification(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    try {
      int id;
      if (payload['id'] is int) {
        id = payload['id'];
      } else if (payload['id'] is String) {
        final stringId = payload['id'] as String;
        id = int.tryParse(stringId) ?? stringId.hashCode;
      } else {
        sendMessage('updateProgressNotification',
            {'success': false, 'error': 'Invalid notification ID'},
            bridgeId: bridgeId, sessionId: sessionId);
        return;
      }

      final progress = payload['progress'] as int? ?? 0;
      final body = payload['body']?.toString();

      await NotificationService().updateProgressNotification(
        id: id,
        progress: progress,
        body: body,
      );

      sendMessage('updateProgressNotification', {'success': true, 'id': id, 'progress': progress},
          bridgeId: bridgeId, sessionId: sessionId);
    } catch (e) {
      sendMessage('updateProgressNotification',
          {'success': false, 'error': e.toString()},
          bridgeId: bridgeId, sessionId: sessionId);
    }
  }

  // ==================== 权限检查 ====================

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
      print('[Bridge] Storage permission status: $status');
      
      if (status.isGranted) {
        return true;
      }

      print('[Bridge] Requesting storage permission...');
      final result = await Permission.storage.request();
      print('[Bridge] Storage permission request result: $result');
      
      return result.isGranted;
    } catch (e) {
      print('[Bridge] Error checking storage permission: $e');
      return false;
    }
  }

  Future<bool> _requestAndroid13StoragePermission() async {
    try {
      print('[Bridge] Android 13+: Checking MANAGE_EXTERNAL_STORAGE permission');
      
      final manageStatus = await Permission.manageExternalStorage.status;
      print('[Bridge] MANAGE_EXTERNAL_STORAGE status: $manageStatus');
      
      if (manageStatus.isGranted) {
        return true;
      }

      print('[Bridge] Requesting MANAGE_EXTERNAL_STORAGE permission...');
      final result = await Permission.manageExternalStorage.request();
      print('[Bridge] MANAGE_EXTERNAL_STORAGE request result: $result');
      
      return result.isGranted;
    } catch (e) {
      print('[Bridge] Error requesting Android 13 storage permission: $e');
      return false;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWebMessage':
        print(
            '[FlutterBridge] onWebMessage->handleWebMessage, message: ${call.arguments}');

        await _handleWebMessage(call.arguments as String);
        break;
    }
    _externalHandler?.call(call);
  }

  Future<void> _handleWebMessage(String messageString,
      {String? sessionId}) async {
    try {
      final Map<String, dynamic> json =
          jsonDecode(messageString) as Map<String, dynamic>;
      // 如果前端消息里已经有 sessionId，优先使用前端传递的
      final messageSessionId = json['sessionId'] as String?;
      final finalSessionId = messageSessionId ?? sessionId;

      final message = BridgeMessage(
        type: json['type'] as String,
        payload: json['payload'],
        bridgeId: json['bridgeId'] as String?,
        sessionId: finalSessionId,
      );

      // 提取 bridgeId
      final bridgeId = message.bridgeId;

      print(
          'NyaNyaOpenURL message.type ${message.type}, sessionId: ${message.sessionId}');
      // 标记是否需要分发消息（默认需要，除了特殊情况）
      bool shouldDispatch = true;

      switch (message.type) {
        case 'load':
          _handleLoadMessage(sessionId: finalSessionId);
          // load 消息不需要分发，因为它已经通过 sendMessage 发送了 appConfig
          shouldDispatch = false;
          break;
        case 'enableLocation':
          _enableLocation = message.payload as bool;
          _handleEnableLocation(_enableLocation, sessionId: finalSessionId);
          break;
        case 'getCurrentLocation':
          _handleGetCurrentLocation(
              bridgeId: bridgeId, sessionId: finalSessionId);
          break;
        case 'keepScreenOn':
          final keepOn = message.payload as bool;
          _handleKeepScreenOn(keepOn);
          break;
        case 'enableBackgroundLocation':
          _enableBackgroundLocation = message.payload as bool;
          _handleEnableBackgroundLocation(_enableBackgroundLocation,
              sessionId: finalSessionId);
          break;
        case 'enableBackgroundTasks':
          final enable = message.payload as bool;
          _backgroundService.setEnableBackgroundTasks(enable);
          if (enable) {
            _backgroundStartTime =
                DateTime.now().millisecondsSinceEpoch ~/ 1000;
            _backgroundLocationCount = 0;
          }
          break;
        // ============ 车辆数据统一接口 ============
        case 'carGet':
          final getCategory = message.payload as String?;
          if (getCategory != null) {
            _handleVehicleGet(getCategory,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'carGetField':
          final getFieldPayload = message.payload as Map<String, dynamic>?;
          if (getFieldPayload != null) {
            final category = getFieldPayload['category'] as String?;
            final field = getFieldPayload['field'] as String?;
            if (category != null) {
              _handleCarGetField(category, field,
                  bridgeId: bridgeId, sessionId: finalSessionId);
            }
          }
          break;
        case 'carEnableListener':
          final listenerPayload = message.payload as Map<String, dynamic>?;
          if (listenerPayload != null) {
            final category = listenerPayload['category'] as String?;
            final enabled = listenerPayload['enabled'] as bool? ?? true;
            if (category != null) {
              _handleVehicleEnableListener(category, enabled);
            }
          }
          break;
        case 'carSet':
          final setPayload = message.payload as Map<String, dynamic>?;
          if (setPayload != null) {
            final type = setPayload['type'] as String?;
            final field = setPayload['field'] as String?;
            final value = setPayload['value'];
            if (type != null && field != null) {
              _handleVehicleSet(type, field, value,
                  bridgeId: bridgeId, sessionId: finalSessionId);
            }
          }
          break;
        case 'hasFeature':
          final hasFeaturePayload = message.payload as Map<String, dynamic>?;
          if (hasFeaturePayload != null) {
            final category = hasFeaturePayload['category'] as String?;
            final feature = hasFeaturePayload['feature'] as String?;
            if (category == 'vehicleset' && feature != null) {
              final result =
                  await _vehicleService.services.vehicleset.hasFeature(feature);
              final responseKey = 'hasFeature:${message.bridgeId ?? ''}';
              sendMessage(responseKey, result,
                  bridgeId: bridgeId, sessionId: finalSessionId);
            }
          }
          break;
        case 'setLanguage':
          final lang = message.payload as String?;
          if (lang != null) {
            _languageService.setLanguage(lang);
            _i18nService.setLanguage(lang);
          }
          break;
        case 'enableCarData':
          final enableCar = message.payload as bool;
          if (enableCar) {
            _vehicleService.startCarDataUpdates();
          } else {
            _vehicleService.stopCarDataUpdates();
          }
          break;
        case 'getCarData':
          _vehicleService.requestCarData();
          break;
        case 'enableCarDataListener':
          final enableData = message.payload as bool;
          await _vehicleService.enableCarDataListener(enableData);
          break;
        case 'testCarData':
          final enabled = message.payload as bool;
          await _vehicleService.testCarData(enabled);
          break;
        case 'setCarDataListenerDebounceDelay':
          final delayMs = message.payload as int;
          await _vehicleService.setCarDataListenerDebounceDelay(delayMs);
          break;
        case 'checkCarSDKAvailable':
          final available = await _vehicleService.checkCarSDKAvailable();
          sendMessage('checkCarSDKAvailable', {'available': available},
              bridgeId: bridgeId, sessionId: finalSessionId);
          break;
        case 'setLogEnabled':
          final payload = message.payload as Map<String, dynamic>?;
          final type = payload?['type'] as String?;
          final enabled = payload?['enabled'] as bool? ?? false;
          if (type != null) {
            _logService.setLogEnabled(type, enabled);
          }
          break;
        case 'setStatusBar':
          final statusType = message.payload as String?;
          if (statusType != null) {
            _handleSetStatusBar(statusType);
          }
          break;
        case 'getStatusBarData':
          _handleGetStatusBarData(
              bridgeId: bridgeId, sessionId: finalSessionId);
          break;
        case 'getThemeColor':
          _handleGetThemeColor(bridgeId: bridgeId, sessionId: finalSessionId);
          break;
        case 'checkNewVersion':
          final showCheckingNotification = message.payload is Map
              ? (message.payload as Map)['showCheckingNotification'] as bool? ??
                  true
              : true;
          _handleCheckNewVersion(
              showCheckingNotification: showCheckingNotification,
              sessionId: finalSessionId);
          break;
        case 'updateAppNewVersion':
          final payload = message.payload is Map ? message.payload as Map : null;
          if (payload != null) {
            final downloadUrl = payload['downloadUrl'] as String?;
            final version = payload['version'] as String? ?? '';
            if (downloadUrl != null && downloadUrl.isNotEmpty) {
              _handleUpdateAppNewVersion(downloadUrl, version);
            }
          }
          break;
        case 'switchResources':
          final host = message.payload as String?;
          if (host != null) {
            _handleSwitchResources(host,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'updateLocalWebResources':
          final url = message.payload as String?;
          if (url != null) {
            _handleUpdateLocalWebResources(url,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'restartApp':
          _handleRestartApp();
          break;
        case 'quitApp':
          _handleQuitApp();
          break;
        case 'closeLocalServer':
          _handleCloseLocalServer();
          break;
        case 'sendNotification':
          if (message.payload is Map) {
            _handleSendNotification(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'cancelNotification':
          final cancelId = message.payload;
          _handleCancelNotification(cancelId,
              bridgeId: bridgeId, sessionId: finalSessionId);
          break;
        case 'sendProgressNotification':
          if (message.payload is Map) {
            _handleSendProgressNotification(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'updateProgressNotification':
          if (message.payload is Map) {
            _handleUpdateProgressNotification(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'thirdPartyLogin':
          final type = message.payload as String?;
          if (type != null) {
            _handleThirdPartyLogin(type,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'openInBrowser':
          final url = message.payload as String?;
          if (url != null) {
            _handleOpenInBrowser(url,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'openAppSettings':
          _handleOpenAppSettings();
          break;
        case 'switchEngine':
          final type = message.payload as String?;
          if (type != null) {
            _handleSwitchEngine(type,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'appStorage':
          if (message.payload is Map) {
            _handleAppStorage(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'checkPermissions':
          _handleCheckPermissions(message.payload,
              bridgeId: bridgeId, sessionId: finalSessionId);
          break;
        case 'requestPermissions':
          _handleRequestPermissions(message.payload,
              bridgeId: bridgeId, sessionId: finalSessionId);
          break;
        case 'saveFile':
          if (message.payload is Map) {
            _fileService.saveFile(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'readFile':
          final filePath = message.payload as String?;
          if (filePath != null) {
            _fileService.readFile(filePath,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        // 流式文件保存
        case 'saveFileStreamStart':
          if (message.payload is Map) {
            _fileService.saveFileStreamStart(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'saveFileStreamChunk':
          if (message.payload is Map) {
            _fileService.saveFileStreamChunk(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'saveFileStreamEnd':
          if (message.payload is Map) {
            _fileService.saveFileStreamEnd(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        // 流式文件读取
        case 'readFileStreamStart':
          final filePath = message.payload as String?;
          if (filePath != null) {
            _fileService.readFileStreamStart(filePath,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'readFileStreamChunk':
          if (message.payload is Map) {
            _fileService.readFileStreamChunk(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        case 'readFileStreamEnd':
          if (message.payload is Map) {
            _fileService.readFileStreamEnd(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        // 音频播放接口
        case 'playAudio':
          if (message.payload is Map) {
            _handlePlayAudio(message.payload as Map<String, dynamic>,
                bridgeId: bridgeId, sessionId: finalSessionId);
          }
          break;
        // 停止音频播放接口
        case 'stopAudio':
          _handleStopAudio(bridgeId: bridgeId, sessionId: finalSessionId);
          break;
        // default 不需要特殊处理，shouldDispatch 保持 true
      }

      // 统一分发消息（除了 load 消息）
      if (shouldDispatch) {
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
            'altitudeAccuracy': position.altitudeAccuracy,
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

    final duration =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - _backgroundStartTime;
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

  // 打开浏览器处理
  Future<void> _handleOpenInBrowser(String url,
      {String? bridgeId, String? sessionId}) async {
    print('[NyaNyaOpenURL Bridge] Open in browser requested: $url');

    try {
      // 清理 URL：移除首尾的反引号、空格、引号等无效字符
      String cleanedUrl = url.trim();

      cleanedUrl = cleanedUrl.replaceAll(RegExp(r'`'), '');

      print('[NyaNyaOpenURL Bridge] Cleaned URL: $cleanedUrl');

      if (cleanedUrl.isEmpty) {
        throw Exception('URL is empty after cleaning');
      }

      if (await canLaunchUrlString(cleanedUrl)) {
        await launchUrlString(cleanedUrl, mode: LaunchMode.externalApplication);

        sendMessage(
            'openInBrowser',
            {
              'success': true,
              'url': cleanedUrl,
            },
            bridgeId: bridgeId,
            sessionId: sessionId);
      } else {
        sendMessage(
            'openInBrowser',
            {
              'success': false,
              'error': 'Cannot launch URL',
              'url': cleanedUrl,
            },
            bridgeId: bridgeId,
            sessionId: sessionId);
      }
    } catch (e) {
      print('[Bridge] Error opening in browser: $e');
      sendMessage(
          'openInBrowser',
          {
            'success': false,
            'error': e.toString(),
            'url': url,
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
    }
  }

  // 第三方登录处理
  Future<void> _handleThirdPartyLogin(String type,
      {String? bridgeId, String? sessionId}) async {
    print('[Bridge] Third party login requested: $type');

    try {
      if (type == 'qq') {
        await _handleQQLogin(bridgeId: bridgeId, sessionId: sessionId);
      } else {
        const MethodChannel channel = MethodChannel('flutter_bridge');
        final result =
            await channel.invokeMethod('thirdPartyLogin', {'type': type});

        print('[Bridge] Third party login result: $result');

        final Map<String, dynamic> resultMap =
            Map<String, dynamic>.from(result as Map);
        final bool success = resultMap['success'] as bool;

        if (success) {
          sendMessage(
              'thirdPartyLogin',
              {
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
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
        } else {
          sendMessage(
              'thirdPartyLogin',
              {
                'success': false,
                'error': resultMap['error'] as String? ?? 'Login failed',
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
        }
      }
    } catch (e) {
      print('[Bridge] Third party login error: $e');
      sendMessage(
          'thirdPartyLogin',
          {
            'success': false,
            'error': e.toString(),
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
    }
  }

  // QQ 登录处理（Flutter端实现）
  Future<void> _handleQQLogin({String? bridgeId, String? sessionId}) async {
    print('[Bridge] QQ login requested');

    try {
      final String? qqAppId = dotenv.env['QQ_APP_ID'];
      final String? qqUniversalLink = dotenv.env['QQ_UNIVERSAL_LINK'];

      if (qqAppId == null ||
          qqAppId.isEmpty ||
          qqAppId == 'your_qq_app_id_here') {
        throw Exception('QQ_APP_ID not configured');
      }

      await TencentKitPlatform.instance.registerApp(
        appId: qqAppId,
        universalLink:
            qqUniversalLink?.isNotEmpty == true ? qqUniversalLink : null,
      );

      // QQ SDK 3.5.7+ 需要先授权设备信息权限
      try {
        const MethodChannel qqChannel = MethodChannel('qq_login');
        await qqChannel.invokeMethod('setPermissionGranted');
        print('[Bridge] QQ permission granted successfully');
      } catch (e) {
        print('[Bridge] Failed to grant QQ permission: $e');
      }

      final Completer<TencentLoginResp> loginCompleter =
          Completer<TencentLoginResp>();

      StreamSubscription<TencentResp>? subscription;
      subscription = TencentKitPlatform.instance.respStream().listen((resp) {
        if (resp is TencentLoginResp) {
          subscription?.cancel();
          if (!loginCompleter.isCompleted) {
            loginCompleter.complete(resp);
          }
        }
      });

      await TencentKitPlatform.instance.login(
        scope: <String>[TencentScope.kGetSimpleUserInfo],
      );

      final TencentLoginResp loginRespResult =
          await loginCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('QQ login timeout'),
      );

      print('[Bridge] QQ login result: ${loginRespResult.ret}');

      if (loginRespResult.isSuccessful == true) {
        // 调用 QQ UnionID 接口获取 unionid
        String? unionid;
        try {
          final response = await http.get(Uri.parse(
              'https://graph.qq.com/oauth2.0/me?access_token=${loginRespResult.accessToken}&unionid=1&fmt=json'));
          if (response.statusCode == 200) {
            final jsonData = json.decode(response.body);
            unionid = jsonData['unionid'] as String?;
            print('[Bridge] QQ unionid obtained: $unionid');
          }
        } catch (e) {
          print('[Bridge] Failed to get QQ unionid: $e');
        }

        // 调用 QQ 用户信息接口获取用户资料
        String userNickname = '';
        String userAvatar = '';
        String userAvatarBig = '';
        String userGender = '';
        String userCity = '';
        try {
          final userInfoResponse = await http.get(Uri.parse(
              'https://graph.qq.com/user/get_user_info?access_token=${loginRespResult.accessToken}&oauth_consumer_key=$qqAppId&openid=${loginRespResult.openid}'));
          if (userInfoResponse.statusCode == 200) {
            final userInfoData = json.decode(userInfoResponse.body);
            if (userInfoData['ret'] == 0) {
              userNickname = userInfoData['nickname']?.toString() ?? '';
              userAvatar = userInfoData['figureurl']?.toString() ?? '';
              userAvatarBig = userInfoData['figureurl_qq_2']?.toString() ??
                  userInfoData['figureurl_qq_1']?.toString() ?? '';
              userGender = userInfoData['gender']?.toString() ?? '';
              userCity = userInfoData['city']?.toString() ?? '';
              print('[Bridge] QQ user info obtained: $userNickname, $userAvatar');
            } else {
              print('[Bridge] QQ user info error: ${userInfoData['msg']}');
            }
          }
        } catch (e) {
          print('[Bridge] Failed to get QQ user info: $e');
        }

        sendMessage(
            'thirdPartyLogin',
            {
              'success': true,
              'data': {
                // 通用字段（谷歌和QQ都有）
                'type': 'qq',
                'accessToken': loginRespResult.accessToken,
                // QQ 专属字段
                'openid': loginRespResult.openid,
                'unionid': unionid,
                'user': {
                  'id': loginRespResult.openid,
                  // 通用字段（谷歌和QQ都有）
                  'name': userNickname,
                  'avatar': userAvatar,
                  // QQ 专属字段
                  'avatarBig': userAvatarBig,
                  'gender': userGender,
                  'city': userCity,
                  // Google 专属字段
                  'email': '',
                },
              },
            },
            bridgeId: bridgeId,
            sessionId: sessionId);
      } else {
        sendMessage(
            'thirdPartyLogin',
            {
              'success': false,
              'error': loginRespResult.msg ?? 'QQ login failed',
            },
            bridgeId: bridgeId,
            sessionId: sessionId);
      }
    } catch (e) {
      print('[Bridge] QQ login error: $e');
      sendMessage(
          'thirdPartyLogin',
          {
            'success': false,
            'error': e.toString(),
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
    }
  }

  Future<void> _handleSwitchEngine(String type,
      {String? bridgeId, String? sessionId}) async {
    print('[Bridge] Switch engine requested: $type');

    try {
      final engine =
          type == 'gecko' ? WebViewEngine.gecko : WebViewEngine.system;

      // 使用全局的EngineManager来设置引擎
      await EngineManager().setCustomEngine(engine);

      sendMessage(
          'switchEngine',
          {
            'success': true,
            'engine': type,
            'message':
                'Engine switched to $type, please restart app to take effect',
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
    } catch (e) {
      print('[Bridge] Switch engine error: $e');
      sendMessage(
          'switchEngine',
          {
            'success': false,
            'error': e.toString(),
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
    }
  }

  void _handleAppStorage(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    final operation = payload['operation'] as String?;
    final key = payload['key'] as String?;
    final value = payload['value'];
    final expiresIn = payload['expiresIn'] as int?; // 有效期（毫秒）
    final hostname = payload['hostname'] as String?; // 域名标识

    if (operation == null || key == null) {
      sendMessage(
          'appStorage',
          {
            'success': false,
            'error': 'operation and key are required',
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
      return;
    }

    // 使用域名作为标识，如果没有域名则使用 sessionId 或默认值
    final storageKeyPrefix = hostname ?? sessionId ?? 'default';

    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '${storageKeyPrefix}_${key}_timestamp';

      switch (operation) {
        case 'set':
          // 存储值
          await prefs.setString('${storageKeyPrefix}_$key', jsonEncode(value));
          // 存储时间戳（如果有有效期）
          if (expiresIn != null && expiresIn > 0) {
            final expiresAt = DateTime.now().millisecondsSinceEpoch + expiresIn;
            await prefs.setInt(timestampKey, expiresAt);
          } else {
            // 无有效期则清除时间戳
            await prefs.remove(timestampKey);
          }
          sendMessage(
              'appStorage',
              {
                'success': true,
                'operation': 'set',
                'key': key,
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
          break;

        case 'get':
          // 检查是否过期
          final expiresAt = prefs.getInt(timestampKey);
          if (expiresAt != null &&
              DateTime.now().millisecondsSinceEpoch > expiresAt) {
            // 已过期，删除数据
            await prefs.remove('${storageKeyPrefix}_$key');
            await prefs.remove(timestampKey);
            sendMessage(
                'appStorage',
                {
                  'success': true,
                  'operation': 'get',
                  'key': key,
                  'value': null,
                  'expired': true,
                },
                bridgeId: bridgeId,
                sessionId: sessionId);
          } else {
            // 未过期或无有效期
            final storedValue = prefs.getString('${storageKeyPrefix}_$key');
            sendMessage(
                'appStorage',
                {
                  'success': true,
                  'operation': 'get',
                  'key': key,
                  'value': storedValue != null ? jsonDecode(storedValue) : null,
                  'expired': false,
                },
                bridgeId: bridgeId,
                sessionId: sessionId);
          }
          break;

        case 'delete':
          await prefs.remove('${storageKeyPrefix}_$key');
          await prefs.remove(timestampKey);
          sendMessage(
              'appStorage',
              {
                'success': true,
                'operation': 'delete',
                'key': key,
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
          break;

        default:
          sendMessage(
              'appStorage',
              {
                'success': false,
                'error': 'Unknown operation: $operation',
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
      }
    } catch (e) {
      print('[Bridge] appStorage error: $e');
      sendMessage(
          'appStorage',
          {
            'success': false,
            'error': e.toString(),
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
    }
  }

  /// 处理音频播放请求
  Future<void> _handlePlayAudio(Map<String, dynamic> payload,
      {String? bridgeId, String? sessionId}) async {
    print('[Bridge] _handlePlayAudio called');
    
    final type = payload['type'] as String? ?? 'base64';
    final base64Data = payload['base64Data'] as String?;
    final text = payload['text'] as String?;
    final edgeTTS = payload['edgeTTS'] as Map<String, dynamic>?;
    final exclusive = payload['exclusive'] as bool? ?? false;
    
    // 处理音量参数，支持 int 和 double 类型
    final volumeValue = payload['volume'];
    double volume = 1.0;
    if (volumeValue is int) {
      volume = volumeValue.toDouble();
    } else if (volumeValue is double) {
      volume = volumeValue;
    }
    
    // 处理播放速度参数，支持 int 和 double 类型
    final speedValue = payload['speed'];
    double speed = 1.0;
    if (speedValue is int) {
      speed = speedValue.toDouble();
    } else if (speedValue is double) {
      speed = speedValue;
    }
    
    Uint8List? audioBytes;
    
    try {
      if (type == 'text') {
        // Text模式：调用 Edge TTS API 获取音频
        if (text == null || text.isEmpty) {
          print('[Bridge] playAudio error: text is required for text mode');
          sendMessage(
              'playAudioError',
              {
                'error': 'text is required for text mode',
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
          return;
        }
        
        if (edgeTTS == null || 
            edgeTTS['url'] == null || 
            edgeTTS['apiKey'] == null) {
          print('[Bridge] playAudio error: edgeTTS config is required for text mode');
          sendMessage(
              'playAudioError',
              {
                'error': 'edgeTTS config (url and apiKey) is required for text mode',
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
          return;
        }
        
        print('[Bridge] playAudio: calling Edge TTS API...');
        
        // 调用 Edge TTS API
        final ttsUrl = edgeTTS['url'] as String;
        final apiKey = edgeTTS['apiKey'] as String;
        
        final response = await http.post(
          Uri.parse('$ttsUrl/v1/audio/speech'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'tts-1',
            'input': text,
            'voice': 'zh-CN-XiaoxiaoNeural',
            'response_format': 'mp3',
            'speed': speed,
          }),
        );
        
        if (response.statusCode != 200) {
          throw Exception('TTS API request failed with status ${response.statusCode}');
        }
        
        audioBytes = response.bodyBytes;
        print('[Bridge] playAudio: TTS API response received');
        
      } else {
        // Base64模式：解码音频数据
        if (base64Data == null || base64Data.isEmpty) {
          print('[Bridge] playAudio error: base64Data is required for base64 mode');
          sendMessage(
              'playAudioError',
              {
                'error': 'base64Data is required for base64 mode',
              },
              bridgeId: bridgeId,
              sessionId: sessionId);
          return;
        }
        
        audioBytes = base64Decode(base64Data);
      }
      
      // 保存当前播放的会话信息
      _currentAudioBridgeId = bridgeId;
      _currentAudioSessionId = sessionId;
      
      // 配置音频焦点模式（实现混音的关键）
      final audioSession = await AudioSession.instance;
      
      if (exclusive) {
        // 独占模式：请求独占音频焦点，暂停其他应用
        await audioSession.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.assistanceNavigationGuidance,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        // 激活独占焦点
        await audioSession.setActive(true);
      } else {
        // 共存模式：使用 duck 模式，与其他音频混合播放
        await audioSession.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.assistanceNavigationGuidance,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ));
        // 激活共存焦点
        await audioSession.setActive(true);
      }
      
      // 设置音量（用户指定或默认值）
      await _audioPlayer.setVolume(volume);
      
      // 设置播放速度
      await _audioPlayer.setSpeed(speed);
      
      // 将音频数据写入临时文件，然后播放
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(audioBytes!);
      
      // 使用 just_audio 播放临时文件
      await _audioPlayer.setAudioSource(AudioSource.file(tempFile.path));
      
      // 发送开始播放回调
      sendMessage(
          'playAudioStarted',
          {
            'message': 'Starting audio playback',
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
      
      // 开始播放
      await _audioPlayer.play();
      
      // 监听播放状态变化（使用 firstWhere 等待播放完成）
      final completer = Completer<void>();
      var isPlayingReported = false;
      
      final subscription = _audioPlayer.playerStateStream.listen((PlayerState state) {
        final processingState = state.processingState;
        final playing = state.playing;
        
        // 播放中事件（只发送一次）
        if (playing && !isPlayingReported) {
          isPlayingReported = true;
          sendMessage(
              'playAudioPlaying',
              {
                'message': 'Audio is playing',
              },
              bridgeId: _currentAudioBridgeId,
              sessionId: _currentAudioSessionId);
        }
        
        // 播放完成或停止
        if (processingState == ProcessingState.completed || 
            processingState == ProcessingState.idle) {
          completer.complete();
        }
      });
      
      // 等待播放完成
      await completer.future;
      
      // 发送播放完成回调
      sendMessage(
          'playAudioCompleted',
          {
            'message': 'Audio playback completed',
          },
          bridgeId: _currentAudioBridgeId,
          sessionId: _currentAudioSessionId);
      
      // 取消监听器
      subscription.cancel();
      
      // 播放完成后释放音频焦点，恢复系统音乐音量
      if (!exclusive) {
        await audioSession.setActive(false);
      }
      
      // 删除临时文件
      tempFile.delete().catchError((_) => {});
      
      // 重置当前播放会话
      _currentAudioBridgeId = null;
      _currentAudioSessionId = null;
      
    } catch (e) {
      print('[Bridge] playAudio error: $e');
      sendMessage(
          'playAudioError',
          {
            'error': e.toString(),
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
      // 重置当前播放会话
      _currentAudioBridgeId = null;
      _currentAudioSessionId = null;
    }
  }

  /// 处理停止音频播放请求
  Future<void> _handleStopAudio({String? bridgeId, String? sessionId}) async {
    print('[Bridge] _handleStopAudio called');
    
    try {
      // 停止播放
      await _audioPlayer.stop();
      
      // 释放音频焦点
      final audioSession = await AudioSession.instance;
      await audioSession.setActive(false);
      
      // 重置当前播放会话
      _currentAudioBridgeId = null;
      _currentAudioSessionId = null;
      
      // 发送停止完成回调
      sendMessage(
          'stopAudioCompleted',
          {
            'message': 'Audio playback stopped',
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
      
      print('[Bridge] _handleStopAudio completed');
    } catch (e) {
      print('[Bridge] stopAudio error: $e');
      sendMessage(
          'stopAudioError',
          {
            'error': e.toString(),
          },
          bridgeId: bridgeId,
          sessionId: sessionId);
      // 重置当前播放会话
      _currentAudioBridgeId = null;
      _currentAudioSessionId = null;
    }
  }

  void dispose() {
    _positionSubscription?.cancel();
    _carDataSubscription?.cancel();
    _disposeVehicleDataListeners();
    _vehicleService.dispose();
    _messageHandlers.clear();
    _audioPlayer.dispose();
  }
}
