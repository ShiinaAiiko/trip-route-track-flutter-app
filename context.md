## 指令
1. You are only allowed to modify files within the current directory. Never touch or mention any parent or sibling directories. 你只允许修改当前目录下的文件。切勿触及或提及任何父级或同级目录。
2. 每次改了代码都要告知我改了啥，为何这么改
3. 每次修改完代码，请保证编译通过，不能有错误；禁止使用release.sh里的生产部署来测试
4. **所有 UI 文案都必须使用 i18n 国际化系统**：
   - 翻译文件位置：`modules/i18n/lib/translations.dart`
   - 使用方式：`BridgeController().i18nService.t('key_name')`
   - 新增文案时，必须同时添加 `zh-CN`、`en-US`、`zh-TW` 三个语言版本
5. **UI 组件尽量使用 Shadcn UI**：
   - 优先使用 Shadcn UI 提供的组件
   - 当前使用的 Shadcn UI 版本：`0.5.7`
   - 例如：使用 `ShadToast` 替代 Material SnackBar，使用 `ShadButton` 替代 Material Button

**Shadcn UI Toast 组件注意事项**：
   - `ShadToast` 在移动端会强制设置 `minWidth: double.infinity`，导致弹框占满整个屏幕宽度
   - 即使设置 `constraints` 或 `width` 参数也无法限制最大宽度
   - `ShadToast` **内置了淡入淡出动画**，无需额外配置
   - 如果需要控制宽度，只能使用自定义组件

**当前 Toast 使用情况**：
   - 退出提示：使用 `ShadToast`，显示"再按一次退出程序"，3秒后自动消失
   - 分享提示：使用 `ShadToast`，显示"已复制URL"，2秒后自动消失

---

## 项目背景

这是一个**行程路线轨迹 Flutter 应用**（trip-route-track-flutter-app），主要功能是用 WebView 加载 `https://trip.aiiko.club/zh-CN` 并将手机传感器数据传递给网页。

## 重要决策

1. **浏览器引擎选择**：使用 **GeckoView 替代系统 WebView**，解决老版本 Android 手机 WebView 版本过旧的问题
2. **GeckoView 版本要求**：必须 ≥ 130，当前使用 **143.0.20250929153833**
3. **Java 版本**：升级到 **Java 17**
4. **加载动画的逻辑**：当启动app后，立即显示加载动画，背景色根据系统颜色自动设置。此时后台的webview内核立即加载。但是必须隐藏。直到网页加载成功后，再隐藏加载动画，并显示webview
5. **以静态形式加载网站**：网站是由next开发的，静态目录的形式加载，提升加载速度
6. **PlatformView 渲染模式**：使用 **Hybrid Composition** 模式（通过 `PlatformViewLink`），解决 VirtualDisplay 模式下输入法无法唤起的问题
7. **状态栏动态变化**：前端通过 `setStatusBar` 消息动态控制状态栏样式和显示模式
8. **本地服务器端口区分**：开发环境使用 **13218**，生产环境使用 **13219**

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
   - 支持常驻通知和带自动关闭的通知

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

**权限配置**（已扩展）：

- `BYDAUTO_AC_COMMON` - 空调通用权限
- `BYDAUTO_BODYWORK_COMMON` - 车身通用权限
- `BYDAUTO_ENGINE_COMMON` - 发动机通用权限
- `BYDAUTO_TYRE_COMMON` - 轮胎通用权限
- `BYDAUTO_INSTRUMENT_COMMON` - 仪表通用权限
- `BYDAUTO_DOORLOCK_COMMON` - 门锁通用权限
- `BYDAUTO_PANORAMA_COMMON` - 全景通用权限
- `BYDAUTO_VEHICLESET_COMMON` - 车辆设置通用权限
- `BYDAUTO_SPEED_GET` - 车速数据权限
- `BYDAUTO_STATISTIC_GET` - 行驶数据权限
- `BYDAUTO_TYRE_GET` - 轮胎数据权限
- `BYDAUTO_ENGINE_GET` - 发动机数据权限
- `BYDAUTO_ENERGY_GET` - 能量数据权限
- `BYDAUTO_CHARGE_GET` - 充电数据权限

**签名配置**：

- 参考 `car-staus-helper` 项目使用平台密钥（`platform.keystore`）进行测试
- 密钥库密码：`android`
- 密钥别名：`androiddebugkey`
- 密钥密码：`android`
- 原始签名已备份至 `keystore_backup/trip-release-key.keystore.backup`

**依赖**：

- `bydauto-openapi.jar` - 比亚迪官方SDK
- `BydApiReflectHelper.kt` - 反射调用隐藏API工具类

**当前问题**：

- 比亚迪车机 API 需要系统签名才能正常工作
- 当前使用平台密钥（`platform.keystore`）进行测试，但不确定是否与目标车机系统签名匹配
- 权限检查通过但无法获取数据，可能原因：
  1. 签名不匹配（车机使用自定义签名而非标准平台签名）
  2. 包名未在车机白名单中
  3. API 调用方式不正确
- 待在真实比亚迪车机上进行测试验证

**白屏问题修复**（已实现）：

1. **本地服务状态检测**：
   - 添加 `ServerStatus` 枚举（stopped/starting/running/error）
   - 添加 `checkServerHealth()` 方法检测服务健康状态
   - 添加自动重启机制（最多重试 3 次）

2. **App 前后台切换处理**：
   - 在 `didChangeAppLifecycleState` 中检测 `AppLifecycleState.resumed`
   - 进入前台时自动检测本地服务状态
   - 服务异常时自动重启并重新加载页面

3. **通知提醒**：
   - 服务启动失败时发送通知提醒用户
   - 使用 `flutter_local_notifications` 实现通知功能

4. **页面加载保护**：
   - 添加 `_isPageLoaded` 标记页面是否成功加载
   - 服务正常时不强制刷新页面，保护用户工作状态

**参考 [car-staus-helper](https://gitee.com/ljwzz/car-staus-helper/blob/master/release/%E5%BC%80%E5%8F%91%E7%AC%94%E8%AE%B0.txt) 项目的关键发现**（来自开发者笔记）：

1. **权限声明**：AndroidManifest.xml 中必须声明权限，否则 requestPermissions 不会弹权限请求窗口
2. **系统签名**：必须使用 platform.keystore 签名
3. **监听器类型**：registerListener 必须使用 abstract class（如 AbsBYDAutoSpeedListener），不能改为 interface
4. **监听器包名**：注册的抽象类包名必须与 device 一致（继承自 android.hardware.bydauto.* 包）
5. **监听器方法**：可以只实现代码中需要的方法，无需实现全部抽象方法

### 全局 i18n 国际化系统

**功能概述**：实现了完整的全局国际化系统，支持多语言切换，包括：
- Flutter UI 文本国际化
- 桌面 App 标题跟随语言设置
- 通知文本国际化
- 语言设置持久化存储

**支持的语言**：
- `zh-CN` - 简体中文（默认）
- `en-US` - 英语
- `zh-TW` - 繁体中文

**核心组件**：

1. **I18nService** (`modules/i18n/lib/i18n_service.dart`)
   - 单例模式，管理全局语言状态
   - 使用 `SharedPreferences` 持久化存储语言设置
   - 支持语言切换事件广播（Stream）
   - 提供 `translate()` / `t()` 方法进行文本翻译
   - 支持参数替换（如 `{duration}`、`{count}`）
   - 自动调用 Android 原生方法更新桌面 App 标题

2. **AppTranslations** (`modules/i18n/lib/translations.dart`)
   - 定义所有支持的语言和翻译文本
   - 包含 App 标题、加载文本、通知文本、错误提示等

3. **BridgeController 集成** (`modules/flutter_bridge/lib/src/bridge_controller.dart`)
   - 初始化时同时初始化 `I18nService` 和 `LanguageService`
   - 收到前端 `setLanguage` 消息时，同步更新两个服务的语言设置
   - 所有通知文本、错误提示都通过 `_i18nService.t()` 获取翻译

4. **桌面 App 标题动态更新**
   - **问题**：App 内设置语言后，桌面显示的 App 名称仍然跟随系统语言
   - **目标行为**：
     - 当 App 内语言设置为 "system" 或空时，跟随系统语言
     - 当 App 内设置为特定语言时，桌面 App 标题使用对应语言
     - 语言设置变更时，标题立即更新
   - **解决方案**：使用 Android ShortcutManager API 动态更新桌面 App 标题
   - **实现细节**：
     - 新增 `res/xml/shortcuts.xml` - 定义静态快捷方式配置
     - 修改 `MainActivity.kt` - 新增 `updateAppTitle()` 方法，使用 `ShortcutManager.updateShortcuts()` API
     - 修改 `AndroidManifest.xml` - 添加 `android:allowBackup="true"` 和 shortcuts 元数据
     - `i18n_service.dart` 在语言切换时触发 `updateAppTitle()` 调用
   - **工作原理**：
     - Android 7.1 (API 25+)：使用 `ShortcutManager.updateShortcuts()` 动态更新快捷方式标签，会反映到桌面 App 名称
     - 旧版本 Android：尝试切换 Component 启用状态来刷新标题
     - 标题资源在 `values/strings.xml`、`values-zh/strings.xml`、`values-zh-rTW/strings.xml` 中定义
   - **限制**：
     - 不同 Android 启动器有不同的缓存策略
     - 某些启动器可能需要重新启动 App 或滑动移除后再重新添加才能看到标题更新

**关键代码位置**：
- `modules/i18n/lib/i18n_service.dart` - 核心国际化服务
- `modules/i18n/lib/translations.dart` - 翻译文本定义
- `modules/flutter_bridge/lib/src/bridge_controller.dart` - 桥接控制器中的 i18n 集成
- `android/app/src/main/kotlin/club/aiiko/trip/MainActivity.kt` (`updateAppTitle()` 方法)
- `android/app/src/main/res/xml/shortcuts.xml`
- `android/app/src/main/AndroidManifest.xml`

### 通知点击和自动关闭功能

**功能概述**：实现了完整的通知交互功能，包括点击通知打开 App 和自动关闭机制

**核心修改**：

1. **NotificationService 增强** (`modules/flutter_bridge/lib/src/services/notification_service.dart`)：
   - 添加 `onDidReceiveNotificationResponse` 回调处理通知点击事件
   - 创建 `_onNotificationClicked()` 方法，通过 MethodChannel 调用 Android 原生方法打开 App
   - 添加 `showNotificationWithAutoClose()` 方法，支持指定延时自动关闭通知（默认 4000ms）

2. **MainActivity 扩展** (`android/app/src/main/kotlin/club/aiiko/trip/MainActivity.kt`)：
   - 添加新的 MethodChannel `notification_click`
   - 添加 `openApp()` 方法，通过 Intent 打开 MainActivity
   - 设置 `FLAG_ACTIVITY_NEW_TASK` 和 `FLAG_ACTIVITY_CLEAR_TOP` 标志

**通知行为规则**：

| 通知类型 | 点击行为 | 自动关闭 |
|----------|----------|----------|
| 常驻通知（后台定位） | 打开 App | ❌ 不关闭 |
| 非常驻通知（定位开启/关闭、屏幕常亮开启/关闭） | 打开 App | ✅ 4秒后自动关闭 |

**自动关闭通知列表**：
- 定位开启通知（ID: 1）
- 定位关闭通知（ID: 1）
- 屏幕常亮开启通知（ID: 2）
- 屏幕常亮关闭通知（ID: 2）

**常驻通知列表**：
- 后台定位通知（由 Android 前台服务管理）

**关键代码位置**：
- `modules/flutter_bridge/lib/src/services/notification_service.dart`
- `android/app/src/main/kotlin/club/aiiko/trip/MainActivity.kt`（`openApp()` 方法和 `NOTIFICATION_CLICK_CHANNEL`）

### 状态栏动态变化功能

**功能概述**：前端通过 `setStatusBar` 消息动态控制 Android 系统状态栏的样式和显示模式

**支持的类型**：
| 类型 | 状态栏颜色 | 图标颜色 | SystemUiMode | SafeArea |
|------|------------|----------|--------------|----------|
| `system` | 透明 | 跟随系统 | edgeToEdge | ✅ 启用 |
| `light` | 白色 (#FFFFFF) | 黑色 | edgeToEdge | ✅ 启用 |
| `dark` | 黑色 (#000000) | 白色 | edgeToEdge | ✅ 启用 |
| `transparent` | 半透明黑色 (50% opacity) | 白色 | edgeToEdge | ✅ 启用 |
| `hide` | 隐藏 | 隐藏 | immersiveSticky | ❌ 禁用 |
| `transparent-light` | 完全透明 | 黑色 | edgeToEdge | ❌ 禁用 |
| `transparent-dark` | 完全透明 | 白色 | edgeToEdge | ❌ 禁用 |

**消息格式**：
```json
{
  "type": "setStatusBar",
  "payload": "light"
}
```

**消息流向**：
```
前端 → BridgeController → SystemChrome.setSystemUIOverlayStyle()
                                   ↓
                          同时更新 SafeAreaTop 状态
```

**关键代码位置**：
- `modules/flutter_bridge/lib/src/bridge_controller.dart` (`_handleSetStatusBar()` 方法)
- `lib/main.dart` (`_statusBarHandlerListener()` 和 `SafeArea` 控制)

### 比亚迪车机日志系统

**功能概述**：为比亚迪车机相关代码添加完整的日志系统，通过 `bydLog` 消息类型发送给前端，便于调试和问题排查

**日志来源**：
1. **BYDAutoVehicleService.kt** - 车辆服务初始化、设备启动/停止、数据更新
2. **BydApiReflectHelper.kt** - 反射 API 调用（参数、返回值、异常）
3. **vehicle_service.dart** - Flutter 层方法调用、数据解析

**新增方法**：
- `BYDAutoVehicleService.sendBydLogToFlutter()` - 通过 MethodChannel 发送日志到 Flutter
- `VehicleService._handleMethodCall()` - 新增 `onBydLog` case 处理

**日志流向**：
```
Android 原生层
   ↓ MethodChannel: onBydLog
Flutter 层 (VehicleService)
   ↓ BridgeController().sendMessage('bydLog', ...)
前端网页
```

**日志内容**：
- 服务初始化状态
- 设备连接/断开事件
- 权限检查结果
- 数据变化监听回调
- 反射 API 调用详情
- JSON 数据解析过程
- 所有异常堆栈信息

**异常类型细化**（BydApiReflectHelper）：
- `ClassNotFoundException` - 类未找到
- `NoSuchMethodException` - 方法未找到
- `IllegalAccessException` - 访问权限被拒绝
- `InvocationTargetException` - 内部异常（包含 cause）
- `Exception` - 其他未知异常

**关键代码位置**：
- `android/app/src/main/kotlin/club/aiiko/trip/BYDAutoVehicleService.kt`
- `android/app/src/main/kotlin/club/aiiko/trip/BydApiReflectHelper.kt`
- `modules/flutter_bridge/lib/src/services/vehicle_service.dart`

### 本地服务器端口区分

**功能概述**：本地静态服务器在不同构建环境下使用不同端口，便于本地网站在线调试

**端口配置**：

| 环境 | 端口 | 说明 |
|------|------|------|
| 开发环境 (`kDebugMode`) | **13218** | `flutter run` 时使用 |
| 生产环境 (`kReleaseMode`) | **13219** | `flutter run --release` 或打包时使用 |

**实现方式**：
- 使用 `flutter/foundation.dart` 中的 `kDebugMode` 判断当前环境
- `LocalServer` 构造函数中根据环境选择端口
- 添加 `port` getter 暴露端口值

**涉及文件**：
- `lib/local_server.dart` - 添加 `port` getter 和环境判断
- `lib/main.dart` - 传递 `serverPort` 到 Android 端
- `GeckoViewPlatform.kt` - 接收 `serverPort` 参数用于 JS Bridge

**本地调试配置**：
如需连接远程开发服务器，可直接修改 `local_server.dart` 中的 `url` getter：
```dart
String get url => 'http://192.168.0.112:23202';  // 远程调试地址
```

### 状态栏数据获取接口

**功能概述**：前端通过 `getStatusBarData` 消息获取当前状态栏高度、屏幕尺寸等数据

**消息格式**：

前端发送：
```json
{
  "type": "getStatusBarData",
  "payload": null
}
```

Flutter 返回：
```json
{
  "type": "getStatusBarData",
  "payload": {
    "statusBarHeight": 44,
    "statusBarHeightRaw": 46.769,
    "bottomPadding": 34,
    "bottomPaddingRaw": 34.0,
    "viewPaddingTop": 44,
    "viewPaddingBottom": 34,
    "viewInsetsTop": 0,
    "viewInsetsBottom": 0,
    "screenWidth": 390,
    "screenHeight": 844,
    "physicalWidth": 1170,
    "physicalHeight": 2532,
    "devicePixelRatio": 3.0,
    "isDarkMode": false,
    "safeAreaTop": 44,
    "safeAreaBottom": 34
  }
}
```

**返回字段说明**：

| 字段 | 说明 | 单位 |
|------|------|------|
| `statusBarHeight` | 状态栏高度（取整后） | 逻辑像素 |
| `statusBarHeightRaw` | 状态栏高度（原始值） | 逻辑像素 |
| `bottomPadding` | 底部安全区域高度（取整后） | 逻辑像素 |
| `viewPaddingTop/Bottom` | 视图内边距 | 逻辑像素 |
| `viewInsetsTop/Bottom` | 视图插入区域（如软键盘） | 逻辑像素 |
| `screenWidth/Height` | 屏幕宽高（逻辑像素） | 逻辑像素 |
| `physicalWidth/Height` | 屏幕物理像素宽高 | 物理像素 |
| `devicePixelRatio` | 设备像素比 | - |
| `isDarkMode` | 是否深色模式 | Boolean |

**关键代码位置**：
- `modules/flutter_bridge/lib/src/bridge_controller.dart` (`_handleGetStatusBarData()` 方法)

### App 自动更新系统

**功能概述**：实现了完整的自动更新功能，包括版本检查、下载、安装流程

**核心组件**：

1. **UpdateService** (`modules/flutter_bridge/lib/src/services/update_service.dart`)：
   - `checkNewVersion()` - 检查最新版本（从 GitHub releases 页面解析）
   - `downloadAndInstall()` - 下载 APK 并触发安装
   - `_cleanupOldApks()` - 清理旧的 APK 文件

2. **更新检查触发** (`modules/flutter_bridge/lib/src/bridge_controller.dart`)：
   - `_handleCheckNewVersion()` - 处理前端发来的检查更新消息
   - 支持 `showCheckingNotification` 参数控制是否显示检查中对话框

**消息格式**：

前端发送：
```json
{
  "type": "checkNewVersion",
  "payload": {
    "showCheckingNotification": true
  }
}
```

- `showCheckingNotification: true` - 主动检查（用户点击），显示检查中对话框和结果对话框
- `showCheckingNotification: false` - 静默检查（后台自动），仅当发现新版本时显示对话框

Flutter 返回：
```json
{
  "type": "updateAvailable",
  "payload": {
    "version": "1.0.6",
    "downloadUrl": "https://github.com/..."
  }
}
// 或
{
  "type": "updateNotAvailable",
  "payload": {
    "currentVersion": "1.0.5"
  }
}
```

**对话框逻辑**：

| showCheckingNotification | 检查中对话框 | 已是最新版对话框 | 发现新版本对话框 |
|-------------------------|-------------|----------------|----------------|
| true                    | ✅ 显示      | ✅ 显示          | ✅ 显示          |
| false                   | ❌ 不显示    | ❌ 不显示        | ✅ 显示          |

**国际化文案**：

- `update_checking` / `update_checking_title` - 检查中对话框
- `update_available` - 发现新版本标题（如：发现新版本 {version}）
- `update_available_content` - 发现新版本内容（如：您的应用需要更新以获取最新功能和优化）
- `update_now` - 立即更新按钮
- `update_skip` - 跳过此版本按钮
- `update_no_new_version_title` / `update_no_new_version_content` - 已是最新版本对话框

**APK 文件管理**：

- **启动时清理**：应用启动时自动清理下载目录下的旧 APK 文件
- **下载前清理**：每次下载新版本前清理旧的 APK 文件
- **安装后不删除**：由于 Android 系统限制无法检测安装结果，启动时会清理旧的安装包

**下载进度通知**：

- 通知 ID：1001
- 进度通知显示当前下载百分比
- 下载完成通知可点击触发安装（仅在 100% 时生效）
- 点击非 100% 通知无任何效果

**关键代码位置**：
- `modules/flutter_bridge/lib/src/services/update_service.dart`
- `modules/flutter_bridge/lib/src/bridge_controller.dart` (`_handleCheckNewVersion()`)
- `modules/flutter_bridge/lib/src/services/notification_service.dart`
- `modules/i18n/lib/translations.dart` (更新相关文案)

**⚠️ 待测试验证**：
- 自动更新系统的完整流程需要在真实设备上测试
- APK 下载和安装功能需要验证
- 通知点击安装功能需要验证

## 待解决问题

### ✅ 已解决问题

1. **bridgeId 消息传递问题**（已解决）：
   - **问题**：前端发送消息包含 `bridgeId`，Flutter 返回时未正确传递，导致前端无法匹配响应
   - **原因**：GeckoView 执行 JS 时，JSON 字符串未用引号包裹，导致 JS 解析错误
   - **修复**：
     - JSON 字符串用单引号包裹
     - 转义 JSON 字符串中的单引号
   - **关键代码**：`GeckoViewPlatform.kt` 的 `postMessage` 方法

2. **热更新进度 UI 更新问题**（已解决）：
   - **问题**：进度在更新但对话框 UI 不刷新
   - **原因**：`showDialog` 创建的对话框捕获初始状态，外部 setState 无法触发对话框内部重建
   - **修复**：使用 `ValueNotifier` + `ValueListenableBuilder` 实现对话框内部状态更新

3. **重启 App 闪退问题**（已解决）：
   - **问题**：调用 `restartApp` 时 App 直接闪退
   - **原因**：Alarm 方式重启不稳定
   - **修复**：改为直接 `startActivity` + `System.exit(0)`

4. **混合内容访问问题**（已解决）：
   - **问题**：HTTPS 页面无法访问 localhost 的 HTTP 资源
   - **修复**：在 GeckoView 设置 `javaScript.setAllowInsecureConnections(GeckoRuntimeSettings.ALLOW_ALL)`

5. **外接充电量数据获取**（✅ 已实现）：
   - 通过 `AbsBYDAutoInstrumentListener` 监听 `onExternalChargingPowerChanged` 事件
   - 整合到 `carData` 中，字段名为 `externalChargingPower`
   - 详见"比亚迪车辆数据功能"章节

### ⚠️ 待测试验证

1. **热更新功能完整流程**：
   - 下载进度显示（包括字节数）
   - 解压进度显示
   - 资源替换后加载效果
   - 前端决定是否重启 App

2. **restartApp 和 quitApp 可靠性**：
   - 重启是否能正确恢复状态
   - quitApp 是否彻底关闭进程

3. **switchResources 域名切换**：
   - 持久化存储是否正常
   - 下次启动是否正确加载上次选择的域名
   - 云端域名访问时 JS Bridge 是否正常工作

### 🚧 开发中/待排查

1. **比亚迪车机 API 数据获取问题**：
   - 权限检查通过但无法获取车辆数据
   - 可能原因：
     - 签名不匹配（车机使用自定义签名而非标准平台签名）
     - 包名未在车机白名单中
     - API 调用方式不正确
   - 已新增完整日志系统（通过 `bydLog` 消息），便于调试
   - 待在真实比亚迪车机上进行测试验证

2. **输入法收起后底部黑色区域问题**：
   - 已在 `GeckoViewWrapper` 中添加键盘变化监听器
   - 输入法收起时强制刷新布局
   - 需实际测试验证效果

3. **前台服务与 MIUI 兼容性问题**（⚠️ 开发中）：
   - `flutter_foreground_task` 插件与 MIUI 系统不兼容
   - 症状：调用 `FlutterForegroundTask.startService()` 时触发 MIUI 系统日志权限检查，导致 `Process is going to kill itself!` 崩溃
   - 当前状态：**前台服务已暂时禁用**
   - 状态检测逻辑仍然正常工作，可以确保 App 返回时正确恢复状态

4. **定位数据数量不一致问题**（⚠️ 开发中）：
   - **现象**：前端开启定位和后台定位后，前端显示定位数量（3557）与后台通知显示的定位计数（2843）不一致
   - **差距**：约 714 个，差距约 20%
   - **可能原因**：
     - Flutter Geolocator 在后台模式下被系统节流
     - 某些位置更新因精度不够被丢弃
     - `sendMessage` 到前端过程中有消息丢失
     - 前端接收到消息但某些原因未计入
   - **当前状态**：正在排查中
   - **定位任务分析**：
     - `enableLocation` 和 `enableBackgroundLocation` 共用同一个 `Geolocator.getPositionStream` stream
     - 定位任务只有一条，不会重复创建

5. **标签页回主页动画卡顿问题**（⚠️ 开发中）：
   - **现象**：使用 `AnimatedSize` 实现 header 高度过渡动画时，动画不够丝滑，有卡顿
   - **原因分析**：`AnimatedSize` 在 Column 中可能导致整个布局树重新计算，影响性能
   - **当前状态**：已实现但效果不理想，待优化

---

## 前端 JS Bridge SDK 新增方法

**功能概述**：实现了前端 SDK 新增的完整方法集，支持域名切换、本地资源热更新、App 重启等功能

**新增方法**：

| 方法名 | 功能说明 |
|--------|----------|
| `switchResources` | 切换主页域名（本地静态服务/云端），持久化存储用户选择 |
| `updateLocalWebResources` | 下载并切换本地静态资源（热更新），显示下载和解压进度 |
| `restartApp` | 重启 App |
| `quitApp` | 关闭 App |
| `sendNotification` | 发送通知 |
| `cancelNotification` | 取消指定通知 |

### switchResources - 域名切换

**消息格式**：
```json
{
  "type": "switchResources",
  "payload": "https://trip.aiiko.club"
}
```

**功能**：
- 切换 WebView 加载的主页地址
- 支持本地服务器地址（如 `http://localhost:13218`）和云端地址
- 使用 `SharedPreferences` 持久化存储用户选择的域名
- 下次启动时自动加载上次选择的域名

**关键代码位置**：
- `modules/flutter_bridge/lib/src/bridge_controller.dart` (`_handleSwitchResources()`)

### updateLocalWebResources - 热更新

**消息格式**：
```json
{
  "type": "updateLocalWebResources",
  "payload": "https://trip.aiiko.club/packages/static/trip-route-track-web-1.0.45-build.tgz"
}
```

**热更新流程**：
1. **下载阶段**：从指定 URL 下载 `.tgz` 压缩包
2. **解压阶段**：解压下载的文件到临时目录
3. **替换阶段**：删除旧的静态资源，将解压的文件重命名为新的资源目录
4. **通知阶段**：发送完成消息，前端决定是否重启 App

**进度消息类型**：
```json
// 下载中
{"type": "updateLocalWebResourcesDownloading", "payload": {"progress": 50}}

// 解压中
{"type": "updateLocalWebResourcesExtracting", "payload": {"progress": 30}}

// 完成
{"type": "updateLocalWebResourcesCompleted", "payload": {"success": true}}
```

**UI 进度显示**：
- 使用 `AlertDialog` 显示进度对话框
- 使用 `ValueNotifier` + `ValueListenableBuilder` 实现进度实时更新
- 下载阶段显示：下载进度百分比 + 已下载/总大小（格式化显示 B/KB/MB/GB）
- 解压阶段显示：解压进度百分比

**本地服务器适配**：
- 优先从 `static_resources` 目录加载资源
- 不存在时回退到 `assets/out/` 目录
- 支持 URL 解码和路径匹配

**关键代码位置**：
- `modules/flutter_bridge/lib/src/bridge_controller.dart` (`_handleUpdateLocalWebResources()`)
- `lib/main.dart` (进度对话框 UI)
- `lib/local_server.dart` (资源加载优先级)

**依赖新增**：
- `archive: ^3.6.0` - 用于解压 `.tgz` 压缩包

### restartApp 和 quitApp - App 控制

**实现方式**：调用 Android 原生方法

**MainActivity.kt 新增方法**：
```kotlin
private fun restartApp() {
    val intent = Intent(this, MainActivity::class.java)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    startActivity(intent)
    System.exit(0)
}

private fun quitApp() {
    Process.killProcess(Process.myPid())
}
```

**问题修复**：
- **原问题**：使用 Alarm 方式重启不稳定，容易失败
- **修复**：改为直接 startActivity 然后 System.exit(0)，更可靠

### sendNotification 和 cancelNotification - 通知控制

**sendNotification 消息格式**：
```json
{
  "type": "sendNotification",
  "payload": {
    "id": 123,
    "title": "通知标题",
    "body": "通知内容",
    "ongoing": false,
    "autoCloseTimeout": 4000
  }
}
```

**cancelNotification 消息格式**：
```json
{
  "type": "cancelNotification",
  "payload": 123
}
```

### bridgeId 机制调整

**问题**：前端 SDK 将消息中的 `__bridgeId` 改为 `bridgeId`，Flutter 端需要适配

**修改内容**：
- `BridgeMessage` 类：`__bridgeId` 字段改为 `bridgeId`
- 所有消息收发逻辑使用 `bridgeId` 而非 `__bridgeId`
- 保持向后兼容：如果消息中有 `__bridgeId` 也能正确解析（已验证不需要）

**关键代码位置**：
- `modules/flutter_bridge/lib/src/bridge_message.dart`

### 混合内容访问问题

**问题**：当切换到云端 HTTPS 域名时，页面需要访问 localhost 的 HTTP 资源（JS Bridge），浏览器会阻止混合内容请求

**解决方案**：
- 在 `GeckoViewPlatform.kt` 中设置 GeckoRuntime 允许混合内容
```kotlin
settings.javaScript.setAllowInsecureConnections(GeckoRuntimeSettings.ALLOW_ALL)
```
- 这样 HTTPS 页面可以正常访问 `http://localhost:13218/__flutter_bridge__`

### 第三方登录功能（Google Sign-In）

**功能概述**：实现了完整的第三方登录功能，支持通过 JS Bridge 调用原生 Google 登录，登录成功后返回用户信息和 token

**支持的登录类型**：
- ✅ Google 登录（已实现）
- ⚠️ QQ 登录（预留位置）
- ⚠️ GitHub 登录（预留位置）

**消息格式**：

前端发送：
```json
{
  "type": "thirdPartyLogin",
  "payload": {
    "loginType": "google"
  },
  "bridgeId": "xxx"
}
```

Flutter 返回（成功）：
```json
{
  "type": "thirdPartyLogin",
  "payload": {
    "success": true,
    "data": {
      "type": "google",
      "idToken": "xxx",
      "accessToken": "",
      "user": {
        "id": "115995855783961453134",
        "name": "Aiiko Shiina",
        "email": "shiina.aiiko@gmail.com",
        "avatar": "https://lh3.googleusercontent.com/..."
      }
    }
  },
  "bridgeId": "xxx"
}
```

Flutter 返回（失败）：
```json
{
  "type": "thirdPartyLogin",
  "payload": {
    "success": false,
    "error": "10: "
  },
  "bridgeId": "xxx"
}
```

**核心实现**：

1. **前端 JS Bridge** (`web/plugins/reactNativeWebJsBridge.ts`)：
   - 定义 `ThirdPartyLoginType` 枚举（google/qq/github）
   - 定义 `ThirdPartyLoginResult` 类型
   - 添加 `thirdPartyLogin()` 方法

2. **Flutter Bridge** (`modules/flutter_bridge/lib/src/bridge_controller.dart`)：
   - 添加 `thirdPartyLogin` 消息处理 case
   - 通过 MethodChannel 调用 Android 原生登录方法
   - 将登录结果返回给前端

3. **Android 原生** (`MainActivity.kt`)：
   - 添加 Google Sign-In 依赖 (`play-services-auth:21.2.0`)
   - 初始化 GoogleSignInClient
   - 实现 `handleThirdPartyLogin()` 方法
   - 处理登录回调 `onActivityResult()`

**环境变量配置**（`.env`）：
```bash
# Google Sign-In Client IDs
GOOGLE_CLIENT_ID_DEV=xxx.apps.googleusercontent.com  # Android 客户端 ID（开发）
GOOGLE_CLIENT_ID_PROD=xxx.apps.googleusercontent.com  # Android 客户端 ID（生产）
GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com   # Web 客户端 ID（用于获取 idToken）
```

**关键代码位置**：
- `web/plugins/reactNativeWebJsBridge.ts` - 前端 JS Bridge SDK
- `modules/flutter_bridge/lib/src/bridge_controller.dart` - Flutter 消息处理
- `android/app/src/main/kotlin/club/aiiko/trip/MainActivity.kt` - Android 原生登录实现
- `android/app/build.gradle` - 依赖配置和环境变量读取
- `.env` - 环境变量配置

**注意事项**：
- 获取 `idToken` 需要使用 Web 客户端 ID，而非 Android 客户端 ID
- 需要在 Google Cloud Console 中配置正确的 SHA-1 指纹和包名
- 开发环境和生产环境使用不同的 Android 客户端 ID
- QQ 和 GitHub 登录已预留位置，可根据需求添加对应的 SDK

---

## App 前后台切换状态检测与恢复机制

### 功能概述

实现了一套完整的 App 前后台切换状态检测与恢复机制，确保 App 在后台被系统回收后重新进入时能够正确恢复状态，同时最大化保留用户操作状态。

### 核心组件

**静态持久化变量**（防止 Widget 重建时状态丢失）：
```dart
static bool _isLoadingStatic = true;
static bool _isPageLoadedStatic = false;
static LoadingStep _loadingStepStatic = LoadingStep.initial;
static List<String> _loadingLogStatic = [];
static DateTime? _lastBackgroundTimeStatic;
static bool _isInBackgroundStatic = false;
static DateTime? _lastRecoveryTimeStatic;
static bool _isRecoveringStatic = false;
static bool _kernelHealthyStatic = false;
```

**关键检测方法**：
- `LocalServer.instance.checkServerHealth()` - 检测 LocalServer 服务健康状态
- `checkKernelHealth()` - 检测 GeckoView 内核健康状态（调用原生 `checkSessionsHealth` 方法）

### 检测逻辑

```dart
Future<void> _checkAndRecoverState() async {
  // 1. 检测 LocalServer 服务状态
  final serverHealthy = LocalServer.instance.checkServerHealth();

  // 2. 检测 GeckoView 内核状态（调用原生方法检测所有 session 是否有效）
  final kernelHealthy = await checkKernelHealth();

  // 3. 任一不健康时触发恢复
  if (!serverHealthy || !kernelHealthy) {
    await _performRecovery();
  }
}
```

### 原生端 checkSessionsHealth 方法

**GeckoViewPlatform.kt** 中添加了 `checkSessionsHealth` 方法：

```kotlin
"checkSessionsHealth" -> {
    Log.d(TAG, "checkSessionsHealth called, tabCount: ${tabManager.tabCount}")
    val sessionsValid = tabManager.tabStack.all { tab ->
        try {
            tab.session.isOpen
        } catch (e: Exception) {
            Log.e(TAG, "Session check failed: ${e.message}")
            false
        }
    }
    Log.d(TAG, "checkSessionsHealth result: $sessionsValid, tabCount: ${tabManager.tabCount}")
    result.success(sessionsValid && tabManager.tabCount > 0)
}
```

### Flutter 端 checkKernelHealth 方法

```dart
Future<bool> checkKernelHealth() async {
    _kernelHealthyStatic = _channel != null;
    if (!_kernelHealthyStatic) return false;

    try {
        final result = await _channel!.invokeMethod<bool>('checkSessionsHealth');
        _kernelHealthyStatic = result ?? false;
        print('[NYANYA-KERNEL] checkSessionsHealth result: $_kernelHealthyStatic');
    } catch (e) {
        print('[NYANYA-KERNEL] checkSessionsHealth failed: $e');
        _kernelHealthyStatic = false;
    }

    return _kernelHealthyStatic;
}
```

### 日志前缀

| 标识 | 含义 |
|------|------|
| `[NYANYA-LIFECYCLE]` | 生命周期状态变化 |
| `[NYANYA-CHECK]` | 状态检测结果 |
| `[NYANYA-SERVER]` | LocalServer 服务日志 |
| `[NYANYA-RECOVERY]` | 恢复操作日志 |
| `[NYANYA-FGS]` | 前台服务日志（暂时禁用） |
| `[NYANYA-INIT]` | initState 日志 |

### AndroidManifest.xml 修改

**服务配置**：
```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="specialUse"
    android:exported="false"
    android:stopWithTask="false">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Keep app alive in background" />
</service>
```

**说明**：`stopWithTask="false"` 确保当用户从最近任务中划掉 App 时，前台服务不会自动停止。

### 关键代码位置

- `lib/main.dart` - 状态检测逻辑、生命周期管理
- `lib/local_server.dart` - LocalServer 服务健康检测
- `android/app/src/main/AndroidManifest.xml` - 前台服务配置

### 前台服务状态

| 组件 | 状态 |
|------|------|
| flutter_foreground_task 插件 | ⚠️ 暂时禁用（MIUI 不兼容） |
| 状态检测逻辑 | ✅ 正常工作 |
| stopWithTask 属性 | 已设置为 false |

---

## v1.0.9 更新内容

### 内部网站 URL 统一替换功能

**功能概述**：当检测到用户访问内部网站（localhost:13218/13219/13220）时，将显示用 URL 统一替换为 `trip.aiiko.club`，提升用户体验。

**实现细节**：

1. **URL 检测逻辑**：
   - 检测 `localhost:13218`、`localhost:13219`、`localhost:13220`
   - 检测 `127.0.0.1:13218`、`127.0.0.1:13219`、`127.0.0.1:13220`

2. **URL 替换规则**：
   - 原：`http://localhost:13218/zh-CN/trip`
   - 显：`https://trip.aiiko.club/zh-CN/trip`

3. **回调机制**：
   - `LocalServer.onUrlChange` 回调在 URL 变化时被触发
   - 替换后的 URL 和标题会同步到 Tab 状态

**关键代码位置**：
- `lib/main.dart` - `onUrlChange` 回调处理

### GeckoRuntime 重启增强

**问题**：当 GeckoView 内核不健康时，直接重启可能仍使用旧的 Runtime 实例，导致恢复失败。

**解决方案**：

1. **新增 `shutdownGeckoRuntime` 方法**：
   - 在 Flutter 端通过 MethodChannel 调用原生方法
   - 原生端调用 `GeckoRuntime.shutdown()` 并清理实例

2. **恢复流程优化**：
   ```dart
   // 步骤0: 如果 GeckoView 内核不健康，先清理旧的 GeckoRuntime
   final kernelHealthy = await checkKernelHealth();
   if (!kernelHealthy) {
     await _channel?.invokeMethod('shutdownGeckoRuntime');
     await Future.delayed(const Duration(milliseconds: 100));
   }
   // 然后继续正常恢复流程...
   ```

**关键代码位置**：
- `android/app/src/main/kotlin/club/aiiko/trip/GeckoViewPlatform.kt` - `shutdownRuntime()` 函数
- `lib/main.dart` - `_performRecovery()` 中的提前清理逻辑

### checkGeckoViewReady 方法

**功能**：检测 GeckoView 是否已准备好接受操作，用于更精确的状态判断。

**检测项**：
| 检测项 | 说明 |
|--------|------|
| runtimeExists | GeckoRuntime 实例存在且未关闭 |
| sessionExists | 当前 Session 存在 |
| isSessionOpen | Session 处于打开状态 |
| viewAttached | GeckoView 已附加到窗口 |

**返回值**：只有所有检测项都为 `true` 时，才认为 GeckoView 已准备好。

**关键代码位置**：
- `android/app/src/main/kotlin/club/aiiko/trip/GeckoViewPlatform.kt` - `checkGeckoViewReady` 方法

### GeckoRuntime 单例创建优化

**问题**：`Only one GeckoRuntime instance is allowed` 异常可能导致 App 崩溃。

**解决方案**：

1. **双重检查锁模式**：
   - 第一次检查：快速判断是否已存在可用实例
   - 同步块内第二次检查：确保线程安全

2. **异常捕获**：
   - 捕获 `Only one GeckoRuntime instance is allowed` 异常
   - 认为是正常情况，复用已有实例

```kotlin
if (geckoRuntime != null && !isRuntimeShutdown) {
    return geckoRuntime!!
}
synchronized(this) {
    if (geckoRuntime != null && !isRuntimeShutdown) {
        return geckoRuntime!!
    }
    try {
        // 创建新的 GeckoRuntime...
    } catch (e: Exception) {
        if (e.message?.contains("Only one GeckoRuntime instance is allowed") == true) {
            isRuntimeShutdown = false
            return geckoRuntime!!
        }
        throw e
    }
}
```

### 版本信息

| 项目 | 值 |
|------|------|
| App 版本 | v1.0.9 (1.0.9+98) |
| 发布日期 | 2026-05-21 |
| release.sh 版本 | v1.0.9 |

### i18n 翻译更新

**变更内容**：
| Key | zh-CN | en-US | zh-TW |
|-----|-------|-------|-------|
| loading_subtitle | 由 Vibe Coding 构建 | Built with Vibe Coding | 由 Vibe Coding 建構 |
| update_skip | 下次再说 | - | 下次再說 |

### 自动更新服务优化

**变更**：移除下载前清理旧 APK 文件的逻辑

**原因**：避免在下载过程中删除正在使用的 APK 文件导致问题

---

## 当前未解决的问题

1. **比亚迪车机 API 数据获取**：
   - 权限检查通过但无法获取车辆数据
   - 需要在真实车机环境测试验证

2. **定位数据数量不一致**：
   - 前端显示与后台通知显示数量存在差距（约 20%）
   - 可能原因：系统节流、消息丢失、前端未计入

3. **前台服务 MIUI 兼容性**：
   - `flutter_foreground_task` 插件与 MIUI 系统不兼容
   - 已暂时禁用前台服务
