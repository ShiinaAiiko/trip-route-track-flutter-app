import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class ChargeService {
  static final ChargeService _instance = ChargeService._internal();
  factory ChargeService() => _instance;
  ChargeService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<ChargeData> _chargeDataController =
      StreamController<ChargeData>.broadcast();

  Stream<ChargeData> get chargeDataStream => _chargeDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final chargeData = ChargeData.fromJson(data);
    _chargeDataController.add(chargeData);
  }

  Future<ChargeData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getChargeData');
      if (result != null) {
        return ChargeData.fromJson(Map<String, dynamic>.from(result));
      }
      return ChargeData.defaultData();
    } catch (e) {
      print('[ChargeService] get() failed: $e');
      return ChargeData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableChargeListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[ChargeService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _chargeDataController.close();
  }

}