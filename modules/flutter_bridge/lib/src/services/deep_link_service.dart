import 'dart:async';
import 'package:flutter/services.dart';

typedef DeepLinkCallback = void Function(Map<String, dynamic> data);

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  DeepLinkCallback? _callback;
  StreamSubscription<String>? _linkSubscription;

  void init({DeepLinkCallback? callback}) {
    _callback = callback;
    _initPlatformChannel();
    _getInitialLink();
  }

  void _initPlatformChannel() {
    const MethodChannel channel = MethodChannel('deep_link');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final String url = call.arguments as String;
        _handleDeepLink(url);
      }
      return null;
    });
  }

  Future<void> _getInitialLink() async {
    try {
      const MethodChannel channel = MethodChannel('deep_link');
      final String? initialLink =
          await channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      print('[DeepLinkService] Error getting initial link: $e');
    }
  }

  void _handleDeepLink(String url) {
    print('[DeepLinkService] Received deep link: $url');
    
    try {
      final Uri uri = Uri.parse(url);
      
      final Map<String, dynamic> data = {
        'url': url,
        'scheme': uri.scheme,
        'host': uri.host,
        'path': uri.path,
        'queryParameters': uri.queryParameters,
        'fragment': uri.fragment,
      };
      
      _callback?.call(data);
    } catch (e) {
      print('[DeepLinkService] Error parsing deep link: $e');
    }
  }

  void setCallback(DeepLinkCallback callback) {
    _callback = callback;
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
