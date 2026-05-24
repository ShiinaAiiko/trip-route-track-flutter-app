import 'package:flutter/widgets.dart';
import 'webview_options.dart';
import 'webview_bridge.dart';
import 'gecko_webview.dart';

class WebViewController {
  late NyaNyaWebview _webView;
  late NyaNyaWebviewController _nyaNyaController;
  late WebViewBridge _bridge;
  final WebViewOptions _options;

  WebViewController(this._options) {
    _nyaNyaController = NyaNyaWebviewController();
    _bridge = WebViewBridge(messageSender: _sendMessageToWebView);
    _initWebView();
  }

  void _initWebView() {
    switch (_options.engine) {
      case WebViewEngine.gecko:
        _webView = NyaNyaWebview(
          options: _options,
          messageHandler: _handleWebMessage,
          controllerKey: _nyaNyaController.key,
        );
        break;
      case WebViewEngine.system:
        throw UnimplementedError('System WebView not yet implemented');
    }
  }

  void _handleWebMessage(String message) {
    _bridge.handleMessage(message);
  }

  void _sendMessageToWebView(String message) {
    _nyaNyaController.postMessage(message);
  }

  Widget build(BuildContext context) {
    return _webView;
  }

  Future<void> loadUrl(String url) => _nyaNyaController.loadUrl(url);

  Future<void> reload() => _nyaNyaController.reload();

  Future<void> goBack() => _nyaNyaController.goBack();

  Future<void> goForward() => _nyaNyaController.goForward();

  Future<bool> canGoBack() => _nyaNyaController.canGoBack();

  Future<bool> canGoForward() => _nyaNyaController.canGoForward();

  Future<void> evaluateJavascript(String script) => _nyaNyaController.evaluateJavascript(script);

  Future<void> postMessage(String message) => _nyaNyaController.postMessage(message);

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