import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // 暂时禁用
import 'local_server.dart';
import 'components/components.dart';
import 'package:flutter_bridge/src/bridge_controller.dart';
import 'package:flutter_bridge/src/bridge_message.dart';
import 'package:i18n/i18n.dart';

String? _initialUrl;
String _appTitle = '';

// 全局通知服务
FlutterLocalNotificationsPlugin? _notificationPlugin;

Future<void> _initNotificationService() async {
  _notificationPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await _notificationPlugin!.initialize(initializationSettings);
}

Future<void> _showNotification(String title, String body) async {
  if (_notificationPlugin == null) {
    await _initNotificationService();
  }
  
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'local_server_channel',
    'Local Server',
    channelDescription: 'Local server status notifications',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await _notificationPlugin!.show(
    0,
    title,
    body,
    platformChannelSpecifics,
    payload: 'item x',
  );
}

/// 初始化前台服务
// Future<void> _initForegroundTask(dynamic i18nService) async {
//   FlutterForegroundTask.init(
//     androidNotificationOptions: AndroidNotificationOptions(
//       channelId: 'foreground_task',
//       channelName: i18nService.t('foreground_task_channel_name'),
//       channelDescription: i18nService.t('foreground_task_channel_description'),
//       channelImportance: NotificationChannelImportance.LOW,
//       priority: NotificationPriority.LOW,
//       iconData: const NotificationIconData(
//         resType: ResourceType.mipmap,
//         resPrefix: ResourcePrefix.ic,
//         name: 'launcher',
//       ),
//     ),
//     iosNotificationOptions: const IOSNotificationOptions(),
//     foregroundTaskOptions: const ForegroundTaskOptions(
//       interval: 5000,
//       autoRunOnBoot: false,
//       allowWakeLock: true,
//       allowWifiLock: true,
//     ),
//   );
//   
//   await FlutterForegroundTask.requestNotificationPermission();
// }

/// 启动前台服务（进入后台时调用）
// Future<void> _startForegroundTask(dynamic i18nService) async {
//   try {
//     print('[NYANYA-FGS] Starting foreground service...');
//     await FlutterForegroundTask.startService(
//       notificationTitle: i18nService.t('foreground_task_notification_title'),
//       notificationText: i18nService.t('foreground_task_notification_text'),
//     );
//     print('[NYANYA-FGS] Foreground service started');
//   } catch (e) {
//     print('[NYANYA-FGS] Failed to start foreground service: $e');
//   }
// }

/// 停止前台服务（回到前台时调用）
// Future<void> _stopForegroundTask() async {
//   try {
//     print('[NYANYA-FGS] Stopping foreground service...');
//     await FlutterForegroundTask.stopService();
//     print('[NYANYA-FGS] Foreground service stopped');
//   } catch (e) {
//     print('[NYANYA-FGS] Failed to stop foreground service: $e');
//   }
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化通知服务
  await _initNotificationService();
  
  // 初始化 BridgeController (包含 i18n)
  await BridgeController().init();
  final i18nService = BridgeController().i18nService;
  _appTitle = i18nService.t('app_title');
  
  // 先访问 LocalServer.instance 确保单例初始化（端口已确定）
  final localServerUrl = LocalServer.instance.url;
  _initialUrl = BridgeController().languageService.getLocalizedUrl(localServerUrl);
  
  // 初始化前台服务（提升应用在后台的存活概率）- 需要 i18n
  // await _initForegroundTask(i18nService); // 暂时禁用
  
  // 启动本地服务（带重试机制）
  try {
    await LocalServer.instance.start();
    print('Local server started successfully on $localServerUrl');
  } catch (e) {
    print('Failed to start local server after retries: $e');
    await _showNotification(i18nService.t('service_start_failed_title'), i18nService.t('service_start_failed_content'));
  }
  
  final brightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: brightness == Brightness.dark ? Colors.black : Colors.white,
    statusBarIconBrightness:
        brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor:
        brightness == Brightness.dark ? Colors.black : Colors.white,
    systemNavigationBarIconBrightness:
        brightness == Brightness.dark ? Brightness.light : Brightness.dark,
  ));
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Brightness _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _appTitle,
      theme: ThemeData(
        brightness: _brightness,
        scaffoldBackgroundColor:
            _brightness == Brightness.dark ? Colors.black : Colors.white,
      ),
      home: const WebViewContainer(),
    );
  }
}

class WebViewContainer extends StatefulWidget {
  const WebViewContainer({super.key});

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

// 加载状态枚举
enum LoadingStep {
  initial,
  loadingGecko,
  geckoSuccess,
  geckoFailed,
  loadingServer,
  serverSuccess,
  serverFailed,
  loadingWeb,
  webSuccess,
  webFailed,
}

class _WebViewContainerState extends State<WebViewContainer>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // ================================
  // 静态持久化变量 - 防止 Widget 重建时状态丢失
  // ================================
  static bool _isLoadingStatic = true;
  static bool _isPageLoadedStatic = false; // 标记页面是否已经成功加载过
  static LoadingStep _loadingStepStatic = LoadingStep.initial;
  static List<String> _loadingLogStatic = [];
  static DateTime? _lastBackgroundTimeStatic; // 记录进入后台的时间
  static bool _isInBackgroundStatic = false; // 标记是否在后台
  static DateTime? _lastRecoveryTimeStatic; // 记录上次恢复的时间
  static bool _isRecoveringStatic = false; // 标记是否正在恢复中
  static bool _kernelHealthyStatic = false; // 标记内核是否健康
  static bool _safeAreaTopStatic = true; // 标记顶部是否启用 SafeArea
  static bool _safeAreaBottomStatic = true; // 标记底部是否启用 SafeArea
  // ================================

  double _pitch = 0.0;
  double _roll = 0.0;
  bool _isLoading = _isLoadingStatic;
  bool _isPageLoaded = _isPageLoadedStatic;
  Brightness _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  late String _loadingSubtitle;
  
  // 详细加载状态追踪
  LoadingStep _loadingStep = _loadingStepStatic;
  List<String> _loadingLog = List.from(_loadingLogStatic);
  
  // 后台状态追踪
  DateTime? _lastBackgroundTime = _lastBackgroundTimeStatic;
  bool _isInBackground = _isInBackgroundStatic;
  DateTime? _lastRecoveryTime = _lastRecoveryTimeStatic;
  bool _safeAreaTop = _safeAreaTopStatic;

  Timer? _sensorTimer;
  Timer? _loadTimeoutTimer;
  
  late void Function(BridgeMessage) _closeLoadingHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _loadingSubtitle = BridgeController().i18nService.t('loading_subtitle');
    _bridgeHandlerListener();
    _statusBarHandlerListener();
    
    // 关键修复：如果正在恢复中，跳过加载序列（避免重复启动服务器）
    if (_isRecoveringStatic) {
      print('[NYANYA-INIT] recovery in progress, skipping');
      return;
    }
    
    // 关键修复：如果页面已经加载过，就不应该重新运行加载序列
    if (!_isPageLoaded) {
      print('[NYANYA-INIT] first load, starting sequence');
      // 开始详细加载流程
      _startLoadingSequence();
      
      // 超时时间延长到15秒，确保有足够时间完成所有加载步骤
      _loadTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _isLoading) {
          print('Loading timeout after 15 seconds');
          _addLoadingLog(BridgeController().i18nService.t('loading_web_failed'));
          setState(() {
            _loadingStep = LoadingStep.webFailed;
            _loadingStepStatic = _loadingStep;
          });
          
          // 再等待2秒后关闭加载界面
          Timer(const Duration(seconds: 2), () {
            if (mounted && _isLoading) {
              setState(() {
                _isLoading = false;
                _isLoadingStatic = _isLoading;
              });
            }
          });
        }
      });
    } else {
      print('[NYANYA-INIT] page already loaded, skip sequence');
      // 页面已经加载过，确保 _isLoading 保持 false
      if (_isLoading) {
        setState(() {
          _isLoading = false;
          _isLoadingStatic = _isLoading;
        });
      }
      _loadTimeoutTimer?.cancel();
    }
  }

  /// 详细加载流程
  Future<void> _startLoadingSequence() async {
    final i18n = BridgeController().i18nService;
    
    // 1. 加载 GeckoView 内核
    setState(() {
      _loadingStep = LoadingStep.loadingGecko;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t('loading_gecko'));
      _loadingLogStatic.add(i18n.t('loading_gecko'));
    });
    print('Loading GeckoView engine...');
    
    // 等待一小段时间让 GeckoView 初始化（实际由平台层完成）
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _loadingStep = LoadingStep.geckoSuccess;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t('loading_gecko_success'));
      _loadingLogStatic.add(i18n.t('loading_gecko_success'));
    });
    print('GeckoView engine loaded');
    
    // 2. 启动本地静态服务
    setState(() {
      _loadingStep = LoadingStep.loadingServer;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t('loading_server'));
      _loadingLogStatic.add(i18n.t('loading_server'));
    });
    print('Starting local server...');
    
    try {
      await LocalServer.instance.start();
      setState(() {
        _loadingStep = LoadingStep.serverSuccess;
        _loadingStepStatic = _loadingStep;
        _loadingLog.add(i18n.t('loading_server_success'));
        _loadingLogStatic.add(i18n.t('loading_server_success'));
      });
      print('Local server started successfully');
    } catch (e) {
      setState(() {
        _loadingStep = LoadingStep.serverFailed;
        _loadingStepStatic = _loadingStep;
        _loadingLog.add(i18n.t('loading_server_failed'));
        _loadingLogStatic.add(i18n.t('loading_server_failed'));
      });
      print('Local server failed to start: $e');
      return;
    }
    
    // 3. 等待网站响应
    setState(() {
      _loadingStep = LoadingStep.loadingWeb;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t('loading_web'));
      _loadingLogStatic.add(i18n.t('loading_web'));
    });
    print('Waiting for website response...');
    
    // 网站响应由 JavaScript 的 closeLoading 消息触发，这里不主动标记成功
  }

  void _addLoadingLog(String message) {
    setState(() {
      _loadingLog.add(message);
      _loadingLogStatic.add(message);
    });
  }

  void _bridgeHandlerListener() {
    _closeLoadingHandler = (message) {
      print('Received closeLoading message');
      
      // 标记网站响应成功
      final i18n = BridgeController().i18nService;
      _addLoadingLog(i18n.t('loading_web_success'));
      
      setState(() {
        _loadingStep = LoadingStep.webSuccess;
        _loadingStepStatic = _loadingStep;
        _isLoading = false;
        _isLoadingStatic = _isLoading;
        _isPageLoaded = true; // 标记页面已成功加载
        _isPageLoadedStatic = _isPageLoaded;
      });
      _loadTimeoutTimer?.cancel();
    };
    BridgeController().on('closeLoading', _closeLoadingHandler);
  }

  void _statusBarHandlerListener() {
    BridgeController().setStatusBarChangeHandler((String type) {
      setState(() {
        _safeAreaTop = (type != 'transparent-light' && type != 'transparent-dark' && type != 'hide');
        _safeAreaTopStatic = _safeAreaTop;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('[NYANYA-LIFECYCLE] state=$state');
    
    if (state == AppLifecycleState.paused) {
      _lastBackgroundTime = DateTime.now();
      _lastBackgroundTimeStatic = _lastBackgroundTime;
      _isInBackground = true;
      _isInBackgroundStatic = _isInBackground;
      
      // TODO: 前台服务暂时禁用 (flutter_foreground_task 与 MIUI 不兼容)
      // _startForegroundTaskSafe();
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _isInBackgroundStatic = _isInBackground;
      // TODO: 前台服务暂时禁用
      // _stopForegroundTaskSafe();
      _checkAndRecoverState();
    }
  }

  // void _startForegroundTaskSafe() {
  //   Future.delayed(const Duration(milliseconds: 500), () {
  //     try {
  //       if (_isInBackgroundStatic) {
  //         _startForegroundTaskImpl();
  //       }
  //     } catch (e, stack) {
  //       print('[NYANYA-FGS] _startForegroundTaskSafe failed: $e');
  //       print('[NYANYA-FGS] stack: $stack');
  //     }
  //   });
  // }

  // void _stopForegroundTaskSafe() {
  //   try {
  //     _stopForegroundTaskImpl();
  //   } catch (e, stack) {
  //     print('[NYANYA-FGS] _stopForegroundTaskSafe failed: $e');
  //     print('[NYANYA-FGS] stack: $stack');
  //   }
  // }

  // void _startForegroundTaskImpl() {
  //   final service = BridgeController().i18nService;
  //   _startForegroundTask(service);
  // }

  // void _stopForegroundTaskImpl() {
  //   _stopForegroundTask();
  // }

  /// 检测并恢复应用状态
  /// 
  /// 核心原则：
  /// 1. 每次从后台返回都检测
  /// 2. 只有服务真的挂了才恢复
  /// 3. 页面加载成功过才考虑恢复
  Future<void> _checkAndRecoverState() async {
    print('[NYANYA-CHECK] === Checking app state on resume ===');
    print('[NYANYA-CHECK]   _lastBackgroundTime: $_lastBackgroundTime');
    print('[NYANYA-CHECK]   _isPageLoaded: $_isPageLoaded');
    print('[NYANYA-CHECK]   LocalServer status: ${LocalServer.instance.status}');
    print('[NYANYA-CHECK]   LocalServer serverExists: ${LocalServer.instance.serverExists}');
    print('[NYANYA-CHECK]   _channel: ${_channel == null ? "null" : "exists"}');
    
    if (_lastBackgroundTime == null) {
      print('[NYANYA-CHECK] First launch, skip check');
      return;
    }
    
    final bgDuration = DateTime.now().difference(_lastBackgroundTime!).inMilliseconds;
    print('[NYANYA-CHECK] Background duration: ${bgDuration}ms');
    
    if (!_isPageLoaded) {
      print('[NYANYA-CHECK] Page never loaded, skip recovery');
      return;
    }
    
    final serverHealthy = LocalServer.instance.checkServerHealth();
    print('[NYANYA-CHECK] Server health: $serverHealthy');
    
    final kernelHealthy = checkKernelHealth();
    print('[NYANYA-CHECK] Kernel health: $kernelHealthy');
    
    if (!serverHealthy || !kernelHealthy) {
      print('[NYANYA-RECOVERY] Starting recovery...');
      _isRecoveringStatic = true;
      await _performRecovery();
      _isRecoveringStatic = false;
    } else {
      print('[NYANYA-CHECK] Server and Kernel healthy, preserved');
    }
  }

  /// 检测 GeckoView 内核是否健康
  bool checkKernelHealth() {
    _kernelHealthyStatic = _channel != null;
    return _kernelHealthyStatic;
  }

  /// 执行恢复操作
  Future<void> _performRecovery() async {
    print('[NYANYA-RECOVERY] _performRecovery() called');
    _lastRecoveryTime = DateTime.now();
    _lastRecoveryTimeStatic = _lastRecoveryTime;
    
    setState(() {
      _isLoading = true;
      _isLoadingStatic = _isLoading;
      _loadingLog.clear();
      _loadingLogStatic.clear();
    });
    
    // 重新设置超时计时器（防止前端不调用closeLoading导致loading一直显示）
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        print('[NYANYA-RECOVERY] timeout, hiding loading');
        setState(() {
          _isLoading = false;
          _isLoadingStatic = _isLoading;
        });
      }
    });
    
    final i18n = BridgeController().i18nService;
    
    try {
      // 步骤1: 重启本地服务
      setState(() {
        _loadingLog.add(i18n.t('loading_server'));
        _loadingLogStatic.add(i18n.t('loading_server'));
      });
      await LocalServer.instance.restart();
      print('Server restarted successfully');
      
      setState(() {
        _loadingLog.add(i18n.t('loading_server_success'));
        _loadingLogStatic.add(i18n.t('loading_server_success'));
        _loadingLog.add(i18n.t('loading_web'));
        _loadingLogStatic.add(i18n.t('loading_web'));
      });
      
      // 等待服务启动
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 步骤2: 重新加载页面
      _reloadWebView();
      
    } catch (e) {
      print('Failed to perform recovery: $e');
      setState(() {
        _loadingLog.add(i18n.t('loading_server_failed'));
        _loadingLogStatic.add(i18n.t('loading_server_failed'));
      });
      await _showNotification(i18n.t('app_exception_title'), i18n.t('app_exception_content'));
      
      // 3秒后关闭加载界面
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingStatic = _isLoading;
          });
        }
      });
    }
  }

  /// 重新加载 WebView
  void _reloadWebView() {
    if (_channel != null) {
      try {
        final url = _initialUrl ?? LocalServer.instance.url;
        _channel!.invokeMethod('loadUrl', {'url': url});
        print('Reloading webview with URL: $url');
      } catch (e) {
        print('Failed to reload webview: $e');
        // 如果调用失败，可能是 GeckoView 已销毁，需要通过重建来恢复
        print('GeckoView may be destroyed, will be recreated on next frame');
      }
    }
  }

  @override
  void didChangePlatformBrightness() {
    _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:
          _brightness == Brightness.dark ? Colors.black : Colors.white,
      statusBarIconBrightness:
          _brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          _brightness == Brightness.dark ? Colors.black : Colors.white,
      systemNavigationBarIconBrightness:
          _brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    ));
  }

  void _initSensorStreams() {
    gyroscopeEventStream().listen((GyroscopeEvent event) {
      const double dt = 0.016;
      setState(() {
        _pitch += event.y * dt * (180 / 3.1415926535);
        _roll += event.x * dt * (180 / 3.1415926535);
        _pitch = _pitch.clamp(-90.0, 90.0);
        _roll = _roll.clamp(-90.0, 90.0);
      });
    });

    accelerometerEventStream().listen((AccelerometerEvent event) {});
  }

  void _startSensorBridge() {
    _sensorTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (_channel != null) {
        final message = '''
          {
            "type": "SENSOR_DATA",
            "data": {
              "pitch": ${_pitch.toStringAsFixed(2)},
              "roll": ${_roll.toStringAsFixed(2)},
              "timestamp": ${DateTime.now().millisecondsSinceEpoch}
            }
          }
        ''';
        _channel?.invokeMethod('postMessage', {'message': message});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();
    _sensorTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    BridgeController().off('closeLoading', _closeLoadingHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPressed,
      child: Scaffold(
        backgroundColor: _brightness == Brightness.dark ? Colors.black : Colors.white,
        body: SafeArea(
          // top: true,
          top: _safeAreaTop,
          bottom: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildGeckoView(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: _isLoading
                    ? Container(
                        key: const ValueKey('loading'),
                        color: _brightness == Brightness.dark ? Colors.black : Colors.white,
                        child: LoadingContent(
                          brightness: _brightness,
                          subtitle: _loadingSubtitle,
                          loadingLog: _loadingLog,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _handleBackPressed() async {
    if (_channel != null) {
      try {
        final result = await _channel!.invokeMethod<bool>('goBack');
        if (result == true) {
          return false;
        }
      } catch (e) {
        print('Error calling goBack: $e');
      }
    }
    return true;
  }

  Widget _buildGeckoView() {
    const viewType = 'geckoView';
    final initialUrl = _initialUrl ?? LocalServer.instance.url;
    final serverPort = LocalServer.instance.port;
    final creationParams = <String, dynamic>{
      'initialUrl': initialUrl,
      'serverPort': serverPort,
      'isDarkMode': _brightness == Brightness.dark,
    };

    if (Theme.of(context).platform == TargetPlatform.android) {
      return PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (BuildContext context, PlatformViewController controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          final controller = PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
          );
          controller.addOnPlatformViewCreatedListener((int id) {
            print('PlatformView created with id: $id');
            _channel = MethodChannel('gecko_view_$id');
            print('MethodChannel created: gecko_view_$id');
            BridgeController().setChannel(_channel);
            BridgeController().setExternalHandler(_handleMethodCall);
            print('BridgeController initialized');
            params.onPlatformViewCreated(id);
          });
          controller.create();
          return controller;
        },
      );
    } else {
      return const Center(
        child: Text('This platform is not supported'),
      );
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('_handleMethodCall: ${call.method}');
    switch (call.method) {
      case 'onPageStart':
        break;
      case 'onPageStop':
        break;
    }
  }
}
