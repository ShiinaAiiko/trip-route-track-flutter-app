import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class KeepAwakeService {
  static final KeepAwakeService _instance = KeepAwakeService._internal();
  factory KeepAwakeService() => _instance;
  KeepAwakeService._internal();

  bool _isKeepAwake = false;

  bool get isKeepAwake => _isKeepAwake;

  Future<void> activate() async {
    if (!_isKeepAwake) {
      await WakelockPlus.enable();
      _isKeepAwake = true;
    }
  }

  Future<void> deactivate() async {
    if (_isKeepAwake) {
      await WakelockPlus.disable();
      _isKeepAwake = false;
    }
  }

  void setKeepAwake(bool keepAwake) {
    if (keepAwake) {
      activate();
    } else {
      deactivate();
    }
  }
}
