import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'webview_options.dart';

typedef NyaNyaMessageHandler = void Function(String message);
typedef NyaNyaChannelCreatedCallback = void Function(MethodChannel channel);

class SystemWebview extends StatefulWidget {
  final WebViewOptions options;
  final NyaNyaMessageHandler messageHandler;
  final NyaNyaChannelCreatedCallback? onChannelCreated;
  final OpenUrlHandler? onOpenUrl;

  const SystemWebview({
    super.key,
    required this.options,
    required this.messageHandler,
    this.onChannelCreated,
    this.onOpenUrl,
  });

  @override
  State<SystemWebview> createState() => _SystemWebviewState();
}

class _SystemWebviewState extends State<SystemWebview> with AutomaticKeepAliveClientMixin {
  MethodChannel? _channel;
  int? _platformViewId;
  bool _isDisposed = false;
  late WebViewOptions _currentOptions;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentOptions = widget.options;
    print('[NyaNyaOpenURL] SystemWebview.initState: this.hashCode=${identityHashCode(this)}, widget.onOpenUrl = ${widget.onOpenUrl}');
  }

  @override
  void didUpdateWidget(SystemWebview oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[NyaNyaOpenURL] SystemWebview.didUpdateWidget: this.hashCode=${identityHashCode(this)}');
    if (widget.options != oldWidget.options) {
      setState(() {
        _currentOptions = widget.options;
      });
    }
    // 不再需要跟踪 _onOpenUrl，直接用 widget.onOpenUrl
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin requires this!
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    print('[NyaNyaOpenURL] SystemWebview.build: this.hashCode=${identityHashCode(this)}');
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        viewType: 'systemWebView',
        surfaceFactory: (BuildContext context, PlatformViewController controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          final controller = PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: 'systemWebView',
            layoutDirection: TextDirection.ltr,
            creationParams: <String, dynamic>{
              'url': _currentOptions.initialUrl,
              'serverPort': _currentOptions.serverPort,
              'enableJavascript': _currentOptions.enableJavascript,
              'enableMixedContent': _currentOptions.enableMixedContent,
            },
            creationParamsCodec: const StandardMessageCodec(),
          );

          controller.addOnPlatformViewCreatedListener((int id) {
            _platformViewId = id;
            _channel = MethodChannel('club.aiiko.system_view_$id');
            _channel!.setMethodCallHandler(_handleMethodCall);

            widget.onChannelCreated?.call(_channel!);

            loadUrl(_currentOptions.initialUrl);
            params.onPlatformViewCreated(id);
          });

          controller.create();
          return controller;
        },
      );
    }

    return const Center(
      child: Text('SystemWebview is only supported on Android'),
    );
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('[NyaNyaOpenURL] ========== SystemWebview._handleMethodCall START ==========');
    print('[NyaNyaOpenURL] SystemWebview._handleMethodCall: received method=${call.method}, arguments=${call.arguments}');
    print('[NyaNyaOpenURL] SystemWebview._handleMethodCall: widget.onOpenUrl is null? ${widget.onOpenUrl == null}');
    print('[NyaNyaOpenURL] SystemWebview._handleMethodCall: _currentOptions.newTabBehavior = ${_currentOptions.newTabBehavior}');
    try {
      switch (call.method) {
        case 'testCommunication':
          print('[NyaNyaOpenURL] SystemWebview: testCommunication received from native!');
          return {'status': 'ok', 'message': 'Hello from Flutter SystemWebview!', 'time': DateTime.now().millisecondsSinceEpoch};
        case 'onWebMessage':
          final String message = call.arguments as String;
          widget.messageHandler(message);
          return {'status': 'ok'};
        case 'onOpenUrl':
          print('[NyaNyaOpenURL] ========== SystemWebview onOpenUrl RECEIVED ==========');
          final urlFromArgs = call.arguments['url'];
          final targetFromArgs = call.arguments['target'];
          print('[NyaNyaOpenURL] SystemWebview onOpenUrl raw args: url=$urlFromArgs (${urlFromArgs.runtimeType}), target=$targetFromArgs (${targetFromArgs.runtimeType})');
          
          final String url = urlFromArgs as String? ?? '';
          final String? target = targetFromArgs as String?;
          
          print('[NyaNyaOpenURL] SystemWebview: onOpenUrl parsed, url=$url, target=$target');
          print('[NyaNyaOpenURL] SystemWebview: _currentOptions.newTabBehavior = ${_currentOptions.newTabBehavior}');
          print('[NyaNyaOpenURL] SystemWebview: widget.onOpenUrl != null = ${widget.onOpenUrl != null}');
          
          if (_currentOptions.newTabBehavior == NewTabBehavior.delegate) {
            print('[NyaNyaOpenURL] SystemWebview: newTabBehavior is delegate');
            if (widget.onOpenUrl != null) {
              print('[NyaNyaOpenURL] SystemWebview: Calling user onOpenUrl callback NOW!');
              widget.onOpenUrl!(url, target);
              print('[NyaNyaOpenURL] SystemWebview: user onOpenUrl callback called!');
            } else {
              print('[NyaNyaOpenURL] SystemWebview: WARNING - widget.onOpenUrl is NULL!');
            }
          } else {
            print('[NyaNyaOpenURL] SystemWebview: newTabBehavior is NOT delegate, loading url in current webview');
            loadUrl(url);
          }
          print('[NyaNyaOpenURL] ========== SystemWebview onOpenUrl HANDLED ==========');
          return {'status': 'ok', 'url': url, 'target': target};
        case 'onPageStart':
          return {'status': 'ok'};
        case 'onPageStop':
          return {'status': 'ok'};
        default:
          print('[NyaNyaOpenURL] SystemWebview: Unknown method called: ${call.method}');
          return {'status': 'error', 'error': 'Unknown method'};
      }
    } catch (e, stack) {
      print('[NyaNyaOpenURL] ========== ERROR IN SystemWebview _handleMethodCall ==========');
      print('[NyaNyaOpenURL] SystemWebview: Error in _handleMethodCall: $e');
      print('[NyaNyaOpenURL] SystemWebview: Stack trace: $stack');
      print('[NyaNyaOpenURL] =================================================');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<void> loadUrl(String url) async {
    if (_channel == null) {
      await _waitForChannel();
    }
    await _channel?.invokeMethod('loadUrl', {'url': url});
  }

  Future<void> reload() async {
    await _channel?.invokeMethod('reload');
  }

  Future<void> goBack() async {
    await _channel?.invokeMethod('goBack');
  }

  Future<void> goForward() async {
    await _channel?.invokeMethod('goForward');
  }

  Future<bool> canGoBack() async {
    return await _channel?.invokeMethod<bool>('canGoBack') ?? false;
  }

  Future<bool> canGoForward() async {
    return await _channel?.invokeMethod<bool>('canGoForward') ?? false;
  }

  Future<void> evaluateJavascript(String script) async {
    await _channel?.invokeMethod('evaluateJavascript', {'script': script});
  }

  Future<void> postMessage(String message) async {
    if (_channel == null) {
      await _waitForChannel();
    }
    await _channel?.invokeMethod('postMessage', {'message': message});
  }

  Future<void> openInBrowser(String url) async {
    await _channel?.invokeMethod('openInBrowser', {'url': url});
  }

  Future<void> _waitForChannel() async {
    int attempts = 0;
    const maxAttempts = 50;
    while (_channel == null && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  Future<bool> checkWebViewReady() async {
    if (_channel == null) return false;
    try {
      return await _channel?.invokeMethod<bool>('checkWebViewReady') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkSessionsHealth() async {
    if (_channel == null) return false;
    try {
      return await _channel?.invokeMethod<bool>('checkSessionsHealth') ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    print('[NyaNyaOpenURL] SystemWebview.dispose CALLED! this.hashCode=${identityHashCode(this)}, _channel=$_channel');
    _isDisposed = true;
    _channel?.setMethodCallHandler(null);
    _channel?.invokeMethod('dispose');
    _channel = null;
    super.dispose();
  }
}