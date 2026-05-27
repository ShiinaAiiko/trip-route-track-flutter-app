import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class StatisticService {
  static final StatisticService _instance = StatisticService._internal();
  factory StatisticService() => _instance;
  StatisticService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<StatisticData> _statisticDataController =
      StreamController<StatisticData>.broadcast();

  Stream<StatisticData> get statisticDataStream => _statisticDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final statisticData = StatisticData.fromJson(data);
    _statisticDataController.add(statisticData);
  }

  Future<StatisticData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatisticData');
      if (result != null) {
        return StatisticData.fromJson(Map<String, dynamic>.from(result));
      }
      return StatisticData(
        drivingTime: 0,
        elecDrivingRange: 0,
        elecPercentage: 0,
        fuelDrivingRange: 0,
        fuelPercentage: 0,
        lastElecConPHM: 0,
        lastFuelConPHM: 0,
        totalElecConPHM: 0,
        totalFuelConPHM: 0,
        totalFuelCon: 0,
        totalElecCon: 0,
        totalMileage: 0,
        keyBatteryLevel: 0,
        evMileage: 0,
      );
    } catch (e) {
      print('[StatisticService] get() failed: $e');
      return StatisticData(
        drivingTime: 0,
        elecDrivingRange: 0,
        elecPercentage: 0,
        fuelDrivingRange: 0,
        fuelPercentage: 0,
        lastElecConPHM: 0,
        lastFuelConPHM: 0,
        totalElecConPHM: 0,
        totalFuelConPHM: 0,
        totalFuelCon: 0,
        totalElecCon: 0,
        totalMileage: 0,
        keyBatteryLevel: 0,
        evMileage: 0,
      );
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableStatisticListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[StatisticService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _statisticDataController.close();
  }
}