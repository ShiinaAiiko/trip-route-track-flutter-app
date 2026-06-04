import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<SensorData> _sensorDataController =
      StreamController<SensorData>.broadcast();

  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final sensorData = SensorData.fromJson(data);
    _sensorDataController.add(sensorData);
  }

  Future<SensorData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSensorData');
      if (result != null) {
        return SensorData.fromJson(Map<String, dynamic>.from(result));
      }
      return SensorData.defaultData();
    } catch (e) {
      print('[SensorService] get() failed: $e');
      return SensorData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableSensorListener', {'enabled': enabled});
      _isListening = enabled;
    } catch (e) {
      print('[SensorService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _sensorDataController.close();
  }

}