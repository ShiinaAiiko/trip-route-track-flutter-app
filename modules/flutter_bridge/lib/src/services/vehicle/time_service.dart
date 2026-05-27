import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class TimeService {
  static final TimeService _instance = TimeService._internal();
  factory TimeService() => _instance;
  TimeService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<TimeData> _timeDataController =
      StreamController<TimeData>.broadcast();

  Stream<TimeData> get timeDataStream => _timeDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final timeData = TimeData.fromJson(data);
    _timeDataController.add(timeData);
  }

  Future<TimeData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTimeData');
      if (result != null) {
        return TimeData.fromJson(Map<String, dynamic>.from(result));
      }
      return TimeData.defaultData();
    } catch (e) {
      print('[TimeService] get() failed: $e');
      return TimeData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableTimeListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[TimeService] enableListener() failed: $e');
    }
  }

  Future<bool> set(String field, dynamic value) async {
    try {
      final result = await _channel.invokeMethod<bool>('setTimeData', {
        'field': field,
        'value': value,
      });
      return result ?? false;
    } catch (e) {
      print('[TimeService] set($field, $value) failed: $e');
      return false;
    }
  }

  void dispose() {
    _timeDataController.close();
  }
}
