import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class AirQualityService {
  static final AirQualityService _instance = AirQualityService._internal();
  factory AirQualityService() => _instance;
  AirQualityService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<AirQualityData> _airQualityDataController =
      StreamController<AirQualityData>.broadcast();

  Stream<AirQualityData> get airQualityDataStream => _airQualityDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final airQualityData = AirQualityData.fromJson(data);
    _airQualityDataController.add(airQualityData);
  }

  Future<AirQualityData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAirQualityData');
      if (result != null) {
        return AirQualityData.fromJson(Map<String, dynamic>.from(result));
      }
      return AirQualityData.defaultData();
    } catch (e) {
      print('[AirQualityService] get() failed: $e');
      return AirQualityData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableAirQualityListener', {'enabled': enabled});
      _isListening = enabled;
    } catch (e) {
      print('[AirQualityService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _airQualityDataController.close();
  }

}