import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class DoorService {
  static final DoorService _instance = DoorService._internal();
  factory DoorService() => _instance;
  DoorService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<DoorData> _doorDataController =
      StreamController<DoorData>.broadcast();

  Stream<DoorData> get doorDataStream => _doorDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final doorData = DoorData.fromJson(data);
    _doorDataController.add(doorData);
  }

  Future<DoorData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDoorData');
      if (result != null) {
        return DoorData.fromJson(Map<String, dynamic>.from(result));
      }
      return DoorData.defaultData();
    } catch (e) {
      print('[DoorService] get() failed: $e');
      return DoorData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableDoorListener', {'enabled': enabled});
      _isListening = enabled;
    } catch (e) {
      print('[DoorService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _doorDataController.close();
  }

}