import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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

  void _onNotificationClicked(NotificationResponse response) {
    // 点击通知时，使用 MethodChannel 调用 Android 原生方法打开 app
    const MethodChannel channel = MethodChannel('notification_click');
    channel.invokeMethod('openApp');
  }

  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    bool ongoing = false,
  }) async {
    if (!_initialized) {
      await init();
    }

    final AndroidNotificationDetails androidNotificationDetails =
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