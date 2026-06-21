import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'l10n_helper.dart';
import '../features/tasks/task_service.dart';
import '../features/calendar/calendar_service.dart';
import '../features/gmail/gmail_service.dart';

class WidgetService {
  // 위젯 프로바이더의 정규화된 클래스명. 코틀린 네임스페이스(namespace)는
  // applicationId(com.dhwjdgh.myboard[.debug])와 다르므로, home_widget 플러그인이
  // ${packageName}.HomeWidgetProvider 로 클래스를 찾으면 ClassNotFoundException 이
  // 발생해 위젯 갱신 브로드캐스트가 실패한다. 정확한 FQN 을 직접 지정한다.
  static const _providerClass = 'com.dhwjdgh.prv_dashboard.HomeWidgetProvider';

  static Future<void> saveTaskListId(String listId) async {
    try {
      await HomeWidget.saveWidgetData<String>('task_list_id', listId);
    } catch (e, st) {
      debugPrint('WidgetService.saveTaskListId error: $e\n$st');
    }
  }

  static Future<void> updateTasks(List<Task> tasks) async {
    try {
      final active = tasks.where((t) => !t.isCompleted).toList();
      final display = [...active, ...tasks.where((t) => t.isCompleted)];

      final futures = <Future>[
        HomeWidget.saveWidgetData<String>('task_count', '${display.length}'),
      ];
      for (var i = 0; i < display.length; i++) {
        futures.add(HomeWidget.saveWidgetData<String>('task_$i', display[i].title));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_id', display[i].id));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_done', display[i].isCompleted ? 'true' : 'false'));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_due', display[i].due != null ? display[i].due!.toIso8601String() : ''));
      }
      // task_count를 신뢰하므로 별도 tail 정리 불필요 — 위젯은 0..task_count-1만 읽음
      await Future.wait(futures);
      await HomeWidget.updateWidget(qualifiedAndroidName: _providerClass);
    } catch (e, st) {
      debugPrint('WidgetService.updateTasks error: $e\n$st');
    }
  }

  static Future<void> updateCalendar(List<CalendarEvent> events) async {
    try {
      final now = DateTime.now();
      final allDayLabel = appL10n().allDay;

      // 월별 이벤트 날짜 집합 저장 (현재 달 ±1개월)
      for (var offset = -1; offset <= 1; offset++) {
        final targetMonth = DateTime(now.year, now.month + offset);
        final ty = targetMonth.year;
        final tm = targetMonth.month;
        final days = events
            .where((e) {
              final dt = e.startDt?.toLocal();
              if (dt != null) return dt.year == ty && dt.month == tm;
              if (e.startDate != null && e.startDate!.length >= 10) {
                return int.tryParse(e.startDate!.substring(0, 4)) == ty &&
                       int.tryParse(e.startDate!.substring(5, 7)) == tm;
              }
              return false;
            })
            .map((e) {
              if (e.startDt != null) return e.startDt!.toLocal().day;
              if (e.startDate != null && e.startDate!.length >= 10) {
                return int.tryParse(e.startDate!.substring(8, 10)) ?? 0;
              }
              return 0;
            })
            .where((d) => d > 0)
            .toSet();
        await HomeWidget.saveWidgetData<String>('cal_ev_${ty}_$tm', days.join(','));
        // generic fallback key for current month
        if (offset == 0) {
          await HomeWidget.saveWidgetData<String>('cal_event_days', days.join(','));
        }
      }

      // 일별 이벤트 데이터 저장 (위젯 날짜 탭 시 상세 패널 표시용)
      // key: cal_day_YYYYMMDD_titles / _times / _ids
      final Map<String, List<CalendarEvent>> byDay = {};
      final startMonth = DateTime(now.year, now.month - 1, 1);
      final endMonth = DateTime(now.year, now.month + 2, 0);
      for (var d = startMonth; d.isBefore(endMonth.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
        final dayKey = '${d.year.toString().padLeft(4,'0')}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
        byDay[dayKey] = [];
      }

      for (final e in events) {
        String? dayKey;
        if (e.startDt != null) {
          final d = e.startDt!.toLocal();
          dayKey = '${d.year.toString().padLeft(4,'0')}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
        } else if (e.startDate != null && e.startDate!.length >= 10) {
          dayKey = e.startDate!.replaceAll('-', '').substring(0, 8);
        }
        if (dayKey != null) {
          byDay.putIfAbsent(dayKey, () => []).add(e);
        }
      }
      final dayFutures = <Future>[];
      for (final entry in byDay.entries) {
        final key = entry.key;
        final evList = entry.value;
        evList.sort((a, b) {
          if (a.isAllDay && !b.isAllDay) return -1;
          if (!a.isAllDay && b.isAllDay) return 1;
          if (a.startDt != null && b.startDt != null) {
            return a.startDt!.toLocal().compareTo(b.startDt!.toLocal());
          }
          return 0;
        });
        final take = evList.take(25).toList();
        final titles = take.map((e) => e.summary).join('|');
        final times  = take.map((e) {
          if (e.isAllDay) return allDayLabel;
          if (e.startDt != null) {
            final d = e.startDt!.toLocal();
            return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
          }
          return '';
        }).join('|');
        final ids = take.map((e) => e.id).join('|');
        final colors = take.map((e) {
          final hex = e.color.toARGB32().toRadixString(16).padLeft(8, '0');
          return '#$hex';
        }).join('|');
        dayFutures.add(HomeWidget.saveWidgetData<String>('cal_day_${key}_titles', titles));
        dayFutures.add(HomeWidget.saveWidgetData<String>('cal_day_${key}_times',  times));
        dayFutures.add(HomeWidget.saveWidgetData<String>('cal_day_${key}_ids',    ids));
        dayFutures.add(HomeWidget.saveWidgetData<String>('cal_day_${key}_colors', colors));
      }
      await Future.wait(dayFutures);

      await HomeWidget.updateWidget(qualifiedAndroidName: _providerClass);
    } catch (e, st) {
      debugPrint('WidgetService.updateCalendar error: $e\n$st');
    }
  }

  static Future<void> updateGmail(List<GmailMessage> messages) async {
    try {
      final noSubject = appL10n().noSubject;
      final sorted = List<GmailMessage>.from(messages);
      sorted.sort((a, b) {
        final valA = int.tryParse(a.internalDate) ?? 0;
        final valB = int.tryParse(b.internalDate) ?? 0;
        return valB.compareTo(valA);
      });

      final unread = sorted.where((m) => m.isUnread).length;
      final gmailCount = sorted.length < 25 ? sorted.length : 25;
      final gmailFutures = <Future>[
        HomeWidget.saveWidgetData<String>('gmail_unread', '$unread'),
        HomeWidget.saveWidgetData<int>('gmail_count', gmailCount),
      ];
      for (var i = 0; i < 25; i++) {
        if (i < sorted.length) {
          final m = sorted[i];
          final sender = m.displayName.isNotEmpty ? m.displayName : m.from;
          final timeStr = formatEmailDate(m.date, isEnglish: isEnglishLocale());
          final subjectLine = m.subject.isNotEmpty ? m.subject : noSubject;
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_sender',  sender));
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_time',    timeStr));
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_subject', subjectLine));
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_unread',  m.isUnread ? 'true' : 'false'));
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_id',      m.id));
        } else {
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_sender',  ''));
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_time',    ''));
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_subject', ''));
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_unread',  'false'));
          gmailFutures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_id',      ''));
        }
      }
      await Future.wait(gmailFutures);
      await HomeWidget.updateWidget(qualifiedAndroidName: _providerClass);
    } catch (e, st) {
      debugPrint('WidgetService.updateGmail error: $e\n$st');
    }
  }

  static Future<void> clearAllData() async {
    try {
      final now = DateTime.now();
      final futures = <Future>[];

      // 태스크
      futures.add(HomeWidget.saveWidgetData<String>('task_count', '0'));
      for (var i = 0; i < 100; i++) {
        futures.add(HomeWidget.saveWidgetData<String>('task_$i', ''));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_id', ''));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_done', 'false'));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_due', ''));
      }

      // Gmail
      futures.add(HomeWidget.saveWidgetData<int>('gmail_count', 0));
      for (var i = 0; i < 25; i++) {
        futures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_sender', ''));
        futures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_time', ''));
        futures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_subject', ''));
        futures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_unread', 'false'));
        futures.add(HomeWidget.saveWidgetData<String>('gmail_${i}_id', ''));
      }

      // 캘린더 — updateCalendar와 동일 범위로 정리
      futures.add(HomeWidget.saveWidgetData<String>('cal_event_days', ''));
      for (var offset = -1; offset <= 1; offset++) {
        final t = DateTime(now.year, now.month + offset);
        futures.add(HomeWidget.saveWidgetData<String>('cal_ev_${t.year}_${t.month}', ''));
      }
      final startMonth = DateTime(now.year, now.month - 1, 1);
      final endMonth = DateTime(now.year, now.month + 2, 0);
      for (var d = startMonth; d.isBefore(endMonth.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
        final key = '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
        futures.add(HomeWidget.saveWidgetData<String>('cal_day_${key}_titles', ''));
        futures.add(HomeWidget.saveWidgetData<String>('cal_day_${key}_times', ''));
        futures.add(HomeWidget.saveWidgetData<String>('cal_day_${key}_ids', ''));
        futures.add(HomeWidget.saveWidgetData<String>('cal_day_${key}_colors', ''));
      }

      await Future.wait(futures);
      await HomeWidget.updateWidget(qualifiedAndroidName: _providerClass);
    } catch (e, st) {
      debugPrint('WidgetService.clearAllData error: $e\n$st');
    }
  }

  static Future<List<String>> getPendingCompletions() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('pending_completions', defaultValue: '');
      if (raw == null || raw.isEmpty) return [];
      return raw.split(',').where((s) => s.isNotEmpty).toList();
    } catch (e, st) {
      debugPrint('WidgetService.getPendingCompletions error: $e\n$st');
      return [];
    }
  }

  static Future<void> clearPendingCompletions() async {
    try {
      await HomeWidget.saveWidgetData<String>('pending_completions', '');
    } catch (e, st) {
      debugPrint('WidgetService.clearPendingCompletions error: $e\n$st');
    }
  }

  static Future<List<String>> getPendingDeletions() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('pending_deletions', defaultValue: '');
      if (raw == null || raw.isEmpty) return [];
      return raw.split(',').where((s) => s.isNotEmpty).toList();
    } catch (e, st) {
      debugPrint('WidgetService.getPendingDeletions error: $e\n$st');
      return [];
    }
  }

  static Future<void> clearPendingDeletions() async {
    try {
      await HomeWidget.saveWidgetData<String>('pending_deletions', '');
    } catch (e, st) {
      debugPrint('WidgetService.clearPendingDeletions error: $e\n$st');
    }
  }

  static Future<List<String>> getPendingNewTasks() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('pending_new_tasks', defaultValue: '');
      if (raw == null || raw.isEmpty) return [];
      return raw.split('\n').where((s) => s.isNotEmpty).toList();
    } catch (e, st) {
      debugPrint('WidgetService.getPendingNewTasks error: $e\n$st');
      return [];
    }
  }

  static Future<void> clearPendingNewTasks() async {
    try {
      await HomeWidget.saveWidgetData<String>('pending_new_tasks', '');
    } catch (e, st) {
      debugPrint('WidgetService.clearPendingNewTasks error: $e\n$st');
    }
  }
}
