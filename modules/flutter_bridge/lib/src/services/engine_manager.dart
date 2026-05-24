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
      
      // 只有成功获取到版本号且版本低于85时才切换到Gecko
      // 如果获取失败返回0，保持默认的system引擎
      if (version > 0 && version < _minSystemWebViewVersion) {
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
    // 添加重试机制，解决首次启动时 channel 未注册的问题
    const maxRetries = 5;
    const retryDelay = Duration(milliseconds: 200);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final version = await _channel.invokeMethod<String>('getSystemWebViewVersion');
        if (version != null) {
          final match = RegExp(r'^(\d+)').firstMatch(version);
          if (match != null) {
            final versionInt = int.parse(match.group(1)!);
            print('[EngineManager] Got WebView version: $versionInt (attempt $attempt)');
            return versionInt;
          }
        }
      } on PlatformException catch (e) {
        print('[EngineManager] PlatformException (attempt $attempt): ${e.message}');
      } catch (e) {
        print('[EngineManager] Error getting WebView version (attempt $attempt): $e');
      }
      
      if (attempt < maxRetries) {
        print('[EngineManager] Retrying to get WebView version... (attempt $attempt/$maxRetries)');
        await Future.delayed(retryDelay);
      }
    }
    
    print('[EngineManager] Failed to get WebView version after $maxRetries attempts');
    return 0;
  }

  String getEngineName(WebViewEngine engine) {
    return engine == WebViewEngine.gecko ? 'gecko' : 'system';
  }
  
  /// 获取系统WebView版本号（公开方法）
  Future<int> getWebViewVersion() async {
    return await _getSystemWebViewVersion();
  }
}