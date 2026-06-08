import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showMailNotification({
    required int newCount,
    required String from,
  }) async {
    const details = AndroidNotificationDetails(
      'mail_channel',
      '새 메일 알림',
      channelDescription: '새 Gmail 메일 도착 시 알림',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    await _plugin.show(
      0,
      '새 메일 $newCount통',
      from,
      const NotificationDetails(android: details),
    );
  }
}
