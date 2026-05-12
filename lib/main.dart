import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'local_server.dart';
import 'package:flutter_bridge/src/bridge_controller.dart';

String? _initialUrl;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 启动本地HTTP服务器
  await LocalServer.instance.start();
  
  // 初始化 BridgeController 并获取本地化 URL
  await BridgeController().init();
  final languageService = BridgeController().languageService;
  _initialUrl = languageService.getLocalizedUrl('http://localhost:8080/');
  
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

class _WebViewContainerState extends State<WebViewContainer>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  double _pitch = 0.0;
  double _roll = 0.0;
  bool _isLoading = true;
  Brightness _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

  Timer? _sensorTimer;
  Timer? _loadTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    // _initSensorStreams();
    // _initBridgeController();
    // 添加超时机制，确保网页能正常显示
    _loadTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
        // _startSensorBridge();
      }
    });
  }

  void _initBridgeController() {
    // BridgeController 已经在 main() 中初始化过了
    // 这里只需要启动传感器（GPS由前端控制）
    _startSensorBridge();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brightness == Brightness.dark ? Colors.black : Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildGeckoView(),
            // 加载完成前显示覆盖层，遮挡 GeckoView 的闪烁
            if (_isLoading)
              Container(
                color: _brightness == Brightness.dark ? Colors.black : Colors.white,
                child: _buildLoadingContent(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Center(
          child: _LoadingDots(),
        ),
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              '行程路线轨迹 App 由 AI 构建',
              style: TextStyle(
                color: _brightness == Brightness.dark ? Colors.white : Colors.black,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeckoView() {
    const viewType = 'geckoView';
    final initialUrl = _initialUrl ?? 'http://localhost:8080/';
    // print('initialUrl language: $initialUrl');
    final creationParams = <String, dynamic>{
      'initialUrl': initialUrl,
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
            // 初始化 bridge controller（它会设置 MethodCallHandler）
            BridgeController().setChannel(_channel);
            // 设置外部 handler，让 main.dart 也能收到消息
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
        // 页面开始加载时就关闭 loading，让用户立即看到网页加载过程
      
        break;
      case 'onPageStop':
        setState(() {
          _isLoading = false;
        });

        _loadTimeoutTimer?.cancel();
        // _startSensorBridge();
        break;
    }
  }

}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BounceDot(
          color: Color(0xFFfeadbc),
          delay: Duration(milliseconds: 0),
        ),
        SizedBox(width: 16),
        _BounceDot(
          color: Color(0xFF09d1fe),
          delay: Duration(milliseconds: 200),
        ),
        SizedBox(width: 16),
        _BounceDot(
          color: Color(0xFF8552e4),
          delay: Duration(milliseconds: 400),
        ),
      ],
    );
  }
}

class _BounceDot extends StatefulWidget {
  final Color color;
  final Duration delay;

  const _BounceDot({
    required this.color,
    required this.delay,
  });

  @override
  State<_BounceDot> createState() => _BounceDotState();
}

class _BounceDotState extends State<_BounceDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: -35).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _isAnimating = true;
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double offset = _isAnimating ? _animation.value : 0;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
