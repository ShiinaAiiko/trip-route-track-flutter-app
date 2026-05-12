import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

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

    await _notificationsPlugin.initialize(initializationSettings);
    _initialized = true;
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

  Future<void> cancelNotification(int id) async {
    if (!_initialized) {
      await init();
    }
    await _notificationsPlugin.cancel(id);
  }
}
