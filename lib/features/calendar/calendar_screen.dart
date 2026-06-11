import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tasks/task_service.dart';
import 'calendar_service.dart';
import 'event_detail_sheet.dart';
import 'event_form_screen.dart';
import '../settings/widget_settings_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _showFilter = false;

  @override
  Widget build(BuildContext context) {
    final cal = ref.watch(calendarProvider);
    final tasks = ref.watch(taskServiceProvider).value ?? [];

    // 태스크 마감일 → dateKey 맵
    final tasksByDate = <String, List<Task>>{};
    for (final t in tasks) {
      if (t.due != null && !t.isCompleted) {
        final d = t.due!.toLocal();
        final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
        tasksByDate.putIfAbsent(key, () => []).add(t);
      }
    }

    // 이번 달 일정 정렬 (태스크 포함)
    final allMonthItems = <_MonthItem>[];
    for (final e in cal.events) {
      allMonthItems.add(_MonthItem.fromEvent(e));
    }
    for (final entry in tasksByDate.entries) {
      // 이번 달 태스크만
      if (entry.key.startsWith('${cal.year}-${cal.month.toString().padLeft(2,'0')}')) {
        for (final t in entry.value) {
          allMonthItems.add(_MonthItem.fromTask(t, entry.key));
        }
      }
    }
    allMonthItems.sort((a, b) => a.sortKey.compareTo(b.sortKey));

    return Scaffold(
      appBar: AppBar(
        title: _MonthNav(cal: cal, ref: ref),
        titleSpacing: 0,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            ),
            onPressed: () => ref.read(calendarProvider.notifier).goToday(),
            child: const Text('오늘'),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: cal.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: () => ref.read(calendarProvider.notifier).loadEvents(),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.filter_list),
            onPressed: () => setState(() => _showFilter = !_showFilter),
            tooltip: '캘린더 필터',
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WidgetSettingsScreen())),
          ),
        ],
      ),
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: () => ref.read(calendarProvider.notifier).loadEvents(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [
              // 요일 헤더
              _DowHeader(),
              // 달력 그리드 (자연 높이)
              _CalendarGrid(
                year: cal.year,
                month: cal.month,
                eventsByDate: cal.eventsByDate,
                tasksByDate: tasksByDate,
              ),
              const Divider(height: 1),
              // 이달 일정 목록 헤더
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                alignment: Alignment.centerLeft,
                child: Text(
                  '${cal.year}년 ${cal.month}월 일정 (${allMonthItems.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // 이달 일정 리스트
              allMonthItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          '이번 달 일정이 없어요',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: allMonthItems.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                      itemBuilder: (ctx, i) => _MonthItemTile(item: allMonthItems[i]),
                    ),
            ]),
          ),
        ),
        // 캘린더 필터 패널
        if (_showFilter)
          GestureDetector(
            onTap: () => setState(() => _showFilter = false),
            child: Container(color: Colors.transparent),
          ),
        if (_showFilter)
          Positioned(
            top: 0, right: 0,
            child: _CalendarFilterPanel(
              calendars: cal.calendars,
              hiddenCalendars: cal.hiddenCalendars,
              onToggle: (id) => ref.read(calendarProvider.notifier).toggleCalendar(id),
              onClose: () => setState(() => _showFilter = false),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final now = DateTime.now();
          final key = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventFormScreen(initialDateKey: key)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── 이달 일정 아이템 모델 ─────────────────────────────────────────────────

class _MonthItem {
  final String dateKey;
  final String sortKey;
  final String title;
  final Color color;
  final bool isTask;
  final bool isAllDay;
  final String timeLabel;

  const _MonthItem({
    required this.dateKey,
    required this.sortKey,
    required this.title,
    required this.color,
    required this.isTask,
    required this.isAllDay,
    required this.timeLabel,
  });

  factory _MonthItem.fromEvent(CalendarEvent e) {
    final time = e.isAllDay
        ? '종일'
        : (e.startDt != null
            ? '${e.startDt!.toLocal().hour.toString().padLeft(2,'0')}:${e.startDt!.toLocal().minute.toString().padLeft(2,'0')}'
            : '');
    final sk = e.isAllDay ? '${e.dateKey}T00:00' : (e.startDt?.toLocal().toIso8601String() ?? e.dateKey);
    return _MonthItem(
      dateKey: e.dateKey,
      sortKey: sk,
      title: e.summary,
      color: e.color,
      isTask: false,
      isAllDay: e.isAllDay,
      timeLabel: time,
    );
  }

  factory _MonthItem.fromTask(Task t, String dateKey) {
    return _MonthItem(
      dateKey: dateKey,
      sortKey: '${dateKey}T00:00',
      title: t.title,
      color: const Color(0xFF1A73E8),
      isTask: true,
      isAllDay: true,
      timeLabel: '마감',
    );
  }

  String get displayDate {
    final parts = dateKey.split('-');
    if (parts.length < 3) return dateKey;
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    final dt = DateTime.tryParse('${dateKey}T00:00:00');
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = dt != null ? weekdays[dt.weekday - 1] : '';
    return '$m/$d($wd)';
  }
}

// ── 이달 일정 타일 ────────────────────────────────────────────────────────

class _MonthItemTile extends StatelessWidget {
  const _MonthItemTile({required this.item});
  final _MonthItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          // 날짜 열
          SizedBox(
            width: 44,
            child: Text(
              item.displayDate,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // 색상 점 / 태스크 아이콘
          item.isTask
              ? Icon(Icons.check_box_outline_blank, size: 14, color: item.color)
              : Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          // 제목
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(fontSize: 13, fontWeight: item.isTask ? FontWeight.normal : FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 시간
          if (item.timeLabel.isNotEmpty)
            Text(
              item.timeLabel,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
        ]),
      ),
    );
  }
}

// ── 월 이동 ───────────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  const _MonthNav({required this.cal, required this.ref});
  final CalendarState cal;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: const Icon(Icons.chevron_left, color: Colors.white),
        onPressed: () => ref.read(calendarProvider.notifier).prevMonth(),
      ),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${cal.year}년 ${cal.month}월',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: const Icon(Icons.chevron_right, color: Colors.white),
        onPressed: () => ref.read(calendarProvider.notifier).nextMonth(),
      ),
    ]);
  }
}

// ── 요일 헤더 ────────────────────────────────────────────────────────────

class _DowHeader extends StatelessWidget {
  static const _days = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: List.generate(7, (i) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            alignment: Alignment.center,
            child: Text(
              _days[i],
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: i == 0 ? Colors.red[400] : (i == 6 ? Colors.blue[400] : muted),
              ),
            ),
          ),
        )),
      ),
    );
  }
}

// ── 달력 그리드 ───────────────────────────────────────────────────────────

class _CalendarGrid extends ConsumerWidget {
  const _CalendarGrid({
    required this.year, required this.month,
    required this.eventsByDate, required this.tasksByDate,
  });

  final int year, month;
  final Map<String, List<CalendarEvent>> eventsByDate;
  final Map<String, List<Task>> tasksByDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startOffset = firstDay.weekday % 7;
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();
    final double textScale = MediaQuery.maybeTextScalerOf(context)?.scale(1.0) ?? 
                             (MediaQuery.maybeOf(context)?.textScaleFactor) ?? 1.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = screenWidth / 7;
    final minCellHeight = 28.0 + (38.0 * textScale);
    final childAspectRatio = (cellWidth / minCellHeight).clamp(0.45, 0.85);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, childAspectRatio: childAspectRatio,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, i) {
        final dayNum = i - startOffset + 1;
        if (dayNum < 1 || dayNum > lastDay.day) {
          final bColor = Theme.of(context).colorScheme.outlineVariant;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                right:  BorderSide(color: bColor, width: 0.5),
                bottom: BorderSide(color: bColor, width: 0.5),
              ),
            ),
          );
        }
        final dateKey = '$year-${month.toString().padLeft(2,'0')}-${dayNum.toString().padLeft(2,'0')}';
        final isToday = dayNum == today.day && month == today.month && year == today.year;
        final dayEvents = eventsByDate[dateKey] ?? [];
        final dayTasks = tasksByDate[dateKey] ?? [];
        final col = i % 7;
        final isWeekend = col == 0 || col == 6;
        final isSunday = col == 0;

        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => EventDetailSheet(dateKey: dateKey, events: dayEvents),
          ),
          child: _DayCell(
            day: dayNum, isToday: isToday, isSunday: isSunday,
            events: dayEvents, tasks: dayTasks, isWeekend: isWeekend,
          ),
        );
      },
    );
  }
}

// ── 날짜 셀 ──────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day, required this.isToday, required this.isSunday,
    required this.events, required this.tasks, required this.isWeekend,
  });

  final int day;
  final bool isToday, isWeekend, isSunday;
  final List<CalendarEvent> events;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final allItems = [
      ...events.map((e) => (title: e.summary, color: e.color, isTask: false, isAllDay: e.isAllDay, startDt: e.startDt)),
      ...tasks.map((t) => (title: t.title, color: const Color(0xFF1A73E8), isTask: true, isAllDay: false, startDt: t.due)),
    ];
    allItems.sort((a, b) {
      if (a.isAllDay && !b.isAllDay) return -1;
      if (!a.isAllDay && b.isAllDay) return 1;
      if (!a.isTask && b.isTask) return -1;
      if (a.isTask && !b.isTask) return 1;
      if (a.startDt != null && b.startDt != null) {
        return a.startDt!.toLocal().compareTo(b.startDt!.toLocal());
      }
      return 0;
    });
    final visible = allItems.take(2).toList();
    final extra = allItems.length - visible.length;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: scheme.outlineVariant, width: 0.5),
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        color: isToday ? scheme.primaryContainer.withAlpha(60) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 2),
            width: 20, height: 20,
            decoration: isToday
                ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
                : null,
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 11, fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? Colors.white
                    : (isWeekend ? (isSunday ? Colors.red[400] : Colors.blue[400]) : null),
              ),
            ),
          ),
        ),
        for (final item in visible)
          if (item.isTask)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
              child: Row(children: [
                Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF1A73E8), shape: BoxShape.circle)),
                const SizedBox(width: 3),
                Expanded(child: Text(item.title, style: const TextStyle(fontSize: 9.5, color: Color(0xFF1A73E8)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            )
          else
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: item.color.withOpacity(0.85), borderRadius: BorderRadius.circular(6)),
              child: Text(
                item.title,
                style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Text('+$extra', style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

// ── 캘린더 필터 패널 ─────────────────────────────────────────────────────

class _CalendarFilterPanel extends StatelessWidget {
  const _CalendarFilterPanel({
    required this.calendars,
    required this.hiddenCalendars,
    required this.onToggle,
    required this.onClose,
  });

  final List<CalendarInfo> calendars;
  final Set<String> hiddenCalendars;
  final void Function(String) onToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 240,
        constraints: const BoxConstraints(maxHeight: 360),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(children: [
              Text('캘린더 표시', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClose, padding: EdgeInsets.zero),
            ]),
          ),
          const Divider(height: 1),
          if (calendars.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('로그인 후 이용 가능해요', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: calendars.length,
                itemBuilder: (_, i) {
                  final c = calendars[i];
                  final enabled = !hiddenCalendars.contains(c.id);
                  return ListTile(
                    dense: true,
                    leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                    title: Text(c.summary, style: const TextStyle(fontSize: 13)),
                    trailing: Checkbox(
                      value: enabled,
                      onChanged: (_) => onToggle(c.id),
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () => onToggle(c.id),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}
