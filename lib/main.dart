
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: brightness == Brightness.dark ? Colors.black : Colors.white,
    statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: brightness == Brightness.dark ? Colors.black : Colors.white,
    systemNavigationBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
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

class _WebViewContainerState extends State<WebViewContainer> with WidgetsBindingObserver {
  InAppWebViewController? _webController;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  double _pitch = 0.0;
  double _roll = 0.0;
  bool _isLoading = true;
  Brightness _brightness = Brightness.dark;

  Timer? _sensorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _initSensorStreams();
  }

  @override
  void didChangePlatformBrightness() {
    _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: _brightness == Brightness.dark ? Colors.black : Colors.white,
      statusBarIconBrightness: _brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: _brightness == Brightness.dark ? Colors.black : Colors.white,
      systemNavigationBarIconBrightness: _brightness == Brightness.dark ? Brightness.light : Brightness.dark,
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
      if (_webController != null) {
        final jsonData = '''
          window.postMessage({
            type: 'SENSOR_DATA',
            data: {
              pitch: ${_pitch.toStringAsFixed(2)},
              roll: ${_roll.toStringAsFixed(2)},
              timestamp: ${DateTime.now().millisecondsSinceEpoch}
            }
          }, '*')
        ''';
        _webController?.evaluateJavascript(source: jsonData);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();
    _sensorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('https://trip.aiiko.club/zh-CN')),
              onWebViewCreated: (controller) {
                _webController = controller;
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                });
                _startSensorBridge();
              },
            ),
            AnimatedOpacity(
              opacity: _isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _buildLoadingPlaceholder(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: _brightness == Brightness.dark ? Colors.black : Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

class _BounceDotState extends State<_BounceDot> with SingleTickerProviderStateMixin {
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
