import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/widget_service.dart';

// ── 유틸 ──────────────────────────────────────────────────────────────────

Color hexToColor(String hex) {
  final h = hex.replaceAll('#', '').padLeft(6, '0');
  return Color(int.parse('FF$h', radix: 16));
}

// ISO 8601 + 로컬 오프셋 (예: "2024-01-15T09:00:00+09:00")
String toRfc3339(DateTime local) {
  final off = local.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final h = off.inHours.abs().toString().padLeft(2, '0');
  final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}'
      '-${local.month.toString().padLeft(2, '0')}'
      '-${local.day.toString().padLeft(2, '0')}'
      'T${local.hour.toString().padLeft(2, '0')}'
      ':${local.minute.toString().padLeft(2, '0')}:00'
      '$sign$h:$m';
}

// ── 색상 팔레트 (index.html의 ECOLS 참고) ─────────────────────────────────

const kGoogleEventColors = <String, String>{
  '1': '#7986cb', '2': '#33b679', '3': '#8e24aa',
  '4': '#e67c73', '5': '#f6c026', '6': '#f5511d',
  '7': '#039be5', '8': '#616161', '9': '#3f51b5',
  '10': '#0b8043', '11': '#d50000',
};

// ── 모델 ──────────────────────────────────────────────────────────────────

class CalendarInfo {
  final String id;
  final String summary;
  final Color color;
  final bool isWritable;
  const CalendarInfo({
    required this.id,
    required this.summary,
    required this.color,
    this.isWritable = true,
  });
}

class CalendarEvent {
  final String id;
  final String calendarId;
  final String calendarName;
  final String summary;
  final bool isAllDay;
  final DateTime? startDt;
  final DateTime? endDt;
  final String? startDate;
  final String? endDate;
  final Color color;
  final String? location;
  final String? description;
  final String? colorId;

  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.calendarName,
    required this.summary,
    required this.isAllDay,
    required this.color,
    this.startDt,
    this.endDt,
    this.startDate,
    this.endDate,
    this.location,
    this.description,
    this.colorId,
  });

  String get dateKey {
    if (startDt != null) {
      final l = startDt!.toLocal();
      return '${l.year}-${l.month.toString().padLeft(2,'0')}-${l.day.toString().padLeft(2,'0')}';
    }
    return startDate ?? '';
  }

  factory CalendarEvent.fromJson(
    Map<String, dynamic> j, {
    required String calendarId,
    required String calendarName,
    required Color calColor,
    required Map<String, String> eventColorMap,
  }) {
    final colorId = j['colorId'] as String?;
    var eventColor = calColor;
    if (colorId != null && eventColorMap.containsKey(colorId)) {
      eventColor = hexToColor(eventColorMap[colorId]!);
    }
    final startDtStr = (j['start'] as Map?)?['dateTime'] as String?;
    final endDtStr = (j['end'] as Map?)?['dateTime'] as String?;
    return CalendarEvent(
      id: j['id'] as String,
      calendarId: calendarId,
      calendarName: calendarName,
      summary: (j['summary'] as String?) ?? '(제목 없음)',
      isAllDay: startDtStr == null,
      startDt: startDtStr != null ? DateTime.tryParse(startDtStr) : null,
      endDt: endDtStr != null ? DateTime.tryParse(endDtStr) : null,
      startDate: (j['start'] as Map?)?['date'] as String?,
      endDate: (j['end'] as Map?)?['date'] as String?,
      color: eventColor,
      location: j['location'] as String?,
      description: j['description'] as String?,
      colorId: colorId,
    );
  }
}

// ── State ─────────────────────────────────────────────────────────────────

class CalendarState {
  final int year;
  final int month;
  final List<CalendarEvent> events;
  final List<CalendarInfo> calendars;
  final Map<String, String> eventColorMap;
  final Set<String> hiddenCalendars;
  final bool loading;
  final String? error;

  const CalendarState({
    required this.year,
    required this.month,
    this.events = const [],
    this.calendars = const [],
    this.eventColorMap = const {},
    this.hiddenCalendars = const {},
    this.loading = false,
    this.error,
  });

  CalendarState copyWith({
    int? year, int? month,
    List<CalendarEvent>? events,
    List<CalendarInfo>? calendars,
    Map<String, String>? eventColorMap,
    Set<String>? hiddenCalendars,
    bool? loading, String? error,
  }) => CalendarState(
    year: year ?? this.year,
    month: month ?? this.month,
    events: events ?? this.events,
    calendars: calendars ?? this.calendars,
    eventColorMap: eventColorMap ?? this.eventColorMap,
    hiddenCalendars: hiddenCalendars ?? this.hiddenCalendars,
    loading: loading ?? this.loading,
    error: error,
  );

  Map<String, List<CalendarEvent>> get eventsByDate {
    final map = <String, List<CalendarEvent>>{};
    for (final e in events) {
      final k = e.dateKey;
      if (k.isNotEmpty) map.putIfAbsent(k, () => []).add(e);
    }
    return map;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier(ref.watch(apiClientProvider));
});

// ── Notifier ──────────────────────────────────────────────────────────────

class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier(this._api) : super(CalendarState(
    year: DateTime.now().year,
    month: DateTime.now().month,
    eventColorMap: Map.from(kGoogleEventColors),
  )) {
    _init();
  }

  final ApiClient _api;

  Future<void> _init() async {
    await _loadFilter();
    await _loadColors();
    await loadEvents();
  }

  Future<void> _loadFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('g-cal-filter-hidden') ?? [];
    state = state.copyWith(hiddenCalendars: raw.toSet());
  }

  Future<void> _saveFilter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('g-cal-filter-hidden', state.hiddenCalendars.toList());
  }

  Future<void> _loadColors() async {
    try {
      final results = await Future.wait([
        _api.get('https://www.googleapis.com/calendar/v3/colors'),
        _api.get('https://www.googleapis.com/calendar/v3/users/me/calendarList'),
      ]);
      final colorsData = results[0] as Map<String, dynamic>;
      final calListData = results[1] as Map<String, dynamic>;

      final eventMap = Map<String, String>.from(kGoogleEventColors);
      final apiEvent = (colorsData['event'] as Map?)?.cast<String, dynamic>() ?? {};
      for (final e in apiEvent.entries) {
        eventMap[e.key] = (e.value as Map)['background'] as String;
      }

      final calItems = (calListData['items'] as List?) ?? [];
      final calendars = calItems.map((item) {
        final m = item as Map<String, dynamic>;
        final colorHex = (m['backgroundColor'] as String?) ?? '#4285F4';
        final role = m['accessRole'] as String?;
        final isWritable = role == 'owner' || role == 'writer';
        return CalendarInfo(
          id: m['id'] as String,
          summary: (m['summary'] as String?) ?? '',
          color: hexToColor(colorHex),
          isWritable: isWritable,
        );
      }).toList();

      state = state.copyWith(eventColorMap: eventMap, calendars: calendars);
    } catch (e) { debugPrint('캘린더 색상 로드 실패: $e'); }
  }

  Future<void> loadEvents() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final from = DateTime(state.year, state.month, 1).toUtc().toIso8601String();
      final to = DateTime(state.year, state.month + 1, 0, 23, 59, 59).toUtc().toIso8601String();

      final sources = state.calendars.isNotEmpty
          ? state.calendars
          : [const CalendarInfo(id: 'primary', summary: '', color: Color(0xFF4285F4))];

      final events = <CalendarEvent>[];
      for (final cal in sources) {
        if (state.hiddenCalendars.contains(cal.id)) continue;
        try {
          final data = await _api.get(
            'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(cal.id)}/events',
            params: {
              'timeMin': from, 'timeMax': to,
              'singleEvents': 'true', 'orderBy': 'startTime', 'maxResults': '100',
            },
          );
          for (final item in (data['items'] as List?) ?? []) {
            events.add(CalendarEvent.fromJson(
              item as Map<String, dynamic>,
              calendarId: cal.id, calendarName: cal.summary,
              calColor: cal.color, eventColorMap: state.eventColorMap,
            ));
          }
        } catch (e) { debugPrint('캘린더 이벤트 로드 실패 (${cal.id}): $e'); }
      }

      events.sort((a, b) {
        final ak = a.isAllDay ? '${a.dateKey}T00:00' : (a.startDt?.toLocal().toIso8601String() ?? '');
        final bk = b.isAllDay ? '${b.dateKey}T00:00' : (b.startDt?.toLocal().toIso8601String() ?? '');
        return ak.compareTo(bk);
      });

      state = state.copyWith(events: events, loading: false);
      WidgetService.updateCalendar(events);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> prevMonth() async {
    var y = state.year;
    var m = state.month - 1;
    if (m < 1) { m = 12; y--; }
    state = state.copyWith(year: y, month: m);
    await loadEvents();
  }

  Future<void> nextMonth() async {
    var y = state.year;
    var m = state.month + 1;
    if (m > 12) { m = 1; y++; }
    state = state.copyWith(year: y, month: m);
    await loadEvents();
  }

  Future<void> goToday() async {
    final now = DateTime.now();
    state = state.copyWith(year: now.year, month: now.month);
    await loadEvents();
  }

  Future<void> toggleCalendar(String calId) async {
    final hidden = Set<String>.from(state.hiddenCalendars);
    if (hidden.contains(calId)) { hidden.remove(calId); } else { hidden.add(calId); }
    state = state.copyWith(hiddenCalendars: hidden);
    await _saveFilter();
    await loadEvents();
  }

  Future<void> saveEvent({
    String? eventId,
    required String calendarId,
    String? originalCalendarId,
    required String title,
    required bool isAllDay,
    DateTime? startDt,
    DateTime? endDt,
    String? startDate,
    String? colorId,
    String? location,
    String? description,
    String? recurrence,
    List<String>? attendeeEmails,
    String? notifMethod,
    int? notifMinutes,
  }) async {
    final body = <String, dynamic>{'summary': title};
    if (location?.isNotEmpty == true) body['location'] = location;
    if (description?.isNotEmpty == true) body['description'] = description;
    if (colorId?.isNotEmpty == true) body['colorId'] = colorId;
    if (recurrence?.isNotEmpty == true) body['recurrence'] = [recurrence];
    if (attendeeEmails?.isNotEmpty == true) {
      body['attendees'] = attendeeEmails!.map((e) => {'email': e}).toList();
    }
    if (notifMinutes != null) {
      body['reminders'] = {
        'useDefault': false,
        'overrides': [{'method': notifMethod ?? 'popup', 'minutes': notifMinutes}],
      };
    }
    if (isAllDay) {
      body['start'] = {'date': startDate};
      body['end'] = {'date': startDate};
    } else {
      body['start'] = {'dateTime': toRfc3339(startDt!)};
      body['end'] = {'dateTime': toRfc3339(endDt!)};
    }

    final calEnc = Uri.encodeComponent(calendarId);
    if (eventId != null) {
      if (originalCalendarId != null && originalCalendarId != calendarId) {
        // Move the event to the destination calendar first
        final srcEnc = Uri.encodeComponent(originalCalendarId);
        final evEnc = Uri.encodeComponent(eventId);
        await _api.post(
          'https://www.googleapis.com/calendar/v3/calendars/$srcEnc/events/$evEnc/move?destination=${Uri.encodeComponent(calendarId)}',
        );
      }
      await _api.patch(
        'https://www.googleapis.com/calendar/v3/calendars/$calEnc/events/${Uri.encodeComponent(eventId)}',
        body: body,
      );
    } else {
      await _api.post(
        'https://www.googleapis.com/calendar/v3/calendars/$calEnc/events',
        body: body,
      );
    }
    await loadEvents();
  }

  Future<void> deleteEvent(String calendarId, String eventId) async {
    await _api.delete(
      'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events/${Uri.encodeComponent(eventId)}',
    );
    state = state.copyWith(events: state.events.where((e) => e.id != eventId).toList());
  }
}
