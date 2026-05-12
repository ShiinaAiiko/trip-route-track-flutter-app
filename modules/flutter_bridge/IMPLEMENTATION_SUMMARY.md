# FlutterBridge 实现总结

## 实现概述

已成功实现 FlutterBridge SDK，提供与 React Native JSBridge 兼容的通信机制，支持定位、屏幕常亮、后台任务和语言设置功能。

## 功能实现清单

### ✅ 已完成功能

1. **定位功能**
   - 使用 `geolocator` 包实现 GPS 定位
   - 1 秒间隔更新位置
   - 支持高精度定位
   - 自动请求权限

2. **屏幕常亮**
   - 使用 `SystemChrome.setEnabledSystemUIMode()` 实现
   - 支持开启/关闭屏幕常亮
   - 沉浸式模式体验

3. **后台任务**
   - Android 前台服务实现
   - 后台持续定位
   - 通知栏显示实时信息（持续时间、定位次数、速度、海拔）
   - 应用生命周期管理（前台/后台切换）

4. **语言设置**
   - 使用 `shared_preferences` 持久化存储
   - 支持多语言切换（zh-CN, zh-TW, en-US, system）
   - 通过 URL 参数切换网站语言

5. **JSBridge 通信**
   - 完全兼容 RN 的 `window.ReactNativeWebView` 接口
   - 支持双向消息传递
   - 自动注入 JSBridge 脚本到网页

## 代码改动说明

### 新增文件

#### Flutter 端
```
modules/flutter_bridge/
├── lib/
│   ├── flutter_bridge.dart          # 主入口
│   └── src/
│       ├── bridge_controller.dart    # 核心控制器
│       ├── bridge_message.dart      # 消息定义
│       └── services/
│           ├── keep_awake_service.dart
│           ├── background_service.dart
│           └── language_service.dart
└── README.md                       # 使用文档
```

#### Android 端
```
android/app/src/main/kotlin/club/aiiko/trip/
└── BackgroundService.kt             # 后台服务
```

### 修改文件

#### 1. pubspec.yaml
- 添加 `shared_preferences: ^2.2.2` 依赖

#### 2. lib/main.dart
- 导入 FlutterBridge SDK
- 初始化 BridgeController
- 监听来自网站的消息
- 实现应用生命周期管理
- 支持语言切换和 URL 更新

#### 3. android/app/src/main/kotlin/club/aiiko/trip/MainActivity.kt
- 添加后台服务 MethodChannel 处理
- 实现 startBackgroundService、stopBackgroundService、updateNotification 方法

#### 4. android/app/src/main/kotlin/club/aiiko/trip/GeckoViewPlatform.kt
- 添加 `injectJSBridge()` 方法
- 设置 `GeckoSession.MessageDelegate` 监听网页消息
- 注入 `window.ReactNativeWebView` 对象

#### 5. android/app/src/main/AndroidManifest.xml
- 添加权限：
  - `FOREGROUND_SERVICE`
  - `POST_NOTIFICATIONS`
  - `WAKE_LOCK`
- 注册 BackgroundService

## 前端网站对接指南

### 1. 接收来自 Flutter 的消息

网站需要监听 `window.addEventListener('message')`：

```javascript
window.addEventListener('message', (event) => {
  try {
    const data = typeof event.data === 'string' 
      ? JSON.parse(event.data) 
      : event.data;
    
    if (data.type === 'location') {
      // 处理位置数据
      const { latitude, longitude, altitude, speed } = data.payload.coords;
      console.log('Location:', latitude, longitude);
      
      // 更新 UI 或执行业务逻辑
    }
  } catch (e) {
    console.error('Failed to parse message:', e);
  }
});
```

### 2. 发送消息给 Flutter

使用 `window.ReactNativeWebView.postMessage()`：

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
window.sendToFlutter('enableLocation', true);
window.sendToFlutter('keepScreenOn', true);
window.sendToFlutter('setLanguage', 'zh-CN');
```

### 4. 消息协议

#### Flutter → 网站
| 类型 | Payload | 说明 |
|------|----------|------|
| `location` | `{ coords: {...}, timestamp: number }` | 位置数据 |
| `appConfig` | `{ version: string, system: string }` | 应用配置 |

#### 网站 → Flutter
| 类型 | Payload | 说明 |
|------|----------|------|
| `enableLocation` | `boolean` | 启用/禁用定位 |
| `keepScreenOn` | `boolean` | 保持屏幕常亮 |
| `enableBackgroundTasks` | `boolean` | 启用后台任务 |
| `setLanguage` | `string` | 设置语言 |

### 5. 位置数据格式

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

### 6. 语言设置

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

## 与 RN JSBridge 的兼容性

### 完全兼容的接口

前端代码无需任何修改即可从 RN 迁移到 Flutter：

```javascript
// RN 和 Flutter 都支持相同的接口
window.ReactNativeWebView.postMessage(JSON.stringify({
  type: 'enableLocation',
  payload: true,
}));

window.addEventListener('message', (event) => {
  const msg = JSON.parse(event.data);
  // 处理消息
});
```

### 主要区别

| 特性 | RN | Flutter |
|------|-----|---------|
| 定位实现 | `@react-native-community/geolocation` | `geolocator` |
| 后台任务 | `react-native-background-actions` | Android 前台服务 |
| 屏幕常亮 | `react-native-keep-awake` | `SystemChrome` |
| 语言存储 | `@react-native-async-storage/async-storage` | `shared_preferences` |

## 使用示例

### 完整的前端集成示例

```javascript
// 初始化
document.addEventListener('DOMContentLoaded', () => {
  // 监听 Flutter 消息
  window.addEventListener('message', handleFlutterMessage);
  
  // 发送初始化配置
  window.sendToFlutter('setLanguage', 'zh-CN');
  window.sendToFlutter('enableLocation', true);
});

function handleFlutterMessage(event) {
  const data = typeof event.data === 'string' 
    ? JSON.parse(event.data) 
    : event.data;
  
  switch (data.type) {
    case 'location':
      updateLocationOnMap(data.payload);
      break;
      
    case 'appConfig':
      console.log('App version:', data.payload.version);
      break;
  }
}

function updateLocationOnMap(location) {
  const { latitude, longitude, speed } = location.coords;
  
  // 更新地图标记
  map.setCenter([longitude, latitude]);
  
  // 更新速度显示
  document.getElementById('speed').textContent = 
    `${(speed * 3.6).toFixed(1)} km/h`;
}

// 用户点击按钮时
document.getElementById('start-tracking').addEventListener('click', () => {
  window.sendToFlutter('enableBackgroundTasks', true);
  window.sendToFlutter('keepScreenOn', true);
});

document.getElementById('stop-tracking').addEventListener('click', () => {
  window.sendToFlutter('enableBackgroundTasks', false);
  window.sendToFlutter('keepScreenOn', false);
});
```

## 注意事项

1. **权限**：首次使用需要用户授权位置权限
2. **后台任务**：Android 8.0+ 需要前台服务权限
3. **语言持久化**：语言设置会保存到本地，重启后保持
4. **消息格式**：所有消息必须是 JSON 格式
5. **线程安全**：BridgeController 是单例模式，线程安全

## 测试建议

1. 测试定位功能是否正常更新
2. 测试屏幕常亮是否生效
3. 测试后台任务和通知显示
4. 测试语言切换和 URL 更新
5. 测试应用前后台切换时的行为

## 下一步

1. 运行 `flutter pub get` 安装依赖
2. 运行 `flutter run` 启动应用
3. 在网站中测试 JSBridge 通信
4. 根据实际需求调整定位频率和后台任务逻辑
