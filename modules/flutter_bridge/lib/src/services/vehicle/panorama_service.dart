import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class PanoramaService {
  static final PanoramaService _instance = PanoramaService._internal();
  factory PanoramaService() => _instance;
  PanoramaService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<PanoramaData> _panoramaDataController =
      StreamController<PanoramaData>.broadcast();

  Stream<PanoramaData> get panoramaDataStream => _panoramaDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final panoramaData = PanoramaData.fromJson(data);
    _panoramaDataController.add(panoramaData);
  }

  Future<PanoramaData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPanoramaData');
      if (result != null) {
        return PanoramaData.fromJson(Map<String, dynamic>.from(result));
      }
      return PanoramaData.defaultData();
    } catch (e) {
      print('[PanoramaService] get() failed: $e');
      return PanoramaData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enablePanoramaListener', {'enabled': enabled});
      _isListening = enabled;
    } catch (e) {
      print('[PanoramaService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _panoramaDataController.close();
  }
}