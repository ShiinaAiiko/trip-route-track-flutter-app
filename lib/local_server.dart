import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:flutter_bridge/src/bridge_controller.dart';

enum ServerStatus {
  stopped,
  starting,
  running,
  error,
}

class LocalServer {
  static LocalServer? _instance;
  HttpServer? _server;
  final int _port;
  List<String> _allAssets = [];
  ServerStatus _status = ServerStatus.stopped;
  String? _lastError;
  int _restartAttempts = 0;
  static const int _maxRestartAttempts = 3;
  static const int _devPort = 13218;
  static const int _prodPort = 13219;
  static const int _prodTmapPort = 13220;
  Completer<void>? _startCompleter;
  static void Function(String url, String title)? onUrlChange;

  LocalServer() : _port = kDebugMode ? _devPort : _prodPort;

  static LocalServer get instance {
    _instance ??= LocalServer();
    return _instance!;
  }

  String get url => 'http://localhost:$_port';
  // String get url => 'http://192.168.0.112:23202';
  int get port => _port;
  ServerStatus get status => _status;
  String? get lastError => _lastError;
  bool get isRunning => _status == ServerStatus.running;
  bool get serverExists => _server != null;

  Future<void> start({bool forceRestart = false}) async {
    print('[NYANYA-SERVER] start(): _status=$_status, _server=${_server == null ? "null" : "exists"}');
    
    // 如果已经运行且不需要强制重启，直接返回
    if (_status == ServerStatus.running && !forceRestart) {
      print('[NYANYA-SERVER]   already running, returning');
      return;
    }

    // 如果正在启动，等待完成
    if (_status == ServerStatus.starting && _startCompleter != null) {
      print('[NYANYA-SERVER]   starting in progress, waiting...');
      await _startCompleter!.future;
      return;
    }

    // 创建新的 completer
    _startCompleter = Completer<void>();
    _status = ServerStatus.starting;
    _lastError = null;

    print('[NYANYA-SERVER]   starting server...');

    try {
      // 加载所有 assets
      await _loadAllAssets();

      // 创建 handler
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler(_handleRequest);

      // 停止旧服务器（如果存在）
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
      }

      // 启动服务器
      print('[NYANYA-SERVER]   binding to port $_port...');
      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, _port);
      print('[NYANYA-SERVER]   bound, _server: ${_server == null ? "NULL" : "exists"}');
      
      _status = ServerStatus.running;
      _restartAttempts = 0;
      print('[NYANYA-SERVER] STARTED on http://localhost:$_port (assets: ${_allAssets.length})');
      _startCompleter?.complete();

    } catch (e) {
      _status = ServerStatus.error;
      _lastError = e.toString();
      _server = null;
      print('[NYANYA-SERVER] FAILED: $e');
      
      if (_restartAttempts < _maxRestartAttempts) {
        _restartAttempts++;
        print('[NYANYA-SERVER]   retry ${_restartAttempts}/$_maxRestartAttempts...');
        await Future.delayed(const Duration(seconds: 1));
        await start(forceRestart: true);
      } else {
        print('[NYANYA-SERVER]   max retries, giving up');
        _startCompleter?.completeError(e);
        rethrow;
      }
    }
  }

  Future<void> ensureRunning() async {
    if (_status != ServerStatus.running) {
      await start();
    }
  }

  bool checkServerHealth() {
    print('[NYANYA-SERVER] checkServerHealth: _server=${_server == null ? "NULL" : "exists"}, _status=$_status');
    
    if (_server == null) {
      print('[NYANYA-SERVER]   -> FALSE (server is null)');
      return false;
    }
    
    try {
      final isHealthy = _status == ServerStatus.running;
      print('[NYANYA-SERVER]   -> $isHealthy');
      return isHealthy;
    } catch (e) {
      print('[NYANYA-SERVER]   -> FALSE (exception: $e)');
      return false;
    }
  }

  Future<void> restart() async {
    print('Restarting local server...');
    _restartAttempts = 0;
    await start(forceRestart: true);
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
      _status = ServerStatus.stopped;
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

    // 处理 bridge 请求
    if (path == '__flutter_bridge__') {
      final message = request.url.queryParameters['message'];
      if (message != null) {
        try {
          print('Received bridge message: $message');
          final Map<String, dynamic> json = jsonDecode(message) as Map<String, dynamic>;
          if (json['type'] == 'url_change' && json['url'] != null) {
            final url = json['url'] as String;
            final title = json['title'] as String? ?? '';
            print('URL changed to: $url, title: $title');
            LocalServer.onUrlChange?.call(url, title);
          } else {
            BridgeController().handleWebMessage(message);
          }
        } catch (e) {
          print('Failed to handle bridge message: $e');
        }
      }
      return Response.ok('', headers: {
        'Content-Type': 'text/plain',
        'Access-Control-Allow-Origin': '*',
      });
    }

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