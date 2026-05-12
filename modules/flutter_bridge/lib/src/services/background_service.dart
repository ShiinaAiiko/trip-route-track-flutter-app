import 'dart:async';
import 'package:flutter/services.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  bool _isRunning = false;
  bool _enableBackgroundTasks = false;
  Timer? _backgroundTimer;
  final MethodChannel _methodChannel = const MethodChannel('flutter_background');

  bool get isRunning => _isRunning;
  bool get enableBackgroundTasks => _enableBackgroundTasks;

  Future<void> start() async {
    if (!_isRunning) {
      try {
        await _methodChannel.invokeMethod('startBackgroundService');
        _isRunning = true;
      } catch (e) {
        print('Failed to start background service: $e');
      }
    }
  }

  Future<void> stop() async {
    if (_isRunning) {
      try {
        await _methodChannel.invokeMethod('stopBackgroundService');
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
        _isRunning = false;
      } catch (e) {
        print('Failed to stop background service: $e');
      }
    }
  }

  void setEnableBackgroundTasks(bool enable) {
    _enableBackgroundTasks = enable;
  }

  void updateNotification({
    required String taskTitle,
    required String taskDesc,
  }) async {
    if (_isRunning) {
      try {
        await _methodChannel.invokeMethod('updateNotification', {
          'taskTitle': taskTitle,
          'taskDesc': taskDesc,
        });
      } catch (e) {
        print('Failed to update notification: $e');
      }
    }
  }
}
