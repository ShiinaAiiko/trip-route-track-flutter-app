import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class EngineService {
  static final EngineService _instance = EngineService._internal();
  factory EngineService() => _instance;
  EngineService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<EngineData> _engineDataController =
      StreamController<EngineData>.broadcast();

  Stream<EngineData> get engineDataStream => _engineDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final engineData = EngineData.fromJson(data);
    _engineDataController.add(engineData);
  }

  Future<EngineData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getEngineData');
      if (result != null) {
        return EngineData.fromJson(Map<String, dynamic>.from(result));
      }
      return EngineData.defaultData();
    } catch (e) {
      print('[EngineService] get() failed: $e');
      return EngineData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableEngineListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[EngineService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _engineDataController.close();
  }

}