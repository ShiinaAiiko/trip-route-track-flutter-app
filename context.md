---

## 项目背景
这是一个**旅行路线追踪 Flutter 应用**（trip-route-track-flutter-app），主要功能是用 WebView 加载 `https://trip.aiiko.club/zh-CN` 并将手机传感器数据传递给网页。

## 重要决策
1. **浏览器引擎选择**：使用 **GeckoView 替代系统 WebView**，解决老版本 Android 手机 WebView 版本过旧的问题
2. **GeckoView 版本要求**：必须 ≥ 130，当前使用 **143.0.20250929153833**
3. **Java 版本**：升级到 **Java 17**
4. **加载动画的逻辑**：当启动app后，立即显示加载动画，背景色根据系统颜色自动设置。此时后台的webview内核立即加载。但是必须隐藏。直到网页加载成功后，再隐藏加载动画，并显示webview
5. **以静态形式加载网站**：网站是由next开发的，静态目录的形式加载，提升加载速度

## 已完成的修改

### 1. pubspec.yaml
- 移除 `flutter_inappwebview` 依赖
- 添加静态资源配置（assets/out/ 目录）

### 2. 静态目录加载
- 将 Next.js 项目构建为静态文件（`npm run build`）
- 静态文件存放在 `assets/out/` 目录
- 通过 Base64 编码的 data URL 加载本地静态页面（避免 GeckoView 直接访问 assets 路径的问题）
- Flutter assets 配置：`assets/out/` 及其子目录

### 2. Android 配置
- `android/app/build.gradle`：
  - 更新 Java 版本从 1.8 → 17
  - 添加 `repositories` 块，包含 Mozilla Maven 仓库
  - 添加 GeckoView 143.0.20250929153833 依赖
- `android/build.gradle`：移除 `allprojects` 块（避免覆盖 settings.gradle 的仓库配置）
- `android/settings.gradle`：已有 Mozilla 仓库配置

### 3. Android 代码
- 新建 `GeckoViewFactory.kt`：PlatformView 工厂
- 新建 `GeckoViewPlatform.kt`：GeckoView 集成核心逻辑，支持加载 URL、执行 JS、发送消息
- 修改 `MainActivity.kt`：注册 GeckoView PlatformView

### 4. Flutter 代码
- 修改 `lib/main.dart`：使用 `AndroidView` 集成 GeckoView，保持传感器数据传递功能

### 5. GPS 定位功能
- 添加 `permission_handler` 和 `geolocator` 依赖
- 在 `lib/main.dart` 中实现：
  - 静默后台申请位置权限（`locationWhenInUse`）
  - 位置服务检查和自动开启
  - 1秒间隔持续位置更新
  - 通过 `MethodChannel` 将 GPS 数据传递给 WebView

---

## 新增/更新的内容

### 静态资源自动更新
**问题**：Flutter 的 pubspec.yaml 不能递归包含子目录，每次构建网站后需要手动列出所有子目录。

**解决方案**：
- 创建了 `update_flutter_assets.sh` 脚本，自动扫描 `assets/out/` 下所有子目录
- 在 `release.sh` 的 `dev()` 和 `_build()` 函数中集成了自动化更新逻辑
- 每次运行 `./release.sh dev` 或 `./release.sh build` 时都会自动更新 pubspec.yaml

### 本地静态服务器增强
**文件**：`lib/local_server.dart`

**功能**：
- 从 AssetManifest.json 加载所有资源
- URL 解码处理（解决 `%5B` 等 URL 编码问题）
- 类似 nginx 的路径匹配策略：
  - 原路径
  - 添加 .html 后缀
  - 添加 /index.html 后缀

### 输入法问题（未完全解决）
**问题**：网页内的 input 标签无法唤起输入法

**尝试的解决方案**：
1. MainActivity.kt - 添加了 windowSoftInputMode 配置
2. GeckoViewPlatform.kt - 添加了焦点和输入法处理：
   - isFocusable = true
   - isFocusableInTouchMode = true
   - isClickable = true
   - 焦点变化监听器
   - 触摸事件监听器
   - showInputMethod() 方法
   - 页面加载完成后延迟请求焦点

**当前状态**：输入法仍然无法唤起，需要进一步调试

### 语言切换问题
**问题**：从 `/` 切换到 `/zh-CN` 时，部分文件 404

**解决方案**：
- 在 local_server.dart 中添加了 URL 解码
- 实现了类似 nginx 的 .html 后缀自动添加功能

## 待解决问题

### 1. 输入法无法唤起
GeckoView 中的网页 input 标签无法唤起 Android 输入法
需要进一步研究 GeckoView 的焦点和输入法集成

### 2. 可能需要研究的方向
- GeckoView 的嵌入式编辑器模式
- Android WebView vs GeckoView 的输入法处理差异
- 可能需要通过 JavaScript 注入来触发输入法的显示
