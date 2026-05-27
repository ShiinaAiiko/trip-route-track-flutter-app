import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class SpeedService {
  static final SpeedService _instance = SpeedService._internal();
  factory SpeedService() => _instance;
  SpeedService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<SpeedData> _speedDataController =
      StreamController<SpeedData>.broadcast();

  Stream<SpeedData> get speedDataStream => _speedDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  /// 内部方法：设置监听器，接收原生推送的数据
  void setupListener(Map<String, dynamic> data) {
    final speedData = SpeedData.fromJson(data);
    _speedDataController.add(speedData);
  }

  /// 获取车速数据（统一接口）
  /// @return 车速数据对象，包含 currentSpeed、accelerateDeepness、brakeDeepness
  Future<SpeedData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSpeedData');
      if (result != null) {
        return SpeedData.fromJson(Map<String, dynamic>.from(result));
      }
      return SpeedData(currentSpeed: 0, accelerateDeepness: 0, brakeDeepness: 0);
    } catch (e) {
      print('[SpeedService] get() failed: $e');
      return SpeedData(currentSpeed: 0, accelerateDeepness: 0, brakeDeepness: 0);
    }
  }

  /// 启用车速监听（统一接口）
  /// @param enabled 是否启用监听
  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableSpeedListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[SpeedService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _speedDataController.close();
  }
}