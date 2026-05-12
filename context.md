You are only allowed to modify files within the current directory. Never touch or mention any parent or sibling directories. 你只允许修改当前目录下的文件。切勿触及或提及任何父级或同级目录。

---

## 项目背景
这是一个**旅行路线追踪 Flutter 应用**（trip-route-track-flutter-app），主要功能是用 WebView 加载 `https://trip.aiiko.club/zh-CN` 并将手机传感器数据传递给网页。

## 重要决策
1. **浏览器引擎选择**：使用 **GeckoView 替代系统 WebView**，解决老版本 Android 手机 WebView 版本过旧的问题
2. **GeckoView 版本要求**：必须 ≥ 130，当前使用 **143.0.20250929153833**
3. **Java 版本**：升级到 **Java 17**
4. **加载动画的逻辑**：当启动app后，立即显示加载动画，背景色根据系统颜色自动设置。此时后台的webview内核立即加载。但是必须隐藏。直到网页加载成功后，再隐藏加载动画，并显示webview
5. **以静态形式加载网站**：网站是由next开发的，静态目录的形式加载，提升加载速度
6. **PlatformView 渲染模式**：使用 **Hybrid Composition** 模式（通过 `PlatformViewLink`），解决 VirtualDisplay 模式下输入法无法唤起的问题

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
- `android/app/src/main/AndroidManifest.xml`：添加 Hybrid Composition 配置 `<meta-data android:name="flutter.platform_views_mode" android:value="hybrid" />`

### 3. Android 代码
- 新建 `GeckoViewFactory.kt`：PlatformView 工厂
- 新建 `GeckoViewPlatform.kt`：GeckoView 集成核心逻辑，支持加载 URL、执行 JS、发送消息，包含自定义 `GeckoViewWrapper` 类处理焦点和输入法
- 修改 `MainActivity.kt`：注册 GeckoView PlatformView，添加窗口软输入模式设置 `SOFT_INPUT_ADJUST_RESIZE`

### 4. Flutter 代码
- 修改 `lib/main.dart`：使用 `PlatformViewLink`（Hybrid Composition）集成 GeckoView，保持传感器数据传递功能
- 新增 `lib/local_server.dart`：本地静态文件服务器，支持 URL 解码和类似 nginx 的路径匹配策略

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

### App 图标自动更新
**功能**：每次更新网站时，自动从 `assets/out/icons/` 目录复制图标到 Android mipmap 目录

**映射关系**：
- `48x48.png` → `mipmap-mdpi/ic_launcher.png`
- `64x64.png` → `mipmap-hdpi/ic_launcher.png`
- `128x128.png` → `mipmap-xhdpi/ic_launcher.png`
- `256x256.png` → `mipmap-xxhdpi/ic_launcher.png`
- `512x512.png` → `mipmap-xxxhdpi/ic_launcher.png`

**集成方式**：已集成到 `update_flutter_assets.sh` 脚本中，每次运行 `./release.sh dev` 或 `./release.sh build` 时自动更新

### 本地静态服务器增强
**文件**：`lib/local_server.dart`

**功能**：
- 从 AssetManifest.json 加载所有资源
- URL 解码处理（解决 `%5B` 等 URL 编码问题）
- 类似 nginx 的路径匹配策略：
  - 原路径
  - 添加 .html 后缀
  - 添加 /index.html 后缀

### 输入法问题（已解决）
**问题**：网页内的 input 标签无法唤起输入法，以及输入内容无法进入输入框

**根本原因**：
- Flutter 的 PlatformView 默认使用 VirtualDisplay 模式，导致 Android 系统认为 View 不是活跃的输入目标（isActive=false）
- 输入连接没有正确建立，导致输入内容无法传递给网页

**解决方案**：
1. **启用 Hybrid Composition**：
   - 在 `lib/main.dart` 中使用 `PlatformViewLink` 替代 `AndroidView`
   - 在 `AndroidManifest.xml` 中添加 `<meta-data android:name="flutter.platform_views_mode" android:value="hybrid" />`
   
2. **修复输入连接**：
   - `GeckoViewWrapper.onCheckIsTextEditor()` 返回 `true`
   - `GeckoViewWrapper.onCreateInputConnection()` 委托给父类处理
   - 移除 touch listener 中的强制 `showSoftInput()` 调用，让 GeckoView 内部根据输入框点击自动处理

**修复效果**：
- ✅ 只有点击输入框时才唤起输入法
- ✅ 输入内容可以正确显示在输入框中

### 语言切换问题
**问题**：从 `/` 切换到 `/zh-CN` 时，部分文件 404

**解决方案**：
- 在 local_server.dart 中添加了 URL 解码
- 实现了类似 nginx 的 .html 后缀自动添加功能

### Flutter Bridge SDK 实现

**功能概述**：实现了完整的 Flutter 与 WebView 之间的桥接通信功能

**模块结构**：`modules/flutter_bridge/`

**核心组件**：

1. **BridgeController**（单例）：
   - 统一管理桥接通信
   - 支持消息订阅和分发
   - 管理 MethodChannel 通信
   - 管理 GPS 定位状态和后台定位
   - 管理屏幕常亮状态

2. **LanguageService**：
   - 使用 SharedPreferences 持久化存储语言设置
   - 支持设置和获取当前语言
   - 提供 URL 本地化方法 `getLocalizedUrl()`

3. **KeepAwakeService**：
   - 管理屏幕唤醒状态
   - 支持保持屏幕常亮（使用 wakelock_plus）

4. **BackgroundService**：
   - 管理后台任务状态
   - 支持后台定位更新
   - 管理前台服务通知

5. **NotificationService**：
   - 管理系统通知显示
   - 支持常驻通知

**消息传递机制**：
- 前端通过 `window.ReactNativeWebView.postMessage()` 发送消息
- 使用 XMLHttpRequest 发送到 `http://localhost:8080/__flutter_bridge__`
- 本地服务器拦截并转发给 BridgeController
- BridgeController 处理消息并分发给注册的 handler

**语言持久化流程**：
- App 启动时初始化 BridgeController，加载保存的语言
- 根据语言设置构建本地化 URL（如 `http://localhost:8080/zh-CN`）
- URL 作为全局常量，只计算一次
- 前端调用 `setLanguage()` 时保存到 SharedPreferences

**GPS 和屏幕常亮控制**：
- 完全由前端指令控制，不再默认启动
- `enableLocation`：控制是否开启 GPS 定位
- `keepScreenOn`：控制是否保持屏幕常亮
- `enableBackgroundLocation`：控制是否开启后台定位
- 开启时自动申请必要权限，发送系统通知提醒用户

**后台定位实现**：
- 使用 Android 前台服务（Foreground Service）确保后台持续运行
- 在通知中实时显示持续时间和定位次数
- 通知格式：`已开启XX分XX秒，已记录XXX个定位`
- geolocator 配合前台服务通知实现后台定位

**appConfig 消息**：
- 前端 SDK 初始化完成后发送 `load` 消息
- Flutter 返回 `appConfig`，包含 `version` 和 `system`（值为 "Flutter App"）

**修复的问题**：
- ✅ MethodChannel 只能绑定一个 handler 的问题（通过外部 handler 机制解决）
- ✅ GeckoRuntime 单例创建问题（双重检查锁）
- ✅ loading 动画延迟问题（页面开始加载时立即关闭）
- ✅ 黑屏问题（移除不必要的 handler.post 调用）
- ✅ GPS 默认启动问题（改为前端控制）
- ✅ 通知权限问题（Android 13+ 需要显式申请）
- ✅ 前台服务权限问题（添加 FOREGROUND_SERVICE 和 FOREGROUND_SERVICE_LOCATION）
- ✅ 重复通知问题（只保留 Android 后台服务通知）

**依赖新增**：
- `wakelock_plus: ^1.2.1`
- `flutter_local_notifications: ^17.2.3`
- `package_info_plus: ^8.0.0`

**关键代码位置**：
- `modules/flutter_bridge/lib/src/bridge_controller.dart`
- `modules/flutter_bridge/lib/src/services/language_service.dart`
- `modules/flutter_bridge/lib/src/services/keep_awake_service.dart`
- `modules/flutter_bridge/lib/src/services/background_service.dart`
- `modules/flutter_bridge/lib/src/services/notification_service.dart`
- `modules/flutter_bridge/lib/src/services/vehicle_service.dart`
- `android/app/src/main/kotlin/club/aiiko/trip/GeckoViewPlatform.kt`
- `android/app/src/main/kotlin/club/aiiko/trip/BackgroundService.kt`
- `android/app/src/main/kotlin/club/aiiko/trip/MainActivity.kt`
- `android/app/src/main/kotlin/club/aiiko/trip/BYDAutoVehicleService.kt`
- `lib/local_server.dart`（`/__flutter_bridge__` 端点）
- `lib/main.dart`（桥接初始化和 URL 构建）

### 比亚迪车辆数据功能

**功能概述**：通过比亚迪车机开放API获取车辆实时数据，并通过 Flutter Bridge 发送给前端

**数据项**：
| 数据项 | API 类 | 方法 | 说明 |
|--------|--------|------|------|
| 车速 | BYDAutoSpeedDevice | getCurrentSpeed() | 0 ~ 282.0 km/h |
| 电量 | BYDAutoStatisticDevice | getElecPercentageValue() | 0 ~ 100% |
| 油量 | BYDAutoStatisticDevice | getFuelPercentageValue() | 0 ~ 100% |
| 油门深度 | BYDAutoSpeedDevice | getAccelerateDeepness() | 0 ~ 100% |
| 刹车深度 | BYDAutoSpeedDevice | getBrakeDeepness() | 0 ~ 100% |
| 总里程 | BYDAutoStatisticDevice | getTotalMileageValue() | 0 ~ 999999 km |
| 混动里程 | BYDAutoStatisticDevice | getEVMileageValue() | 0 ~ 999999 km |
| 胎压 | BYDAutoTyreDevice | getTyrePressureValue(area) | 0 ~ 4094 kpa（四轮独立） |

**消息类型**：`carData`

**消息格式**：
```json
{
  "type": "carData",
  "payload": {
    "speed": 60.5,
    "elecPercentage": 75.0,
    "fuelPercentage": 45,
    "accelerateDepth": 30,
    "brakeDepth": 0,
    "totalMileage": 125000,
    "evMileage": 45000,
    "tyrePressure": {
      "leftFront": 230,
      "rightFront": 228,
      "leftRear": 225,
      "rightRear": 232
    },
    "chargeStatus": 1,
    "chargePower": 60,
    "timestamp": 1699999999999
  }
}
```

**前端控制**：
- 发送 `enableCarData: true` 开启车辆数据监听
- 发送 `enableCarData: false` 停止车辆数据监听
- 数据有变化时立即发送，无需轮询
- 发送 `getCarData` 立即获取当前数据（无论是否变化）

**主动查询机制**：
- `getCarData` 消息用于前端主动获取当前车辆数据
- 无论数据是否变化，都会立即返回当前缓存的数据
- 返回格式与 `carData` 完全一致

**非比亚迪设备兼容**：
- 当 JAR 为 stub 或 API 不可用时，返回全 0 数据
- `isBydServiceAvailable` 标志跟踪服务是否可用
- `sendEmptyCarData()` 方法发送全 0 数据作为 fallback
- 避免 `Stub!` 异常导致应用崩溃

**比亚迪 API 推送模式**：
- 采用注册监听器（Listener）方式，数据由 API 主动推送
- 非轮询模式，数据变化时 API 自动回调通知

**权限配置**：
- `BYDAUTO_AC_COMMON` - 通用权限（需动态申请）
- `BYDAUTO_SPEED_GET` - 车速数据权限
- `BYDAUTO_STATISTIC_GET` - 行驶数据权限
- `BYDAUTO_TYRE_GET` - 轮胎数据权限

**依赖**：
- `bydauto-openapi.jar` - 比亚迪官方SDK

## 待解决问题

（当前无待解决问题）
