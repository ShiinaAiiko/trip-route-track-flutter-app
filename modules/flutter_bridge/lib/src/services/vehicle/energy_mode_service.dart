import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class EnergyModeService {
  static final EnergyModeService _instance = EnergyModeService._internal();
  factory EnergyModeService() => _instance;
  EnergyModeService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<EnergyModeData> _energyModeDataController =
      StreamController<EnergyModeData>.broadcast();

  Stream<EnergyModeData> get energyModeDataStream => _energyModeDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final energyModeData = EnergyModeData.fromJson(data);
    _energyModeDataController.add(energyModeData);
  }

  Future<EnergyModeData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getEnergyModeData');
      if (result != null) {
        return EnergyModeData.fromJson(Map<String, dynamic>.from(result));
      }
      return EnergyModeData.defaultData();
    } catch (e) {
      print('[EnergyModeService] get() failed: $e');
      return EnergyModeData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableEnergyModeListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[EnergyModeService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _energyModeDataController.close();
  }

}