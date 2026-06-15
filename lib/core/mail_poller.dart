import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'l10n_helper.dart';
import 'notification_service.dart';

const _gmailBase = 'https://gmail.googleapis.com/gmail/v1/users/me';

// 포그라운드 전용 폴러 (60초 간격). 백그라운드 알림은 MailNotificationWorker(15분)가 담당.
class MailPoller {
  MailPoller(this._api, {this.onNewMail});

  final ApiClient _api;
  final Future<void> Function()? onNewMail;
  Timer? _timer;
  int _lastUnread = -1; // -1 = 아직 기준값 없음

  void start() {
    stop();
    _poll(); // 즉시 1회 실행 → 기준 unread 수 세팅
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastUnread = -1;
  }

  Future<void> _poll() async {
    try {
      final data = await _api.get('$_gmailBase/labels/INBOX');
      final unread = (data['messagesUnread'] as int?) ?? 0;

      if (_lastUnread == -1) {
        _lastUnread = unread; // 최초 — 기준선만 기록, 알림 없음
        return;
      }

      if (unread > _lastUnread) {
        final newCount = unread - _lastUnread;
        await _notifyNew(newCount);
        await onNewMail?.call();
      }
      _lastUnread = unread;
    } catch (e) {
      debugPrint('메일 폴링 실패: $e');
    }
  }

  Future<void> _notifyNew(int newCount) async {
    var from = appL10n().mailNotificationDefaultSender;
    try {
      final listData = await _api.get(
        '$_gmailBase/messages',
        params: {'labelIds': 'INBOX', 'maxResults': '1', 'q': 'is:unread'},
      );
      final ids = (listData['messages'] as List?) ?? [];
      if (ids.isNotEmpty) {
        final msgData = await _api.get(
          '$_gmailBase/messages/${ids[0]['id']}',
          params: {'format': 'metadata', 'metadataHeaders': 'From'},
        );
        final headers = (msgData['payload']?['headers'] as List?) ?? [];
        final raw = headers
            .cast<Map>()
            .firstWhere(
              (h) => (h['name'] as String).toLowerCase() == 'from',
              orElse: () => {'value': ''},
            )['value'] as String;
        if (raw.isNotEmpty) {
          // "DisplayName <addr>" → "DisplayName" 추출
          final match = RegExp(r'^"?([^"<]+)"?\s*<').firstMatch(raw);
          from = match?.group(1)?.trim() ?? raw;
        }
      }
    } catch (e) {
      debugPrint('발신자 정보 조회 실패: $e');
    }

    await NotificationService.showMailNotification(newCount: newCount, from: from);
  }
}
