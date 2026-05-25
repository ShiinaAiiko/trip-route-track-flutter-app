import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'webview_options.dart';
import 'webview_bridge.dart';
import 'gecko_webview.dart';

class WebViewController {
  late NyaNyaWebview _webView;
  late NyaNyaWebviewController _nyaNyaController;
  late WebViewBridge _bridge;
  final WebViewOptions _options;
  OpenUrlHandler? _onOpenUrl;
  VoidCallback? _onClose;
  final String sessionId;

  void Function(String sessionId, String message)? onMessage;
  void Function(String sessionId, dynamic channel)? onChannelCreated;

  // 用于包装回调，允许在不重新创建 WebView 的情况下更新
  late void Function(String, String?) _onOpenUrlWrapper;

  WebViewController(this._options, {String? sessionId})
      : sessionId = sessionId ?? _generateSessionId() {
    print(
        '[NyaNyaOpenURL] WebViewController constructor called, sessionId: $sessionId');
    _nyaNyaController = NyaNyaWebviewController();
    _bridge = WebViewBridge(messageSender: _sendMessageToWebView);

    // 创建一个包装器来调用当前的回调
    _onOpenUrlWrapper = (url, target) {
      print(
          '[NyaNyaOpenURL] WebViewController._onOpenUrlWrapper called: url=$url, target=$target, _onOpenUrl=${_onOpenUrl}');
      _onOpenUrl?.call(url, target);
    };

    _initWebView();
  }

  static String _generateSessionId() {
    return const Uuid().v4();
  }

  void _initWebView() {
    switch (_options.engine) {
      case WebViewEngine.gecko:
      case WebViewEngine.system:
        _webView = NyaNyaWebview(
          options: _options,
          messageHandler: _handleWebMessage,
          controllerKey: _nyaNyaController.key,
          onOpenUrl: _onOpenUrlWrapper,
          onClose: _onClose,
          onChannelCreated: (channel) {
            _nyaNyaController.setChannel(channel);
            onChannelCreated?.call(sessionId, channel);
          },
        );
        break;
    }
  }

  void setOnCloseHandler(VoidCallback? handler) {
    print(
        '[NyaNyaOpenURL] WebViewController.setOnCloseHandler called: handler=${handler}');
    _onClose = handler;
    // 需要重新初始化 WebView 来传递新的 onClose
    _initWebView();
  }

  void _handleWebMessage(String message) {
    _bridge.handleMessage(message);
    onMessage?.call(sessionId, message);
  }

  void _sendMessageToWebView(String message) {
    _nyaNyaController.postMessage(message);
  }

  Widget build(BuildContext context) {
    return _webView;
  }

  Future<void> loadUrl(String url) => _nyaNyaController.loadUrl(url);

  Future<void> reload() {
    print(
        '[DEBUG] _handleRefresh called, _nyaNyaController: $_nyaNyaController');
    return _nyaNyaController.reload();
  }

  Future<void> goBack() => _nyaNyaController.goBack();

  Future<void> goForward() => _nyaNyaController.goForward();

  Future<bool> canGoBack() {
    print(
        '[DEBUG] updateNavigationState WebViewController.canGoBack() called, _nyaNyaController: $_nyaNyaController');
    return _nyaNyaController.canGoBack();
  }

  Future<bool> canGoForward() {
    print(
        '[DEBUG] updateNavigationState WebViewController.canGoForward() called, _nyaNyaController: $_nyaNyaController');
    return _nyaNyaController.canGoForward();
  }

  Future<void> evaluateJavascript(String script) =>
      _nyaNyaController.evaluateJavascript(script);

  Future<void> postMessage(String message) =>
      _nyaNyaController.postMessage(message);

  Future<void> setOnOpenUrlHandler(OpenUrlHandler? handler) {
    print(
        '[NyaNyaOpenURL] WebViewController.setOnOpenUrlHandler called: handler=${handler}');
    _onOpenUrl = handler;
    // 包装器已经会调用当前的 _onOpenUrl，所以不需要重新创建 WebView
    return Future.value();
  }

  Future<void> openInBrowser(String url) {
    return _nyaNyaController.openInBrowser(url);
  }

  void on(String eventName, BridgeMessageHandler handler) {
    _bridge.on(eventName, handler);
  }

  void off(String eventName, BridgeMessageHandler handler) {
    _bridge.off(eventName, handler);
  }

  Future<dynamic> send(String type, dynamic payload) {
    return _bridge.send(type, payload);
  }

  void sendWithoutResponse(String type, dynamic payload) {
    _bridge.sendWithoutResponse(type, payload);
  }

  Future<void> dispose() async {
    _bridge.dispose();
  }

  WebViewBridge get bridge => _bridge;

  WebViewOptions get options => _options;
}
