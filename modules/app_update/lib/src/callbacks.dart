import 'version_info.dart';

// App 更新进度回调
typedef AppUpdateProgressCallback = void Function(
    int progress, int receivedBytes, int totalBytes);

// App 更新完成回调
typedef AppUpdateCompleteCallback = void Function(bool success, String? error);

// 安装请求回调（用于通知 UI 显示安装按钮）
typedef AppUpdateInstallRequestCallback = void Function();

// 更新检查回调
typedef UpdateCheckCallback = void Function(
    VersionInfo? versionInfo, String currentVersion, bool showCheckingNotification);

// 更新检查中回调
typedef UpdateCheckingCallback = void Function();
