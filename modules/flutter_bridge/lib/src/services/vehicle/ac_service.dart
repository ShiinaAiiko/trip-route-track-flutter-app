import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class AcService {
  static final AcService _instance = AcService._internal();
  factory AcService() => _instance;
  AcService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<AcData> _acDataController =
      StreamController<AcData>.broadcast();

  Stream<AcData> get acDataStream => _acDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  /// 内部方法：设置监听器，接收原生推送的数据
  void setupListener(Map<String, dynamic> data) {
    final acData = AcData.fromJson(data);
    _acDataController.add(acData);
  }

  /// 获取空调数据（统一接口）
  /// @return 空调数据对象
  Future<AcData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAcData');
      if (result != null) {
        return AcData.fromJson(Map<String, dynamic>.from(result));
      }
      return AcData.defaultData();
    } catch (e) {
      print('[AcService] get() failed: $e');
      return AcData.defaultData();
    }
  }

  /// 启用空调监听（统一接口）
  /// @param enabled 是否启用监听
  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableAcListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[AcService] enableListener() failed: $e');
    }
  }

  /// 设置空调字段（统一接口）
  /// @param field 字段名
  /// @param value 字段值
  /// @return 是否设置成功
  Future<bool> set(String field, dynamic value) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('setAcData', {
        'field': field,
        'value': value,
      });
      return result?['success'] == true;
    } catch (e) {
      print('[AcService] set($field, $value) failed: $e');
      return false;
    }
  }

  void dispose() {
    _acDataController.close();
  }
}