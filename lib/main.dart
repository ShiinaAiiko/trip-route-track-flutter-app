import 'dart:async';
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
// import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // 暂时禁用
import 'local_server.dart';
import 'components/components.dart';
import 'package:flutter_bridge/src/bridge_controller.dart';
import 'package:flutter_bridge/src/bridge_message.dart';
import 'package:i18n/i18n.dart';

String? _initialUrl;
String _appTitle = '';



// 标签页数据类
class TabInfo {
  final dynamic id; // 使用 dynamic 兼容 Long/int
  final String url;
  final String title;
  final bool isCurrent;

  TabInfo({
    required this.id,
    required this.url,
    required this.title,
    required this.isCurrent,
  });

  factory TabInfo.fromMap(Map<String, dynamic> map) {
    String url = map['url'] as String;
    // 检测是否为内部网站（本地服务端口）
    final isInternalWebsite = url.contains('localhost:13218') ||
        url.contains('localhost:13219') ||
        url.contains('localhost:13220') ||
        url.contains('127.0.0.1:13218') ||
        url.contains('127.0.0.1:13219') ||
        url.contains('127.0.0.1:13220');
    // 若判定为内部网站，则将显示用域名统一修改为 trip.aiiko.club
    if (isInternalWebsite) {
      url = url.replaceAll(
        RegExp(r'https?://(localhost|127\.0\.0\.1):(13218|13219|13220)'),
        'https://trip.aiiko.club',
      );
    }
    return TabInfo(
      id: map['id'],
      url: url,
      title: map['title'] as String,
      isCurrent: map['isCurrent'] as bool? ?? false,
    );
  }

  TabInfo copyWith({String? url, String? title, bool? isCurrent}) {
    return TabInfo(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

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
  
  // 初始化通知服务
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
      await _showNotification(i18nService.t('service_start_failed_title'), i18nService.t('service_start_failed_content'));
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
  MethodChannel? _channel;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // ================================
  // 静态持久化变量 - 防止Widget重建时状态丢失
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
  static int _retryCountStatic = 0; // 记录重试次数
  static const int _maxRetriesStatic = 3; // 最大重试次数
  static bool _safeAreaTopStatic = true; // 标记顶部是否启用SafeArea
  static bool _safeAreaBottomStatic = true; // 标记底部是否启用SafeArea
  static List<TabInfo> _tabsStatic = []; // 标签页列表
  static bool _canGoBackStatic = false; // 是否可以返回上一页
  static bool _canGoForwardStatic = false; // 是否可以前进到下一页
  static String _currentTitleStatic = ''; // 当前页面标题
  static String _currentUrlStatic = ''; // 当前页面URL
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
  
  // 重试机制追踪
  int _retryCount = _retryCountStatic;
  static const int _maxRetries = _maxRetriesStatic;
  
  // 标签页状态
  List<TabInfo> _tabs = _tabsStatic;
  bool _canGoBack = _canGoBackStatic;
  bool _canGoForward = _canGoForwardStatic;
  String _currentTitle = _currentTitleStatic;
  String _currentUrl = _currentUrlStatic;

  Timer? _sensorTimer;
  Timer? _loadTimeoutTimer;
  Timer? _exitAppTimer;
  Timer? _tabStackChangedTimer;
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
    
    // 关键修复：如果正在恢复中，跳过加载序列（避免重复启动服务器）
    if (_isRecoveringStatic) {
      print('[NYANYA-INIT] recovery in progress, skipping');
      return;
    }
    
    // 关键修复：如果页面已经加载过，就不应该重新运行加载序列
    if (!_isPageLoaded) {
      print('[NYANYA-INIT] first load, starting sequence');
      // 发送 App 刚启动打开事件
      BridgeController().sendAppStartEvent();
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

  /// 验证 GeckoView 是否准备就绪
  Future<bool> _checkGeckoViewReady() async {
    if (_channel == null) {
      print('[NYANYA-GECKO] Channel not available yet');
      return false;
    }
    try {
      final result = await _channel?.invokeMethod<bool>('checkGeckoViewReady');
      print('[NYANYA-GECKO] checkGeckoViewReady result: $result');
      return result ?? false;
    } catch (e) {
      print('[NYANYA-GECKO] checkGeckoViewReady failed: $e');
      return false;
    }
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
  Future<void> _handleLoadFailure(String translationKey, LoadingStep errorStep) async {
    final i18n = BridgeController().i18nService;
    setState(() {
      _loadingStep = errorStep;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t(translationKey));
      _loadingLogStatic.add(i18n.t(translationKey));
    });
    
    // 检查是否可以重试
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _retryCountStatic = _retryCount;
      
      // 添加重试提示信息
      final retryMessage = '重试 $_retryCount/$_maxRetries...';
      _addLoadingLog(retryMessage);
      
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
        await _channel?.invokeMethod('shutdownGeckoRuntime');
        await LocalServer.instance.restart();
      } catch (e) {
        print('[NYANYA-RETRY] Failed to cleanup before retry: $e');
      }
      // 等待一小段时间让资源清理完成
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    // 1. 加载 GeckoView 内核
    setState(() {
      _loadingStep = LoadingStep.loadingGecko;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t('loading_gecko'));
      _loadingLogStatic.add(i18n.t('loading_gecko'));
    });
    print('Loading GeckoView engine...');
    
    // 等待 GeckoView 初始化，然后验证
    bool geckoReady = false;
    int geckoCheckAttempts = 0;
    while (!geckoReady && geckoCheckAttempts < 5) {
      await Future.delayed(const Duration(milliseconds: 400));
      geckoReady = await _checkGeckoViewReady();
      geckoCheckAttempts++;
      print('[NYANYA-GECKO] Check attempt $geckoCheckAttempts: $geckoReady');
    }
    
    if (!geckoReady) {
      print('[NYANYA-GECKO] Failed to load GeckoView after all checks');
      await _handleLoadFailure('loading_gecko_failed', LoadingStep.geckoFailed);
      return;
    }
    
    setState(() {
      _loadingStep = LoadingStep.geckoSuccess;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t('loading_gecko_success'));
      _loadingLogStatic.add(i18n.t('loading_gecko_success'));
    });
    print('GeckoView engine loaded successfully');
    
    // 2. 启动本地静态服务
    setState(() {
      _loadingStep = LoadingStep.loadingServer;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t('loading_server'));
      _loadingLogStatic.add(i18n.t('loading_server'));
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
      await _handleLoadFailure('loading_server_failed', LoadingStep.serverFailed);
      return;
    }
    
    LocalServer.onUrlChange = (String url, String title) {
      print('[onUrlChange] url: $url, title: $title');
      if (mounted) {
        String displayUrl = url;
        String displayTitle = title;

        // 检测是否为内部网站（本地服务端口）
        final isInternalWebsite = url.contains('localhost:13218') ||
            url.contains('localhost:13219') ||
            url.contains('localhost:13220') ||
            url.contains('127.0.0.1:13218') ||
            url.contains('127.0.0.1:13219') ||
            url.contains('127.0.0.1:13220');

        // 若判定为内部网站，则将显示用域名统一修改为 trip.aiiko.club
        if (isInternalWebsite) {
          displayUrl = url.replaceAll(
            RegExp(r'https?://(localhost|127\.0\.0\.1):(13218|13219|13220)'),
            'https://trip.aiiko.club',
          );
          print('[onUrlChange] 内部网站检测成功，替换后的URL: $displayUrl');
        }

        setState(() {
          _currentUrl = displayUrl;
          _currentUrlStatic = displayUrl;
          _currentTitle = displayTitle;
          _currentTitleStatic = displayTitle;
          if (_tabs.isNotEmpty) {
            final currentIndex = _tabs.indexWhere((t) => t.isCurrent);
            if (currentIndex >= 0) {
              _tabs[currentIndex] = _tabs[currentIndex].copyWith(url: displayUrl, title: displayTitle);
              _tabsStatic = _tabs;
            }
          }
        });
      }
    };
    setState(() {
      _loadingStep = LoadingStep.serverSuccess;
      _loadingStepStatic = _loadingStep;
      _loadingLog.add(i18n.t('loading_server_success'));
      _loadingLogStatic.add(i18n.t('loading_server_success'));
    });
    print('Local server started successfully');
    
    // 加载成功，重置重试计数
    _resetRetryCount();
    
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

  void _handleExitAppRequest() {
    if (_exitAppRequested) {
      print('Exiting app now');
      _exitAppTimer?.cancel();
      _exitAppTimer = null;
      SystemNavigator.pop();
    } else {
      _exitAppRequested = true;
      final exitMessage = BridgeController().i18nService.t('press_back_again_to_exit');
      _showToast(exitMessage);

      _exitAppTimer?.cancel();
      _exitAppTimer = Timer(const Duration(seconds: 3), () {
        _exitAppRequested = false;
      });
    }
  }

  void _bridgeHandlerListener() {
    _closeLoadingHandler = (message) {
      print('Received closeLoading message');
      
      // 标记网站响应成功
      final i18n = BridgeController().i18nService.t('loading_web_success');
      _addLoadingLog(i18n);
      
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
      _showCheckingUpdateDialog();
    });
    
    BridgeController().setUpdateCheckCallback((versionInfo, currentVersion, showCheckingNotification) {
      if (showCheckingNotification) {
        _closeCheckingUpdateDialog();
      }
      if (versionInfo != null) {
        _showUpdateAvailableDialog(versionInfo.version, versionInfo.downloadUrl);
      } else {
        if (showCheckingNotification) {
          _showNoUpdateDialog(currentVersion);
        }
      }
    });

    BridgeController().setLocalWebResourcesUpdateProgressCallback((progress, stage, receivedBytes, totalBytes) {
      _updateLocalWebResourcesProgress(progress, stage, receivedBytes, totalBytes);
    });

    BridgeController().setLocalWebResourcesUpdateCompleteCallback((success, error) {
      _closeLocalWebResourcesUpdateDialog();
    });
  }

  bool _isCheckingUpdateDialogOpen = false;

  bool _isLocalWebResourcesUpdateDialogOpen = false;
  final ValueNotifier<int> _localWebResourcesUpdateProgress = ValueNotifier(0);
  final ValueNotifier<String> _localWebResourcesUpdateStage = ValueNotifier('downloading');
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
                      return Text(i18n.t('hot_update_download_progress', {'progress': '$progress'}));
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

  void _updateLocalWebResourcesProgress(int progress, String stage, int receivedBytes, int totalBytes) {
    print('[Main] Update progress: $progress% (stage: $stage, $receivedBytes/$totalBytes)');
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

  void _showCheckingUpdateDialog() {
    if (_isCheckingUpdateDialogOpen) return;
    _isCheckingUpdateDialogOpen = true;
    final i18n = BridgeController().i18nService;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(i18n.t('update_checking_title')),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(i18n.t('update_checking')),
          ],
        ),
      ),
    );
  }

  void _closeCheckingUpdateDialog() {
    if (_isCheckingUpdateDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      _isCheckingUpdateDialogOpen = false;
    }
  }

  void _showUpdateAvailableDialog(String version, String downloadUrl) {
    final i18n = BridgeController().i18nService;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(i18n.t('update_available', {'version': version})),
        content: Text(i18n.t('update_available_content')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              BridgeController().skipUpdate(version);
            },
            child: Text(i18n.t('update_skip')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              BridgeController().startUpdate(downloadUrl, version);
            },
            child: Text(i18n.t('update_now')),
          ),
        ],
      ),
    );
  }

  void _showNoUpdateDialog(String currentVersion) {
    final i18n = BridgeController().i18nService;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(i18n.t('update_no_new_version_title')),
        content: Text(i18n.t('update_no_new_version_content', {'version': currentVersion})),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(i18n.t('confirm')),
          ),
        ],
      ),
    );
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
    
    final kernelHealthy = await checkKernelHealth();
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
  Future<bool> checkKernelHealth() async {
    _kernelHealthyStatic = _channel != null;
    if (!_kernelHealthyStatic) return false;
    
    try {
      final result = await _channel!.invokeMethod<bool>('checkSessionsHealth');
      _kernelHealthyStatic = result ?? false;
      print('[NYANYA-KERNEL] checkSessionsHealth result: $_kernelHealthyStatic');
    } catch (e) {
      print('[NYANYA-KERNEL] checkSessionsHealth failed: $e');
      _kernelHealthyStatic = false;
    }
    
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

    // 步骤0: 如果 GeckoView 内核不健康，先清理旧的 GeckoRuntime
    final kernelHealthy = await checkKernelHealth();
    if (!kernelHealthy) {
      print('[NYANYA-RECOVERY] Kernel unhealthy, shutting down old GeckoRuntime first');
      try {
        await _channel?.invokeMethod('shutdownGeckoRuntime');
        print('[NYANYA-RECOVERY] GeckoRuntime shutdown successfully');
      } catch (e) {
        print('[NYANYA-RECOVERY] GeckoRuntime shutdown failed: $e');
      }
      // 等待一小段时间确保资源被清理
      await Future.delayed(const Duration(milliseconds: 100));
    }

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
      print('[NYANYA-RECOVERY] Failed to perform recovery: $e');
      setState(() {
        _loadingLog.add(i18n.t('loading_server_failed'));
        _loadingLogStatic.add(i18n.t('loading_server_failed'));
      });
      await _showNotification(i18n.t('app_exception_title'), i18n.t('app_exception_content'));
      
      // 3秒后重启 App
      Timer(const Duration(seconds: 3), () {
        BridgeController().restartApp();
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
    _tabStackChangedTimer?.cancel();
    BridgeController().off('closeLoading', _closeLoadingHandler);
    super.dispose();
  }
  
  // ================================
  // 标签页相关方法 - 放在这里确保在build之前声明
  // ================================
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('_handleMethodCall: ${call.method}');
    switch (call.method) {
      case 'onPageStart':
        break;
      case 'onPageStop':
        break;
    }
  }
  
  Future<void> _loadTabs() async {
    if (_channel == null) return;
    try {
      final tabsData = await _channel!.invokeMethod<List<dynamic>>('getTabsInfo');
      if (tabsData != null && mounted) {
        setState(() {
          _tabs = tabsData.map((tab) => TabInfo.fromMap(Map<String, dynamic>.from(tab))).toList();
          _tabsStatic = _tabs;
        });
      }
    } catch (e) {
      print('Error loading tabs: $e');
    }
  }
  
  Future<void> _closeCurrentTab() async {
    if (_channel == null) return;
    try {
      await _channel!.invokeMethod<bool>('closeCurrentTab');
      // 注意：原生端会触发 onTabStackChanged，不需要再次调用 _loadTabs()
    } catch (e) {
      print('Error closing current tab: $e');
    }
  }
  
  Future<void> _closeTab(dynamic tabId) async {
    if (_channel == null) return;
    try {
      await _channel!.invokeMethod<bool>('closeTab', {'tabId': tabId});
      // 注意：原生端会触发 onTabStackChanged，不需要再次调用 _loadTabs()
    } catch (e) {
      print('Error closing tab: $e');
    }
  }

  // 获取简化的 URL（去掉协议前缀），内部网站替换域名为 trip.aiiko.club
  String _getDisplayUrl(String url) {
    String processedUrl = url;
    // 检测是否为内部网站（本地服务端口）
    final isInternalWebsite = url.contains('localhost:13218') ||
        url.contains('localhost:13219') ||
        url.contains('localhost:13220') ||
        url.contains('127.0.0.1:13218') ||
        url.contains('127.0.0.1:13219') ||
        url.contains('127.0.0.1:13220');
    // 若判定为内部网站，则将显示用域名统一修改为 trip.aiiko.club
    if (isInternalWebsite) {
      processedUrl = url.replaceAll(
        RegExp(r'https?://(localhost|127\.0\.0\.1):(13218|13219|13220)'),
        'https://trip.aiiko.club',
      );
    }
    if (processedUrl.startsWith('https://')) {
      return processedUrl.substring(8);
    }
    if (processedUrl.startsWith('http://')) {
      return processedUrl.substring(7);
    }
    return processedUrl;
  }

  // 构建 Chrome PWA 样式的 header
  Widget _buildPwaHeader() {
    final textColor = _brightness == Brightness.dark ? Colors.white : Colors.black;
    final subTextColor = _brightness == Brightness.dark ? Colors.white70 : Colors.black54;
    final backgroundColor = _brightness == Brightness.dark ? const Color(0xFF202124) : Colors.white;
    
    // 获取当前标签
    final currentTab = _tabs.isNotEmpty 
        ? _tabs.firstWhere((t) => t.isCurrent, orElse: () => _tabs.first)
        : null;
    
    final displayTitle = currentTab?.title.isNotEmpty == true 
        ? currentTab!.title 
        : (_currentTitle.isNotEmpty ? _currentTitle : '');
    final displayUrl = currentTab?.url.isNotEmpty == true 
        ? _getDisplayUrl(currentTab!.url) 
        : '';
    
    // 只有标签数 > 1 时才显示 header，否则返回空容器（高度为0）以便 AnimatedSize 动画
    if (_tabs.length <= 1) {
      return Container(height: 0);
    }
    
    return Container(
      color: backgroundColor,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 4,
        right: 4,
        bottom: 8,
      ),
      child: Row(
        children: [
          // 左侧 X 按钮
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              icon: const Icon(Icons.close, size: 24),
              padding: EdgeInsets.zero,
              color: textColor,
              onPressed: () async {
                await _closeCurrentTab();
              },
            ),
          ),
          const SizedBox(width: 4),
          // 中间：标题 + URL（两行）
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displayTitle.isNotEmpty)
                  Text(
                    displayTitle,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (displayUrl.isNotEmpty)
                  Text(
                    displayUrl,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 右侧三个点按钮
          SizedBox(
            width: 44,
            height: 44,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 24),
              color: backgroundColor,
              iconColor: textColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected: (value) {
                _handleMenuAction(value);
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    padding: EdgeInsets.zero,
                    value: 'actions',
                    child: Column(
                      children: [
                        // 顶部图标按钮行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildMenuIconButton(
                              context,
                              Icons.arrow_back,
                              'back',
                              !_canGoBack,
                            ),
                            _buildMenuIconButton(
                              context,
                              Icons.arrow_forward,
                              'forward',
                              !_canGoForward,
                            ),
                            _buildMenuIconButton(
                              context,
                              Icons.refresh,
                              'refresh',
                              false,
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                        // 列表项
                        // _buildMenuItem(context, Icons.open_in_browser, 'open_in_browser'),
                        _buildMenuItem(context, Icons.share, 'share'),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuIconButton(BuildContext ctx, IconData icon, String action, bool disabled) {
    final textColor = _brightness == Brightness.dark ? Colors.white : Colors.black;
    return IconButton(
      icon: Icon(icon, size: 20),
      color: disabled ? Colors.grey : textColor,
      onPressed: disabled ? null : () {
        Navigator.pop(ctx);
        _handleMenuAction(action);
      },
    );
  }

  Widget _buildMenuItem(BuildContext ctx, IconData icon, String key) {
    final textColor = _brightness == Brightness.dark ? Colors.white : Colors.black;
    final label = BridgeController().i18nService.t(key);
    return SizedBox(
      height: 48,
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          _handleMenuAction(key);
        },
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    print('[_handleMenuAction] action: $action, _channel: ${_channel == null ? "null" : "exists"}');
    switch (action) {
      case 'back':
        _channel?.invokeMethod('goBack');
        break;
      case 'forward':
        _channel?.invokeMethod('goForward');
        break;
      case 'refresh':
        _channel?.invokeMethod('reload');
        break;
      case 'open_in_browser':
        _openInBrowser();
        break;
      case 'share':
        _shareUrl();
        break;
    }
  }

  void _openInBrowser() async {
    print('[_openInBrowser] called');
    final currentTab = _tabs.isNotEmpty
        ? _tabs.firstWhere((t) => t.isCurrent, orElse: () => _tabs.first)
        : null;
    final url = currentTab?.url ?? _currentUrl;
    print('[_openInBrowser] url: $url');
    if (url.isNotEmpty && _channel != null) {
      try {
        await _channel!.invokeMethod('openInBrowser', {'url': url});
        print('[_openInBrowser] success');
      } catch (e) {
        print('[_openInBrowser] error: $e');
      }
    }
  }

  void _shareUrl() async {
    print('[_shareUrl] called');
    final currentTab = _tabs.isNotEmpty
        ? _tabs.firstWhere((t) => t.isCurrent, orElse: () => _tabs.first)
        : null;
    final url = currentTab?.url ?? _currentUrl;
    print('[_shareUrl] url: $url');
    if (url.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: url));
      final message = BridgeController().i18nService.t('url_copied');
      _showToast(message);
    }
  }

  void _showToast(String message) {
    final screenWidth = MediaQuery.of(context).size.width;
    ShadToaster.of(context).show(
      ShadToast(
        title: Text(message),
        alignment: Alignment.bottomCenter,
        offset: const Offset(0, 50),
        duration: const Duration(seconds: 2),
      ),
    );
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
            
            _channel!.setMethodCallHandler((call) async {
              switch (call.method) {
                case 'onPageStart':
                  print('Page started: ${call.arguments}');
                  break;
                case 'onPageStop':
                  print('Page stopped: ${call.arguments}');
                  break;
                case 'onTitleChange':
                  final title = call.arguments['title'] as String? ?? '';
                  if (mounted) {
                    setState(() {
                      _currentTitle = title;
                      _currentTitleStatic = title;
                    });
                  }
                  break;
                case 'onTabStackChanged':
                  print('Tab stack changed: ${call.arguments}');
                  // 防抖：避免短时间内多次更新导致闪烁
                  _tabStackChangedTimer?.cancel();
                  _tabStackChangedTimer = Timer(const Duration(milliseconds: 100), () {
                    final tabsData = call.arguments['tabs'] as List<dynamic>? ?? [];
                    final canGoBack = call.arguments['canGoBack'] as bool? ?? false;
                    final canGoForward = call.arguments['canGoForward'] as bool? ?? false;
                    if (mounted) {
                      setState(() {
                        _tabs = tabsData.map((tab) => TabInfo.fromMap(Map<String, dynamic>.from(tab))).toList();
                        _tabsStatic = _tabs;
                        _canGoBack = canGoBack;
                        _canGoBackStatic = canGoBack;
                        _canGoForward = canGoForward;
                        _canGoForwardStatic = canGoForward;
                        final currentTab = _tabs.isNotEmpty ? _tabs.firstWhere((t) => t.isCurrent, orElse: () => _tabs.first) : null;
                        print('[_onTabStackChanged] _canGoBack=$_canGoBack, _canGoForward=$_canGoForward, currentTab=${currentTab?.url}, isCurrent=${currentTab?.isCurrent}');
                      });
                    }
                  });
                  break;
                case 'onTabChanged':
                  print('Tab changed: ${call.arguments}');
                  _loadTabs();
                  break;
                case 'onTabOpened':
                  print('Tab opened: ${call.arguments}');
                  _loadTabs();
                  break;
                case 'onRequestExitApp':
                  print('Request exit app');
                  _handleExitAppRequest();
                  break;
              }
            });
            
            Future.delayed(const Duration(milliseconds: 500), () {
              _loadTabs();
            });
            
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

  @override
  Widget build(BuildContext context) {
    final showHeader = _tabs.length > 1;
    return Scaffold(
      backgroundColor: _brightness == Brightness.dark ? Colors.black : Colors.white,
      body: SafeArea(
        top: !showHeader,  // header 已经处理了状态栏 padding
        bottom: true,
        child: Column(
          children: [
            // Chrome PWA 样式的 header，使用 AnimatedSize 实现平滑过渡动画
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.linear,
              child: _buildPwaHeader(),
            ),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}


