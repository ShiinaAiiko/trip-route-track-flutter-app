import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class VehicleSettingService {
  static final VehicleSettingService _instance = VehicleSettingService._internal();
  factory VehicleSettingService() => _instance;
  VehicleSettingService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<VehicleSettingData> _vehicleSettingDataController =
      StreamController<VehicleSettingData>.broadcast();

  Stream<VehicleSettingData> get vehicleSettingDataStream => _vehicleSettingDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final vehicleSettingData = VehicleSettingData.fromJson(data);
    _vehicleSettingDataController.add(vehicleSettingData);
  }

  Future<VehicleSettingData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getVehicleSettingData');
      if (result != null) {
        return VehicleSettingData.fromJson(Map<String, dynamic>.from(result));
      }
      return VehicleSettingData.defaultData();
    } catch (e) {
      print('[VehicleSettingService] get() failed: $e');
      return VehicleSettingData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableVehicleSettingListener', {'enabled': enabled});
      _isListening = enabled;
    } catch (e) {
      print('[VehicleSettingService] enableListener() failed: $e');
    }
  }

  Future<bool> set(String field, dynamic value) async {
    try {
      final result = await _channel.invokeMethod<bool>('setVehicleSettingData', {
        'field': field,
        'value': value,
      });
      return result ?? false;
    } catch (e) {
      print('[VehicleSettingService] set($field, $value) failed: $e');
      return false;
    }
  }

  Future<bool> hasFeature(String feature) async {
    try {
      final result = await _channel.invokeMethod<bool>('vehicleSettingHasFeature', {
        'feature': feature,
      });
      return result ?? false;
    } catch (e) {
      print('[VehicleSettingService] hasFeature($feature) failed: $e');
      return false;
    }
  }

  void dispose() {
    _vehicleSettingDataController.close();
  }
}