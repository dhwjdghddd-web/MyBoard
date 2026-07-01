import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
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
    final tasks = ref.watch(taskServiceProvider).valueOrNull ?? [];
    final l = AppLocalizations.of(context)!;

    final tasksByDate = <String, List<Task>>{};
    for (final t in tasks) {
      if (t.due != null && !t.isCompleted) {
        final d = t.due!.toLocal();
        final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
        tasksByDate.putIfAbsent(key, () => []).add(t);
      }
    }

    final allMonthItems = <_MonthItem>[];
    for (final e in cal.events) {
      allMonthItems.add(_MonthItem.fromEvent(e, allDayLabel: l.allDay));
    }
    for (final entry in tasksByDate.entries) {
      if (entry.key.startsWith('${cal.year}-${cal.month.toString().padLeft(2,'0')}')) {
        for (final t in entry.value) {
          allMonthItems.add(_MonthItem.fromTask(t, entry.key, dueLabel: l.taskDue));
        }
      }
    }
    allMonthItems.sort((a, b) {
      final c = a.sortKey.compareTo(b.sortKey);
      return c != 0 ? c : a.id.compareTo(b.id); // 동점 시 결정적 tiebreak
    });

    // 현재 달이면 '오늘 이후 남은 일정'만, 다른 달은 그 달 전체를 표시한다.
    final now = DateTime.now();
    final isCurrentMonth = cal.year == now.year && cal.month == now.month;
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final monthItems = isCurrentMonth
        ? allMonthItems.where((it) => it.dateKey.compareTo(todayKey) >= 0).toList()
        : allMonthItems;
    final monthHeaderText = isCurrentMonth
        ? l.calendarMonthRemainingHeader(monthItems.length)
        : l.calendarMonthItemsHeader(cal.year, cal.month, monthItems.length);
    final emptyText = isCurrentMonth ? l.calendarNoRemaining : l.calendarEmpty;

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
            child: Text(l.calendarToday),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: cal.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            tooltip: l.refreshTooltip,
            onPressed: () => ref.read(calendarProvider.notifier).loadEvents(),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.filter_list),
            onPressed: () => setState(() => _showFilter = !_showFilter),
            tooltip: l.calendarFilter,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.settings),
            tooltip: l.settingsTitle,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WidgetSettingsScreen())),
          ),
        ],
      ),
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: () => ref.read(calendarProvider.notifier).loadEvents(),
          child: MediaQuery.of(context).size.width >= 600
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(children: [
                          _DowHeader(),
                          _CalendarGrid(
                            year: cal.year,
                            month: cal.month,
                            eventsByDate: cal.eventsByDate,
                            tasksByDate: tasksByDate,
                          ),
                        ]),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      flex: 4,
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            monthHeaderText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Expanded(
                          child: monthItems.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      emptyText,
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: monthItems.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                                  itemBuilder: (ctx, i) => _MonthItemTile(item: monthItems[i]),
                                ),
                        ),
                      ]),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(children: [
                    _DowHeader(),
                    _CalendarGrid(
                      year: cal.year,
                      month: cal.month,
                      eventsByDate: cal.eventsByDate,
                      tasksByDate: tasksByDate,
                    ),
                    const Divider(height: 1),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        monthHeaderText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    monthItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                emptyText,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: monthItems.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                            itemBuilder: (ctx, i) => _MonthItemTile(item: monthItems[i]),
                          ),
                  ]),
                ),
        ),
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
  final String id;
  final String dateKey;
  final String sortKey;
  final String title;
  final Color color;
  final bool isTask;
  final bool isAllDay;
  final String timeLabel;

  const _MonthItem({
    required this.id,
    required this.dateKey,
    required this.sortKey,
    required this.title,
    required this.color,
    required this.isTask,
    required this.isAllDay,
    required this.timeLabel,
  });

  factory _MonthItem.fromEvent(CalendarEvent e, {required String allDayLabel}) {
    final time = e.isAllDay
        ? allDayLabel
        : (e.startDt != null
            ? '${e.startDt!.toLocal().hour.toString().padLeft(2,'0')}:${e.startDt!.toLocal().minute.toString().padLeft(2,'0')}'
            : '');
    final sk = e.isAllDay ? '${e.dateKey}T00:00' : (e.startDt?.toLocal().toIso8601String() ?? e.dateKey);
    return _MonthItem(
      id: e.id,
      dateKey: e.dateKey,
      sortKey: sk,
      title: e.summary,
      color: e.color,
      isTask: false,
      isAllDay: e.isAllDay,
      timeLabel: time,
    );
  }

  factory _MonthItem.fromTask(Task t, String dateKey, {required String dueLabel}) {
    return _MonthItem(
      id: t.id,
      dateKey: dateKey,
      sortKey: '${dateKey}T00:00',
      title: t.title,
      color: const Color(0xFF1A73E8),
      isTask: true,
      isAllDay: true,
      timeLabel: dueLabel,
    );
  }

  // weekdayNames: index 0=Mon(weekday==1) … 6=Sun(weekday==7)
  String displayDate(List<String> weekdayNames) {
    final parts = dateKey.split('-');
    if (parts.length < 3) return dateKey;
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    final dt = DateTime.tryParse('${dateKey}T00:00:00');
    final wd = dt != null ? weekdayNames[dt.weekday - 1] : '';
    return '$m/$d\n$wd';
  }
}

// ── 이달 일정 타일 ────────────────────────────────────────────────────────

class _MonthItemTile extends StatelessWidget {
  const _MonthItemTile({required this.item});
  final _MonthItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    // weekday 1=Mon … 7=Sun
    final weekdayNames = [
      l.weekdayMon, l.weekdayTue, l.weekdayWed, l.weekdayThu, l.weekdayFri, l.weekdaySat, l.weekdaySun,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => EventDetailSheet(dateKey: item.dateKey),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              child: Text(
                item.displayDate(weekdayNames),
                style: TextStyle(
                  fontSize: 10.5,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            item.isTask
                ? Icon(Icons.check_box_outline_blank, size: 14, color: item.color)
                : Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: item.isTask ? FontWeight.normal : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.timeLabel.isNotEmpty)
              Text(
                item.timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ]),
        ),
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
    final l = AppLocalizations.of(context)!;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: const Icon(Icons.chevron_left, color: Colors.white),
        onPressed: () => ref.read(calendarProvider.notifier).prevMonth(),
      ),
      Flexible(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            final picked = await showDialog<int>(
              context: context,
              builder: (_) => _YearPickerDialog(initialYear: cal.year),
            );
            if (picked != null) {
              ref.read(calendarProvider.notifier).setYear(picked);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l.calendarMonthFormat(cal.year, cal.month),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
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

// ── 연도 선택 다이얼로그 ─────────────────────────────────────────────────

class _YearPickerDialog extends StatefulWidget {
  const _YearPickerDialog({required this.initialYear});
  final int initialYear;

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.calendarYearPickerTitle),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l.calendarPrevYear,
            onPressed: () => setState(() => _year--),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '$_year',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l.calendarNextYear,
            onPressed: () => setState(() => _year++),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _year),
          child: Text(l.calendarYearPickerApply),
        ),
      ],
    );
  }
}

// ── 요일 헤더 ────────────────────────────────────────────────────────────

class _DowHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Sun=0, Mon=1, … Sat=6
    final days = [
      l.weekdaySun, l.weekdayMon, l.weekdayTue, l.weekdayWed, l.weekdayThu, l.weekdayFri, l.weekdaySat,
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: List.generate(7, (i) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            alignment: Alignment.center,
            child: Text(
              days[i],
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
    final double textScale = MediaQuery.maybeTextScalerOf(context)?.scale(1.0) ?? 1.0;
    final bool isTablet = MediaQuery.of(context).size.width >= 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final calendarWidth = isTablet ? (screenWidth * 0.6) : screenWidth;
    final cellWidth = calendarWidth / 7;
    final minCellHeight = 28.0 + (38.0 * textScale);
    final childAspectRatio = (cellWidth / minCellHeight).clamp(0.45, 0.85);

    final cellHeight = cellWidth / childAspectRatio;
    final availableForEvents = cellHeight - 24.0;
    final calculatedSlots = (availableForEvents / 15.0).floor();
    final maxSlots = isTablet ? calculatedSlots.clamp(2, 6) : 2;

    // 다중일 '종일' 일정 레인 배정: 각 일정이 걸친 모든 날 동안 같은 줄(lane)에 오도록 해
    // 서로 다른 일정이 같은 줄에서 이어져 보이는 것을 막는다.
    final multiSet = <String, CalendarEvent>{};
    for (final list in eventsByDate.values) {
      for (final e in list) {
        if (e.isAllDay && e.isMultiDay) multiSet[e.id] = e;
      }
    }
    final multiEvents = multiSet.values.toList()
      ..sort((a, b) {
        final s = (a.startDay ?? DateTime(2000)).compareTo(b.startDay ?? DateTime(2000));
        if (s != 0) return s;
        // 더 긴 일정 먼저(같은 시작이면 오래 가는 것을 위 레인에)
        final d = (b.lastDay ?? DateTime(2000)).compareTo(a.lastDay ?? DateTime(2000));
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    bool overlaps(CalendarEvent a, CalendarEvent b) {
      final as_ = a.startDay, ae = a.lastDay, bs = b.startDay, be = b.lastDay;
      if (as_ == null || ae == null || bs == null || be == null) return false;
      return !(ae.isBefore(bs) || be.isBefore(as_));
    }
    final laneOf = <String, int>{};
    final lanes = <List<CalendarEvent>>[];
    for (final e in multiEvents) {
      var lane = 0;
      while (true) {
        if (lane >= lanes.length) lanes.add([]);
        if (lanes[lane].any((o) => overlaps(o, e))) {
          lane++;
        } else {
          lanes[lane].add(e);
          laneOf[e.id] = lane;
          break;
        }
      }
    }

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
            builder: (_) => EventDetailSheet(dateKey: dateKey),
          ),
          child: _DayCell(
            day: dayNum, isToday: isToday, isSunday: isSunday,
            events: dayEvents, tasks: dayTasks, isWeekend: isWeekend,
            maxSlots: maxSlots, dateKey: dateKey, col: col, laneOf: laneOf,
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
    required this.maxSlots, required this.dateKey, required this.col,
    required this.laneOf,
  });

  final int day;
  final bool isToday, isWeekend, isSunday;
  final List<CalendarEvent> events;
  final List<Task> tasks;
  final int maxSlots;
  final String dateKey;
  final int col;
  final Map<String, int> laneOf; // 다중일 종일 일정 id → 레인(줄) 번호

  // 여러 날에 걸친 종일 일정 막대(칸 끝까지, 시작/끝만 둥글게 → 같은 일정끼리 이어짐)
  Widget _bar(CalendarEvent e) {
    final isStart = e.dateKey == dateKey;
    final isEnd = e.lastDateKey == dateKey;
    const r = Radius.circular(3);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 2, left: isStart ? 2 : 0, right: isEnd ? 2 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: e.color,
        borderRadius: BorderRadius.horizontal(
          left: isStart ? r : Radius.zero,
          right: isEnd ? r : Radius.zero,
        ),
      ),
      child: Text(
        // 막대 시작일 또는 주의 첫 칸(일요일)에만 제목 → 이어지는 느낌 유지하되 빈 칸 방지
        (isStart || col == 0) ? e.summary : ' ',
        style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // 레인 정렬용 빈 자리(같은 일정이 날짜마다 같은 줄에 오도록 높이만 확보)
  Widget _placeholder() => Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        child: const Text(' ', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
      );

  Widget _chip(String title, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        child: Text(
          title,
          style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _taskRow(BuildContext context, String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: '● ', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
            TextSpan(text: title),
          ]),
          style: TextStyle(fontSize: 9.5, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 1) 다중일 종일 일정 → 레인 배치 (같은 일정이 날짜마다 같은 줄에)
    final laneEvent = <int, CalendarEvent>{};
    var maxLane = -1;
    for (final e in events) {
      if (e.isAllDay && e.isMultiDay) {
        final lane = laneOf[e.id] ?? 0;
        laneEvent[lane] = e;
        if (lane > maxLane) maxLane = lane;
      }
    }

    // 2) 그 외(하루 종일 / 시간 / 태스크) 정렬: 종일 → 시간 → 태스크, 그 안에서 시각·id
    final others = <({String id, String title, Color color, bool isTask, int rank, DateTime? startDt})>[
      ...events.where((e) => !(e.isAllDay && e.isMultiDay)).map((e) => (
            id: e.id, title: e.summary, color: e.color, isTask: false,
            rank: e.isAllDay ? 1 : 2, startDt: e.startDt,
          )),
      ...tasks.map((t) => (
            id: t.id, title: t.title, color: const Color(0xFF1A73E8), isTask: true,
            rank: 3, startDt: t.due,
          )),
    ];
    others.sort((a, b) {
      if (a.rank != b.rank) return a.rank - b.rank;
      if (a.startDt != null && b.startDt != null) {
        final c = a.startDt!.toLocal().compareTo(b.startDt!.toLocal());
        if (c != 0) return c;
      }
      return a.id.compareTo(b.id);
    });

    // 3) 행 구성: 레인(0..maxLane, 빈 레인은 placeholder) → 그 외 항목
    final rows = <({Widget w, bool isEvent})>[];
    for (var lane = 0; lane <= maxLane; lane++) {
      final e = laneEvent[lane];
      rows.add((w: e != null ? _bar(e) : _placeholder(), isEvent: e != null));
    }
    for (final o in others) {
      rows.add((w: o.isTask ? _taskRow(context, o.title) : _chip(o.title, o.color), isEvent: true));
    }

    final visible = rows.take(maxSlots).toList();
    final shownEvents = visible.where((r) => r.isEvent).length;
    final totalEvents = laneEvent.length + others.length;
    final extra = totalEvents - shownEvents;

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
        Expanded(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxHeight: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in visible) r.w,
                  if (extra > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Text('+$extra', style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ),
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
    final l = AppLocalizations.of(context)!;
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
              Text(l.showCalendars, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClose, padding: EdgeInsets.zero),
            ]),
          ),
          const Divider(height: 1),
          if (calendars.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.loginRequired, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
