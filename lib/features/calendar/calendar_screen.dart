import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../tasks/task_service.dart';
import 'calendar_service.dart';
import 'event_detail_sheet.dart';
import 'event_form_screen.dart';

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
    final taskDates = <String>{};
    for (final t in tasks) {
      if (t.due != null && !t.isCompleted) {
        final d = t.due!.toLocal();
        taskDates.add(
          '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}',
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: _MonthNav(cal: cal, ref: ref),
        titleSpacing: 0,
        actions: [
          TextButton(
            onPressed: () => ref.read(calendarProvider.notifier).goToday(),
            child: const Text('오늘', style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: cal.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: () => ref.read(calendarProvider.notifier).loadEvents(),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => setState(() => _showFilter = !_showFilter),
            tooltip: '캘린더 필터',
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          // 요일 헤더
          _DowHeader(),
          // 달력 그리드
          Expanded(
            child: _CalendarGrid(
              year: cal.year,
              month: cal.month,
              eventsByDate: cal.eventsByDate,
              taskDates: taskDates,
            ),
          ),
        ]),
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

// ── 월 이동 ───────────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  const _MonthNav({required this.cal, required this.ref});
  final CalendarState cal;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: const Icon(Icons.chevron_left, color: Colors.white),
        onPressed: () => ref.read(calendarProvider.notifier).prevMonth(),
      ),
      Text(
        '${cal.year}년 ${cal.month}월',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      IconButton(
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
            padding: const EdgeInsets.symmetric(vertical: 6),
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
    required this.eventsByDate, required this.taskDates,
  });

  final int year, month;
  final Map<String, List<CalendarEvent>> eventsByDate;
  final Set<String> taskDates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startOffset = firstDay.weekday % 7; // 일=0
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, childAspectRatio: 0.65,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, i) {
        final dayNum = i - startOffset + 1;
        if (dayNum < 1 || dayNum > lastDay.day) {
          return const SizedBox.shrink(); // 이전/다음 달 빈 셀
        }
        final dateKey = '$year-${month.toString().padLeft(2,'0')}-${dayNum.toString().padLeft(2,'0')}';
        final isToday = dayNum == today.day && month == today.month && year == today.year;
        final dayEvents = eventsByDate[dateKey] ?? [];
        final hasTask = taskDates.contains(dateKey);
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
            events: dayEvents, hasTask: hasTask, isWeekend: isWeekend,
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
    required this.events, required this.hasTask, required this.isWeekend,
  });

  final int day;
  final bool isToday, hasTask, isWeekend, isSunday;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = events.take(2).toList();
    final extra = events.length - visible.length;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: scheme.outlineVariant, width: 0.5),
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        color: isToday ? scheme.primaryContainer.withAlpha(60) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 날짜 숫자
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 3),
            width: 22, height: 22,
            decoration: isToday
                ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
                : null,
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? Colors.white
                    : (isWeekend ? (isSunday ? Colors.red[400] : Colors.blue[400]) : null),
              ),
            ),
          ),
        ),
        // 이벤트 칩
        for (final ev in visible)
          Container(
            margin: const EdgeInsets.fromLTRB(2, 1, 2, 0),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: ev.color,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              ev.summary,
              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('+$extra', style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        // 태스크 점
        if (hasTask)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 1, 0, 0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle),
              ),
            ]),
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
