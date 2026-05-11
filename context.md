You are only allowed to modify files within the current directory. Never touch or mention any parent or sibling directories.

---

## 项目背景
这是一个**旅行路线追踪 Flutter 应用**（trip-route-track-flutter-app），主要功能是用 WebView 加载 `https://trip.aiiko.club/zh-CN` 并将手机传感器数据传递给网页。

## 重要决策
1. **浏览器引擎选择**：使用 **GeckoView 替代系统 WebView**，解决老版本 Android 手机 WebView 版本过旧的问题
2. **GeckoView 版本要求**：必须 ≥ 130，当前使用 **143.0.20250929153833**
3. **Java 版本**：升级到 **Java 17**

## 已完成的修改

### 1. pubspec.yaml
- 移除 `flutter_inappwebview` 依赖

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

### 6. 加载动画优化
- 移除权限申请文案，加载动画页面只显示三个点动画和底部文字
- 延迟500ms后再申请权限，避免启动时页面闪烁
- 使用 `Offstage` 组件实现 GeckoView 后台加载但不显示，等加载完成后再显示

### 7. 闪屏问题修复
- 将 Android 启动背景改为透明（`@android:color/transparent`）
- GeckoView 背景色根据系统亮度动态设置（通过 `isDarkMode` 参数传递）
- 使用 `Offstage` 组件在加载完成前隐藏 GeckoView，避免初始化时的白色闪烁

### 8. 修复的问题
- 修复 GPS 位置更新被重复启动的问题（添加 `_isLocationUpdating` 标志位）
- 修复 WebView 触摸事件被拦截的问题（使用 `Visibility` 组件）
- 修复 GeckoView 权限委托配置，允许网页获取位置信息
- 修复启动闪屏问题（Android 背景透明、GeckoView 背景适配、Offstage 延迟显示）

## 当前状态
应用功能正常：
- 启动时显示加载动画（三个点+底部文字），后台静默申请 GPS 权限，无闪屏
- GPS 数据每秒更新一次
- 网页可通过 `navigator.geolocation` 获取位置数据
- 传感器数据（陀螺仪、加速度计）正常传递给网页

## 下一步
运行 `./release.sh dev` 测试应用是否能正常构建和运行！
