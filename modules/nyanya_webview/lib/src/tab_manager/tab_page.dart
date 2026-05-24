import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../webview_options.dart';
import '../webview_controller.dart';
import 'tab_manager.dart';

class TabPage extends StatefulWidget {
  final String tabId;
  final String url;
  final WebViewOptions options;
  final void Function(String tabId, String title)? onTitleChanged;
  final void Function(String tabId, String url)? onUrlChanged;
  final OpenUrlHandler? onOpenUrl;
  final VoidCallback? onClose;

  const TabPage({
    super.key,
    required this.tabId,
    required this.url,
    required this.options,
    this.onTitleChanged,
    this.onUrlChanged,
    this.onOpenUrl,
    this.onClose,
  });

  @override
  State<TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<TabPage> {
  late WebViewController _controller;
  String _currentUrl = '';
  String _currentTitle = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _initController();
  }

  void _initController() {
    _controller = WebViewController(widget.options);
    _controller.setOnOpenUrlHandler((url, target) {
      widget.onOpenUrl?.call(url, target);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleMessage(String message) {
    try {
      if (message.contains('"type"')) {
        final typeStart = message.indexOf('"type":"') + 8;
        final typeEnd = message.indexOf('"', typeStart);
        final type = message.substring(typeStart, typeEnd);

        if (type == 'onTitleChange') {
          final titleStart = message.indexOf('"title":"') + 9;
          final titleEnd = message.indexOf('"', titleStart);
          final title = message.substring(titleStart, titleEnd);
          if (title.isNotEmpty && mounted) {
            setState(() {
              _currentTitle = title;
            });
            widget.onTitleChanged?.call(widget.tabId, title);
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: 0,
        children: [
          _buildWebView(),
        ],
      ),
    );
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