# Trip Route Track Flutter App - 开发上下文

## 指令

1. You are only allowed to modify files within the current directory. Never touch or mention any parent or sibling directories. 你只允许修改当前目录下的文件。切勿触及或提及任何父级或同级目录。
2. 每次改了代码都要告知我改了啥，为何这么改
3. 每次修改完代码，请确保编译通过，不能有错误；禁止使用 release.sh 里的生产部署来测试
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

## 项目概述

这是一个行程路线轨迹 Flutter 应用，主要功能是使用 WebView 加载网页并将手机传感器数据传递给前端。

**核心特性**：
- 双内核支持（GeckoView + 系统 WebView）
- 本地静态资源加载
- GPS 定位与后台定位
- 比亚迪车机数据集成
- 第三方登录（Google + QQ）
- 全局国际化（zh-CN / en-US / zh-TW）
- 自动更新系统
- 多标签页支持

---

## 项目结构

```
trip-route-track-flutter-app/
├── lib/                      # 主应用代码
│   ├── main.dart            # 入口文件
│   ├── local_server.dart    # 本地静态资源服务器
│   ├── models/              # 数据模型
│   ├── components/          # UI 组件
│   └── ...
├── modules/                 # 本地模块
│   ├── flutter_bridge/      # Flutter WebView 桥接
│   ├── i18n/                # 国际化模块
│   └── app_update/          # 自动更新模块
├── android/                 # Android 原生代码
├── assets/out/              # 静态网站资源
├── pubspec.yaml             # 依赖配置
└── release.sh               # 发布脚本
```

---

## 核心模块说明

### 1. nyanya_webview - 双内核 WebView

**仓库地址**：`https://github.com/ShiinaAiiko/nyanya-webview.git`  
**本地路径**：`../../../lib/nyanya-webview`（通过 dependency_overrides 覆盖）

**功能**：
- 支持 GeckoView 和系统 WebView 双内核
- 自动内核选择：系统 WebView < 85 时自动切换到 GeckoView
- 用户自定义内核选择（持久化存储）
- 统一的 WebView 接口抽象

**关键文件**：
- `webview_interface.dart` - 抽象接口
- `webview_options.dart` - 配置选项
- `gecko_webview.dart` - GeckoView 实现
- `system_webview.dart` - 系统 WebView 实现
- `webview_factory.dart` - 工厂类

---

### 2. flutter_bridge - 桥接模块

**路径**：`modules/flutter_bridge/`

**核心功能**：
- **BridgeController**（单例）：统一管理桥接通信、消息订阅/分发
- **LanguageService**：语言切换与持久化
- **KeepAwakeService**：屏幕常亮控制
- **BackgroundService**：后台任务管理
- **NotificationService**：系统通知
- **VehicleService**：比亚迪车机数据
- **EngineManager**：内核选择管理
- **UpdateService**：自动更新

**消息传递机制**：
- 前端 → `window.ReactNativeWebView.postMessage()` → 本地服务器 `/__flutter_bridge__` → BridgeController
- 支持 `bridgeId` 机制进行请求-响应匹配

**前端可调用方法**：
| 方法 | 功能 |
|------|------|
| `switchResources` | 切换主页域名（本地/云端） |
| `updateLocalWebResources` | 热更新本地静态资源 |
| `restartApp` | 重启 App |
| `quitApp` | 关闭 App |
| `sendNotification` / `cancelNotification` | 通知控制 |
| `enableLocation` / `enableBackgroundLocation` | 定位控制 |
| `keepScreenOn` | 屏幕常亮 |
| `setStatusBar` | 状态栏样式控制 |
| `getStatusBarData` | 获取状态栏数据 |
| `switchEngine` | 切换 WebView 内核 |
| `thirdPartyLogin` | 第三方登录 |
| `enableCarData` / `getCarData` | 车辆数据控制 |

---

### 3. i18n - 国际化模块

**路径**：`modules/i18n/`

**功能**：
- 支持 zh-CN / en-US / zh-TW 三种语言
- 翻译文件：`lib/translations.dart`
- 使用方式：`BridgeController().i18nService.t('key')`
- 桌面 App 标题动态更新（通过 ShortcutManager）

---

### 4. app_update - 自动更新模块

**路径**：`modules/app_update/`

**功能**：
- 检查 GitHub Releases 最新版本
- 下载 APK 并显示进度通知
- 自动清理旧版本 APK
- 下载完成后触发安装

---

## 技术架构

### 本地静态资源服务器

**文件**：`lib/local_server.dart`

**功能**：
- 从 `static_resources/` 优先加载，回退到 `assets/out/`
- URL 解码处理
- 类似 nginx 的路径匹配（自动添加 .html / index.html）
- 开发环境端口：13218，生产环境端口：13219
- 健康检测与自动重启

---

### GPS 定位

**依赖**：`permission_handler`、`geolocator`

**功能**：
- 静默申请位置权限
- 1秒间隔持续定位
- 后台定位（前台服务）
- 定位数据通过 JS Bridge 发送给前端

---

### 比亚迪车机数据

**18 个数据分类**：
| 分类 | 说明 |
|------|------|
| speed | 车速、加速/刹车深度 |
| statistic | 总里程、EV 里程、电量、油量 |
| instrument | 充电功率 |
| door | 车门状态 |
| vehicleSetting | 蓝牙、空调、能量回馈等 |
| engine | 发动机状态 |
| panorama | 摄像头模式 |
| sensor | 环境光、温度 |
| time | 系统时间 |
| energyMode | 能量模式 |
| radar | 雷达距离 |
| tyre | 胎压 |
| airQuality | PM2.5、PM10 |
| charge | 充电状态 |
| media | 媒体播放 |
| bodyStatus | 车身状态 |
| light | 车灯状态 |
| carData | 完整数据（包含以上所有） |

**实现方式**：
- 原生端反射调用 BYDAuto API
- 通过 `bydLog` 消息发送调试日志
- 非比亚迪设备返回全 0 数据

---

### 第三方登录

#### Google 登录
- 使用 `play-services-auth:21.2.0`
- 需要 Web 客户端 ID 获取 idToken
- 环境变量：`.env` 中的 GOOGLE_CLIENT_ID_DEV/PROD

#### QQ 登录
- 使用 `tencent_kit` 插件
- QQ SDK 3.5.7+ 需要调用 `Tencent.setIsPermissionGranted` 授权
- 获取 openid → 调用接口获取 unionid 和用户资料
- 返回数据结构与 Google 登录兼容

---

### 多标签页架构

- 每个标签页拥有独立的 UUID v4 sessionId
- BridgeController 按 sessionId 隔离 JS Bridge
- Tab 关闭时自动清理资源
- 支持导航（前进/后退）、分享等操作

---

### 前后台状态检测与恢复

**检测项**：
- LocalServer 健康状态
- GeckoView 内核健康状态（session 是否有效）

**恢复机制**：
- 自动重启 LocalServer
- 清理旧 GeckoRuntime 并重新初始化
- 重新加载页面
- 使用静态变量防止 Widget 重建时状态丢失

---

## UI 规范

- 使用 **Shadcn UI** 组件库
- Toast 使用 `ShadToast`（移动端占满宽度）
- 所有文案必须使用 i18n 国际化
- 退出确认：双次返回（第一次显示 Toast，3秒内再次返回退出）

---

## 开发规范

补充说明：请严格遵守文件开头的 **指令** 部分。

---

## 重要决策

| 决策 | 说明 |
|------|------|
| GeckoView 版本 | ≥ 85 推荐，当前使用最新版本 |
| Java 版本 | Java 17 |
| PlatformView 模式 | Hybrid Composition（解决输入法问题） |
| 静态资源加载 | 优先 local_server，次选 assets |
| 自动更新源 | GitHub Releases |
| 仓库结构 | nyanya_webview 独立仓库 |

---

## 关键代码位置

| 功能 | 文件路径 |
|------|----------|
| 入口 | `lib/main.dart` |
| 本地服务器 | `lib/local_server.dart` |
| 桥接控制器 | `modules/flutter_bridge/lib/src/bridge_controller.dart` |
| 国际化服务 | `modules/i18n/lib/i18n_service.dart` |
| 翻译定义 | `modules/i18n/lib/translations.dart` |
| GeckoView 平台 | `android/app/src/main/kotlin/club/aiiko/trip/GeckoViewPlatform.kt` |
| 主 Activity | `android/app/src/main/kotlin/club/aiiko/trip/MainActivity.kt` |
| 比亚迪车机服务 | `android/app/src/main/kotlin/club/aiiko/trip/BYDAutoVehicleService.kt` |

---

## 当前未解决问题

1. **比亚迪车机 API 数据获取**：权限检查通过但无法获取数据，需真实车机测试
2. **定位数据数量不一致**：前端与后台通知显示数量存在差距（~20%）
3. **前台服务 MIUI 兼容性**：`flutter_foreground_task` 与 MIUI 不兼容，已暂时禁用
4. **QQ 登录完整流程验证**：需测试真机端到端流程及异常容错
5. **QQ 设备兼容性**：旧版 QQ/TIM 可能导致 `getAppVersionName` 返回 null

---

## 版本信息

| 项目 | 值 |
|------|-----|
| App 版本 | v1.0.13 |
| nyanya_webview | v1.0.0 |
| 发布日期 | 2026-05-26 |
