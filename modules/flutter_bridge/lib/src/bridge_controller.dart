import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'bridge_message.dart';
import 'services/keep_awake_service.dart';
import 'services/background_service.dart';
import 'services/language_service.dart';

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
  int _backgroundLocationCount = 0;
  int _backgroundStartTime = 0;
  double _currentSpeed = 0;
  double _currentAltitude = 0;

  bool get enableLocation => _enableLocation;
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
    final jsonMessage = message.toJson();

    await _channel?.invokeMethod('postMessage', {
      'message': jsonMessage.toString(),
    });
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
        case 'enableLocation':
          _enableLocation = message.payload as bool;
          _dispatchMessage(message);
          break;
        case 'keepScreenOn':
          _keepAwakeService.setKeepAwake(message.payload as bool);
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
