# tab_manager 模块开发文档

## 概述

`tab_manager` 是 `nyanya_webview` 库的标签页管理模块，提供完整的多标签页浏览功能。该模块支持独立的 Flutter 路由标签页，关闭后能完美回到原页面状态。

## 功能特性

- **无限标签页**：支持通过路由栈无限叠加标签页
- **PWA 风格导航**：顶部导航栏，包含返回、刷新、关闭等操作
- **标签切换**：支持在多个标签页之间切换
- **URL 美化**：内部网站 URL 自动替换为友好显示地址
- **标签状态管理**：使用 ChangeNotifier 管理标签状态
- **最大标签数限制**：可配置最大标签页数量，超出自动关闭旧标签

## 目录结构

```
tab_manager/
├── tab_manager.dart          # 标签管理器（状态管理）
├── tab_page.dart             # 单个标签页 Widget
└── tab_manager_widget.dart   # 标签管理器主 Widget
```

## 核心组件

### 1. TabManager - 标签管理器

**文件**：`tab_manager.dart`

标签状态管理类，继承自 `ChangeNotifier`，负责管理所有标签页的状态。

```dart
class TabInfo {
  final String id;           // 标签唯一 ID
  final String url;          // 标签 URL
  final String title;        // 标签标题
  final bool isCurrent;      // 是否为当前标签
}

class TabManager extends ChangeNotifier {
  final WebViewOptions Function(String url) _optionsBuilder;
  final int maxTabs;
  final List<TabInfo> _tabs;
  int _currentIndex;
}
```

**主要方法**：

| 方法 | 说明 |
|------|------|
| `openTab(url, title)` | 打开新标签页 |
| `closeTab(tabId)` | 关闭指定标签页 |
| `switchToTab(index)` | 切换到指定标签页 |
| `replaceCurrentTab(url, title)` | 替换当前标签页 URL |
| `updateTabTitle(tabId, title)` | 更新标签页标题 |
| `updateTabUrl(tabId, url)` | 更新标签页 URL |
| `clearAllTabs()` | 清除所有标签页 |
| `buildOptions(url)` | 构建 WebViewOptions |

**使用示例**：

```dart
final tabManager = TabManager(
  optionsBuilder: (url) => WebViewOptions(
    engine: WebViewEngine.gecko,
    initialUrl: url,
    serverPort: 13218,
    newTabBehavior: NewTabBehavior.delegate,
  ),
  maxTabs: 10,
);

// 监听状态变化
tabManager.addListener(() {
  setState(() {});
});

// 打开新标签
final tab = tabManager.openTab('https://example.com');

// 切换标签
tabManager.switchToTab(0);

// 关闭标签
tabManager.closeTab(tab.id);
```

### 2. TabManagerWidget - 标签管理器主 Widget

**文件**：`tab_manager_widget.dart`

标签管理器的主界面组件，提供标签栏和标签内容展示。

**构造参数**：

```dart
class TabManagerWidget extends StatefulWidget {
  final String initialUrl;                              // 初始 URL
  final WebViewOptions Function(String url) optionsBuilder;  // 选项构建器
  final int maxTabs;                                    // 最大标签数（默认 10）
  final bool showTabBar;                                // 是否显示标签栏（默认 true）
  final Widget? loadingWidget;                          // 加载中 Widget
  final Brightness? brightness;                         // 亮度模式
  final void Function(WebViewBridge bridge)? onBridgeReady;  // Bridge 就绪回调
}
```

**主要功能**：
- 显示顶部标签栏（多标签时）
- 管理标签页的打开/关闭/切换
- 处理新页面打开（通过 onOpenUrl）
- URL 美化显示

**标签栏特性**：
- 水平滚动显示标签
- 当前标签高亮显示
- 每个标签显示标题和 URL
- 点击关闭按钮关闭标签
- 点击标签切换到该标签

### 3. TabPage - 单个标签页

**文件**：`tab_page.dart`

单个标签页的 Widget，内部封装 WebView。

**构造参数**：

```dart
class TabPage extends StatefulWidget {
  final String tabId;
  final String url;
  final WebViewOptions options;
  final void Function(String tabId, String title)? onTitleChanged;
  final void Function(String tabId, String url)? onUrlChanged;
  final OpenUrlHandler? onOpenUrl;
  final VoidCallback? onClose;
}
```

**TabPageRoute**：

自定义路由类，用于标签页导航，携带 tabId 和 url 信息。

```dart
class TabPageRoute<T> extends MaterialPageRoute<T> {
  final String tabId;
  final String url;
}
```

## 架构设计

### 标签页路由栈

标签页采用 Flutter 路由栈实现，支持无限叠加：

```
主页面
  ↓ (打开新标签)
TabPage (标签1)
  ↓ (再打开新标签)
TabPage (标签2)
  ↓ (再打开新标签)
TabPage (标签3)
  ↓ (返回)
TabPage (标签2)
  ↓ (返回)
TabPage (标签1)
  ↓ (返回)
主页面
```

这种设计的优点：
- 每个标签页独立，互不影响
- 返回时完美恢复原页面状态
- 原生支持手势返回
- 内存占用可控（可配置 maxTabs）

### URL 美化规则

内部网站 URL 自动替换为友好显示地址：

```
原始: http://localhost:13218/zh-CN/trip
显示: https://trip.aiiko.club/zh-CN/trip

匹配规则:
- localhost:13218 / 13219 / 13220
- 127.0.0.1:13218 / 13219 / 13220
```

## 使用指南

### 基本使用 - TabManagerWidget

```dart
import 'package:nyanya_webview/nyanya_webview.dart';

TabManagerWidget(
  initialUrl: 'https://trip.aiiko.club',
  optionsBuilder: (url) => WebViewOptions(
    engine: WebViewEngine.gecko,
    initialUrl: url,
    serverPort: 13218,
    newTabBehavior: NewTabBehavior.delegate,
  ),
  maxTabs: 10,
  showTabBar: true,
  brightness: Brightness.light,
  onBridgeReady: (bridge) {
    // Bridge 就绪，可以注册事件监听
    bridge.on('myEvent', (message) {
      print('Received: $message');
    });
  },
)
```

### 基本使用 - 直接使用 TabManager

```dart
import 'package:nyanya_webview/nyanya_webview.dart';

// 1. 创建 TabManager
final tabManager = TabManager(
  optionsBuilder: (url) => WebViewOptions(
    engine: WebViewEngine.gecko,
    initialUrl: url,
    serverPort: 13218,
    newTabBehavior: NewTabBehavior.delegate,
  ),
  maxTabs: 10,
);

// 2. 使用 ChangeNotifierProvider（可选）
ChangeNotifierProvider.value(
  value: tabManager,
  child: YourWidget(),
)

// 3. 在 Widget 中使用
Consumer<TabManager>(
  builder: (context, tabManager, child) {
    return Column(
      children: [
        // 显示标签栏
        if (tabManager.hasMultipleTabs)
          _buildTabBar(tabManager),
        // 显示当前标签内容
        Expanded(
          child: _buildCurrentTab(tabManager),
        ),
      ],
    );
  },
)

// 4. 打开新标签
tabManager.openTab('https://example.com');

// 5. 使用 navigateToTab 导航
navigateToTab(
  context: context,
  tabManager: tabManager,
  tabId: tab.id,
  url: tab.url,
);
```

### 自定义标签栏

```dart
Widget _buildCustomTabBar(TabManager tabManager) {
  return Container(
    height: 50,
    color: Colors.grey[200],
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: tabManager.tabCount,
      itemBuilder: (context, index) {
        final tab = tabManager.tabs[index];
        return GestureDetector(
          onTap: () => tabManager.switchToTab(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: tab.isCurrent ? Colors.blue : Colors.grey[300],
            ),
            child: Center(
              child: Text(tab.title.isNotEmpty ? tab.title : tab.url),
            ),
          ),
        );
      },
    ),
  );
}
```

## 开发指南

### 扩展 TabInfo

在 `tab_manager.dart` 中添加新字段：

```dart
class TabInfo {
  final String id;
  final String url;
  final String title;
  final bool isCurrent;
  final DateTime? createdAt;  // 新增字段

  TabInfo({
    required this.id,
    required this.url,
    this.title = '',
    this.isCurrent = false,
    this.createdAt,  // 新增参数
  });

  TabInfo copyWith({
    String? url,
    String? title,
    bool? isCurrent,
    DateTime? createdAt,  // 新增
  }) {
    return TabInfo(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,  // 新增
    );
  }
}
```

### 自定义 TabPage 外观

修改 `_TabPageContent` 或创建自定义 Widget：

```dart
class CustomTabPage extends StatelessWidget {
  final String tabId;
  final String url;
  final WebViewOptions options;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('自定义标签页'),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: WebViewController(options).build(context),
    );
  }
}
```

### 添加标签页持久化

在 `TabManager` 中添加保存/加载方法：

```dart
class TabManager extends ChangeNotifier {
  // ... 现有代码 ...

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final tabsJson = jsonEncode(_tabs.map((t) => {
      'id': t.id,
      'url': t.url,
      'title': t.title,
      'isCurrent': t.isCurrent,
    }).toList());
    await prefs.setString('tabs', tabsJson);
    await prefs.setInt('currentIndex', _currentIndex);
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final tabsJson = prefs.getString('tabs');
    if (tabsJson != null) {
      // 解析并恢复标签
    }
  }
}
```

## 调试 Tips

- 使用 `TabManager.addListener()` 监听状态变化
- 打印 `tabManager.tabs` 查看所有标签状态
- 打印 `tabManager.currentIndex` 查看当前标签索引
- 使用 `adb logcat | grep NyaNyaOpenURL` 查看标签页相关日志

## 当前开发状态

| 功能 | 状态 |
|------|------|
| TabManager 状态管理 | ✅ 已完成 |
| TabManagerWidget UI | ✅ 已完成 |
| TabPage Widget | ✅ 已完成 |
| TabPageRoute 路由 | ✅ 已完成 |
| 标签栏 UI | ✅ 已完成 |
| URL 美化显示 | ✅ 已完成 |
| 最大标签数限制 | ✅ 已完成 |
| 标签页持久化 | ❌ 未实现 |
| 标签页缩略图 | ❌ 未实现 |
| 标签页拖拽排序 | ❌ 未实现 |

## 与 nyanya_webview 主模块的关系

`tab_manager` 是 `nyanya_webview` 的子模块，依赖主模块的：

- `WebViewOptions` - WebView 配置
- `WebViewController` - WebView 控制器
- `WebViewBridge` - JavaScript 桥接
- `OpenUrlHandler` - 新开页面回调

主模块通过 `lib/nyanya_webview.dart` 导出 tab_manager 模块：

```dart
export 'src/tab_manager/tab_manager.dart';
export 'src/tab_manager/tab_page.dart';
export 'src/tab_manager/tab_manager_widget.dart';
```

## 相关文档

- [nyanya_webview 模块开发文档](../../DEVELOPMENT.md)
- 项目根目录 context.md

## 维护者

NyaNya 开发团队
