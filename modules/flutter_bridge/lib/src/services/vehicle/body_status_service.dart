import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class BodyStatusService {
  static final BodyStatusService _instance = BodyStatusService._internal();
  factory BodyStatusService() => _instance;
  BodyStatusService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<BodyStatusData> _bodyStatusDataController =
      StreamController<BodyStatusData>.broadcast();

  Stream<BodyStatusData> get bodyStatusDataStream => _bodyStatusDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final bodyStatusData = BodyStatusData.fromJson(data);
    _bodyStatusDataController.add(bodyStatusData);
  }

  Future<BodyStatusData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getBodyStatusData');
      if (result != null) {
        return BodyStatusData.fromJson(Map<String, dynamic>.from(result));
      }
      return BodyStatusData.defaultData();
    } catch (e) {
      print('[BodyStatusService] get() failed: $e');
      return BodyStatusData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableBodyStatusListener', enabled);
      _isListening = enabled;
    } catch (e) {
      print('[BodyStatusService] enableListener() failed: $e');
    }
  }

  void dispose() {
    _bodyStatusDataController.close();
  }

}