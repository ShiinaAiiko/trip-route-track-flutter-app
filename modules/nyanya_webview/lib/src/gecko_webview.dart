import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'system_webview.dart';
import 'webview_interface.dart';
import 'webview_options.dart';

typedef NyaNyaMessageHandler = void Function(String message);
typedef NyaNyaChannelCreatedCallback = void Function(MethodChannel channel);

class NyaNyaWebview extends StatefulWidget {
  final WebViewOptions options;
  final NyaNyaMessageHandler messageHandler;
  final GlobalKey<_NyaNyaWebviewState>? controllerKey;
  final NyaNyaChannelCreatedCallback? onChannelCreated;

  const NyaNyaWebview({
    super.key,
    required this.options,
    required this.messageHandler,
    this.controllerKey,
    this.onChannelCreated,
  });

  @override
  State<NyaNyaWebview> createState() => _NyaNyaWebviewState();
}

class _NyaNyaWebviewState extends State<NyaNyaWebview> {
  MethodChannel? _channel;
  int? _platformViewId;
  bool _isDisposed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // 根据 engine 参数选择不同的实现
      switch (widget.options.engine) {
        case WebViewEngine.gecko:
          return GeckoWebview(
            options: widget.options,
            messageHandler: widget.messageHandler,
            onChannelCreated: (channel) {
              _channel = channel;
              widget.onChannelCreated?.call(channel);
            },
          );
        case WebViewEngine.system:
          return SystemWebview(
            options: widget.options,
            messageHandler: widget.messageHandler,
            onChannelCreated: (channel) {
              _channel = channel;
              widget.onChannelCreated?.call(channel);
            },
          );
      }
    }

    return const Center(
      child: Text('NyaNyaWebview is only supported on Android'),
    );
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

  Future<void> shutdownGeckoRuntime() async {
    if (widget.options.engine == WebViewEngine.gecko) {
      await _channel?.invokeMethod('shutdownGeckoRuntime');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _channel?.invokeMethod('dispose');
    _channel = null;
    super.dispose();
  }
}

// GeckoWebview 内部实现
class GeckoWebview extends StatefulWidget {
  final WebViewOptions options;
  final NyaNyaMessageHandler messageHandler;
  final NyaNyaChannelCreatedCallback? onChannelCreated;

  const GeckoWebview({
    super.key,
    required this.options,
    required this.messageHandler,
    this.onChannelCreated,
  });

  @override
  State<GeckoWebview> createState() => _GeckoWebviewState();
}

class _GeckoWebviewState extends State<GeckoWebview> {
  MethodChannel? _channel;
  int? _platformViewId;
  bool _isDisposed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    return PlatformViewLink(
      viewType: 'geckoView',
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
          viewType: 'geckoView',
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{
            'url': widget.options.initialUrl,
            'serverPort': widget.options.serverPort,
            'enableJavascript': widget.options.enableJavascript,
            'enableMixedContent': widget.options.enableMixedContent,
          },
          creationParamsCodec: const StandardMessageCodec(),
        );

        controller.addOnPlatformViewCreatedListener((int id) {
          _platformViewId = id;
          _channel = MethodChannel('club.aiiko.gecko_view_$id');
          _channel!.setMethodCallHandler(_handleMethodCall);

          widget.onChannelCreated?.call(_channel!);

          _loadUrl(widget.options.initialUrl);
          params.onPlatformViewCreated(id);
        });

        controller.create();
        return controller;
      },
    );
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWebMessage':
        final String message = call.arguments as String;
        widget.messageHandler(message);
        break;
      case 'onPageStart':
        break;
      case 'onPageStop':
        break;
    }
  }

  Future<void> _loadUrl(String url) async {
    await _channel?.invokeMethod('loadUrl', {'url': url});
  }
}

class NyaNyaWebviewController {
  final GlobalKey<_NyaNyaWebviewState> _key;

  NyaNyaWebviewController() : _key = GlobalKey<_NyaNyaWebviewState>();

  GlobalKey<_NyaNyaWebviewState> get key => _key;

  Future<void> loadUrl(String url) => _key.currentState?.loadUrl(url) ?? Future.value();
  Future<void> reload() => _key.currentState?.reload() ?? Future.value();
  Future<void> goBack() => _key.currentState?.goBack() ?? Future.value();
  Future<void> goForward() => _key.currentState?.goForward() ?? Future.value();
  Future<bool> canGoBack() => _key.currentState?.canGoBack() ?? Future.value(false);
  Future<bool> canGoForward() => _key.currentState?.canGoForward() ?? Future.value(false);
  Future<void> evaluateJavascript(String script) => _key.currentState?.evaluateJavascript(script) ?? Future.value();
  Future<void> postMessage(String message) => _key.currentState?.postMessage(message) ?? Future.value();
  Future<bool> checkWebViewReady() => _key.currentState?.checkWebViewReady() ?? Future.value(false);
  Future<bool> checkSessionsHealth() => _key.currentState?.checkSessionsHealth() ?? Future.value(false);
  Future<void> shutdownGeckoRuntime() => _key.currentState?.shutdownGeckoRuntime() ?? Future.value();
}