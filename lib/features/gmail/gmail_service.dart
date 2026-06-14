import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/widget_service.dart';

const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

// ── RFC 2822 날짜 파싱 ────────────────────────────────────────────────────

const _months = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

DateTime? parseEmailDate(String raw) {
  try {
    final s = raw.replaceAll(RegExp(r'^\w{3},\s*'), '').trim();
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length < 4) return null;
    final day = int.parse(parts[0]);
    final month = _months[parts[1]];
    final year = int.parse(parts[2]);
    final t = parts[3].split(':');
    if (month == null) return null;
    final hour = int.tryParse(t[0]) ?? 0;
    final minute = int.tryParse(t.length > 1 ? t[1] : '0') ?? 0;

    // RFC2822 오프셋(±HHMM) 파싱해 UTC 기준으로 보정
    if (parts.length >= 5) {
      final tz = parts[4];
      final sign = tz.startsWith('-') ? -1 : 1;
      final tzDigits = tz.replaceAll(RegExp(r'[^0-9]'), '');
      if (tzDigits.length >= 4) {
        final tzHour = int.tryParse(tzDigits.substring(0, 2)) ?? 0;
        final tzMin = int.tryParse(tzDigits.substring(2, 4)) ?? 0;
        final utc = DateTime.utc(year, month, day, hour, minute)
            .subtract(Duration(hours: sign * tzHour, minutes: sign * tzMin));
        return utc.toLocal();
      }
    }
    // 오프셋 없거나 파싱 실패 시 로컬로 해석(기존 동작 폴백)
    return DateTime(year, month, day, hour, minute);
  } catch (e) {
    debugPrint('Gmail 날짜 파싱 실패: $e');
    return DateTime.tryParse(raw);
  }
}

String formatEmailDate(String raw) {
  final dt = parseEmailDate(raw);
  if (dt == null) return raw.length > 6 ? raw.substring(0, 6) : raw;
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
  return '${dt.month}월 ${dt.day}일';
}

// ── 이메일 본문 디코딩 ────────────────────────────────────────────────────

String decodeBase64Body(String data) {
  try {
    final normalized = base64Url.normalize(data);
    final bytes = base64Url.decode(normalized);
    return utf8.decode(bytes, allowMalformed: true);
  } catch (e) {
    debugPrint('Base64 디코딩 실패: $e');
    return '';
  }
}

class Attachment {
  final String filename;
  final String mimeType;
  final String attachmentId;
  final int size;
  const Attachment({required this.filename, required this.mimeType, required this.attachmentId, required this.size});
}

List<Attachment> getAttachments(Map<String, dynamic> payload) {
  final result = <Attachment>[];
  _collectAttachments(payload, result);
  return result;
}

void _collectAttachments(Map<String, dynamic> part, List<Attachment> out) {
  final filename = (part['filename'] as String?) ?? '';
  final body = part['body'] as Map<String, dynamic>?;
  final attachmentId = body?['attachmentId'] as String?;
  if (filename.isNotEmpty && attachmentId != null) {
    out.add(Attachment(
      filename: filename,
      mimeType: (part['mimeType'] as String?) ?? 'application/octet-stream',
      attachmentId: attachmentId,
      size: (body?['size'] as int?) ?? 0,
    ));
  }
  final parts = part['parts'] as List?;
  if (parts != null) {
    for (final p in parts) {
      _collectAttachments(p as Map<String, dynamic>, out);
    }
  }
}

String? getEmailBody(Map<String, dynamic> payload) {
  final bodyData = (payload['body'] as Map?)?['data'] as String?;
  if (bodyData != null && bodyData.isNotEmpty) return decodeBase64Body(bodyData);

  final parts = payload['parts'] as List?;
  if (parts != null) {
    for (final p in parts) {
      final m = p as Map<String, dynamic>;
      if (m['mimeType'] == 'text/html') {
        final d = (m['body'] as Map?)?['data'] as String?;
        if (d != null && d.isNotEmpty) return decodeBase64Body(d);
      }
    }
    for (final p in parts) {
      final m = p as Map<String, dynamic>;
      if (m['mimeType'] == 'text/plain') {
        final d = (m['body'] as Map?)?['data'] as String?;
        if (d != null && d.isNotEmpty) {
          final text = decodeBase64Body(d)
              .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
          return '<pre style="white-space:pre-wrap;font:14px/1.5 sans-serif;padding:14px">$text</pre>';
        }
      }
    }
    for (final p in parts) {
      final nested = getEmailBody(p as Map<String, dynamic>);
      if (nested != null) return nested;
    }
  }
  return null;
}

// ── 모델 ──────────────────────────────────────────────────────────────────

class GmailMessage {
  final String id;
  final String from;
  final String subject;
  final String date;
  final String snippet;
  final List<String> labelIds;
  final String internalDate;

  const GmailMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.date,
    required this.snippet,
    required this.labelIds,
    required this.internalDate,
  });

  bool get isUnread => labelIds.contains('UNREAD');
  bool get isStarred => labelIds.contains('STARRED');
  bool get isSpam => labelIds.contains('SPAM');

  String get displayName {
    final match = RegExp(r'^"?([^"<]+)"?\s*<').firstMatch(from);
    if (match != null) return match.group(1)!.trim();
    return from.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  String get initial {
    final name = displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  GmailMessage copyWith({List<String>? labelIds}) =>
      GmailMessage(id: id, from: from, subject: subject, date: date, snippet: snippet,
          labelIds: labelIds ?? this.labelIds, internalDate: internalDate);

  factory GmailMessage.fromJson(Map<String, dynamic> j) {
    String header(String name) {
      final headers = (j['payload']?['headers'] as List?) ?? [];
      return headers.cast<Map>()
          .firstWhere((h) => (h['name'] as String).toLowerCase() == name.toLowerCase(),
              orElse: () => {'value': ''})['value'] as String;
    }
    return GmailMessage(
      id: j['id'] as String,
      from: header('From'),
      subject: header('Subject'),
      date: header('Date'),
      snippet: (j['snippet'] as String?) ?? '',
      labelIds: (j['labelIds'] as List?)?.cast<String>() ?? [],
      internalDate: (j['internalDate'] as String?) ?? '0',
    );
  }
}

// ── State ─────────────────────────────────────────────────────────────────

class GmailState {
  final String label;
  final List<GmailMessage> messages;
  final Map<String, int> labelCounts;
  final Set<String> selectedIds;
  final bool loading;
  final bool loadingMore;
  final String? nextPageToken;
  final String? error;

  const GmailState({
    this.label = 'INBOX',
    this.messages = const [],
    this.labelCounts = const {},
    this.selectedIds = const {},
    this.loading = false,
    this.loadingMore = false,
    this.nextPageToken,
    this.error,
  });

  bool get hasSelection => selectedIds.isNotEmpty;
  bool get isInTrash => label == 'TRASH';

  GmailState copyWith({
    String? label, List<GmailMessage>? messages,
    Map<String, int>? labelCounts, Set<String>? selectedIds,
    bool? loading, bool? loadingMore, String? nextPageToken, String? error,
  }) => GmailState(
    label: label ?? this.label,
    messages: messages ?? this.messages,
    labelCounts: labelCounts ?? this.labelCounts,
    selectedIds: selectedIds ?? this.selectedIds,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    nextPageToken: nextPageToken ?? this.nextPageToken,
    error: error,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────

final gmailProvider =
    StateNotifierProvider<GmailNotifier, GmailState>((ref) {
  return GmailNotifier(ref.watch(apiClientProvider));
});

// ── Notifier ──────────────────────────────────────────────────────────────

class GmailNotifier extends StateNotifier<GmailState> {
  GmailNotifier(this._api) : super(const GmailState()) {
    loadMessages();
    loadLabelCounts();
  }

  final ApiClient _api;

  Future<void> loadMessages({String? query}) async {
    state = state.copyWith(loading: true, error: null, selectedIds: {}, nextPageToken: null);
    try {
      final params = <String, String>{'maxResults': '10'};
      if (query != null && query.isNotEmpty) {
        params['q'] = query;
      } else {
        params['labelIds'] = state.label;
      }

      final data = await _api.get('$_base/messages', params: params);
      final ids = (data['messages'] as List?) ?? [];
      final nextToken = data['nextPageToken'] as String?;
      if (ids.isEmpty) {
        state = state.copyWith(messages: [], loading: false, nextPageToken: null);
        return;
      }

      final details = await Future.wait(
        ids.map((m) => _api.get(
          '$_base/messages/${m['id']}',
          params: {'format': 'metadata', 'metadataHeaders': ['From', 'Subject', 'Date']},
        )),
      );

      final messages = details
          .map((d) => GmailMessage.fromJson(d as Map<String, dynamic>))
          .toList();
      state = state.copyWith(messages: messages, loading: false, nextPageToken: nextToken);
      if (state.label == 'INBOX') {
        WidgetService.updateGmail(messages);
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMoreMessages({String? query}) async {
    if (state.loadingMore || state.nextPageToken == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final params = <String, String>{
        'maxResults': '10',
        'pageToken': state.nextPageToken!,
      };
      if (query != null && query.isNotEmpty) {
        params['q'] = query;
      } else {
        params['labelIds'] = state.label;
      }

      final data = await _api.get('$_base/messages', params: params);
      final ids = (data['messages'] as List?) ?? [];
      final nextToken = data['nextPageToken'] as String?;
      if (ids.isEmpty) {
        state = state.copyWith(loadingMore: false, nextPageToken: null);
        return;
      }

      final details = await Future.wait(
        ids.map((m) => _api.get(
          '$_base/messages/${m['id']}',
          params: {'format': 'metadata', 'metadataHeaders': ['From', 'Subject', 'Date']},
        )),
      );

      final newMessages = details
          .map((d) => GmailMessage.fromJson(d as Map<String, dynamic>))
          .toList();

      final currentIds = state.messages.map((m) => m.id).toSet();
      final filteredNew = newMessages.where((m) => !currentIds.contains(m.id)).toList();

      state = state.copyWith(
        messages: [...state.messages, ...filteredNew],
        loadingMore: false,
        nextPageToken: nextToken,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> selectLabel(String label) async {
    state = state.copyWith(label: label, selectedIds: {});
    await loadMessages();
  }

  Future<void> loadLabelCounts() async {
    const labels = ['INBOX', 'STARRED', 'SENT', 'SPAM', 'TRASH'];
    final counts = <String, int>{};
    for (final lbl in labels) {
      try {
        final data = await _api.get('$_base/labels/$lbl');
        counts[lbl] = (data['messagesUnread'] as int?) ?? 0;
      } catch (e) { debugPrint('라벨 카운트 로드 실패 ($lbl): $e'); }
    }
    state = state.copyWith(labelCounts: counts);
  }

  // 선택 관리
  void toggleSelect(String id) {
    final s = Set<String>.from(state.selectedIds);
    if (s.contains(id)) { s.remove(id); } else { s.add(id); }
    state = state.copyWith(selectedIds: s);
  }

  void selectAll() {
    final all = state.messages.map((m) => m.id).toSet();
    state = state.copyWith(selectedIds: all);
  }

  void clearSelection() => state = state.copyWith(selectedIds: {});

}
