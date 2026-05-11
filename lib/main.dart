import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  StreamSubscription<Position>? _positionSubscription;

  double _pitch = 0.0;
  double _roll = 0.0;
  bool _isLoading = true;
  Brightness _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  Position? _currentPosition;
  bool _isLocationUpdating = false;

  Timer? _sensorTimer;
  Timer? _loadTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _initSensorStreams();
    // 延迟500ms后再申请权限，确保加载动画已完全显示
    Future.delayed(const Duration(milliseconds: 500), () {
      _requestLocationPermission();
    });
    // 添加超时机制，确保网页能正常显示
    _loadTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
        _startSensorBridge();
        _startLocationUpdates();
      }
    });
  }

  void _startLocationUpdates() {
    if (_isLocationUpdating) {
      return; // 已经在更新位置，不需要重复启动
    }
    
    _isLocationUpdating = true;
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: Duration(seconds: 1), // Android特有：1秒更新一次
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      _channel?.invokeMethod('setGeolocation', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': position.timestamp.millisecondsSinceEpoch.toDouble(),
      });
    }, onError: (error) {
      _isLocationUpdating = false;
      _channel?.invokeMethod('setGeolocationError', {
        'code': 'POSITION_UNAVAILABLE',
        'message': error.toString(),
      });
    }, onDone: () {
      _isLocationUpdating = false;
    });
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

  void _requestLocationPermission() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        final result = await Permission.locationWhenInUse.request();
        if (result.isGranted) {
          await _checkAndStartLocation();
        }
      } else if (status.isGranted) {
        await _checkAndStartLocation();
      }
    } catch (e) {
      // 静默处理异常，不影响加载流程
    }
  }

  Future<void> _checkAndStartLocation() async {
    try {
      // 检查位置服务是否启用
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // 位置服务未启用，尝试打开设置
        await Geolocator.openLocationSettings();
        setState(() {
          _currentPosition = null;
        });
        return;
      }

      // 先尝试立即获取一次位置
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = currentPosition;
      });

      // 然后启动持续位置更新
      _startLocationUpdates();
    } catch (e) {
      // 打印错误日志
      print('GPS Error: $e');
    }
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
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: _brightness == Brightness.dark ? Colors.black : Colors.white,
          body: SafeArea(
            bottom: false,
            child: _buildGeckoView(),
          ),
        ),
        // 加载完成前显示覆盖层，遮挡 GeckoView 的闪烁
          if (_isLoading)
            Container(
              color: _brightness == Brightness.dark ? Colors.black : Colors.white,
              child: _buildLoadingContent(),
            ),
      ],
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
    final creationParams = <String, dynamic>{
      'initialUrl': 'https://trip.aiiko.club/zh-CN',
      'isDarkMode': _brightness == Brightness.dark,
    };

    if (Theme.of(context).platform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          _channel = MethodChannel('gecko_view_$id');
          _channel?.setMethodCallHandler(_handleMethodCall);
        },
      );
    } else {
      return const Center(
        child: Text('This platform is not supported'),
      );
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPageStart':
        setState(() {
          _isLoading = true;
        });
        break;
      case 'onPageStop':
        _loadTimeoutTimer?.cancel();
        setState(() {
          _isLoading = false;
        });
        _startSensorBridge();
        _startLocationUpdates();
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
