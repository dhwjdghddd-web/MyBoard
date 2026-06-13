import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static void Function(int? id, String? payload)? _onTap;
  static int _nextId = 1;

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _onTap?.call(response.id, response.payload);
      },
    );
  }

  static void setOnTapCallback(void Function(int? id, String? payload) callback) {
    _onTap = callback;
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
      _nextId++,
      '새 메일 $newCount통',
      from,
      const NotificationDetails(android: details),
      payload: 'mail',
    );
  }
}
