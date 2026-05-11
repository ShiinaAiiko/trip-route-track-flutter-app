# Trip Route Track Flutter App - 开发上下文

## 项目概述
这是一个基于 Flutter 的旅行路线追踪应用，使用 GeckoView 作为 WebView 来加载 Next.js 构建的静态网页。

## 最近完成的工作

### 1. 静态资源加载问题解决
**问题**：Flutter 的 pubspec.yaml 不能递归包含子目录，每次构建网站后需要手动列出所有子目录。

**解决方案**：
- 创建了 `update_flutter_assets.sh` 脚本，自动扫描 `assets/out/` 下所有子目录
- 在 `release.sh` 的 `dev()` 和 `_build()` 函数中集成了自动化更新逻辑
- 每次运行 `./release.sh dev` 或 `./release.sh build` 时都会自动更新 pubspec.yaml

### 2. 本地静态服务器增强
**文件**：`lib/local_server.dart`

**功能**：
- 从 AssetManifest.json 加载所有资源
- URL 解码处理（解决 `%5B` 等 URL 编码问题）
- 类似 nginx 的路径匹配策略：
  - 原路径
  - 添加 .html 后缀
  - 添加 /index.html 后缀

### 3. 输入法问题（未完全解决）
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

### 4. 语言切换问题
**问题**：从 `/` 切换到 `/zh-CN` 时，部分文件 404

**解决方案**：
- 在 local_server.dart 中添加了 URL 解码
- 实现了类似 nginx 的 .html 后缀自动添加功能

## 关键文件

### Flutter 端
- `lib/main.dart` - 主入口，Scaffold 包含 GeckoView
- `lib/local_server.dart` - 本地 HTTP 服务器，提供静态资源
- `pubspec.yaml` - 资源声明（自动更新）

### Android 端
- `android/app/src/main/kotlin/club/aiiko/trip/MainActivity.kt` - FlutterActivity 配置
- `android/app/src/main/kotlin/club/aiiko/trip/GeckoViewPlatform.kt` - GeckoView 平台实现
- `android/app/src/main/kotlin/club/aiiko/trip/GeckoViewFactory.kt` - GeckoView 工厂类
- `android/app/src/main/AndroidManifest.xml` - 应用清单配置

### 脚本
- `release.sh` - 发布脚本，包含自动化资源更新
- `update_flutter_assets.sh` - 自动扫描并更新 pubspec.yaml 资源列表

## 构建命令

```bash
# 开发构建
./release.sh dev

# 生产构建
./release.sh build

# 直接使用 Flutter 命令
flutter build apk --debug --flavor prod
```

## APK 输出位置
- Debug: `build/app/outputs/flutter-apk/app-prod-debug.apk`

## 待解决问题

### 1. 输入法无法唤起
GeckoView 中的网页 input 标签无法唤起 Android 输入法
需要进一步研究 GeckoView 的焦点和输入法集成

### 2. 可能需要研究的方向
- GeckoView 的嵌入式编辑器模式
- Android WebView vs GeckoView 的输入法处理差异
- 可能需要通过 JavaScript 注入来触发输入法的显示

## 技术栈
- Flutter 3.x
- GeckoView (Firefox 的 WebView)
- shelf (Dart HTTP 服务器)
- Next.js (前端框架)
- Android API 21+
