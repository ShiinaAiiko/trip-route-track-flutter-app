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
import 'package:flutter_bridge/src/bridge_message.dart';
import 'package:i18n/i18n.dart';

String? _initialUrl;
String _appTitle = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await LocalServer.instance.start();
  
  await BridgeController().init();
  final i18nService = BridgeController().i18nService;
  _appTitle = i18nService.t('app_title');
  _initialUrl = BridgeController().languageService.getLocalizedUrl('http://localhost:8080/');
  
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

class _WebViewContainerState extends State<WebViewContainer>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  double _pitch = 0.0;
  double _roll = 0.0;
  bool _isLoading = true;
  Brightness _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  late String _loadingSubtitle;

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
    _loadTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _bridgeHandlerListener() {
    _closeLoadingHandler = (message) {
      print('Received closeLoading message');
      setState(() {
        _isLoading = false;
      });
      _loadTimeoutTimer?.cancel();
    };
    BridgeController().on('closeLoading', _closeLoadingHandler);
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
          top: true,
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildGeckoView(),
              AnimatedOpacity(
                opacity: _isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: _isLoading
                    ? Container(
                        color: _brightness == Brightness.dark ? Colors.black : Colors.white,
                        child: _buildLoadingContent(),
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
              _loadingSubtitle,
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
