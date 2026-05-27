import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:i18n/i18n_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Function? _onDownloadNotificationClick;
  bool _isDownloadComplete = false;
  Function(Map<String, dynamic>)? _onNotificationClickWithAction;

  void setDownloadComplete(bool complete) {
    _isDownloadComplete = complete;
  }

  void setNotificationClickCallback(Function(Map<String, dynamic>) callback) {
    _onNotificationClickWithAction = callback;
  }

  Future<void> init() async {
    if (_initialized) return;

    // 请求通知权限（Android 13+ 需要）
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationClicked,
    );
    _initialized = true;
  }

  void setDownloadNotificationCallback(Function callback) {
    _onDownloadNotificationClick = callback;
  }

  void _onNotificationClicked(NotificationResponse response) {
    if (response.id == 1001 && _onDownloadNotificationClick != null && _isDownloadComplete) {
      _onDownloadNotificationClick!();
    } else if (response.id != 1001) {
      // 点击通知时，使用 MethodChannel 调用 Android 原生方法打开 app
      const MethodChannel channel = MethodChannel('notification_click');
      channel.invokeMethod('openApp');
      
      // 如果有 clickActionUrl，回调给前端
      if (_onNotificationClickWithAction != null && response.payload != null) {
        try {
          final payload = Map<String, dynamic>.from(
            Uri.splitQueryString(response.payload!).map(
              (key, value) => MapEntry(key, value),
            ),
          );
          _onNotificationClickWithAction!(payload);
        } catch (e) {
          // 忽略解析错误
        }
      }
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    bool ongoing = false,
    AndroidNotificationDetails? androidDetails,
    String? clickActionType,
    String? clickActionUrl,
  }) async {
    if (!_initialized) {
      await init();
    }

    String? payload;
    if (clickActionUrl != null && clickActionUrl.isNotEmpty) {
      final queryParams = <String, String>{
        if (clickActionType != null) 'clickActionType': clickActionType,
        'clickActionUrl': clickActionUrl,
      };
      payload = Uri(queryParameters: queryParams).toString();
    }

    final AndroidNotificationDetails androidNotificationDetails =
        androidDetails ??
        AndroidNotificationDetails(
          'trip_route_channel',
          'Trip Route',
          channelDescription: 'Trip Route Track Notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ticker: 'ticker',
          ongoing: ongoing,
          autoCancel: !ongoing,
          channelShowBadge: true,
          onlyAlertOnce: true,
        );

    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> showProgressNotification({
    required String title,
    required String body,
    required int progress,
    int id = 0,
    String channelId = 'trip_route_channel',
    String channelName = 'Trip Route',
    String channelDescription = 'Trip Route Track Notifications',
  }) async {
    if (!_initialized) {
      await init();
    }

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ticker: 'ticker',
      ongoing: true,
      autoCancel: false,
      channelShowBadge: true,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
    );

    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> showNotificationWithAutoClose({
    required String title,
    required String body,
    int id = 0,
    int autoCloseDelayMs = 5000,
  }) async {
    await showNotification(title: title, body: body, id: id);
    Future.delayed(Duration(milliseconds: autoCloseDelayMs), () {
      cancelNotification(id);
    });
  }

  Future<void> cancelNotification(int id) async {
    if (!_initialized) {
      await init();
    }
    await _notificationsPlugin.cancel(id);
  }
}