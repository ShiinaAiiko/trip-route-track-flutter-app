import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class RadarService {
  static final RadarService _instance = RadarService._internal();
  factory RadarService() => _instance;
  RadarService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<RadarData> _radarDataController =
      StreamController<RadarData>.broadcast();

  Stream<RadarData> get radarDataStream => _radarDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final radarData = RadarData.fromJson(data);
    _radarDataController.add(radarData);
  }

  Future<RadarData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getRadarData');
      if (result != null) {
        return RadarData.fromJson(Map<String, dynamic>.from(result));
      }
      return RadarData.defaultData();
    } catch (e) {
      print('[RadarService] get() failed: $e');
      return RadarData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableRadarListener', {'enabled': enabled});
      _isListening = enabled;
    } catch (e) {
      print('[RadarService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _radarDataController.close();
  }

}