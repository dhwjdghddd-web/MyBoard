import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'l10n_helper.dart';
import '../features/tasks/task_service.dart';
import '../features/calendar/calendar_service.dart';

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
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_list', display[i].listId));
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

  /// [year]/[month] 한 달치만 위젯 prefs에 반영한다.
  /// 주의: 이 함수가 다른 달의 cal_day_* 키까지 건드리면, 네이티브 위젯
  /// 동기화(CalendarSyncJobService)가 그 달에 써둔 데이터를 지워버린다.
  /// 그래서 과거에 5~8월 전체를 초기화하던 로직이 "7월 일정이 사라지는" 버그의
  /// 원인이었다. 반드시 인자로 받은 해당 월만 갱신할 것.
  static Future<void> updateCalendar(List<CalendarEvent> events,
      {required int year, required int month}) async {
    try {
      final allDayLabel = appL10n().allDay;

      bool inTargetMonth(CalendarEvent e) {
        final dt = e.startDt?.toLocal();
        if (dt != null) return dt.year == year && dt.month == month;
        if (e.startDate != null && e.startDate!.length >= 10) {
          return int.tryParse(e.startDate!.substring(0, 4)) == year &&
                 int.tryParse(e.startDate!.substring(5, 7)) == month;
        }
        return false;
      }

      final monthEvents = events.where(inTargetMonth).toList();

      int? dayOf(CalendarEvent e) {
        if (e.startDt != null) return e.startDt!.toLocal().day;
        if (e.startDate != null && e.startDate!.length >= 10) {
          return int.tryParse(e.startDate!.substring(8, 10));
        }
        return null;
      }

      // 네이티브 CalendarSyncJobService와 동일한 정렬 키(시작 instant epoch millis).
      int startMs(CalendarEvent e) {
        if (e.startDt != null) return e.startDt!.millisecondsSinceEpoch;
        if (e.startDate != null && e.startDate!.length >= 10) {
          final d = DateTime.tryParse(e.startDate!);
          if (d != null) return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
        }
        return 0;
      }

      // 월별 이벤트 날짜 집합 (해당 월만)
      final days = monthEvents.map(dayOf).whereType<int>().where((d) => d > 0).toSet();
      await HomeWidget.saveWidgetData<String>('cal_ev_${year}_$month', days.join(','));
      final now = DateTime.now();
      if (year == now.year && month == now.month) {
        await HomeWidget.saveWidgetData<String>('cal_event_days', days.join(','));
      }

      // 일별 데이터: 해당 월의 모든 날을 빈값으로 초기화 후 이벤트로 채운다.
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final Map<int, List<CalendarEvent>> byDay = {
        for (var d = 1; d <= daysInMonth; d++) d: <CalendarEvent>[],
      };
      for (final e in monthEvents) {
        final day = dayOf(e);
        if (day != null && byDay.containsKey(day)) byDay[day]!.add(e);
      }

      final dayFutures = <Future>[];
      for (final entry in byDay.entries) {
        final key = '${year.toString().padLeft(4, '0')}${month.toString().padLeft(2, '0')}${entry.key.toString().padLeft(2, '0')}';
        final evList = entry.value;
        evList.sort((a, b) {
          // 종일 먼저 → 실제 시작 instant → id (네이티브와 동일 순서)
          if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
          final c = startMs(a).compareTo(startMs(b));
          return c != 0 ? c : a.id.compareTo(b.id);
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

  static Future<void> clearAllData() async {
    try {
      final now = DateTime.now();
      final futures = <Future>[];

      // 태스크
      futures.add(HomeWidget.saveWidgetData<String>('task_count', '0'));
      for (var i = 0; i < 100; i++) {
        futures.add(HomeWidget.saveWidgetData<String>('task_$i', ''));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_id', ''));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_list', ''));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_done', 'false'));
        futures.add(HomeWidget.saveWidgetData<String>('task_${i}_due', ''));
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
