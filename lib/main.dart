import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // 暂时禁用
import 'local_server.dart';
import 'components/components.dart';
import 'models/loading_log.dart';
import 'package:flutter_bridge/src/bridge_controller.dart';
import 'package:flutter_bridge/src/bridge_message.dart';
import 'package:flutter_bridge/src/services/file_log_service.dart';
import 'package:i18n/i18n.dart';
import 'package:nyanya_webview/nyanya_webview.dart';
import 'package:flutter_bridge/src/services/engine_manager.dart';
import 'package:app_update/app_update.dart' as app_update;

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
//       autoRunBoot: false,
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

  // 加载环境变量（从 assets 中读取）
  await dotenv.load(fileName: '.env');

  // await FileLogService().init();

  await _initNotificationService();

  // 初始化 BridgeController (包含 i18n)
  await BridgeController().init();
  final i18nService = BridgeController().i18nService;
  _appTitle = i18nService.t('app_title');

  // 获取自定义 host（如果有）
  final customHost = await BridgeController().getCustomHost();
  String? baseUrl;

  if (customHost != null && customHost.isNotEmpty) {
    // 使用自定义 host
    baseUrl = customHost;
    print('Using custom host: $baseUrl');
  } else {
    // 先访问 LocalServer.instance 确保单例初始化（端口已确定）
    final localServerUrl = LocalServer.instance.url;
    baseUrl = localServerUrl;
    print('Using local server: $baseUrl');
  }

  _initialUrl = BridgeController().languageService.getLocalizedUrl(baseUrl);

  // 初始化前台服务（提升应用在后台的存活概率）- 需要 i18n
  // await _initForegroundTask(i18nService); // 暂时禁用

  // 启动本地服务（带重试机制），只有在使用本地服务时才需要
  if (customHost == null || customHost.isEmpty) {
    try {
      await LocalServer.instance.start();
      print('Local server started successfully on $baseUrl');
    } catch (e) {
      print('Failed to start local server after retries: $e');
      await _showNotification(i18nService.t('service_start_failed_title'),
          i18nService.t('service_start_failed_content'));
    }
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
  Brightness _brightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

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
      _brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      debugShowCheckedModeBanner: false,
      title: _appTitle,
      theme: ShadThemeData(
        brightness: _brightness,
        colorScheme: _brightness == Brightness.dark
            ? const ShadZincColorScheme.dark()
            : const ShadZincColorScheme.light(),
      ),
      home: const ShadToaster(
        child: WebViewContainer(),
      ),
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
  IWebViewCommunication? _communication;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // ================================
  // 静态持久化变量 - 防止Widget重建时状态丢失
  // ================================
  static bool _isLoadingStatic = true;
  static bool _isPageLoadedStatic = false; // 标记页面是否已经成功加载过
  static LoadingStep _loadingStepStatic = LoadingStep.initial;
  static List<LoadingLog> _loadingLogStatic = [];
  static DateTime? _lastBackgroundTimeStatic; // 记录进入后台的时间
  static bool _isInBackgroundStatic = false; // 标记是否在后台
  static DateTime? _lastRecoveryTimeStatic; // 记录上次恢复的时间
  static bool _kernelHealthyStatic = false; // 标记内核是否健康
  static int _retryCountStatic = 0; // 记录重试次数
  static const int _maxRetriesStatic = 3; // 最大重试次数
  static bool _safeAreaTopStatic = true; // 标记顶部是否启用SafeArea
  static bool _safeAreaBottomStatic = true; // 标记底部是否启用SafeArea
  static DateTime? _lastBackPressTimeStatic; // 记录上次按返回键的时间
  static WebViewEngine? _selectedEngineStatic; // 选中的引擎类型
  static int? _webViewVersionStatic; // 系统WebView版本号
  // ================================

  double _pitch = 0.0;
  double _roll = 0.0;
  bool _isLoading = _isLoadingStatic;
  bool _isPageLoaded = _isPageLoadedStatic;
  Brightness _brightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  late String _loadingSubtitle;
  WebViewEngine? _selectedEngine;
  int? _webViewVersion; // 系统WebView版本号

  // 详细加载状态追踪
  LoadingStep _loadingStep = _loadingStepStatic;
  List<LoadingLog> _loadingLog = List.from(_loadingLogStatic);

  // 后台状态追踪
  DateTime? _lastBackgroundTime = _lastBackgroundTimeStatic;
  bool _isInBackground = _isInBackgroundStatic;
  DateTime? _lastRecoveryTime = _lastRecoveryTimeStatic;
  bool _safeAreaTop = _safeAreaTopStatic;

  // 重试机制追踪
  int _retryCount = _retryCountStatic;
  static const int _maxRetries = _maxRetriesStatic;

  // 标签页状态 (已移除，标签页管理移至 nyanya_webview 模块)

  // 固定的 GlobalKey，防止 NyaNyaWebview 重建！
  final _nyaNyaWebviewKey = GlobalKey<State<NyaNyaWebview>>();

  // 保存最终的 engine，一旦确定就不再变化！
  WebViewEngine? _finalEngine;

  Timer? _sensorTimer;
  Timer? _loadTimeoutTimer;
  Timer? _exitAppTimer;
  Timer? _tabStackChangedTimer;
  Timer? _healthCheckPollTimer;
  int _healthCheckCount = 0;
  static const int _maxHealthChecks = 8;
  static const int _healthCheckIntervalMs = 500;
  bool _exitAppRequested = false;

  late void Function(BridgeMessage) _closeLoadingHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _loadingSubtitle = BridgeController().i18nService.t('loading_subtitle');
    _bridgeHandlerListener();
    _statusBarHandlerListener();

    // 关键修复：如果页面已经加载过，就不应该重新运行加载序列
    if (!_isPageLoaded) {
      print('[NYANYA-INIT] first load, starting sequence');
      // 发送 App 刚启动打开事件
      BridgeController().sendAppStartEvent();
      // 先获取引擎类型，再开始加载流程
      _initEngineAndStartLoading();

      // 超时时间延长到15秒，确保有足够时间完成所有加载步骤
      _loadTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _isLoading) {
          print('Loading timeout after 15 seconds');
          _addLoadingLog(LoadingLogType.web,
              BridgeController().i18nService.t('loading_web_failed'));
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

  /// 初始化引擎类型并开始加载流程
  Future<void> _initEngineAndStartLoading() async {
    try {
      _selectedEngine = await EngineManager().getSelectedEngine();
      _selectedEngineStatic = _selectedEngine;
      // 获取WebView版本号用于显示
      _webViewVersion = await EngineManager().getWebViewVersion();
      _webViewVersionStatic = _webViewVersion;
      print(
          '[NYANYA-ENGINE] Selected engine: ${_selectedEngine?.name ?? 'unknown'}, WebView version: $_webViewVersion');
    } catch (e) {
      print('[NYANYA-ENGINE] Failed to get engine: $e');
      _selectedEngine = WebViewEngine.system;
      _selectedEngineStatic = _selectedEngine;
    }

    // 设置最终确定的 engine
    _finalEngine = _selectedEngine;
    print('[NYANYA-ENGINE] Final engine set to: ${_finalEngine!.name}');

    // 触发 rebuild，开始渲染 WebView
    if (mounted) {
      setState(() {});
    }

    await _startLoadingSequence();
  }

  /// 验证 WebView 是否准备就绪
  Future<bool> _checkWebViewReady() async {
    int waitAttempts = 0;
    const maxWaitAttempts = 20;
    while (_communication == null && waitAttempts < maxWaitAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitAttempts++;
    }

    if (_communication != null) {
      try {
        final result = await _communication!.checkReady();
        print('[NYANYA-WEBVIEW] checkWebViewReady (via comm) result: $result');
        return result;
      } catch (e) {
        print('[NYANYA-WEBVIEW] checkWebViewReady (via comm) failed: $e');
        return false;
      }
    }

    print('[NYANYA-WEBVIEW] No communication available');
    return false;
  }

  /// 验证本地服务是否准备就绪
  bool _checkServerReady() {
    final result = LocalServer.instance.checkServerHealth();
    print('[NYANYA-SERVER] checkServerHealth result: $result');
    return result;
  }

  /// 重置重试计数
  void _resetRetryCount() {
    _retryCount = 0;
    _retryCountStatic = 0;
  }

  /// 处理加载失败，决定是否重试
  Future<void> _handleLoadFailure(
      String translationKey, LoadingStep errorStep) async {
    final i18n = BridgeController().i18nService;

    LoadingLogType type = LoadingLogType.engine;
    if (errorStep == LoadingStep.serverFailed) {
      type = LoadingLogType.server;
    } else if (errorStep == LoadingStep.webFailed) {
      type = LoadingLogType.web;
    }

    setState(() {
      _loadingStep = errorStep;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(LoadingLog(type: type, message: i18n.t(translationKey)));
      _loadingLogStatic
          .add(LoadingLog(type: type, message: i18n.t(translationKey)));
    });

    // 检查是否可以重试
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _retryCountStatic = _retryCount;

      // 添加重试提示信息
      final retryMessage = '重试 $_retryCount/$_maxRetries...';
      _addLoadingLog(LoadingLogType.server, retryMessage);

      print('[NYANYA-RETRY] Scheduling retry $_retryCount/$_maxRetries');

      // 等待一小段时间后重试
      await Future.delayed(const Duration(milliseconds: 500));
      await _startLoadingSequence();
    } else {
      // 达到最大重试次数，重启 App
      print('[NYANYA-RETRY] Max retries reached, restarting App');

      Timer(const Duration(seconds: 2), () {
        BridgeController().restartApp();
      });
    }
  }

  /// 详细加载流程
  Future<void> _startLoadingSequence() async {
    final i18n = BridgeController().i18nService;

    // 如果是重试，先清理资源
    if (_retryCount > 0) {
      print('[NYANYA-RETRY] Attempt $_retryCount/$_maxRetries');
      try {
        // 所有引擎都调用 shutdown（SystemWebView 是空实现，GeckoView 是实际关闭）
        if (_communication != null) {
          await _communication!.shutdown();
        }
        await LocalServer.instance.restart();
      } catch (e) {
        print('[NYANYA-RETRY] Failed to cleanup before retry: $e');
      }
      // 等待一小段时间让资源清理完成
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 1. 加载 WebView 内核
    final engine =
        _selectedEngineStatic ?? _selectedEngine ?? WebViewEngine.system;
    final isGecko = engine == WebViewEngine.gecko;
    final loadingKey = isGecko ? 'loading_gecko' : 'loading_system_webview';
    final loadingSuccessKey =
        isGecko ? 'loading_gecko_success' : 'loading_system_webview_success';
    final loadingFailedKey =
        isGecko ? 'loading_gecko_failed' : 'loading_system_webview_failed';

    setState(() {
      _loadingStep = LoadingStep.loadingGecko;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(
          LoadingLog(type: LoadingLogType.engine, message: i18n.t(loadingKey)));
      _loadingLogStatic.add(
          LoadingLog(type: LoadingLogType.engine, message: i18n.t(loadingKey)));
    });
    print('Loading WebView engine: ${engine.name}...');

    // 等待 WebView 初始化，然后验证
    bool webViewReady = false;
    int webViewCheckAttempts = 0;
    while (!webViewReady && webViewCheckAttempts < 5) {
      await Future.delayed(const Duration(milliseconds: 400));
      webViewReady = await _checkWebViewReady();
      webViewCheckAttempts++;
      print(
          '[NYANYA-WEBVIEW] Check attempt $webViewCheckAttempts: $webViewReady');
    }

    if (!webViewReady) {
      print('[NYANYA-WEBVIEW] Failed to load WebView after all checks');
      await _handleLoadFailure(loadingFailedKey, LoadingStep.geckoFailed);
      return;
    }

    setState(() {
      _loadingStep = LoadingStep.geckoSuccess;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(LoadingLog(
          type: LoadingLogType.engine, message: i18n.t(loadingSuccessKey)));
      _loadingLogStatic.add(LoadingLog(
          type: LoadingLogType.engine, message: i18n.t(loadingSuccessKey)));
    });
    print('WebView engine loaded successfully');

    // 2. 启动本地静态服务
    setState(() {
      _loadingStep = LoadingStep.loadingServer;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(LoadingLog(
          type: LoadingLogType.server, message: i18n.t('loading_server')));
      _loadingLogStatic.add(LoadingLog(
          type: LoadingLogType.server, message: i18n.t('loading_server')));
    });
    print('Starting local server...');

    bool serverSuccess = false;
    try {
      if (_retryCount > 0) {
        await LocalServer.instance.restart();
      } else {
        await LocalServer.instance.start();
      }
      serverSuccess = _checkServerReady();
    } catch (e) {
      print('Local server failed to start: $e');
      serverSuccess = false;
    }

    if (!serverSuccess) {
      print('[NYANYA-SERVER] Failed to start or verify local server');
      await _handleLoadFailure(
          'loading_server_failed', LoadingStep.serverFailed);
      return;
    }

    setState(() {
      _loadingStep = LoadingStep.serverSuccess;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(LoadingLog(
          type: LoadingLogType.server,
          message: i18n.t('loading_server_success')));
      _loadingLogStatic.add(LoadingLog(
          type: LoadingLogType.server,
          message: i18n.t('loading_server_success')));
    });
    print('Local server started successfully');

    // 加载成功，重置重试计数
    _resetRetryCount();

    // 3. 等待网站响应
    setState(() {
      _loadingStep = LoadingStep.loadingWeb;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(
          LoadingLog(type: LoadingLogType.web, message: i18n.t('loading_web')));
      _loadingLogStatic.add(
          LoadingLog(type: LoadingLogType.web, message: i18n.t('loading_web')));
    });
    print('Waiting for website response...');

    // 网站响应由 JavaScript 的 closeLoading 消息触发，这里不主动标记成功
  }

  void _addLoadingLog(LoadingLogType type, String message) {
    setState(() {
      _loadingLog.add(LoadingLog(type: type, message: message));
      _loadingLogStatic.add(LoadingLog(type: type, message: message));
    });
  }

  void _bridgeHandlerListener() {
    _closeLoadingHandler = (message) {
      print('Received closeLoading message');

      // 标记网站响应成功
      final i18n = BridgeController().i18nService.t('loading_web_success');
      _addLoadingLog(LoadingLogType.web, i18n);

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

    BridgeController().setUpdateCheckingCallback(() {
      app_update.UpdateDialogManager.showCheckingUpdateDialog(context, BridgeController().i18nService);
    });

    BridgeController().setUpdateCheckCallback(
        (versionInfo, currentVersion, showCheckingNotification) {
      if (showCheckingNotification) {
        app_update.UpdateDialogManager.closeCheckingUpdateDialog(context);
      }
      if (versionInfo != null) {
        app_update.UpdateDialogManager.showUpdateAvailableDialog(
          context: context,
          i18n: BridgeController().i18nService,
          version: versionInfo.version,
          downloadUrl: versionInfo.downloadUrl,
          onSkip: () {
            BridgeController().skipUpdate(versionInfo.version);
          },
          onUpdateNow: () {
            _startAppUpdate(versionInfo.downloadUrl, versionInfo.version);
          },
        );
      } else {
        if (showCheckingNotification) {
          app_update.UpdateDialogManager.showNoUpdateDialog(context, BridgeController().i18nService, currentVersion);
        }
      }
    });

    BridgeController().setLocalWebResourcesUpdateProgressCallback(
        (progress, stage, receivedBytes, totalBytes) {
      _updateLocalWebResourcesProgress(
          progress, stage, receivedBytes, totalBytes);
    });

    BridgeController()
        .setLocalWebResourcesUpdateCompleteCallback((success, error) {
      _closeLocalWebResourcesUpdateDialog();
    });
  }

  bool _isLocalWebResourcesUpdateDialogOpen = false;
  final ValueNotifier<int> _localWebResourcesUpdateProgress = ValueNotifier(0);
  final ValueNotifier<String> _localWebResourcesUpdateStage =
      ValueNotifier('downloading');
  final ValueNotifier<int> _localWebResourcesReceivedBytes = ValueNotifier(0);
  final ValueNotifier<int> _localWebResourcesTotalBytes = ValueNotifier(0);

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }

  void _showLocalWebResourcesUpdateDialog() {
    if (_isLocalWebResourcesUpdateDialogOpen) return;
    _isLocalWebResourcesUpdateDialogOpen = true;
    _localWebResourcesUpdateProgress.value = 0;
    _localWebResourcesUpdateStage.value = 'downloading';
    _localWebResourcesReceivedBytes.value = 0;
    _localWebResourcesTotalBytes.value = 0;
    final i18n = BridgeController().i18nService;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(i18n.t('hot_update_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _localWebResourcesUpdateStage,
                builder: (context, stage, child) {
                  return Text(stage == 'downloading'
                      ? i18n.t('hot_update_downloading')
                      : i18n.t('hot_update_extracting'));
                },
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: _localWebResourcesUpdateProgress,
                builder: (context, progress, child) {
                  return LinearProgressIndicator(value: progress / 100);
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: _localWebResourcesUpdateProgress,
                    builder: (context, progress, child) {
                      return Text(i18n.t('hot_update_download_progress',
                          {'progress': '$progress'}));
                    },
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _localWebResourcesUpdateStage,
                    builder: (context, stage, child) {
                      if (stage != 'downloading') {
                        return const SizedBox.shrink();
                      }
                      return ValueListenableBuilder<int>(
                        valueListenable: _localWebResourcesReceivedBytes,
                        builder: (context, received, child) {
                          return ValueListenableBuilder<int>(
                            valueListenable: _localWebResourcesTotalBytes,
                            builder: (context, total, child) {
                              if (total <= 0) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '${_formatBytes(received)} / ${_formatBytes(total)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateLocalWebResourcesProgress(
      int progress, String stage, int receivedBytes, int totalBytes) {
    print(
        '[Main] Update progress: $progress% (stage: $stage, $receivedBytes/$totalBytes)');
    if (!_isLocalWebResourcesUpdateDialogOpen) {
      _showLocalWebResourcesUpdateDialog();
    }
    _localWebResourcesUpdateProgress.value = progress;
    _localWebResourcesUpdateStage.value = stage;
    _localWebResourcesReceivedBytes.value = receivedBytes;
    _localWebResourcesTotalBytes.value = totalBytes;
  }

  void _closeLocalWebResourcesUpdateDialog() {
    if (_isLocalWebResourcesUpdateDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      _isLocalWebResourcesUpdateDialogOpen = false;
    }
  }

  // 在 State 类中保存当前更新的上下文信息
  String? _currentDownloadUrl;
  String? _currentDownloadVersion;
  bool? _currentDownloadHasExistingApk;
  
  // 静态持久化变量
  static String? _staticCurrentDownloadUrl;
  static String? _staticCurrentDownloadVersion;
  static bool? _staticCurrentDownloadHasExistingApk;
  
  VoidCallback? _cachedNotificationTappedCallback; // 缓存通知点击回调
  VoidCallback? _cachedInstallNotificationTappedCallback; // 缓存安装通知点击回调

  // 检查是否有完整APK的辅助函数
  Future<File?> _checkExistingApkForVersion(String version) async {
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
        return file;
      }
      return null;
    } catch (e) {
      print('[AppUpdate] Failed to check existing APK: $e');
      return null;
    }
  }

  void _startAppUpdate(String downloadUrl, String version) async {
    final appUpdateService = BridgeController().appUpdateService;
    final i18n = BridgeController().i18nService;

    // 保存当前的下载信息（同时保存成员变量和静态变量）
    _currentDownloadUrl = downloadUrl;
    _currentDownloadVersion = version;
    _staticCurrentDownloadUrl = downloadUrl;
    _staticCurrentDownloadVersion = version;

    // 先检查是否有完整APK
    final existingApk = await _checkExistingApkForVersion(version);
    final hasExistingApk = existingApk != null;
    _currentDownloadHasExistingApk = hasExistingApk;
    _staticCurrentDownloadHasExistingApk = hasExistingApk;
    // 保存 APK 长度
    int? existingApkLength = hasExistingApk ? existingApk!.lengthSync() : null;

    // 设置下载进度通知点击回调 - 打开进度弹窗
    _cachedNotificationTappedCallback = () {
      print('[AppUpdate] Download progress notification tapped');
      if (!app_update.UpdateDialogManager.isUpdateProgressDialogOpen) {
        // 重新设置进度回调
        appUpdateService.setProgressCallback((progress, receivedBytes, totalBytes) {
          if (progress == 100) {
            app_update.UpdateDialogManager.setDownloadComplete(totalBytes);
          } else {
            app_update.UpdateDialogManager.updateProgressValue(progress, receivedBytes, totalBytes);
          }
        });
        
        // 重新设置通知回调
        appUpdateService.setNotificationTappedCallback(_cachedNotificationTappedCallback!);
        
        // 显示进度弹窗
        app_update.UpdateDialogManager.showUpdateProgressDialog(
          context: context,
          i18n: i18n,
          onBackgroundDownload: () {
            // 后台下载，不清空进度回调
          },
          onStopUpdate: () async {
            await appUpdateService.stopUpdate();
          },
          onInstallNow: () async {
            await appUpdateService.installUpdate(i18n);
          },
          onLater: () {
            // 下次再说
            _currentDownloadUrl = null;
            _currentDownloadVersion = null;
            appUpdateService.clearProgressCallback();
            appUpdateService.clearInstallRequestCallback();
            appUpdateService.clearCompleteCallback();
          },
        );
      }
    };
    appUpdateService.setNotificationTappedCallback(_cachedNotificationTappedCallback!);
    
    // 设置安装提示通知点击回调 - 打开安装弹窗
    _cachedInstallNotificationTappedCallback = () async {
      print('[AppUpdate] Install prompt notification tapped');
      if (!app_update.UpdateDialogManager.isUpdateProgressDialogOpen) {
        // 优先使用静态变量，然后使用成员变量
        final versionToCheck = _staticCurrentDownloadVersion ?? _currentDownloadVersion;
        
        // 重新检查是否有完整APK（避免状态过期）
        final freshExistingApk = versionToCheck != null
            ? await _checkExistingApkForVersion(versionToCheck!)
            : null;
        final freshHasExistingApk = freshExistingApk != null;
        final freshApkLength = freshHasExistingApk ? freshExistingApk!.lengthSync() : null;
        
        // 确保状态是下载完成
        if (freshHasExistingApk && freshApkLength != null) {
          print('[AppUpdate] Setting download complete from fresh APK (length: $freshApkLength)');
          app_update.UpdateDialogManager.setDownloadComplete(freshApkLength);
        } else {
          print('[AppUpdate] Marking download complete');
          app_update.UpdateDialogManager.markDownloadComplete();
        }
        
        // 重新设置安装通知回调
        appUpdateService.setInstallNotificationTappedCallback(_cachedInstallNotificationTappedCallback!);
        
        // 显示安装弹窗
        app_update.UpdateDialogManager.showUpdateProgressDialog(
          context: context,
          i18n: i18n,
          onBackgroundDownload: () {},
          onStopUpdate: () async {},
          onInstallNow: () async {
            await appUpdateService.installUpdate(i18n);
          },
          onLater: () {
            // 下次再说 - 不清除安装通知回调，不清除静态变量！
            _currentDownloadUrl = null;
            _currentDownloadVersion = null;
            // 注意：不设置静态变量为 null！保留它们以便通知点击时使用
            appUpdateService.clearProgressCallback();
            appUpdateService.clearInstallRequestCallback();
            appUpdateService.clearCompleteCallback();
            // 注意：不调用 clearInstallNotificationTappedCallback，保留通知点击功能
          },
          resetState: false,
        );
      }
    };
    appUpdateService.setInstallNotificationTappedCallback(_cachedInstallNotificationTappedCallback!);

    // 设置进度回调
    appUpdateService.setProgressCallback((progress, receivedBytes, totalBytes) {
      if (progress == 100) {
        app_update.UpdateDialogManager.setDownloadComplete(totalBytes);
      } else {
        app_update.UpdateDialogManager.updateProgressValue(progress, receivedBytes, totalBytes);
      }
    });

    // 设置安装请求回调
    appUpdateService.setInstallRequestCallback(() {
      // 下载完成，设置状态并重新显示弹框
      final totalBytes = app_update.UpdateDialogManager.updateTotalBytes.value > 0 
          ? app_update.UpdateDialogManager.updateTotalBytes.value 
          : (existingApk != null ? existingApk.lengthSync() : 0);
      app_update.UpdateDialogManager.setDownloadComplete(totalBytes);
      
      // 检查弹框是否关闭，如果关闭则重新打开
      if (!app_update.UpdateDialogManager.isUpdateProgressDialogOpen) {
        app_update.UpdateDialogManager.showUpdateProgressDialog(
          context: context,
          i18n: i18n,
          onBackgroundDownload: () {},
          onStopUpdate: () async {},
          onInstallNow: () async {
            await appUpdateService.installUpdate(i18n);
          },
          onLater: () {
            // 下次再说 - 不清除安装通知回调，不清除静态变量！
            _currentDownloadUrl = null;
            _currentDownloadVersion = null;
            // 注意：不设置静态变量为 null！保留它们以便通知点击时使用
            appUpdateService.clearProgressCallback();
            appUpdateService.clearInstallRequestCallback();
            appUpdateService.clearCompleteCallback();
            // 注意：不调用 clearInstallNotificationTappedCallback，保留通知点击功能
          },
          resetState: false,
        );
      }
    });

    // 设置完成回调
    appUpdateService.setCompleteCallback((success, error) {
      if (!success) {
        app_update.UpdateDialogManager.closeUpdateProgressDialog(context);
      }
    });

    // 先根据是否有完整APK决定怎么显示对话框
    if (hasExistingApk) {
      // 有完整APK，直接显示下载完成状态
      final fileSize = existingApk!.lengthSync();
      app_update.UpdateDialogManager.setDownloadComplete(fileSize);
      app_update.UpdateDialogManager.showUpdateProgressDialog(
        context: context,
        i18n: i18n,
        onBackgroundDownload: () {},
        onStopUpdate: () async {},
        onInstallNow: () async {
          await appUpdateService.installUpdate(i18n);
        },
        onLater: () {
          // 下次再说
          _currentDownloadUrl = null;
          _currentDownloadVersion = null;
          appUpdateService.clearProgressCallback();
          appUpdateService.clearInstallRequestCallback();
          appUpdateService.clearCompleteCallback();
        },
        resetState: false,
      );
    } else {
      // 没有完整APK，显示正常下载对话框并开始下载
      app_update.UpdateDialogManager.showUpdateProgressDialog(
        context: context,
        i18n: i18n,
        onBackgroundDownload: () {},
        onStopUpdate: () async {
          await appUpdateService.stopUpdate();
        },
        onInstallNow: () async {
          await appUpdateService.installUpdate(i18n);
        },
        onLater: () {
          // 下次再说
          _currentDownloadUrl = null;
          _currentDownloadVersion = null;
          appUpdateService.clearProgressCallback();
          appUpdateService.clearInstallRequestCallback();
          appUpdateService.clearCompleteCallback();
        },
      );
    }

    // 开始下载
    appUpdateService.startDownload(
      downloadUrl: downloadUrl,
      version: version,
      i18nService: i18n,
      autoInstall: false,
    );
  }

  void _statusBarHandlerListener() {
    BridgeController().setStatusBarChangeHandler((String type) {
      setState(() {
        _safeAreaTop = (type != 'transparent-light' &&
            type != 'transparent-dark' &&
            type != 'hide');
        _safeAreaTopStatic = _safeAreaTop;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('[NYANYA-LIFECYCLE] state=$state');

    // 发送通用的生命周期变化事件
    BridgeController().sendAppLifecycleChangeEvent(state.name);

    if (state == AppLifecycleState.paused) {
      _lastBackgroundTime = DateTime.now();
      _lastBackgroundTimeStatic = _lastBackgroundTime;
      _isInBackground = true;
      _isInBackgroundStatic = _isInBackground;

      // 发送离开 App 进入后台事件
      BridgeController().sendAppPauseEvent();

      // TODO: 前台服务暂时禁用 (flutter_foreground_task 与 MIUI 不兼容)
      // _startForegroundTaskSafe();
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _isInBackgroundStatic = _isInBackground;

      // 发送重新回到 App 事件
      BridgeController().sendAppResumeEvent();

      // TODO: 前台服务暂时禁用
      // _stopForegroundTaskSafe();
      _checkAndRecoverState();
    } else if (state == AppLifecycleState.inactive) {
      // App 进入非活动状态（比如收到电话、弹出对话框）
      BridgeController().sendAppInactiveEvent();
    } else if (state == AppLifecycleState.hidden) {
      // App 完全隐藏
      BridgeController().sendAppHiddenEvent();
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
  /// 2. 立即检查一次，然后轮询检查
  /// 3. 只有服务真的挂了才恢复
  /// 4. 页面加载成功过才考虑恢复
  Future<void> _checkAndRecoverState() async {
    print('[NYANYA-CHECK] === Checking app state on resume ===');
    print('[NYANYA-CHECK]   _lastBackgroundTime: $_lastBackgroundTime');
    print('[NYANYA-CHECK]   _isPageLoaded: $_isPageLoaded');
    print(
        '[NYANYA-CHECK]   LocalServer status: ${LocalServer.instance.status}');
    print(
        '[NYANYA-CHECK]   LocalServer serverExists: ${LocalServer.instance.serverExists}');
    print(
        '[NYANYA-CHECK]   _communication: ${_communication == null ? "null" : "exists"}');

    if (_lastBackgroundTime == null) {
      print('[NYANYA-CHECK] First launch, skip check');
      return;
    }

    final bgDuration =
        DateTime.now().difference(_lastBackgroundTime!).inMilliseconds;
    print('[NYANYA-CHECK] Background duration: ${bgDuration}ms');

    if (!_isPageLoaded) {
      print('[NYANYA-CHECK] Page never loaded, skip recovery');
      return;
    }

    // 先取消之前可能存在的轮询
    _healthCheckPollTimer?.cancel();
    _healthCheckCount = 0;

    // 立即执行第一次检查
    print('[NYANYA-CHECK] Performing immediate health check...');
    final shouldStop = await _performSingleHealthCheck();

    if (shouldStop) {
      return;
    }

    // 启动轮询检查
    print('[NYANYA-CHECK] Starting poll health checks (interval: ${_healthCheckIntervalMs}ms)...');
    _healthCheckPollTimer = Timer.periodic(
      const Duration(milliseconds: _healthCheckIntervalMs),
      (timer) async {
        _healthCheckCount++;
        print('[NYANYA-CHECK] Poll check $_healthCheckCount/$_maxHealthChecks...');

        final stopPoll = await _performSingleHealthCheck();

        if (stopPoll || _healthCheckCount >= _maxHealthChecks) {
          print('[NYANYA-CHECK] Stopping health check poll');
          timer.cancel();
          _healthCheckPollTimer = null;
        }
      },
    );
  }

  /// 执行单次健康检查
  /// 返回 true 表示应该停止轮询
  Future<bool> _performSingleHealthCheck() async {
    final serverHealthy = LocalServer.instance.checkServerHealth();
    print('[NYANYA-CHECK] Server health: $serverHealthy');

    final kernelHealthy = await checkKernelHealth();
    print('[NYANYA-CHECK] Kernel health: $kernelHealthy');

    if (!serverHealthy || !kernelHealthy) {
      print('[NYANYA-RECOVERY] Found unhealthy state, starting recovery...');
      await _performRecovery();
      return true; // 停止轮询
    }

    return false; // 继续轮询
  }

  /// 检测 WebView 内核是否健康
  Future<bool> checkKernelHealth() async {
    if (_communication != null) {
      try {
        final result = await _communication!.checkHealth();
        _kernelHealthyStatic = result;
        print(
            '[NYANYA-KERNEL] checkHealth (via comm) result: $_kernelHealthyStatic');
        return _kernelHealthyStatic;
      } catch (e) {
        print('[NYANYA-KERNEL] checkHealth (via comm) failed: $e');
        return false;
      }
    }

    // 如果没有 communication，对于 system webview，我们认为是健康的
    _kernelHealthyStatic = _finalEngine == WebViewEngine.system;
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
      final kernelHealthy = await checkKernelHealth();
      final serverHealthy = LocalServer.instance.checkServerHealth();

      print('[NYANYA-RECOVERY] Kernel: $kernelHealthy, Server: $serverHealthy');

      if (!kernelHealthy) {
        print(
            '[NYANYA-RECOVERY] Kernel unhealthy, restarting app instead of attempting recovery');
        setState(() {
          _loadingLog.add(LoadingLog(
              type: LoadingLogType.server,
              message: i18n.t('loading_server_failed')));
          _loadingLogStatic.add(LoadingLog(
              type: LoadingLogType.server,
              message: i18n.t('loading_server_failed')));
        });
        await _showNotification(
            i18n.t('app_exception_title'), i18n.t('app_exception_content'));
        Timer(const Duration(seconds: 1), () {
          BridgeController().restartApp();
        });
        return;
      }

      if (!serverHealthy) {
        print('[NYANYA-RECOVERY] Server unhealthy, restarting server only');
        setState(() {
          _loadingLog.add(LoadingLog(
              type: LoadingLogType.server, message: i18n.t('loading_server')));
          _loadingLogStatic.add(LoadingLog(
              type: LoadingLogType.server, message: i18n.t('loading_server')));
        });

        print('[NYANYA-RECOVERY] Restarting local server...');
        await LocalServer.instance.restart();
        print('[NYANYA-RECOVERY] Server restarted successfully');

        setState(() {
          _loadingLog.add(LoadingLog(
              type: LoadingLogType.server,
              message: i18n.t('loading_server_success')));
          _loadingLogStatic.add(LoadingLog(
              type: LoadingLogType.server,
              message: i18n.t('loading_server_success')));
          _loadingLog.add(LoadingLog(
              type: LoadingLogType.web, message: i18n.t('loading_web')));
          _loadingLogStatic.add(LoadingLog(
              type: LoadingLogType.web, message: i18n.t('loading_web')));
        });

        await Future.delayed(const Duration(milliseconds: 300));

        print('[NYANYA-RECOVERY] Reloading webview...');
        await _reloadWebView();
        print('[NYANYA-RECOVERY] Recovery completed');
      }

      setState(() {
        _isLoading = false;
        _isLoadingStatic = _isLoading;
      });
    } catch (e) {
      print('[NYANYA-RECOVERY] Failed to perform recovery: $e');
      setState(() {
        _loadingLog.add(LoadingLog(
            type: LoadingLogType.server,
            message: i18n.t('loading_server_failed')));
        _loadingLogStatic.add(LoadingLog(
            type: LoadingLogType.server,
            message: i18n.t('loading_server_failed')));
      });
      await _showNotification(
          i18n.t('app_exception_title'), i18n.t('app_exception_content'));

      Timer(const Duration(seconds: 3), () {
        BridgeController().restartApp();
      });
    }
  }

  /// 重新加载 WebView
  Future<void> _reloadWebView() async {
    if (_communication != null) {
      try {
        final isReady = await _communication!.checkReady();
        if (!isReady) {
          print(
              '[NYANYA-RECOVERY] WebView not ready, skipping reload (via comm)');
          return;
        }

        final url = _initialUrl ?? LocalServer.instance.url;
        await _communication!.loadUrl(url);
        print('Reloading webview with URL: $url (via comm)');
      } catch (e) {
        print('Failed to reload webview (via comm): $e');
        print('WebView may be destroyed, will be recreated on next frame');
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
    _sensorTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (_) async {
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

      if (_communication != null) {
        try {
          await _communication!.postMessage(message);
        } catch (e) {
          print('[NYANYA-SENSOR] Failed to send via comm: $e');
        }
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
    _tabStackChangedTimer?.cancel();
    _healthCheckPollTimer?.cancel();
    BridgeController().off('closeLoading', _closeLoadingHandler);
    super.dispose();
  }

  Widget _buildNyaNyaWebview() {
    // 关键：如果 engine 还没确定，先渲染一个占位符！
    // 确保不会出现先 SystemWebView 后 GeckoView 的切换！
    if (_finalEngine == null) {
      // 尝试确定 engine
      if (_selectedEngineStatic != null) {
        _finalEngine = _selectedEngineStatic;
        print(
            '[NYANYA-ENGINE] Final engine determined (static): ${_finalEngine!.name}');
        // 等下一帧再 build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else if (_selectedEngine != null) {
        _finalEngine = _selectedEngine;
        print(
            '[NYANYA-ENGINE] Final engine determined (state): ${_finalEngine!.name}');
        // 等下一帧再 build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }

      // 还没确定，先返回占位符
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // engine 已经确定，可以安全地渲染 WebView 了！
    final engine = _finalEngine!;
    // final engine = WebViewEngine.gecko;
    final initialUrl = _initialUrl ?? LocalServer.instance.url;
    final serverPort = LocalServer.instance.port;

    print('[NYANYA-ENGINE] Rendering WebView with engine: ${engine.name}');

    final urlRewriteRules = [
      UrlRewriteRule(
        pattern:
            RegExp(r'https?://(localhost|127\.0\.0\.1):(13218|13219|13220)'),
        replacement: 'https://trip.aiiko.club',
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        print('[NyaNyaWebViewLog] MAIN: PopScope onPopInvoked');

        if (_communication != null) {
          try {
            final canGoBack = await _communication!.canGoBack();
            if (canGoBack) {
              await _communication!.goBack();
              return;
            }
          } catch (e) {
            print('[NyaNyaWebViewLog] Failed to go back via comm: $e');
          }
        }

        // 如果以上都不行，就关闭 App
        _handleMainClose();
      },
      child: NyaNyaWebview(
        key: _nyaNyaWebviewKey,
        options: WebViewOptions(
          engine: engine,
          initialUrl: initialUrl,
          serverPort: serverPort,
          newTabBehavior: NewTabBehavior.delegate,
          urlRewriteRules: urlRewriteRules,
        ),
        messageHandler: (String message) {
          // print('[NyaNyaWebViewLog] MAIN: messageHandler called: $message');
          // BridgeController().handleWebMessage(message, sessionId: 'main');
        },
        // onChannelCreated: (channel) {
        //   _channel = channel;
        //   //  BridgeController().setChannel(channel, sessionId: 'main');
        //   if (channel is MethodChannel) {
        //     BridgeController().setChannel(channel, sessionId: 'main');
        //   }
        // },
        onCommunicationCreated: (communication) {
          print('[NYANYA-MAIN] Communication created: $communication');
          _communication = communication;
          BridgeController().setCommunication(communication, sessionId: 'main');
        },
        onClose: () {
          _handleMainClose();
        },
        onOpenUrl: (url, target) {
          print(
              '[NyaNyaWebViewLog] MAIN: onOpenUrl called: url=$url, target=$target');

          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  TabManagerWidget(
                initialUrl: url,
                optionsBuilder: (tabUrl) => WebViewOptions(
                  engine: engine,
                  initialUrl: tabUrl,
                  serverPort: serverPort,
                  newTabBehavior: NewTabBehavior.delegate,
                  urlRewriteRules: urlRewriteRules,
                ),
                maxTabs: 10,
                showTabBar: true,
                brightness: _brightness,
                language: BridgeController().languageService.currentLanguage ==
                        'system'
                    ? null
                    : BridgeController().languageService.currentLanguage,
                onMessage: (tabId, message) {
                  // print(
                  //     '[NyaNyaWebViewLog] MAIN-TabPage: messageHandler called: $message');
                  // BridgeController()
                  //     .handleWebMessage(message, sessionId: tabId);
                },
                // onChannelCreated: (tabId, channel) {
                //   //  BridgeController().setChannel(channel, sessionId: 'tabId');
                //   if (channel is MethodChannel) {
                //     BridgeController().setChannel(channel, sessionId: tabId);
                //   }
                // },
                onCommunicationCreated: (tabId, communication) {
                  print('[NYANYA-MAIN] Communication created for tab: $tabId');
                  BridgeController()
                      .setCommunication(communication, sessionId: tabId);
                },
                onTabClosed: (tabId) {
                  BridgeController().removeCommunication(tabId);
                },
              ),
              // 推入动画：从右往左滑入
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              // 返回动画：从左往右滑出
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        sessionId: 'main',
      ),
    );
  }

  void _handleMainClose() {
    print('[NyaNyaWebViewLog] MAIN: _handleMainClose called');
    final now = DateTime.now();
    if (_lastBackPressTimeStatic != null &&
        now.difference(_lastBackPressTimeStatic!).inMilliseconds < 3000) {
      print('[NyaNyaWebViewLog] MAIN: Exiting app due to double back press');
      SystemNavigator.pop();
    } else {
      _lastBackPressTimeStatic = now;
      ShadToaster.of(context).show(
        ShadToast(
          title: Text(
              BridgeController().i18nService.t('press_back_again_to_exit')),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _brightness == Brightness.dark ? Colors.black : Colors.white,
      body: SafeArea(
        top: true,
        bottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildNyaNyaWebview(),
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
                      color: _brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
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
    );
  }
}
