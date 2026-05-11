import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class LocalServer {
  static LocalServer? _instance;
  HttpServer? _server;
  int _port = 8080;
  List<String> _allAssets = [];

  static LocalServer get instance {
    _instance ??= LocalServer();
    return _instance!;
  }

  String get url => 'http://localhost:$_port';

  Future<void> start() async {
    if (_server != null) {
      print('Server already running on $_port');
      return;
    }

    print('Starting local server...');

    // 加载所有 assets
    await _loadAllAssets();

    // 创建 handler
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, _port);
      print('=== Local server started on http://localhost:$_port ===');
      print('Total assets available: ${_allAssets.length}');
    } catch (e) {
      print('Failed to start server: $e');
      rethrow;
    }
  }

  Future<void> _loadAllAssets() async {
    try {
      print('Loading AssetManifest.json...');
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestJson) as Map<String, dynamic>;

      _allAssets = manifest.keys
          .where((key) => key.startsWith('assets/out/'))
          .toList();

      print('Total assets in manifest: ${manifest.length}');
      print('Assets from assets/out/: ${_allAssets.length}');

      // 打印一些示例
      for (int i = 0; i < _allAssets.length && i < 10; i++) {
        print('  [${i+1}] ${_allAssets[i]}');
      }
      if (_allAssets.length > 10) {
        print('  ... and ${_allAssets.length - 10} more');
      }
    } catch (e) {
      print('Error loading assets: $e');
      print('Stack trace: $StackTrace');
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print('Local server stopped');
    }
  }

  Future<Response> _handleRequest(Request request) async {
    String path = request.url.path;

    // URL 解码路径
    try {
      path = Uri.decodeFull(path);
    } catch (e) {
      print('Failed to decode path $path: $e');
    }

    print('Request: $path');

    // 默认返回 index.html
    if (path.isEmpty) {
      path = 'index.html';
    }

    // 尝试多个路径
    List<String> tryPaths = [
      path,
      if (!path.endsWith('.html') && !path.contains('.')) '$path.html',
      if (!path.endsWith('/index.html')) '$path/index.html',
    ];

    // 查找对应的 asset
    String? assetKey;
    String? matchedPath;

    for (final tryPath in tryPaths) {
      // 精确匹配
      if (_allAssets.contains('assets/out/$tryPath')) {
        assetKey = 'assets/out/$tryPath';
        matchedPath = tryPath;
        break;
      }
      
      // 尝试模糊匹配（目录下的）
      for (final asset in _allAssets) {
        if (asset.endsWith('/$tryPath')) {
          assetKey = asset;
          matchedPath = tryPath;
          break;
        }
      }
      if (assetKey != null) break;
    }

    if (assetKey == null) {
      print('Asset not found for: $path (tried: ${tryPaths.join(', ')})');
      print('Available assets (first 20):');
      for (int i = 0; i < _allAssets.length && i < 20; i++) {
        print('  ${_allAssets[i]}');
      }
      return Response.notFound('Asset not found: $path');
    }

    print('Found asset: $assetKey (for request: $path)');

    try {
      final bytes = await rootBundle.load(assetKey);
      // 使用匹配到的路径来确定 content type
      final contentType = _getContentType(matchedPath!);

      return Response.ok(
        bytes.buffer.asUint8List(),
        headers: {
          'Content-Type': contentType,
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      print('Error loading asset $assetKey: $e');
      return Response.notFound('Error loading asset: $path');
    }
  }

  String _getContentType(String path) {
    if (path.endsWith('.html')) return 'text/html; charset=utf-8';
    if (path.endsWith('.css')) return 'text/css; charset=utf-8';
    if (path.endsWith('.js')) return 'application/javascript; charset=utf-8';
    if (path.endsWith('.json')) return 'application/json; charset=utf-8';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.gif')) return 'image/gif';
    if (path.endsWith('.svg')) return 'image/svg+xml';
    if (path.endsWith('.ico')) return 'image/x-icon';
    if (path.endsWith('.woff') || path.endsWith('.woff2')) return 'font/woff';
    if (path.endsWith('.ttf')) return 'font/ttf';
    if (path.endsWith('.wasm')) return 'application/wasm';
    return 'application/octet-stream';
  }
}
