# FlutterBridge SDK 使用文档

## 概述

FlutterBridge 是一个用于 Flutter 应用与 WebView 网站之间通信的 SDK，提供了类似 React Native JSBridge 的功能，支持定位、屏幕常亮、后台任务和语言设置等功能。

## 功能特性

1. **定位功能** - 实时获取 GPS 位置数据
2. **屏幕常亮** - 控制屏幕保持常亮状态
3. **后台任务** - 支持后台持续定位
4. **语言设置** - 支持多语言切换，通过网址参数切换语言

## 项目结构

```
modules/flutter_bridge/
├── lib/
│   ├── flutter_bridge.dart          # 主入口文件
│   └── src/
│       ├── bridge_controller.dart    # 核心控制器
│       ├── bridge_message.dart      # 消息定义
│       └── services/
│           ├── keep_awake_service.dart      # 屏幕常亮服务
│           ├── background_service.dart       # 后台任务服务
│           └── language_service.dart       # 语言设置服务
```

## Flutter 端使用方法

### 1. 添加依赖

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.2.2
  geolocator: ^12.0.0
```

### 2. 初始化 Bridge

```dart
import 'modules/flutter_bridge/flutter_bridge.dart';

class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final BridgeController _bridge = BridgeController();
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    _initBridge();
  }

  Future<void> _initBridge() async {
    await _bridge.init();
    
    // 监听来自网站的消息
    _bridge.on('enableLocation', (message) {
      print('Location enabled: ${message.payload}');
    });
    
    _bridge.on('keepScreenOn', (message) {
      print('Keep screen on: ${message.payload}');
    });
    
    _bridge.on('enableBackgroundTasks', (message) {
      print('Background tasks enabled: ${message.payload}');
    });
    
    _bridge.on('setLanguage', (message) {
      print('Language set: ${message.payload}');
    });
  }

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }
}
```

### 3. 连接到 WebView

```dart
// 在创建 PlatformView 时设置 channel
controller.addOnPlatformViewCreatedListener((int id) {
  _channel = MethodChannel('gecko_view_$id');
  _bridge.setChannel(_channel);
  
  // 设置 MethodCallHandler
  _channel?.setMethodCallHandler((call) async {
    if (call.method == 'onWebMessage') {
      // 消息会自动由 bridge 处理
    }
  });
});
```

### 4. 发送消息到网站

```dart
// 发送位置数据
await _bridge.sendMessage('location', {
  'coords': {
    'latitude': 39.9042,
    'longitude': 116.4074,
    'altitude': 50.0,
    'accuracy': 10.0,
    'heading': 45.0,
    'speed': 5.0,
  },
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});

// 发送应用配置
await _bridge.sendMessage('appConfig', {
  'version': '1.0.0',
  'system': 'Android',
});
```

### 5. 启动定位

```dart
_bridge.startLocationUpdates(
  onPositionChange: (Position position) {
    print('Location updated: ${position.latitude}, ${position.longitude}');
  },
  onError: (error) {
    print('Location error: $error');
  },
);
```

### 6. 后台任务管理

```dart
// 启动后台服务
await _bridge.start();

// 停止后台服务
await _bridge.stop();

// 更新通知
_bridge.updateBackgroundNotification(
  taskTitle: '正在后台定位',
  taskDesc: '行程已持续 1h 30m',
);
```

## 前端网站对接说明

### 1. 接收来自 Flutter 的消息

网站需要监听 `window.addEventListener('message')` 来接收消息：

```javascript
// 监听来自 Flutter 的消息
window.addEventListener('message', (event) => {
  try {
    const data = typeof event.data === 'string' 
      ? JSON.parse(event.data) 
      : event.data;
    
    switch (data.type) {
      case 'location':
        // 处理位置数据
        console.log('Location:', data.payload);
        break;
      
      case 'appConfig':
        // 处理应用配置
        console.log('App config:', data.payload);
        break;
    }
  } catch (e) {
    console.error('Failed to parse message:', e);
  }
});
```

### 2. 发送消息给 Flutter

使用 `window.ReactNativeWebView.postMessage()` 发送消息：

```javascript
// 启用定位
window.ReactNativeWebView.postMessage(JSON.stringify({
  type: 'enableLocation',
  payload: true,
}));

// 保持屏幕常亮
window.ReactNativeWebView.postMessage(JSON.stringify({
  type: 'keepScreenOn',
  payload: true,
}));

// 启用后台任务
window.ReactNativeWebView.postMessage(JSON.stringify({
  type: 'enableBackgroundTasks',
  payload: true,
}));

// 设置语言
window.ReactNativeWebView.postMessage(JSON.stringify({
  type: 'setLanguage',
  payload: 'zh-CN',
}));
```

### 3. 便捷方法

FlutterBridge 注入了 `window.sendToFlutter()` 便捷方法：

```javascript
// 使用便捷方法
window.sendToFlutter('enableLocation', true);
window.sendToFlutter('keepScreenOn', true);
window.sendToFlutter('setLanguage', 'zh-CN');
```

## 消息协议

### Flutter → 网站的消息类型

| 类型 | Payload | 说明 |
|------|----------|------|
| `location` | `{ coords: {...}, timestamp: number }` | 位置数据 |
| `appConfig` | `{ version: string, system: string }` | 应用配置 |

### 网站 → Flutter 的消息类型

| 类型 | Payload | 说明 |
|------|----------|------|
| `enableLocation` | `boolean` | 启用/禁用定位 |
| `keepScreenOn` | `boolean` | 保持屏幕常亮 |
| `enableBackgroundTasks` | `boolean` | 启用后台任务 |
| `setLanguage` | `string` | 设置语言（如 'zh-CN', 'en-US'） |

## 位置数据格式

```typescript
{
  coords: {
    latitude: number;      // 纬度
    longitude: number;     // 经度
    altitude: number;      // 海拔（米）
    accuracy: number;      // 精度（米）
    heading: number;      // 方向（度）
    speed: number;        // 速度（米/秒）
  };
  timestamp: number;      // 时间戳（毫秒）
}
```

## 应用配置格式

```typescript
{
  version: string;  // 应用版本号
  system: string;   // 操作系统（Android/iOS）
}
```

## 语言设置

支持的语言代码：
- `system` - 跟随系统
- `zh-CN` - 简体中文
- `zh-TW` - 繁体中文
- `en-US` - 英语

网站会根据语言设置自动加载对应的 URL：
- `http://localhost:8080/` - 跟随系统
- `http://localhost:8080/zh-CN` - 简体中文
- `http://localhost:8080/zh-TW` - 繁体中文
- `http://localhost:8080/en-US` - 英语

## 后台任务通知

当启用后台任务时，系统会显示通知栏通知，内容包含：
- 行程持续时间
- 已获取定位次数
- 当前速度
- 当前海拔

## 权限要求

Android 端需要在 `AndroidManifest.xml` 中添加以下权限：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

## 注意事项

1. **定位权限**：首次使用需要用户授权位置权限
2. **后台任务**：Android 8.0+ 需要前台服务权限
3. **语言设置**：语言设置会持久化存储，重启应用后保持
4. **消息格式**：所有消息必须是 JSON 格式
5. **线程安全**：BridgeController 是单例模式，线程安全

## 迁移指南

从 React Native JSBridge 迁移到 FlutterBridge：

### RN 代码
```typescript
// 接收消息
window.addEventListener('message', (event) => {
  const msg = JSON.parse(event.nativeEvent.data);
  // ...
});

// 发送消息
window.ReactNativeWebView.postMessage(JSON.stringify({
  type: 'enableLocation',
  payload: true,
}));
```

### Flutter 代码（前端无需改动）
```javascript
// 接收消息（完全相同）
window.addEventListener('message', (event) => {
  const msg = JSON.parse(event.data);
  // ...
});

// 发送消息（完全相同）
window.ReactNativeWebView.postMessage(JSON.stringify({
  type: 'enableLocation',
  payload: true,
}));
```

前端代码无需任何修改即可直接使用！
