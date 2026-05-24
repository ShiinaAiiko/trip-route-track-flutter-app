import 'package:flutter/material.dart';
import '../webview_options.dart';
import '../webview_controller.dart';
import '../webview_bridge.dart';
import 'tab_manager.dart';
import 'tab_page.dart';

class TabManagerWidget extends StatefulWidget {
  final String initialUrl;
  final WebViewOptions Function(String url) optionsBuilder;
  final int maxTabs;
  final bool showTabBar;
  final Widget? loadingWidget;
  final Brightness? brightness;
  final void Function(WebViewBridge bridge)? onBridgeReady;

  const TabManagerWidget({
    super.key,
    required this.initialUrl,
    required this.optionsBuilder,
    this.maxTabs = 10,
    this.showTabBar = true,
    this.loadingWidget,
    this.brightness,
    this.onBridgeReady,
  });

  @override
  State<TabManagerWidget> createState() => _TabManagerWidgetState();
}

class _TabManagerWidgetState extends State<TabManagerWidget> {
  late TabManager _tabManager;
  WebViewController? _currentController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabManager = TabManager(
      optionsBuilder: widget.optionsBuilder,
      maxTabs: widget.maxTabs,
      enableTabBarByDefault: widget.showTabBar,
    );
    _tabManager.addListener(_onTabManagerChanged);
    _openInitialTab();
  }

  void _openInitialTab() {
    _tabManager.openTab(widget.initialUrl);
  }

  void _onTabManagerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabManager.removeListener(_onTabManagerChanged);
    _currentController?.dispose();
    super.dispose();
  }

  void _handleOpenUrl(String url, String? target) {
    final tab = _tabManager.openTab(url);
    _openTabPage(tab);
  }

  void _openTabPage(TabInfo tab) {
    Navigator.of(context).push(
      TabPageRoute(
        tabId: tab.id,
        url: tab.url,
        builder: (context) => _buildTabPageContent(tab),
      ),
    );
  }

  Widget _buildTabPageContent(TabInfo tab) {
    return _TabPageContent(
      tabId: tab.id,
      url: tab.url,
      options: _tabManager.buildOptions(tab.url),
      onOpenUrl: _handleOpenUrl,
      onClose: () {
        _tabManager.closeTab(tab.id);
        Navigator.of(context).pop();
      },
      onBridgeReady: widget.onBridgeReady,
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

    if (processedUrl.startsWith('https://')) {
      return processedUrl.substring(8);
    }
    if (processedUrl.startsWith('http://')) {
      return processedUrl.substring(7);
    }
    return processedUrl;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.brightness ?? Brightness.light;
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;
    final subTextColor = brightness == Brightness.dark ? Colors.white70 : Colors.black54;
    final backgroundColor = brightness == Brightness.dark ? const Color(0xFF202124) : Colors.white;

    if (_tabManager.tabCount == 0) {
      return widget.loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (widget.showTabBar && _tabManager.hasMultipleTabs)
          _buildTabBar(brightness, textColor, subTextColor, backgroundColor),
        Expanded(
          child: _buildCurrentTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabBar(
    Brightness brightness,
    Color textColor,
    Color subTextColor,
    Color backgroundColor,
  ) {
    return Container(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabManager.tabCount,
              itemBuilder: (context, index) {
                final tab = _tabManager.tabs[index];
                return _buildTabItem(tab, textColor, subTextColor, backgroundColor);
              },
            ),
          ),
          Divider(height: 1, color: subTextColor.withOpacity(0.2)),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    TabInfo tab,
    Color textColor,
    Color subTextColor,
    Color backgroundColor,
  ) {
    final isSelected = tab.isCurrent;
    return GestureDetector(
      onTap: () => _tabManager.switchToTab(_tabManager.tabs.indexOf(tab)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? backgroundColor : backgroundColor.withOpacity(0.5),
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tab.title.isNotEmpty ? tab.title : _getDisplayUrl(tab.url),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tab.title.isNotEmpty)
                    Text(
                      _getDisplayUrl(tab.url),
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_tabManager.tabCount == 1) {
                  _tabManager.closeTab(tab.id);
                  Navigator.of(context).pop();
                } else {
                  _tabManager.closeTab(tab.id);
                }
              },
              child: Icon(
                Icons.close,
                size: 18,
                color: subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    final currentTab = _tabManager.currentTab;
    if (currentTab == null) {
      return widget.loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    return _TabPageContent(
      key: ValueKey(currentTab.id),
      tabId: currentTab.id,
      url: currentTab.url,
      options: _tabManager.buildOptions(currentTab.url),
      onOpenUrl: _handleOpenUrl,
      onClose: () {
        if (_tabManager.tabCount == 1) {
          _tabManager.closeTab(currentTab.id);
        } else {
          _tabManager.closeTab(currentTab.id);
        }
      },
      onBridgeReady: widget.onBridgeReady,
    );
  }
}

class _TabPageContent extends StatefulWidget {
  final String tabId;
  final String url;
  final WebViewOptions options;
  final OpenUrlHandler? onOpenUrl;
  final VoidCallback? onClose;
  final void Function(WebViewBridge bridge)? onBridgeReady;

  const _TabPageContent({
    super.key,
    required this.tabId,
    required this.url,
    required this.options,
    this.onOpenUrl,
    this.onClose,
    this.onBridgeReady,
  });

  @override
  State<_TabPageContent> createState() => _TabPageContentState();
}

class _TabPageContentState extends State<_TabPageContent> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController(widget.options);
    _controller.setOnOpenUrlHandler((url, target) {
      widget.onOpenUrl?.call(url, target);
    });
    widget.onBridgeReady?.call(_controller.bridge);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.build(context);
  }
}