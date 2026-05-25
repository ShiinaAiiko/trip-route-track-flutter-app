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
  final String? language;
  final void Function(String tabId, String message)? onMessage;
  final void Function(String tabId, dynamic channel)? onChannelCreated;
  final void Function(String tabId)? onTabClosed;

  const TabManagerWidget({
    super.key,
    required this.initialUrl,
    required this.optionsBuilder,
    this.maxTabs = 10,
    this.showTabBar = true,
    this.loadingWidget,
    this.brightness,
    this.onBridgeReady,
    this.language,
    this.onMessage,
    this.onChannelCreated,
    this.onTabClosed,
  });

  @override
  State<TabManagerWidget> createState() => _TabManagerWidgetState();
}

class _TabManagerWidgetState extends State<TabManagerWidget> {
  late TabManager _tabManager;
  WebViewController? _currentController;
  bool _isLoading = true;

  Future<bool> _handleBackPress() async {
    print('[NyaNyaOpenURL] TabManagerWidget._handleBackPress called');
    if (_currentController != null) {
      final canGoBack = await _currentController!.canGoBack();
      print(
          '[NyaNyaOpenURL] TabManagerWidget._handleBackPress: canGoBack=$canGoBack');
      if (canGoBack) {
        await _currentController!.goBack();
        return false; // 不关闭页面，WebView 内部后退
      }
    }
    // WebView 无法后退，关闭当前标签页
    Navigator.of(context).pop();
    return false;
  }

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
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TabManagerWidget(
          initialUrl: url,
          optionsBuilder: widget.optionsBuilder,
          maxTabs: widget.maxTabs,
          showTabBar: widget.showTabBar,
          brightness: widget.brightness,
          onBridgeReady: widget.onBridgeReady,
        ),
        // 推入动画：从右往左滑入
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        // 返回动画：从左往右滑出
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
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
    final textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;
    final subTextColor =
        brightness == Brightness.dark ? Colors.white70 : Colors.black54;
    final backgroundColor =
        brightness == Brightness.dark ? const Color(0xFF202124) : Colors.white;

    if (_tabManager.tabCount == 0) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        body: Column(
          children: [
            if (widget.showTabBar && _tabManager.hasMultipleTabs)
              _buildTabBar(
                  brightness, textColor, subTextColor, backgroundColor),
            Expanded(
              child: _buildCurrentTabContent(),
            ),
          ],
        ),
      ),
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
                return _buildTabItem(
                    tab, textColor, subTextColor, backgroundColor);
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
          color:
              isSelected ? backgroundColor : backgroundColor.withOpacity(0.5),
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
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.normal,
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
                final closingTabId = tab.id;
                widget.onTabClosed?.call(closingTabId);
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
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    return TabPage(
      key: ValueKey(currentTab.id),
      tabId: currentTab.id,
      url: currentTab.url,
      options: _tabManager.buildOptions(currentTab.url),
      onOpenUrl: _handleOpenUrl,
      onClose: () {
        // onRequestExitApp 意味着 WebView 已经退无可退
        // 应该返回上一个 Flutter 页面
        Navigator.of(context).pop();
      },
      onTitleChanged: (tabId, title) {
        _tabManager.updateTabTitle(tabId, title);
      },
      onUrlChanged: (tabId, url) {
        _tabManager.updateTabUrl(tabId, url);
      },
      language: widget.language,
      onMessage: widget.onMessage,
      onChannelCreated: widget.onChannelCreated,
      onTabClosed: widget.onTabClosed,
    );
  }
}
