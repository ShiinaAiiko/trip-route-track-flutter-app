# AGENTS.md — trip-route-track-flutter-app

Android 应用。本质是**一个 WebView 壳**：用本地 shelf 服务器伺服 `../trip-route-track-web` 的静态导出，再通过 JS Bridge 把设备能力（GPS、通知、车机数据、TTS、登录）暴露给网页。

**全部业务逻辑和产品页面都在 `../trip-route-track-web`，本项目里没有。** 当前 `lib/models/` 只有一个 19 行的 `loading_log.dart`；全项目对 `protobuf`/`zstd`/`fixnum` 的引用是 **0 命中**；没有任何地图依赖。要改功能行为，先判断它该活在哪一端。

> 本目录另有一份 `context.md`（317 行）是历史积累的 AI 说明文件。它的**结构和模块说明大体可用**，但以下条目已被核实为过时或错误，以本文件为准：
> - 「自动更新源 GitHub Releases」→ **错**。实际是自托管 `https://trip.aiiko.club/packages/?format=json`
> - 「Shadcn UI 版本 0.5.7」→ pubspec 写的是 `^0.5.0`，且 `pubspec.lock` 被 gitignore，版本在静默漂移
> - 「App 版本 v1.0.13 / 2026-05-26」→ 过期。pubspec 是 `1.1.1+984`，`release.sh` 是 `v1.1.2`，`README.md` 是 `v1.0.14`，三处互相矛盾，tag 停在 `v1.0.25`
> - `android/.../club/aiiko/trip/GeckoViewPlatform.kt` → **该文件不存在**（该目录只有 6 个 .kt）
> - 「你只允许修改当前目录下的文件，切勿触及或提及任何父级或同级目录」→ 与实际不符：`pubspec.yaml` 的 `dependency_overrides` 指向仓库外的 `../../../lib/nyanya-webview`，不提及就无法理解构建

## 1. 构建前提（不满足就 `pub get` 失败，别怀疑代码）

- **当前分支是 `2.x.x`，不是 `main`。** 动手前先确认自己在哪条线上。
- `pubspec.yaml` 有 `dependency_overrides: nyanya_webview: path: ../../../lib/nyanya-webview`，解析到 `OpenSourceProject/lib/nyanya-webview` —— **在 `nyanya/` 之外，且它本身是另一个仓库的 git 子模块**。干净克隆无法 `pub get`。
- `assets/out/` 被 gitignore，但 `pubspec.yaml` 里有 **47 条硬编码 `assets/out/...` 条目**（含构建 ID `JXQ8cb7m0SKqMgQNzYYCz`）。**没有本地 web 导出就无法构建。**
- 只有 Android。没有 `ios/`；`linux/` 是死的模板目录。

## 2. 两条互相独立的 flavor 轴（这是最容易搞混的地方）

| 轴 | 载体 | 取值 | 作用 |
|---|---|---|---|
| Gradle `environment` | `android/app/build.gradle:104` | `dev`(后缀 `.dev`) / `beta`(`.test`) / prod | 包名、签名、Gradle 侧依赖 |
| Dart define | `--dart-define=APP_FLAVOR=` | 决定端口 `13218`/`13219`/`13220`/`13221`（`lib/local_server.dart:29-56`） | 本地服务器端口与主机 |
| 环境变量 | `build.gradle:88-90` `VERSION_TYPE` | `android` 默认 | 写进 `BuildConfig.VERSION_TYPE` |

**关键后果**：`VERSION_TYPE` 是环境变量而不是 flavor，所以**每一个产物都带着 BYD 车机代码和 43 条 BYDAUTO 权限**。目前打不出一个"没有 BYD、没有自更新"的包 —— 这是上架 Google Play 的首要阻塞项（见 §6）。

## 3. 代码规模与真实结构

Dart 约 11,600 行（48 文件）· Kotlin 6,565 行（6 文件 + 1 个死模板 stub）。

```
lib/main.dart                        1,707 行  入口：MyApp→ShadApp→ShadToaster→WebViewContainer→NyaNyaWebview
lib/local_server.dart                  357 行  shelf 静态服务器（100% WebView 专用）
modules/flutter_bridge/              7,905 行  33 个 Dart 文件（见下）
modules/app_update/                    939 行  自托管 APK 更新器
modules/i18n/                          407 行  3 语言 × ~88 key
android/app/src/main/kotlin/club/aiiko/trip/
  BYDAutoVehicleService.kt           4,360 行  111 个函数，BYD 车机 OpenAPI
  MainActivity.kt                    1,170 行  10 个 MethodChannel
  TestBYDAutoVehicleService.kt         595 行  模拟车机数据
  FileLogHelper.kt                     207 行
  BydApiReflectHelper.kt               139 行  ← 反射调用隐藏 API，见 §6
  BackgroundService.kt                  89 行  不采集位置，只为持有进程 + 常驻通知
```

`modules/flutter_bridge/` 的实际情况：`lib/flutter_bridge.dart` 只导出 6 个文件，但 `lib/main.dart` 和 `lib/local_server.dart` **深导入 `package:flutter_bridge/src/...`**（5 处）—— 所谓公开 API 是假的。

`src/bridge_controller.dart` **3,608 行、110 个方法、单个手工单例、20 个注入服务、无接口**。粗略分类：约 1,150–1,250 行是 WebView 专用管道，约 450 行是车机字符串分发胶水，约 1,900–2,000 行是真能力 —— 但每块方法体里都硬写着 `sendMessage(...)`，**只能剪切粘贴复用，不能链接复用**。

`src/services/vehicle/` 的 18 个 `*_service.dart`（约 870 行）是机械克隆：单例 + `MethodChannel('byd_vehicle')` + broadcast `StreamController` + `setupListener/get/enableListener/dispose`。`car_data_types.dart`（1,369 行，20 个纯数据类）**零 WebView 耦合，是干净的**。

## 4. 必须了解的既有缺陷（改相关区域前先看）

| 位置 | 问题 |
|---|---|
| `lib/main.dart:269` | `static const int _maxRetriesStatic = 0` → `_handleLoadFailure` **永不重试**，却仍打印「重试 n/0」，然后无条件 `restartApp()` |
| `lib/main.dart:339-340` | 注释写「超时时间延长到15秒」，下一行实际是 `Timer(const Duration(seconds: 10), …)` |
| `MainActivity.kt:50` + `:174` | **生产路径上无条件实例化了 `TestBYDAutoVehicleService`**（模拟车机遥测）。注意它在 Dart 侧搜不到，实例化点在 Kotlin |
| `lib/main.dart:1435` | `_initSensorStreams()` 定义了但从未被调用（全仓库仅此一处命中） |
| `lib/main.dart:17`、`:69-113`、`:153`、`:1138-1139`、`:1160` 起 | 前台服务栈整段注释掉：import、`_initForegroundTask`/`_startForegroundTask`/`_stopForegroundTask` 定义、调用点、`_startForegroundTaskSafe`/`_stopForegroundTaskImpl`。`:1138` 有 TODO「flutter_foreground_task 与 MIUI 不兼容，暂时禁用」 |
| `lib/main.dart:126` | `file_log_service` 的启用被注释掉（该服务本身是完整可用的：劫持 `print` + 装 `FlutterError.onError` + 轮转） |
| `bridge_controller.dart:822-866` | **`Geolocator.isLocationServiceEnabled()` 的整套检测（3 次重试 + `openLocationSettings()` + 小米 hack）只存在于一个 `/* */` 注释块里** → GPS 总开关关闭时没有任何代码能发现 |
| `bridge_controller.dart:1270-1284` | `if (_enableBackgroundLocation) … else …` 两个分支**逐字节相同** |
| `bridge_controller.dart:105` vs `:1316`/`:1366` | 心跳超时常量是 10 秒，注释一处写 10、两处写 20 |
| `bridge_controller.dart:1252-1355` vs `:2779-2830` | **存在两套分歧的 GPS 配置**：网页路径 `distanceFilter:1, forceLocationManager:false`；回调路径 `distanceFilter:0, forceLocationManager:true` |
| `bridge_controller.dart:1789-1801` | `_getGLRenderer` 调 `MethodChannel('nyanya_gl_info')`，**该 channel 在任何地方都没有实现** → 永远抛异常，`gpuVendor/Renderer/Version` 恒为 null/'unknown' |
| `bridge_controller.dart:383-427`（file_service） | A13 存储权限逻辑与 `bridge_controller.dart:2371-2420` **完全重复实现一遍** |
| `services/vehicle_service.dart:130-260` | 约 130 行**手写 JSON 解析器**，只因为 Kotlin 端把 `onCarDataChanged` 当 JSON 字符串推过来。修法是 Kotlin 改推 `Map`，不是留着这个解析器 |
| `modules/app_update/lib/src/callbacks.dart:13` | `Undefined class 'VersionInfo'`（缺 import）—— 这是 `analyze.log` 记录的**全仓库唯一 analyzer error，今天仍然是坏的** |
| `app_update/pubspec.yaml` ⇄ `flutter_bridge/pubspec.yaml` | **互相 `path:` 依赖（循环）**，只靠顶层 `dependency_overrides` 才编得过。要破环，正确做法是注入 `NotificationService` 而不是 `BridgeController().notificationService`（`update_service.dart:51,55,339,574,590`） |
| `android/app/src/main/AndroidManifest.xml:116-128` | 声明了 `com.pravera.flutter_foreground_task` 的 `<service>`+`<receiver>`，但该包**在 pubspec / lock / .flutter-plugins 里都不存在** → 死声明 |
| `AndroidManifest.xml:154-159` | `<queries>` 里**只有** `PROCESS_TEXT`。`:20` 的 `QUERY_ALL_PACKAGES` 注释说是为了"检测浏览器应用"，但那个 intent 根本没声明 —— 这是它被加进来的原因，也是白送的合规问题 |
| `com/example/flutter_app/MainActivity.kt` | 5 行模板残留，**会被编译** |
| `android/app/java_pid82786.hprof` | **859,183,331 字节**；`out/` 里还有几十个 94–103MB 历史 APK。别把它们当普通文件处理 |

## 5. 值得优先复用的资产（如果要重构，这些是金子）

- **`bridge_controller.dart:3321-3598` 音频/TTS** —— 全仓库保存得最好的非位置能力。OpenAI 兼容的 `/v1/audio/speech` Edge-TTS 调用（`zh-CN-XiaoxiaoNeural`、mp3、speed 参数）、base64 → 临时文件 → `just_audio`、`audio_session` 独占/混音焦点配置、`int|double` 音量速度兼容、焦点释放 + 临时文件清理。导航语音播报直接需要这套。
- **`bridge_controller.dart:1028-1250` 权限** —— 16 个标准 `permission_handler` 类型 + 14 个 BYD 权限的**双向映射表**，标准/BYD 双路 fan-in。抽成 `PermissionService` 即可。
- **`bridge_controller.dart:1451-1564`** —— 教科书式的 Android 三级权限阶梯（`locationWhenInUse` → `locationAlways` → `notification`）然后起前台服务。
- **`services/notification_service.dart`（288 行）** —— `flutter_local_notifications` 封装，含按 id 的点击回调注册表。几乎纯函数，唯一耦合点在 `_onNotificationClicked`。
- **`services/keep_awake_service.dart`（34 行）**、**`deep_link_service.dart`（72 行）**、**`background_service.dart`（60 行）** —— 通用，直接可用。
- **`services/file_service.dart`（462 行）** —— base64 + **64KB 分块流式**读写（`_FileStreamSession`），签名层耦合 WebView。
- **`BYDAutoVehicleService.kt`（4,360 行）** —— 与 WebView 完全无关，只通过 `byd_vehicle` channel 说话，**100% 保留**。
- **`modules/i18n/`（407 行）** —— 零 WebView 耦合，可直接用。注意它只有 ~88 个 app-shell key，真正的 UI 文案目录在 web 端（约 1,190 key）。且 `LanguageService`（flutter_bridge）和 `I18nService`（i18n）**写的是同一个 SharedPreferences key**，两个单例抢一个键。

## 6. 上架合规相关（Google Play / 国内商店）

这一节是本项目最特殊的约束，任何构建改动都要带着它。

**必须移除或改造**：
- `AndroidManifest.xml:10` `REQUEST_INSTALL_PACKAGES` + `app_update` 的自下载自安装（`update_service.dart:361-376` → `installApk`）→ **Play 禁止绕过应用内更新的自更新**。Play 渠道要注入 no-op 的 `UpdateService`，改用 Play In-App Update。
- `:15` `MANAGE_EXTERNAL_STORAGE` → Play 受限权限，改 SAF/MediaStore。
- `:20` `QUERY_ALL_PACKAGES` → 删掉，改为在 `<queries>` 里列出实际用到的包。实际按包名查询的地方只有：`MainActivity.kt:727`（枚举 5 个 WebView provider，`:718-722`）、`:800`/`:1117`（`canRequestPackageInstalls`）、`:922`/`:927`（`setComponentEnabledSetting`）、`:1048`（`getLaunchIntentForPackage`）。
- `:6` `ACCESS_BACKGROUND_LOCATION` + `:9` `FOREGROUND_SERVICE_LOCATION` → 需要权限用途声明 + prominent disclosure + 运行时单独同意。
- 43 条 `BYDAUTO_*` 权限 → Play 渠道整块剥离。
- **`BydApiReflectHelper.kt:16-19` 反射调用隐藏 API**：`Class.forName("android.hardware.bydauto.AbsBYDAutoDevice")` → `getDeclaredMethod("get", int, int)` → `method.isAccessible = true` → `invoke(...)`。这是非公开 API，Play 明令禁止。国内渠道需能证明 BYD 平台授权。
- Google 地图瓦片（web 端 `store/config.ts:111`、`:115` 的 `maps/vt?lyrs=…&gl=cn` 抓取）违反 Google ToS，Play 渠道用已有的 `features.googleMap` 开关关掉。

**签名与产物**：
- `pubspec.yaml:60` 把 **`.env` 声明成了 asset** → `TRIP_STORE_PASSWORD`/`TRIP_KEY_PASSWORD`/`TRIP_KEY_ALIAS`/`QQ_APP_KEY`/Google client ID **全部可从 APK 内读出**。这是必须最先修的一条。
- `build.gradle` debug buildType **用 `signingConfigs.release` 签名**；`minifyEnabled false` + `shrinkResources false` 两个 buildType 都是。
- 没有 `usesCleartextTraffic` 声明，也**没有 `network_security_config.xml`**（`res/xml/` 只有 `file_paths.xml`），而 `local_server.dart:63` 用的是 `http://localhost:<port>`。targetSdk 提升后这还能不能通，**必须真机验证**，不能靠读代码判断 —— 如果升级后 WebView 加载不了本地服务，App 起来就是白屏。
- 上架要 `flutter build appbundle`，而 `release.sh:386` 现在是 `flutter build apk --release --flavor "$flavor" --split-per-abi --no-shrink`。
- keystore（`trip-release-key.keystore`/`platform.keystore`）被 gitignore、只在本地。**启用 Play App Signing 前必须确认签名密钥可升级**，别弄丢。

## 7. 绝对不要做的事

- **不要**把 `.env` 的任何值、keystore 口令、QQ/Google client ID 写进代码、注释、日志或输出。
- **不要**用 `release.sh` 里的生产部署来验证改动（这是 `context.md` 里既有的规则，继续有效）。
- **不要**用无参数的 `git stash`；本目录是多子模块共享工作树的一部分。
- **不要**假设"改这个只影响本项目"：`bridge_controller.dart` 的 `sendMessage` 事件名是和 web 端 `plugins/nyanyaWebJsBridge/` 硬约定的，改名会静默断链。
- **不要**为了通过构建而去动 `dependency_overrides` 或删 `assets/out` 引用 —— 那是环境缺失，不是代码问题。

## 8. UI 与 i18n 约定（沿用 `context.md`，仍然有效）

- 所有 UI 文案必须走 i18n：`modules/i18n/lib/translations.dart`，用法 `BridgeController().i18nService.t('key')`，**新增文案必须同时补 zh-CN / en-US / zh-TW 三份**。
- 优先用 Shadcn UI 组件（`ShadButton` 而非 Material Button，`ShadToast` 而非 SnackBar）。
- `ShadToast` 已知问题：移动端强制 `minWidth: double.infinity`，设 `constraints`/`width` 都压不住；它自带淡入淡出。
- 退出交互：双次返回，第一次弹「再按一次退出程序」3 秒 Toast。
- 注意 pubspec 里没有 `flutter_localizations`/`intl`/gen-l10n，翻译是**一个 Dart 字面量 Map**，不是 `.arb`。

## 9. 质量基础设施：不存在

`analysis_options.yaml` 是未修改的默认模板，`rules:` 整段注释掉。唯一的测试 `test/widget_test.dart`（30 行）是计数器模板、引用了不存在的 widget，**必然红**。没有 CI。

意味着：**任何重构都没有网兜着**。特别是 §4 里那个循环依赖和 `bridge_controller.dart` 的拆分 —— 动手前先建立一个能跑的最小冒烟流程（起服务 + 首屏加载 + 一次 GPS 上报）。

## 10. 常用命令

```bash
flutter pub get
flutter run --dart-define=APP_FLAVOR=dev
flutter build apk --release --flavor prod --split-per-abi --no-shrink   # release.sh:386 实际用的
./release.sh build            # 另有 build:all / build:byd / build:new / build:old / buildDev / build:test
```

`release.sh` 顶部版本 `v1.1.2` 与 pubspec `1.1.1+984` 不一致，属已知状态。
