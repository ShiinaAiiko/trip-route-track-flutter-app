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

  void sendAppLog(String message) {
    print('[LogService] App Log: $message');
    _sendLog(LogType.appLog, message);
  }

  void sendCarLog(String message) {
    print('[LogService] Car Log: $message');
    _sendLog(LogType.carLog, message);
  }
}