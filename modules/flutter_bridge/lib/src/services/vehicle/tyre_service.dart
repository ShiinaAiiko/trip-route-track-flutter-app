import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class TyreService {
  static final TyreService _instance = TyreService._internal();
  factory TyreService() => _instance;
  TyreService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<TyreData> _tyreDataController =
      StreamController<TyreData>.broadcast();

  Stream<TyreData> get tyreDataStream => _tyreDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final tyreData = TyreData.fromJson(data);
    _tyreDataController.add(tyreData);
  }

  Future<TyreData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTyreData');
      if (result != null) {
        return TyreData.fromJson(Map<String, dynamic>.from(result));
      }
      return TyreData.defaultData();
    } catch (e) {
      print('[TyreService] get() failed: $e');
      return TyreData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableTyreListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[TyreService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _tyreDataController.close();
  }

}