import 'dart:async';
import 'package:flutter/services.dart';

class VehicleService {
  static final VehicleService _instance = VehicleService._internal();
  factory VehicleService() => _instance;
  VehicleService._internal();

  static const MethodChannel _channel = MethodChannel('byd_vehicle');

  Function(Map<String, dynamic>)? onCarDataChanged;

  bool _isStarted = false;
  bool get isStarted => _isStarted;

  StreamController<Map<String, dynamic>>? _carDataController;
  Stream<Map<String, dynamic>>? get carDataStream {
    _carDataController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _carDataController!.stream;
  }

  Future<void> init() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCarDataChanged':
        final jsonString = call.arguments as String;
        final data = _parseCarData(jsonString);
        onCarDataChanged?.call(data);
        _carDataController?.add(data);
        break;
    }
  }

  Map<String, dynamic> _parseCarData(String jsonString) {
    try {
      print('[VehicleService] _parseCarData() called with: $jsonString');
      final RegExp boolRegex = RegExp(r'(\w+):\s*(true|false)');
      String normalized = jsonString;
      normalized = normalized.replaceAllMapped(boolRegex, (match) {
        return '"${match.group(1)}": ${match.group(2)}';
      });

      final RegExp nullRegex = RegExp(r':\s*null([,\}])');
      normalized = normalized.replaceAllMapped(nullRegex, (match) {
        return ': null${match.group(1)}';
      });

      final result = _parseJsonString(normalized);
      print('[VehicleService] _parseCarData() parsed result: $result');
      return result;
    } catch (e) {
      print('[VehicleService] _parseCarData() failed: $e');
      return {};
    }
  }

  Map<String, dynamic> _parseJsonString(String jsonString) {
    final Map<String, dynamic> result = {};

    jsonString = jsonString.trim();
    if (jsonString.startsWith('{') && jsonString.endsWith('}')) {
      jsonString = jsonString.substring(1, jsonString.length - 1);
    }

    final List<String> pairs = _splitJsonPairs(jsonString);

    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex == -1) continue;

      String key = pair.substring(0, colonIndex).trim();
      String value = pair.substring(colonIndex + 1).trim();

      key = _parseString(key);

      if (value == 'null') {
        result[key] = null;
      } else if (value == 'true') {
        result[key] = true;
      } else if (value == 'false') {
        result[key] = false;
      } else if (value.startsWith('{')) {
        result[key] = _parseJsonString(value);
      } else if (value.startsWith('[')) {
        result[key] = _parseJsonArray(value);
      } else if (value.startsWith('"') || value.startsWith("'")) {
        result[key] = _parseString(value);
      } else {
        result[key] = _parseNumber(value);
      }
    }

    return result;
  }

  List<String> _splitJsonPairs(String jsonString) {
    final List<String> pairs = [];
    int depth = 0;
    int start = 0;
    bool inString = false;
    String? stringChar;

    for (int i = 0; i < jsonString.length; i++) {
      final char = jsonString[i];

      if ((char == '"' || char == "'") && (i == 0 || jsonString[i - 1] != '\\')) {
        if (!inString) {
          inString = true;
          stringChar = char;
        } else if (char == stringChar) {
          inString = false;
          stringChar = null;
        }
      } else if (!inString) {
        if (char == '{' || char == '[') {
          depth++;
        } else if (char == '}' || char == ']') {
          depth--;
        } else if (char == ',' && depth == 0) {
          pairs.add(jsonString.substring(start, i).trim());
          start = i + 1;
        }
      }
    }

    if (start < jsonString.length) {
      pairs.add(jsonString.substring(start).trim());
    }

    return pairs;
  }

  List<dynamic> _parseJsonArray(String arrayString) {
    final List<dynamic> result = [];
    arrayString = arrayString.trim();
    if (arrayString.startsWith('[') && arrayString.endsWith(']')) {
      arrayString = arrayString.substring(1, arrayString.length - 1);
    }

    if (arrayString.trim().isEmpty) return result;

    final List<String> items = _splitJsonPairs(arrayString);
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed == 'null') {
        result.add(null);
      } else if (trimmed == 'true') {
        result.add(true);
      } else if (trimmed == 'false') {
        result.add(false);
      } else if (trimmed.startsWith('{')) {
        result.add(_parseJsonString(trimmed));
      } else if (trimmed.startsWith('[')) {
        result.add(_parseJsonArray(trimmed));
      } else if (trimmed.startsWith('"') || trimmed.startsWith("'")) {
        result.add(_parseString(trimmed));
      } else {
        result.add(_parseNumber(trimmed));
      }
    }

    return result;
  }

  String _parseString(String value) {
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  dynamic _parseNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('.')) {
      return double.tryParse(trimmed) ?? trimmed;
    } else {
      return int.tryParse(trimmed) ?? trimmed;
    }
  }

  Future<void> startCarDataUpdates() async {
    if (_isStarted) {
      print('[VehicleService] startCarDataUpdates() skipped - already started');
      return;
    }
    print('[VehicleService] startCarDataUpdates() calling native method');
    await _channel.invokeMethod('startCarDataUpdates');
    _isStarted = true;
    print('[VehicleService] startCarDataUpdates() completed');
  }

  Future<void> stopCarDataUpdates() async {
    if (!_isStarted) {
      print('[VehicleService] stopCarDataUpdates() skipped - not started');
      return;
    }
    print('[VehicleService] stopCarDataUpdates() calling native method');
    await _channel.invokeMethod('stopCarDataUpdates');
    _isStarted = false;
    print('[VehicleService] stopCarDataUpdates() completed');
  }

  Future<void> requestCarData() async {
    print('[VehicleService] requestCarData() calling native method');
    await _channel.invokeMethod('requestCarData');
    print('[VehicleService] requestCarData() completed');
  }

  Future<bool> hasBydPermissions() async {
    try {
      print('[VehicleService] hasBydPermissions() calling native method');
      final result = await _channel.invokeMethod<bool>('hasBydPermissions');
      print('[VehicleService] hasBydPermissions() result: $result');
      return result ?? false;
    } catch (e) {
      print('[VehicleService] hasBydPermissions() failed: $e');
      return false;
    }
  }

  Future<void> requestBydPermissions() async {
    try {
      print('[VehicleService] requestBydPermissions() calling native method');
      await _channel.invokeMethod('requestBydPermissions');
      print('[VehicleService] requestBydPermissions() completed');
    } catch (e) {
      print('[VehicleService] requestBydPermissions() failed: $e');
    }
  }

  Future<Map<String, String>> checkBydPermissions(List<String> permissionTypes) async {
    try {
      print('[VehicleService] checkBydPermissions() calling native method for: $permissionTypes');
      final Map<String, bool>? result = await _channel.invokeMethod<Map<String, bool>>('checkBydPermissions', permissionTypes);
      final Map<String, String> mappedResult = {};
      if (result != null) {
        for (final entry in result.entries) {
          mappedResult[entry.key] = entry.value ? 'granted' : 'denied';
        }
      }
      print('[VehicleService] checkBydPermissions() result: $mappedResult');
      return mappedResult;
    } catch (e) {
      print('[VehicleService] checkBydPermissions() failed: $e');
      final Map<String, String> errorResult = {};
      for (final type in permissionTypes) {
        errorResult[type] = 'denied';
      }
      return errorResult;
    }
  }

  void dispose() {
    _carDataController?.close();
    _carDataController = null;
  }
}