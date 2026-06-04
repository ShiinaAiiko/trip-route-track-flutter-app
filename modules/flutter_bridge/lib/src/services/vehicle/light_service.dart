import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class LightService {
  static final LightService _instance = LightService._internal();
  factory LightService() => _instance;
  LightService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<LightData> _lightDataController =
      StreamController<LightData>.broadcast();

  Stream<LightData> get lightDataStream => _lightDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final lightData = LightData.fromJson(data);
    _lightDataController.add(lightData);
  }

  Future<LightData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getLightData');
      if (result != null) {
        return LightData.fromJson(Map<String, dynamic>.from(result));
      }
      return LightData.defaultData();
    } catch (e) {
      print('[LightService] get() failed: $e');
      return LightData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableLightListener', {'enabled': enabled});
      _isListening = enabled;
    } catch (e) {
      print('[LightService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _lightDataController.close();
  }

}