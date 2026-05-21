# 行程路线轨迹 Flutter App

这是一个使用 Flutter 开发的行程路线轨迹记录应用，主要功能是加载本地静态网页，提供 GPS 定位、车辆数据获取、热更新等功能。

## 当前版本

**v1.0.9** (2026-05-21)

## 主要功能

- ✅ 使用 GeckoView 加载本地静态网页（Next.js 构建）
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

## 技术栈

- Flutter SDK
- GeckoView 143.0.20250929153833
- Java 17
- 比亚迪车机开放 API

## 项目进度

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
