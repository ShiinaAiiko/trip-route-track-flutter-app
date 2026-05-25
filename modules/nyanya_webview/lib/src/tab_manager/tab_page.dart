import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../webview_options.dart';
import '../webview_controller.dart';
import 'tab_manager.dart';

// 库内部的 i18n 实现
class _TabPageI18n {
  static final Map<String, Map<String, String>> _translations = {
    'zh-CN': {
      'share': '分享',
      'url_copied': '已复制URL',
      'copy_failed': '复制失败',
      'loading': '加载中...',
    },
    'zh-TW': {
      'share': '分享',
      'url_copied': '已複製URL',
      'copy_failed': '複製失敗',
      'loading': '載入中...',
    },
    'en-US': {
      'share': 'Share',
      'url_copied': 'URL copied',
      'copy_failed': 'Copy failed',
      'loading': 'Loading...',
    },
  };

  static String t(String key, {String? language}) {
    // 使用传入的语言，默认为 en-US
    final targetLanguage = language ?? 'en-US';

    // 查找匹配的语言
    if (_translations.containsKey(targetLanguage)) {
      return _translations[targetLanguage]![key] ?? key;
    }

    // 只匹配语言代码
    final languageOnly = targetLanguage.split('-').first;
    for (final localeKey in _translations.keys) {
      if (localeKey.startsWith('$languageOnly-')) {
        return _translations[localeKey]![key] ?? key;
      }
    }

    // 默认返回英文
    return _translations['en-US']![key] ?? key;
  }
}

class TabPage extends StatefulWidget {
  final String tabId;
  final String url;
  final WebViewOptions options;
  final void Function(String tabId, String title)? onTitleChanged;
  final void Function(String tabId, String url)? onUrlChanged;
  final OpenUrlHandler? onOpenUrl;
  final VoidCallback? onClose;
  final String? language;
  final void Function(String tabId, String message)? onMessage;
  final void Function(String tabId, dynamic channel)? onChannelCreated;
  final void Function(String tabId)? onTabClosed;

  const TabPage({
    super.key,
    required this.tabId,
    required this.url,
    required this.options,
    this.onTitleChanged,
    this.onUrlChanged,
    this.onOpenUrl,
    this.onClose,
    this.language,
    this.onMessage,
    this.onChannelCreated,
    this.onTabClosed,
  });

  @override
  State<TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<TabPage> {
  late WebViewController _controller;
  String _currentUrl = '';
  String _currentTitle = '';
  bool _isLoading = true;

  // 导航栏状态
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _initController();
    // 初始化导航状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNavigationState();
    });
  }

  void _initController() {
    _controller = WebViewController(widget.options, sessionId: widget.tabId);
    _controller.setOnOpenUrlHandler((url, target) {
      widget.onOpenUrl?.call(url, target);
    });
    _controller.setOnCloseHandler(() {
      widget.onClose?.call();
    });

    _controller.onMessage = (sessionId, message) {
      widget.onMessage?.call(widget.tabId, message);
    };

    _controller.onChannelCreated = (sessionId, channel) {
      print('[TabPage] Channel created for session: $sessionId');
      widget.onChannelCreated?.call(sessionId, channel);
    };

    _controller.on('onTitleChange', (message) {
      final payload = message['payload'] as Map<String, dynamic>?;
      final title = payload?['title'] as String? ?? '';
      if (mounted) {
        setState(() {
          _currentTitle = title;
        });
        widget.onTitleChanged?.call(widget.tabId, title);
        _updateNavigationState();
      }
    });

    _controller.on('onLocationChange', (message) {
      final payload = message['payload'] as Map<String, dynamic>?;
      final url = payload?['url'] as String? ?? '';
      print('onLocationChange: $url, mounted: $mounted');
      if (mounted && url != "about:blank") {
        setState(() {
          _currentUrl = url;
        });
        widget.onUrlChanged?.call(widget.tabId, url);
        // 更新导航状态
        _updateNavigationState();
      }
    });

    _controller.on('onPageStart', (message) {
      final payload = message['payload'] as Map<String, dynamic>?;
      final url = payload?['url'] as String? ?? '';
      if (mounted) {
        setState(() {
          _currentUrl = url;
        });
        widget.onUrlChanged?.call(widget.tabId, url);
      }
    });
  }

  @override
  void dispose() {
    widget.onTabClosed?.call(widget.tabId);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          _buildDropdownMenu(),
        ],
      ),
      body: _buildWebView(),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _currentTitle.isNotEmpty
              ? _currentTitle
              : _TabPageI18n.t('loading', language: widget.language),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          _currentUrl.isNotEmpty ? _getDisplayUrl(_currentUrl) : '',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDropdownMenu() {
    return PopupMenuButton<String>(
      key: ValueKey('menu-$_canGoBack-$_canGoForward'),
      icon: const Icon(Icons.more_vert, size: 24),
      onSelected: (value) {
        switch (value) {
          case 'back':
            _handleGoBack();
            break;
          case 'forward':
            _handleGoForward();
            break;
          case 'refresh':
            _handleRefresh();
            break;
          case 'share':
            _handleShare();
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        // 横向排列的图标按钮（返回、前进、刷新）
        PopupMenuItem<String>(
          value: 'placeholder1',
          enabled: true,
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 返回按钮
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: _canGoBack
                    ? () {
                        Navigator.pop(context);
                        _handleGoBack();
                      }
                    : null,
                disabledColor: Colors.grey,
              ),
              // 前进按钮
              IconButton(
                icon: const Icon(Icons.arrow_forward, size: 20),
                onPressed: _canGoForward
                    ? () {
                        Navigator.pop(context);
                        _handleGoForward();
                      }
                    : null,
                disabledColor: Colors.grey,
              ),
              // 刷新按钮
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: Colors.white,
                onPressed: () {
                  Navigator.pop(context);
                  _handleRefresh();
                },
              ),
            ],
          ),
        ),
        // 分割线
        const PopupMenuDivider(),
        // 分享按钮（使用 i18n）
        PopupMenuItem<String>(
          value: 'share',
          onTap: () {
            Future.delayed(Duration.zero, () {
              _handleShare();
            });
          },
          child: Row(
            children: [
              const Icon(Icons.share, size: 20),
              const SizedBox(width: 8),
              Text(_TabPageI18n.t('share', language: widget.language)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleGoBack() async {
    await _controller.goBack();
    _updateNavigationState();
  }

  Future<void> _handleGoForward() async {
    await _controller.goForward();
    _updateNavigationState();
  }

  Future<void> _handleRefresh() async {
    print('[NyaNyaOpenURL] _handleRefresh');
    await _controller.reload();
  }

  Future<void> _handleShare() async {
    final urlToShare = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
    if (urlToShare.isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: urlToShare));
      final message = _TabPageI18n.t('url_copied', language: widget.language);
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: Text(message),
            alignment: Alignment.bottomCenter,
            offset: const Offset(0, 50),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      final message = _TabPageI18n.t('copy_failed', language: widget.language);
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: Text(message),
            alignment: Alignment.bottomCenter,
            offset: const Offset(0, 50),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _updateNavigationState() async {
    print(
        '[DEBUG] _updateNavigationState called, _controller: $_controller, mounted: $mounted');
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();

    print('onLocationChange updateNavigationState: $canGoBack, $canGoForward');
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Widget _buildWebView() {
    return Column(
      children: [
        Expanded(
          child: _controller.build(context),
        ),
      ],
    );
  }

  String _getDisplayUrl(String url) {
    String processedUrl = url;
    final isInternalWebsite = url.contains('localhost:13218') ||
        url.contains('localhost:13219') ||
        url.contains('localhost:13220') ||
        url.contains('127.0.0.1:13218') ||
        url.contains('127.0.0.1:13219') ||
        url.contains('127.0.0.1:13220');

    if (isInternalWebsite) {
      processedUrl = url.replaceAll(
        RegExp(r'https?://(localhost|127\.0\.0\.1):(13218|13219|13220)'),
        'https://trip.aiiko.club',
      );
    }
    if (processedUrl.endsWith('/')) {
      processedUrl = processedUrl.substring(0, processedUrl.length - 1);
    }
    if (processedUrl.startsWith('https://')) {
      return processedUrl.substring(8);
    }
    if (processedUrl.startsWith('http://')) {
      return processedUrl.substring(7);
    }
    return processedUrl;
  }
}

class TabPageRoute<T> extends MaterialPageRoute<T> {
  final String tabId;
  final String url;

  TabPageRoute({
    required this.tabId,
    required this.url,
    required WidgetBuilder builder,
  }) : super(builder: builder);

  @override
  Widget buildContent(BuildContext context) {
    return builder(context);
  }
}

void navigateToTab({
  required BuildContext context,
  required TabManager tabManager,
  required String tabId,
  required String url,
}) {
  Navigator.of(context).push(
    TabPageRoute(
      tabId: tabId,
      url: url,
      builder: (context) => TabPage(
        tabId: tabId,
        url: url,
        options: tabManager.buildOptions(url),
        onOpenUrl: (newUrl, target) {
          if (target == '_blank' || target == '_self') {
            tabManager.openTab(newUrl);
          } else {
            tabManager.openTab(newUrl);
          }
          Navigator.of(context).pop();
        },
        onClose: () {
          tabManager.closeTab(tabId);
          Navigator.of(context).pop();
        },
      ),
    ),
  );
}
