# 行程路线轨迹 Flutter App

这是一个使用 Flutter 开发的行程路线轨迹记录应用，主要功能是加载本地静态网页，提供 GPS 定位、车辆数据获取等功能。

## 主要功能

- ✅ 使用 GeckoView 加载本地静态网页（Next.js 构建）
- ✅ GPS 定位功能（支持后台定位）
- ✅ 全局 i18n 国际化系统（多语言支持：zh-CN、en-US、zh-TW）
- ✅ 桌面 App 标题跟随语言设置动态更新
- ✅ 通知文本国际化
- ✅ 通知点击打开 App 功能
- ✅ 通知自动关闭机制（4秒延时）
- ✅ 屏幕常亮控制
- ✅ 比亚迪车机数据集成（车速、电量、胎压等）
- ✅ 本地静态文件服务器
- ✅ Flutter Bridge SDK（Flutter 与 WebView 双向通信）

## 技术栈

- Flutter SDK
- GeckoView 143.0.20250929153833
- Java 17
- 比亚迪车机开放 API
