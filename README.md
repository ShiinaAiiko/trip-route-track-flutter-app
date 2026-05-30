# 行程路线轨迹 Flutter App

这是一个使用 Flutter 开发的行程路线轨迹记录应用，主要功能是加载本地静态网页，提供 GPS 定位、车辆数据获取、热更新等功能。

## 🌐 在线体验

- **Web 应用**：https://trip.aiiko.club/
- **App 下载**：https://trip.aiiko.club/download

## 当前版本

**v1.0.13** (2026-05-26)

## 主要功能

- ✅ **多内核 WebView 架构** - 支持 GeckoView 和系统 WebView 自由切换
- ✅ 使用 GeckoView / 系统 WebView 加载本地静态网页（Next.js 构建）
- ✅ 引擎自动选择 - 默认使用 System WebView，系统 WebView 版本 < 85 时自动切换到 GeckoView
- ✅ 用户自定义引擎持久化 - 前端通过 `switchEngine` 消息切换，保存设置
- ✅ GPS 定位功能（支持后台定位）
- ✅ 全局 i18n 国际化系统（多语言支持：zh-CN、en-US、zh-TW）
- ✅ 桌面 App 标题跟随语言设置动态更新
- ✅ 通知文本国际化
- ✅ 通知点击打开 App 功能
- ✅ 通知自动关闭机制（4秒延时）
- ✅ 屏幕常亮控制
- ✅ 状态栏动态变化（支持多种模式：system/light/dark/transparent/hide等）
- ✅ 状态栏数据获取接口（getStatusBarData）
- ✅ App 前后台切换状态检测与恢复机制
- ✅ **内部网站 URL 统一替换** - localhost 显示替换为 trip.aiiko.club
- ✅ **GeckoRuntime 重启增强** - 不健康时提前清理旧实例
- ✅ **checkGeckoViewReady** - GeckoView 就绪状态检测
- ⚠️ 比亚迪车机数据集成（车速、电量、胎压等）- 开发中
- ✅ 比亚迪车机日志系统（通过 `bydLog` 消息实时发送到前端）
- ✅ 外接充电量数据获取（`externalChargingPower` 字段）
- ✅ 本地静态文件服务器（开发环境 13218 / 生产环境 13219）
- ✅ Flutter Bridge SDK（Flutter 与 WebView 双向通信）
- ✅ 开发/生产环境差异化标题标识（Dev 前缀）
- ✅ **Shadcn UI Toast 组件**（退出提示、分享成功提示）
- ✅ App 自动更新系统（版本检查、下载、安装）
- ⚠️ 前台服务（暂时禁用 - MIUI 兼容性问题）
- ✅ **域名切换**（switchResources）- 支持本地/云端域名切换，持久化存储
- ✅ **本地资源热更新**（updateLocalWebResources）- 下载 tgz 包，显示下载/解压进度
- ✅ **App 重启/退出**（restartApp/quitApp）- 完整的 App 生命周期控制
- ✅ **通知控制**（sendNotification/cancelNotification）- 灵活的通知管理
- ✅ **混合内容访问支持** - HTTPS 页面可访问 localhost 的 HTTP 资源
- ✅ **第三方登录功能** - Google Sign-In（已实现），QQ/GitHub（预留）
- ✅ **多标签页管理** - 完整的标签页管理功能，支持多标签页浏览
- ✅ **独立 JS Bridge** - 每个标签页都有独立的 JS Bridge，互不干扰
- ✅ **双次退出确认** - 第一次按返回显示提示，3秒内再次按返回退出 App
- ✅ **完整的 18 个车辆数据分类接口** - 车速、统计、仪表、车门、车辆设置、发动机、全景、传感器、时间、能量模式、雷达、轮胎、空气质量、充电、媒体、车身状态、车灯、整体数据
- ✅ **前端类型安全优化** - 将通用 set 方法拆分为具体类型安全的函数
- ✅ **hasFeature 方法** - 车辆设置类的功能查询方法
- ✅ **整体监听功能** - enableCarData 获取所有 18 个分类的完整数据
- ✅ **前端车机数据模拟测试** - startTest 函数模拟真实车机数据，方便前端开发调试

## 技术栈

- Flutter SDK
- GeckoView 143.0.20250929153833
- Java 17
- 比亚迪车机开放 API

## 项目进度

### v1.0.13 (2026-05-26)
- ✅ **完整的 18 个车辆数据分类接口实现** - 车速、统计、仪表、车门、车辆设置、发动机、全景、传感器、时间、能量模式、雷达、轮胎、空气质量、充电、媒体、车身状态、车灯、整体数据
- ✅ **三端架构** - 前端、Flutter、Android 原生完整实现
- ✅ **前端类型安全优化** - 将除空调和车速外的其他 16 个分类的通用 set 方法拆分为具体类型安全的函数
- ✅ **事件监听统一** - 移除过度细分的事件，统一为整体事件派发
- ✅ **hasFeature 方法实现** - 车辆设置类特有的功能查询方法
- ✅ **整体监听功能（enableCarData）** - 获取所有 18 个分类的完整数据
- ✅ **前端车机数据模拟测试** - startTest 函数模拟真实车机数据，无需依赖真实车辆，方便前端开发调试
- ✅ **类型定义优化** - 属于特定模块的类型定义放在对应模块内，避免集中到外部文件

### v1.0.12 (2026-05-25)
- ✅ **多标签页 JS Bridge 隔离** - 每个标签页都有独立的 MethodChannel，通过 sessionId 区分
- ✅ **导航功能修复** - 修复 canGoBack/canGoForward 返回 false 的问题
- ✅ **下拉菜单关闭** - 点击返回/前进/分享按钮后自动关闭下拉菜单
- ✅ **双次退出确认** - 第一次返回显示 Toast 提示，3秒内再次返回退出 App
- ✅ **UUID 生成** - 使用标准 UUID v4 生成 tabId 和 sessionId
- ✅ **多语言加载文本** - tab_page.dart 中添加 loading 翻译（zh-CN/zh-TW/en-US）
- ✅ **标签页关闭清理** - 标签页关闭时调用 removeChannel 清理资源

### v1.0.11 (2026-05-24)
- ✅ **多内核 WebView 架构** - 将 GeckoView 代码拆分为独立 `nyanya_webview` 模块
- ✅ **系统 WebView 内核** - 实现完整系统 WebView 支持
- ✅ **引擎自动选择** - EngineManager 实现，默认 system，版本 < 85 切换 gecko
- ✅ **用户引擎持久化** - switchEngine 消息 + SharedPreferences 保存
- ✅ **加载日志类型化** - LoadingLog 模型，支持多语言显示
- ✅ **appConfig 增强** - 增加 engine 参数返回当前渲染引擎

### v1.0.10 (2026-05-22)
- ✅ **第三方登录功能** - Google Sign-In（已实现），QQ/GitHub（预留位置）
- ✅ **环境变量配置** - 统一管理 Google Client ID、签名密码等敏感配置
- ✅ **开发/生产环境区分** - 通过 release.sh 自动切换环境变量

### v1.0.9 (2026-05-21)
- ✅ **内部网站 URL 统一替换** - localhost 显示替换为 trip.aiiko.club
- ✅ **GeckoRuntime 重启增强** - 不健康时提前清理旧实例
- ✅ **checkGeckoViewReady** - GeckoView 就绪状态检测
- ✅ GeckoRuntime 单例创建优化 - 防止 `Only one GeckoRuntime instance is allowed` 异常
- ✅ i18n 翻译更新 - Vibe Coding 文案
- ✅ 自动更新服务优化 - 移除下载前清理旧 APK 逻辑

### 已完成
1. GeckoView 集成和静态网页加载
2. GPS 定位和后台定位服务
3. 全局 i18n 国际化系统
4. 通知系统（点击打开、自动关闭）
5. Flutter Bridge SDK 通信机制
6. 本地静态文件服务器
7. 开发/生产环境差异化构建配置
8. App 前后台切换状态检测与恢复机制
9. 状态栏动态变化
10. 比亚迪车机日志系统
11. 本地服务器端口区分（开发环境 13218 / 生产环境 13219）
12. 状态栏数据获取接口（getStatusBarData）
13. GeckoView Session 健康检测（白屏问题修复）
14. 外接充电量数据获取（externalChargingPower）
15. App 自动更新系统（版本检查、下载、安装）

### 开发中
1. 比亚迪车机 API 数据集成
   - 已实现 API 调用框架
   - 已配置系统签名（platform.keystore）
   - 已新增完整日志系统（通过 `bydLog` 消息发送到前端）
   - 已在 carData 中添加 `externalChargingPower` 字段
   - 待在真实比亚迪车机上测试验证

2. 定位数据数量不一致问题
   - 现象：前端显示 3557 个定位点，后台通知显示 2843 个
   - 原因正在排查中

3. 前台服务与 MIUI 兼容性
   - `flutter_foreground_task` 插件与 MIUI 系统不兼容
   - 已暂时禁用前台服务

## 当前问题

1. **比亚迪车机 API 数据获取**：
   - 权限检查通过但无法获取车辆数据
   - 需要在真实车机环境测试验证

2. **定位数据数量不一致**：
   - 差距约 20%（3557 vs 2843）
   - 可能原因：系统节流、消息丢失、前端未计入

3. **前台服务 MIUI 崩溃**：
   - `flutter_foreground_task` 插件调用时触发 MIUI 系统日志权限检查
   - 症状：`Process is going to kill itself!`
   - 当前状态：前台服务已暂时禁用

## 构建命令

```bash
# 开发环境构建
./release.sh dev           # 运行开发模式
./release.sh buildDev      # 构建开发版 APK

# 生产环境构建
./release.sh build         # 构建生产版 APK
```

## 版本历史

| 版本 | 日期 | 主要更新 |
|------|------|----------|
| v1.0.13 | 2026-05-26 | 完整的 18 个车辆数据分类接口实现、前端类型安全优化、整体监听功能、前端车机数据模拟测试 |
| v1.0.12 | 2026-05-25 | 多标签页 JS Bridge 隔离、导航功能修复、双次退出确认 |
| v1.0.11 | 2026-05-24 | 多内核 WebView 架构、系统 WebView 支持、引擎自动选择 |
| v1.0.10 | 2026-05-22 | 第三方登录功能（Google Sign-In）、环境变量配置、开发/生产环境区分 |
| v1.0.9 | 2026-05-21 | 内部网站 URL 替换、GeckoRuntime 重启增强、checkGeckoViewReady |
| v1.0.7 | - | App 自动更新系统、Shadcn UI Toast 组件 |
| v1.0.6 | - | GeckoView Session 健康检测、白屏问题修复 |
| v1.0.5 | - | 状态栏动态变化、比亚迪车机日志系统 |
| v1.0.4 | - | 本地服务器端口区分、状态栏数据获取接口 |

## 应用标题标识

| 构建类型 | 标题示例 |
|----------|----------|
| 开发环境 | Dev 行程路线轨迹 |
| 生产环境 | 行程路线轨迹 |

## 🔗 相关链接

- [在线体验](https://trip.aiiko.club/)
- [App 下载](https://trip.aiiko.club/download)
- [Web 前端](../trip-route-track-web)
- [后端服务](../trip-route-track-server)

## 📄 License

MIT
