import 'dart:async';
import 'package:flutter/services.dart';
import 'car_data_types.dart';

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  final StreamController<MediaData> _mediaDataController =
      StreamController<MediaData>.broadcast();

  Stream<MediaData> get mediaDataStream => _mediaDataController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void setupListener(Map<String, dynamic> data) {
    final mediaData = MediaData.fromJson(data);
    _mediaDataController.add(mediaData);
  }

  Future<MediaData> get() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMediaData');
      if (result != null) {
        return MediaData.fromJson(Map<String, dynamic>.from(result));
      }
      return MediaData.defaultData();
    } catch (e) {
      print('[MediaService] get() failed: $e');
      return MediaData.defaultData();
    }
  }

  Future<void> enableListener(bool enabled) async {
    try {
      await _channel.invokeMethod('enableMediaListener', {'enabled': enabled});
      _isListening = enabled;
    } catch (e) {
      print('[MediaService] enableListener() failed: $e');
    }
  }

  Future<bool> set(String field, dynamic value) async {
    try {
      final result = await _channel.invokeMethod<bool>('setMediaData', {
        'field': field,
        'value': value,
      });
      return result ?? false;
    } catch (e) {
      print('[MediaService] set($field, $value) failed: $e');
      return false;
    }
  }

  void dispose() {
    _mediaDataController.close();
  }
}
