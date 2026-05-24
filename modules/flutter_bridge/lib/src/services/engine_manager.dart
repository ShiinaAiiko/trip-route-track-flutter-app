import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyanya_webview/nyanya_webview.dart';

class EngineManager {
  static final EngineManager _instance = EngineManager._internal();
  factory EngineManager() => _instance;
  EngineManager._internal();

  static const MethodChannel _channel = MethodChannel('nyanya/webview');
  
  static const String _prefsKeyCustomEngine = 'custom_webview_engine';
  static const int _minSystemWebViewVersion = 85;

  WebViewEngine? _selectedEngine;
  bool _isInitialized = false;

  Future<WebViewEngine> getSelectedEngine() async {
    if (!_isInitialized) {
      await _initializeEngine();
    }
    return _selectedEngine ?? WebViewEngine.system;
  }

  Future<void> _initializeEngine() async {
    // 1. 先检查用户是否有自定义设置
    final prefs = await SharedPreferences.getInstance();
    final savedEngine = prefs.getString(_prefsKeyCustomEngine);
    
    if (savedEngine != null) {
      // 用户有自定义设置，直接使用
      _selectedEngine = savedEngine == 'gecko' ? WebViewEngine.gecko : WebViewEngine.system;
      _isInitialized = true;
      return;
    }

    // 2. 默认使用system引擎
    _selectedEngine = WebViewEngine.system;

    // 3. 检查系统WebView版本
    try {
      final version = await _getSystemWebViewVersion();
      print('[EngineManager] System WebView version: $version');
      
      if (version < _minSystemWebViewVersion) {
        print('[EngineManager] System WebView version $version < $_minSystemWebViewVersion, switching to Gecko');
        _selectedEngine = WebViewEngine.gecko;
      }
    } catch (e) {
      print('[EngineManager] Failed to get WebView version: $e');
    }

    _isInitialized = true;
  }

  Future<void> setCustomEngine(WebViewEngine engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyCustomEngine, engine == WebViewEngine.gecko ? 'gecko' : 'system');
    _selectedEngine = engine;
    _isInitialized = true;
  }

  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyCustomEngine);
    _selectedEngine = null;
    _isInitialized = false;
    await _initializeEngine();
  }

  Future<int> _getSystemWebViewVersion() async {
    try {
      final version = await _channel.invokeMethod<String>('getSystemWebViewVersion');
      if (version != null) {
        final match = RegExp(r'^(\d+)').firstMatch(version);
        if (match != null) {
          return int.parse(match.group(1)!);
        }
      }
    } on PlatformException catch (e) {
      print('[EngineManager] PlatformException: ${e.message}');
    }
    return 0;
  }

  String getEngineName(WebViewEngine engine) {
    return engine == WebViewEngine.gecko ? 'gecko' : 'system';
  }
}