import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class InstrumentService {
  static final InstrumentService _instance = InstrumentService._internal();
  factory InstrumentService() => _instance;
  InstrumentService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<InstrumentData> _instrumentDataController =
      StreamController<InstrumentData>.broadcast();

  Stream<InstrumentData> get instrumentDataStream => _instrumentDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final instrumentData = InstrumentData.fromJson(data);
    _instrumentDataController.add(instrumentData);
  }

  Future<InstrumentData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInstrumentData');
      if (result != null) {
        return InstrumentData.fromJson(Map<String, dynamic>.from(result));
      }
      return InstrumentData.defaultData();
    } catch (e) {
      print('[InstrumentService] get() failed: $e');
      return InstrumentData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableInstrumentListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[InstrumentService] enableListener() failed: $e');
    }
  }

  Future<bool> set(String field, dynamic value) async {
    try {
      final result = await _channel.invokeMethod<bool>('setInstrumentData', {
        'field': field,
        'value': value,
      });
      return result ?? false;
    } catch (e) {
      print('[InstrumentService] set($field, $value) failed: $e');
      return false;
    }
  }

  void dispose() {
    _instrumentDataController.close();
  }
}
