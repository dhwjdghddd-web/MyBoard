import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'l10n_helper.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static void Function(int? id, String? payload)? _onTap;

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
    final l = appL10n();
    final details = AndroidNotificationDetails(
      'mail_channel',
      l.mailChannelName,
      channelDescription: l.mailChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    // 타임스탬프 기반 ID — 재시작 후에도 이전 알림과 충돌 없음 (32비트 범위 내)
    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    await _plugin.show(
      id,
      l.mailNotificationTitle(newCount),
      from,
      NotificationDetails(android: details),
      payload: 'mail',
    );
  }
}
