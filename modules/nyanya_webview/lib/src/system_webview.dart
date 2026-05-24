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

  const SystemWebview({
    super.key,
    required this.options,
    required this.messageHandler,
    this.onChannelCreated,
  });

  @override
  State<SystemWebview> createState() => _SystemWebviewState();
}

class _SystemWebviewState extends State<SystemWebview> {
  MethodChannel? _channel;
  int? _platformViewId;
  bool _isDisposed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

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
              'url': widget.options.initialUrl,
              'serverPort': widget.options.serverPort,
              'enableJavascript': widget.options.enableJavascript,
              'enableMixedContent': widget.options.enableMixedContent,
            },
            creationParamsCodec: const StandardMessageCodec(),
          );

          controller.addOnPlatformViewCreatedListener((int id) {
            _platformViewId = id;
            _channel = MethodChannel('club.aiiko.system_view_$id');
            _channel!.setMethodCallHandler(_handleMethodCall);

            // 通知外部 channel 已创建
            widget.onChannelCreated?.call(_channel!);

            loadUrl(widget.options.initialUrl);
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

  @override
  void dispose() {
    _isDisposed = true;
    _channel?.invokeMethod('dispose');
    _channel = null;
    super.dispose();
  }
}