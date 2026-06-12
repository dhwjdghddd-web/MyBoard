import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../features/tasks/task_service.dart';
import '../features/calendar/calendar_service.dart';
import '../features/gmail/gmail_service.dart';

class WidgetService {
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

      await HomeWidget.saveWidgetData<String>('task_count', '${display.length}');
      for (var i = 0; i < display.length; i++) {
        await HomeWidget.saveWidgetData<String>('task_$i', display[i].title);
        await HomeWidget.saveWidgetData<String>('task_${i}_id', display[i].id);
        await HomeWidget.saveWidgetData<String>('task_${i}_done', display[i].isCompleted ? 'true' : 'false');
        await HomeWidget.saveWidgetData<String>('task_${i}_due', display[i].due != null ? display[i].due!.toIso8601String() : '');
      }
      // 이전 동기화에서 남은 슬롯 제거
      for (var i = display.length; i < display.length + 30; i++) {
        final old = await HomeWidget.getWidgetData<String>('task_$i', defaultValue: '');
        if (old == null || old.isEmpty) break;
        await HomeWidget.saveWidgetData<String>('task_$i', '');
        await HomeWidget.saveWidgetData<String>('task_${i}_id', '');
        await HomeWidget.saveWidgetData<String>('task_${i}_done', 'false');
        await HomeWidget.saveWidgetData<String>('task_${i}_due', '');
      }
      await HomeWidget.updateWidget(androidName: 'HomeWidgetProvider');
    } catch (e, st) {
      debugPrint('WidgetService.updateTasks error: $e\n$st');
    }
  }

  static Future<void> updateCalendar(List<CalendarEvent> events) async {
    try {
      final now = DateTime.now();

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
          if (e.isAllDay) return '종일';
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
        await HomeWidget.saveWidgetData<String>('cal_day_${key}_titles', titles);
        await HomeWidget.saveWidgetData<String>('cal_day_${key}_times',  times);
        await HomeWidget.saveWidgetData<String>('cal_day_${key}_ids',    ids);
        await HomeWidget.saveWidgetData<String>('cal_day_${key}_colors', colors);
      }

      await HomeWidget.updateWidget(androidName: 'HomeWidgetProvider');
    } catch (e, st) {
      debugPrint('WidgetService.updateCalendar error: $e\n$st');
    }
  }

  static Future<void> updateGmail(List<GmailMessage> messages) async {
    try {
      final sorted = List<GmailMessage>.from(messages);
      sorted.sort((a, b) {
        final valA = int.tryParse(a.internalDate) ?? 0;
        final valB = int.tryParse(b.internalDate) ?? 0;
        return valB.compareTo(valA);
      });

      final unread = sorted.where((m) => m.isUnread).length;
      await HomeWidget.saveWidgetData<String>('gmail_unread', '$unread');

      final gmailCount = sorted.length < 25 ? sorted.length : 25;
      await HomeWidget.saveWidgetData<int>('gmail_count', gmailCount);

      for (var i = 0; i < 25; i++) {
        if (i < sorted.length) {
          final m = sorted[i];
          // 발신자 표시 이름
          final sender = m.displayName.isNotEmpty ? m.displayName : m.from;
          // 시간: gmail_service의 formatEmailDate 사용
          final timeStr = formatEmailDate(m.date);
          // subject
          final subjectLine = m.subject.isNotEmpty ? m.subject : '(제목 없음)';
          await HomeWidget.saveWidgetData<String>('gmail_${i}_sender',  sender);
          await HomeWidget.saveWidgetData<String>('gmail_${i}_time',    timeStr);
          await HomeWidget.saveWidgetData<String>('gmail_${i}_subject', subjectLine);
          await HomeWidget.saveWidgetData<String>('gmail_${i}_unread',  m.isUnread ? 'true' : 'false');
          await HomeWidget.saveWidgetData<String>('gmail_${i}_id',      m.id);
        } else {
          await HomeWidget.saveWidgetData<String>('gmail_${i}_sender',  '');
          await HomeWidget.saveWidgetData<String>('gmail_${i}_time',    '');
          await HomeWidget.saveWidgetData<String>('gmail_${i}_subject', '');
          await HomeWidget.saveWidgetData<String>('gmail_${i}_unread',  'false');
          await HomeWidget.saveWidgetData<String>('gmail_${i}_id',      '');
        }
      }
      await HomeWidget.updateWidget(androidName: 'HomeWidgetProvider');
    } catch (e, st) {
      debugPrint('WidgetService.updateGmail error: $e\n$st');
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
