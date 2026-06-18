import 'dart:convert';
import 'package:flutter/services.dart';
import '../bridge_controller.dart';

enum LogType {
  carLog,
  appLog,
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const MethodChannel _channel = MethodChannel('log_service');

  // 日志开关状态，默认都开启
  bool _carLogEnabled = true;
  bool _appLogEnabled = true;

  bool get carLogEnabled => _carLogEnabled;
  bool get appLogEnabled => _appLogEnabled;

  Future<void> init() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBydLog':
        try {
          final jsonString = call.arguments as String;
          final logData = json.decode(jsonString) as Map<String, dynamic>;
          final type = logData['type'] as String? ?? 'carLog';
          final message = logData['message'] as String? ?? '';
          print('[LogService] BYD Log received: type=$type, message=$message');
          _sendLog(LogType.carLog, message);
        } catch (e) {
          print('[LogService] Failed to parse BYD log: $e');
        }
        break;
      case 'onLog':
        try {
          final jsonString = call.arguments as String;
          final logData = json.decode(jsonString) as Map<String, dynamic>;
          final type = logData['type'] as String? ?? 'appLog';
          final message = logData['message'] as String? ?? '';
          print('[LogService] App Log received: type=$type, message=$message');
          _sendLog(LogType.appLog, message);
        } catch (e) {
          print('[LogService] Failed to parse app log: $e');
        }
        break;
    }
  }

  void _sendLog(LogType type, String message) {
    // 根据开关状态决定是否发送日志
    if (type == LogType.carLog && !_carLogEnabled) {
      return;
    }
    if (type == LogType.appLog && !_appLogEnabled) {
      return;
    }

    try {
      final payload = {
        'type': type == LogType.carLog ? 'carLog' : 'appLog',
        'message': message,
      };
      BridgeController().sendMessage('log', payload);
    } catch (e) {
      print('[LogService] Failed to send log via BridgeController: $e');
    }
  }

  /// 设置日志开关
  /// [type] - 日志类型，'carLog' 或 'appLog'
  /// [enabled] - 是否开启该类型日志
  void setLogEnabled(String type, bool enabled) {
    print('[LogService] setLogEnabled: type=$type, enabled=$enabled');
    if (type == 'carLog') {
      _carLogEnabled = enabled;
    } else if (type == 'appLog') {
      _appLogEnabled = enabled;
    }
  }

  void sendAppLog(String message) {
    print('[LogService] App Log: $message');
    _sendLog(LogType.appLog, message);
  }

  void sendCarLog(String message) {
    print('[LogService] Car Log: $message');
    _sendLog(LogType.carLog, message);
  }
}