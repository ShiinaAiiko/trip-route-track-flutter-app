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
typedef NyaNyaCloseCallback = void Function();

class NyaNyaWebview extends StatefulWidget {
  final WebViewOptions options;
  final NyaNyaMessageHandler messageHandler;
  final GlobalKey<_NyaNyaWebviewState>? controllerKey;
  final NyaNyaChannelCreatedCallback? onChannelCreated;
  final OpenUrlHandler? onOpenUrl;
  final NyaNyaCloseCallback? onClose;

  const NyaNyaWebview({
    super.key,
    required this.options,
    required this.messageHandler,
    this.controllerKey,
    this.onChannelCreated,
    this.onOpenUrl,
    this.onClose,
  });

  @override
  State<NyaNyaWebview> createState() => _NyaNyaWebviewState();
}

class _NyaNyaWebviewState extends State<NyaNyaWebview>
    with AutomaticKeepAliveClientMixin {
  MethodChannel? _channel;
  int? _platformViewId;
  bool _isDisposed = false;
  // 固定 GeckoWebview 和 SystemWebview 的 key，防止它们被重新创建
  final _geckoKey = GlobalKey<State<GeckoWebview>>();
  final _systemKey = GlobalKey<State<SystemWebview>>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print(
        '[NyaNyaOpenURL-Flutter] NyaNyaWebview.initState called! this.hashCode=${identityHashCode(this)}');
  }

  @override
  void didUpdateWidget(NyaNyaWebview oldWidget) {
    super.didUpdateWidget(oldWidget);
    print(
        '[NyaNyaOpenURL-Flutter] NyaNyaWebview.didUpdateWidget called! this.hashCode=${identityHashCode(this)}');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin requires this!
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    print(
        '[NyaNyaOpenURL-Flutter] NyaNyaWebview.build: this.hashCode=${identityHashCode(this)}, engine=${widget.options.engine}, onOpenUrl callback exists: ${widget.onOpenUrl != null}');

    if (defaultTargetPlatform == TargetPlatform.android) {
      switch (widget.options.engine) {
        case WebViewEngine.gecko:
          return GeckoWebview(
            key: _geckoKey,
            options: widget.options,
            messageHandler: widget.messageHandler,
            onChannelCreated: (channel) {
              _channel = channel;
              widget.onChannelCreated?.call(channel);
            },
            onOpenUrl: widget.onOpenUrl,
            onClose: widget.onClose,
          );
        case WebViewEngine.system:
          return SystemWebview(
            key: _systemKey,
            options: widget.options,
            messageHandler: widget.messageHandler,
            onChannelCreated: (channel) {
              _channel = channel;
              widget.onChannelCreated?.call(channel);
            },
            onOpenUrl: widget.onOpenUrl,
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
    print(
        '[NyaNyaOpenURL-Flutter] NyaNyaWebview.reload _handleRefresh CALLED! this.hashCode=${identityHashCode(this)}, _channel=$_channel');
    if (_channel == null) {
      await _waitForChannel();
    }
    print('[NyaNyaOpenURL-Flutter] NyaNyaWebview.reload: _channel=$_channel');
    await _channel?.invokeMethod('reload');
  }

  Future<void> goBack() async {
    if (_channel == null) {
      await _waitForChannel();
    }
    print('[NyaNyaOpenURL-Flutter] NyaNyaWebview.goBack: _channel=$_channel');
    await _channel?.invokeMethod('goBack');
  }

  Future<void> goForward() async {
    if (_channel == null) {
      await _waitForChannel();
    }
    print(
        '[NyaNyaOpenURL-Flutter] NyaNyaWebview.goForward: _channel=$_channel');
    await _channel?.invokeMethod('goForward');
  }

  Future<bool> canGoBack() async {
    print(
        '[NyaNyaOpenURL-Flutter] updateNavigationState NyaNyaWebview.canGoBack CALLED! this.hashCode=${identityHashCode(this)}, _channel=$_channel');
    return await _channel?.invokeMethod<bool>('canGoBack') ?? false;
  }

  Future<bool> canGoForward() async {
    print(
        '[NyaNyaOpenURL-Flutter] updateNavigationState NyaNyaWebview.canGoForward CALLED! this.hashCode=${identityHashCode(this)}, _channel=$_channel');
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
    if (_channel == null) {
      await _waitForChannel();
    }
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

  Future<void> shutdownGeckoRuntime() async {
    if (widget.options.engine == WebViewEngine.gecko) {
      await _channel?.invokeMethod('shutdownGeckoRuntime');
    }
  }

  @override
  void dispose() {
    print(
        '[NyaNyaOpenURL-Flutter] NyaNyaWebview.dispose CALLED! this.hashCode=${identityHashCode(this)}, _channel=$_channel');
    _isDisposed = true;
    _channel?.setMethodCallHandler(null);
    _channel?.invokeMethod('dispose');
    _channel = null;
    super.dispose();
  }
}

class GeckoWebview extends StatefulWidget {
  final WebViewOptions options;
  final NyaNyaMessageHandler messageHandler;
  final NyaNyaChannelCreatedCallback? onChannelCreated;
  final OpenUrlHandler? onOpenUrl;
  final NyaNyaCloseCallback? onClose;

  const GeckoWebview({
    super.key,
    required this.options,
    required this.messageHandler,
    this.onChannelCreated,
    this.onOpenUrl,
    this.onClose,
  });

  @override
  State<GeckoWebview> createState() => _GeckoWebviewState();
}

// 移除静态变量和静态方法，改为直接在 state 中处理

class _GeckoWebviewState extends State<GeckoWebview>
    with AutomaticKeepAliveClientMixin {
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
    print(
        '[NyaNyaOpenURL-Flutter] GeckoWebview.initState: this.hashCode=${identityHashCode(this)}, widget.onOpenUrl = ${widget.onOpenUrl}');
  }

  @override
  void didUpdateWidget(GeckoWebview oldWidget) {
    super.didUpdateWidget(oldWidget);
    print(
        '[NyaNyaOpenURL-Flutter] GeckoWebview.didUpdateWidget: this.hashCode=${identityHashCode(this)}');
    if (widget.options != oldWidget.options) {
      setState(() {
        _currentOptions = widget.options;
      });
    }
  }

  @override
  void dispose() {
    print(
        '[NyaNyaOpenURL-Flutter] GeckoWebview.dispose CALLED! this.hashCode=${identityHashCode(this)}, _channel=$_channel');
    _isDisposed = true;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin requires this!
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        viewType: 'geckoView',
        surfaceFactory:
            (BuildContext context, PlatformViewController controller) {
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
              'url': _currentOptions.initialUrl,
              'serverPort': _currentOptions.serverPort,
              'enableJavascript': _currentOptions.enableJavascript,
              'enableMixedContent': _currentOptions.enableMixedContent,
            },
            creationParamsCodec: const StandardMessageCodec(),
          );

          controller.addOnPlatformViewCreatedListener((int id) {
            print(
                '[NyaNyaOpenURL-Flutter] GeckoWebview: Platform view created, id=$id, this.hashCode=${identityHashCode(this)}');
            _platformViewId = id;
            final channelName = 'club.aiiko.gecko_view_$id';
            _channel = MethodChannel(channelName);
            print(
                '[NyaNyaOpenURL-Flutter] GeckoWebview: Created MethodChannel, name=$channelName, channel.hashCode=${identityHashCode(_channel!)}');
            _channel!.setMethodCallHandler(_actualHandleMethodCall);
            print(
                '[NyaNyaOpenURL-Flutter] GeckoWebview: MethodCallHandler set (instance method)');

            widget.onChannelCreated?.call(_channel!);

            // 立即向原生端发送测试消息
            print(
                '[NyaNyaOpenURL-Flutter] GeckoWebview: Sending testCommunication to native NOW');
            _channel!.invokeMethod('testCommunication').then((result) {
              print(
                  '[NyaNyaOpenURL-Flutter] GeckoWebview: testCommunication response received: $result');
            }).catchError((error) {
              print(
                  '[NyaNyaOpenURL-Flutter] GeckoWebview: testCommunication error: $error');
            });

            loadUrl(_currentOptions.initialUrl);
            params.onPlatformViewCreated(id);
          });

          controller.create();
          return controller;
        },
      );
    }

    return const Center(
      child: Text('GeckoWebview is only supported on Android'),
    );
  }

  Future<dynamic> _actualHandleMethodCall(MethodCall call) async {
    // This is a PROMINENT log that should always show when this function is called
    // print(
    //     '[NyaNyaOpenURL-Flutter] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
    // print(
    //     '[NyaNyaOpenURL-Flutter] >>> GeckoWebview._actualHandleMethodCall START >>>');
    // print(
    //     '[NyaNyaOpenURL-Flutter] >>> received method=${call.method}, arguments=${call.arguments}');
    // print(
    //     '[NyaNyaOpenURL-Flutter] GeckoWebview._actualHandleMethodCall: widget.onOpenUrl is null? ${widget.onOpenUrl == null}');
    // print(
    //     '[NyaNyaOpenURL-Flutter] GeckoWebview._actualHandleMethodCall: _currentOptions.newTabBehavior = ${_currentOptions.newTabBehavior}');
    // print(
    //     '[NyaNyaOpenURL-Flutter] GeckoWebview._actualHandleMethodCall: NewTabBehavior.delegate = ${NewTabBehavior.delegate}');
    // print(
    //     '[NyaNyaOpenURL-Flutter] GeckoWebview._actualHandleMethodCall: condition check = ${_currentOptions.newTabBehavior == NewTabBehavior.delegate}');
    try {
      switch (call.method) {
        case 'testCommunication':
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: testCommunication received from native!');
          return {
            'status': 'ok',
            'message': 'Hello from Flutter GeckoWebview!',
            'time': DateTime.now().millisecondsSinceEpoch
          };
        case 'testNativeToFlutter':
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: testNativeToFlutter received from native! args=${call.arguments}');
          return {'status': 'ok', 'received': true};
        case 'onWebMessage':
          final String message = call.arguments as String;
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: onWebMessage received, message=$message');
          widget.messageHandler(message);
          return {'status': 'ok'};
        case 'onTitleChange':
          final titleFromArgs = call.arguments['title'];
          final String title = titleFromArgs as String? ?? '';
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: onTitleChange received, title=$title');
          widget.messageHandler(
              '{"type":"onTitleChange","payload":{"title":"$title"}}');
          return {'status': 'ok'};
        case 'onLocationChange':
          final urlFromArgs = call.arguments['url'];
          final String url = urlFromArgs as String? ?? '';
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: onLocationChange received, url=$url');
          widget.messageHandler(
              '{"type":"onLocationChange","payload":{"url":"$url"}}');
          return {'status': 'ok'};
        case 'onPageStart':
          final urlFromArgs = call.arguments['url'];
          final String url = urlFromArgs as String? ?? '';
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: onPageStart received, url=$url');
          widget.messageHandler(
              '{"type":"onPageStart","payload":{"url":"$url"}}');
          return {'status': 'ok'};
        case 'onPageStop':
          final successFromArgs = call.arguments['success'];
          final bool success = successFromArgs as bool? ?? false;
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: onPageStop received, success=$success');
          widget.messageHandler(
              '{"type":"onPageStop","payload":{"success":$success}}');
          return {'status': 'ok'};
        case 'onOpenUrl':
          print(
              '[NyaNyaOpenURL-Flutter] ========== onOpenUrl RECEIVED ==========');
          final urlFromArgs = call.arguments['url'];
          final targetFromArgs = call.arguments['target'];
          print(
              '[NyaNyaOpenURL-Flutter] onOpenUrl raw args: url=$urlFromArgs (${urlFromArgs.runtimeType}), target=$targetFromArgs (${targetFromArgs.runtimeType})');

          final String url = urlFromArgs as String? ?? '';
          final String? target = targetFromArgs as String?;

          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: onOpenUrl parsed, url=$url, target=$target');
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: _currentOptions.newTabBehavior = ${_currentOptions.newTabBehavior}');
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: widget.onOpenUrl != null = ${widget.onOpenUrl != null}');

          if (_currentOptions.newTabBehavior == NewTabBehavior.delegate) {
            print(
                '[NyaNyaOpenURL-Flutter] GeckoWebview: newTabBehavior is delegate');
            if (widget.onOpenUrl != null) {
              print(
                  '[NyaNyaOpenURL-Flutter] GeckoWebview: Calling user onOpenUrl callback NOW!');
              widget.onOpenUrl!(url, target);
              print(
                  '[NyaNyaOpenURL-Flutter] GeckoWebview: user onOpenUrl callback called!');
            } else {
              print(
                  '[NyaNyaOpenURL-Flutter] GeckoWebview: WARNING - widget.onOpenUrl is NULL!');
            }
          } else {
            print(
                '[NyaNyaOpenURL-Flutter] GeckoWebview: newTabBehavior is NOT delegate, loading url in current webview');
            loadUrl(url);
          }
          print(
              '[NyaNyaOpenURL-Flutter] ========== onOpenUrl HANDLED ==========');
          return {'status': 'ok', 'url': url, 'target': target};
        case 'onRequestExitApp':
          // Native 端发送请求退出应用的消息
          // 这意味着 WebView 已经无法后退，需要关闭当前标签页
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: onRequestExitApp received, closing current tab');
          if (widget.onClose != null) {
            widget.onClose!();
            print(
                '[NyaNyaOpenURL-Flutter] GeckoWebview: onClose callback called');
          } else {
            print(
                '[NyaNyaOpenURL-Flutter] GeckoWebview: WARNING - onClose is null, cannot close tab');
          }
          return {'status': 'ok'};
        default:
          print(
              '[NyaNyaOpenURL-Flutter] GeckoWebview: Unknown method called: ${call.method}');
          return {'status': 'error', 'error': 'Unknown method'};
      }
    } catch (e, stack) {
      print(
          '[NyaNyaOpenURL-Flutter] ========== ERROR IN _actualHandleMethodCall ==========');
      print(
          '[NyaNyaOpenURL-Flutter] GeckoWebview: Error in _actualHandleMethodCall: $e');
      print('[NyaNyaOpenURL-Flutter] GeckoWebview: Stack trace: $stack');
      print(
          '[NyaNyaOpenURL-Flutter] =================================================');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<void> loadUrl(String url) async {
    if (_channel == null) {
      int attempts = 0;
      const maxAttempts = 50;
      while (_channel == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }
    await _channel?.invokeMethod('loadUrl', {'url': url});
  }
}

class NyaNyaWebviewController {
  final GlobalKey<_NyaNyaWebviewState> _key;
  MethodChannel? _channel;

  NyaNyaWebviewController() : _key = GlobalKey<_NyaNyaWebviewState>();

  GlobalKey<_NyaNyaWebviewState> get key => _key;

  void setChannel(MethodChannel channel) {
    _channel = channel;
  }

  Future<void> loadUrl(String url) async {
    print(
        '[DEBUG] NyaNyaWebviewController.loadUrl() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      await _key.currentState?.loadUrl(url);
    } else if (_channel != null) {
      await _channel?.invokeMethod('loadUrl', {'url': url});
    }
  }

  Future<bool> canGoBack() async {
    print(
        '[DEBUG] NyaNyaWebviewController.canGoBack() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_channel != null) {
      return await _channel!.invokeMethod<bool>('canGoBack') ?? false;
    }
    return _key.currentState?.canGoBack() ?? Future.value(false);
  }

  Future<bool> canGoForward() async {
    print(
        '[DEBUG] NyaNyaWebviewController.canGoForward() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_channel != null) {
      return await _channel!.invokeMethod<bool>('canGoForward') ?? false;
    }
    return _key.currentState?.canGoForward() ?? Future.value(false);
  }

  Future<void> reload() async {
    print(
        '[DEBUG] NyaNyaWebviewController.reload() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      await _key.currentState?.reload();
    } else if (_channel != null) {
      await _channel?.invokeMethod('reload');
    }
  }

  Future<void> goBack() async {
    print(
        '[DEBUG] NyaNyaWebviewController.goBack() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      await _key.currentState?.goBack();
    } else if (_channel != null) {
      await _channel?.invokeMethod('goBack');
    }
  }

  Future<void> goForward() async {
    print(
        '[DEBUG] NyaNyaWebviewController.goForward() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      await _key.currentState?.goForward();
    } else if (_channel != null) {
      await _channel?.invokeMethod('goForward');
    }
  }

  Future<void> evaluateJavascript(String script) async {
    print(
        '[DEBUG] NyaNyaWebviewController.evaluateJavascript() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      await _key.currentState?.evaluateJavascript(script);
    } else if (_channel != null) {
      await _channel?.invokeMethod('evaluateJavascript', {'script': script});
    }
  }

  Future<void> postMessage(String message) async {
    print(
        '[DEBUG] NyaNyaWebviewController.postMessage() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      await _key.currentState?.postMessage(message);
    } else if (_channel != null) {
      await _channel?.invokeMethod('postMessage', {'message': message});
    }
  }

  Future<void> openInBrowser(String url) async {
    print(
        '[DEBUG] NyaNyaWebviewController.openInBrowser() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      await _key.currentState?.openInBrowser(url);
    } else if (_channel != null) {
      await _channel?.invokeMethod('openInBrowser', {'url': url});
    }
  }

  Future<bool> checkWebViewReady() async {
    print(
        '[DEBUG] NyaNyaWebviewController.checkWebViewReady() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      return await _key.currentState?.checkWebViewReady() ?? false;
    } else if (_channel != null) {
      return await _channel?.invokeMethod<bool>('checkWebViewReady') ?? false;
    }
    return false;
  }

  Future<bool> checkSessionsHealth() async {
    print(
        '[DEBUG] NyaNyaWebviewController.checkSessionsHealth() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      return await _key.currentState?.checkSessionsHealth() ?? false;
    } else if (_channel != null) {
      return await _channel?.invokeMethod<bool>('checkSessionsHealth') ?? false;
    }
    return false;
  }

  Future<void> shutdownGeckoRuntime() async {
    print(
        '[DEBUG] NyaNyaWebviewController.shutdownGeckoRuntime() called, _key.currentState: ${_key.currentState}, _channel: $_channel');
    if (_key.currentState != null) {
      await _key.currentState?.shutdownGeckoRuntime();
    } else if (_channel != null) {
      await _channel?.invokeMethod('shutdownGeckoRuntime');
    }
  }
}
