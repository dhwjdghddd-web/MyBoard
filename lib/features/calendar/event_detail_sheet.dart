import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/snackbar_helper.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_service.dart';
import 'event_form_screen.dart';
import '../tasks/task_service.dart';

class EventDetailSheet extends ConsumerStatefulWidget {
  const EventDetailSheet({
    super.key,
    required this.dateKey,
  });

  final String dateKey;

  @override
  ConsumerState<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<EventDetailSheet> {
  static DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (_lastLoadTime == null || now.difference(_lastLoadTime!).inSeconds > 30) {
      _lastLoadTime = now;
      Future.microtask(() {
        ref.read(calendarProvider.notifier).loadEvents();
        ref.read(taskServiceProvider.notifier).loadTasks();
      });
    }
  }

  String _dateLabel(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final parts = widget.dateKey.split('-');
    if (parts.length < 3) return widget.dateKey;
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    // weekday % 7: Sunday=0, Mon=1, … Sat=6
    final weekdays = [
      l.weekdaySun, l.weekdayMon, l.weekdayTue, l.weekdayWed,
      l.weekdayThu, l.weekdayFri, l.weekdaySat,
    ];
    return l.eventDateLabel(weekdays[dt.weekday % 7], dt.month, dt.day);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cal = ref.watch(calendarProvider);
    final tasksAsync = ref.watch(taskServiceProvider);

    final events = cal.events.where((e) => e.dateKey == widget.dateKey).toList();
    final tasks = tasksAsync.valueOrNull ?? [];
    final dayTasks = tasks.where((t) {
      if (t.due == null || t.isCompleted) return false;
      final d = t.due!.toLocal();
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      return key == widget.dateKey;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    _dateLabel(context),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l.newEventTitle),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventFormScreen(initialDateKey: widget.dateKey),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: (events.isEmpty && dayTasks.isEmpty)
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(l.noEventsForDay, style: TextStyle(color: Colors.grey[500])),
                      ]),
                    )
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: events.length + dayTasks.length,
                      itemBuilder: (_, i) {
                        if (i < events.length) {
                          final event = events[i];
                          return _EventCard(
                            event: event,
                            onEdit: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventFormScreen(
                                    initialDateKey: widget.dateKey,
                                    event: event,
                                  ),
                                ),
                              );
                            },
                            onDelete: () async {
                              await ref.read(calendarProvider.notifier).deleteEvent(
                                    event.calendarId, event.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showAutoDismissSnackBar(
                                  SnackBar(content: Text(AppLocalizations.of(context)!.eventDeletedSnack)),
                                );
                              }
                            },
                          );
                        } else {
                          final task = dayTasks[i - events.length];
                          return _TaskCard(task: task);
                        }
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onEdit, required this.onDelete});
  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final timeText = event.isAllDay
        ? l.allDay
        : '${_fmt(event.startDt)} — ${_fmt(event.endDt)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.color.withAlpha(30),
        border: Border(left: BorderSide(color: event.color, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.summary, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(timeText, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          if (event.calendarName.isNotEmpty)
            Text(event.calendarName, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          if (event.location?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('📍 ${event.location}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.edit, size: 14),
              label: Text(l.editButton, style: const TextStyle(fontSize: 12)),
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: Icon(Icons.delete, size: 14, color: Colors.red[400]),
              label: Text(l.deleteButton, style: TextStyle(fontSize: 12, color: Colors.red[400])),
              onPressed: () => _confirmDelete(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: Colors.red[300]!),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.eventDeleteTitle),
        content: Text(l.eventDeleteMessage(event.summary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.deleteButton),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8).withAlpha(30),
        border: const Border(left: BorderSide(color: Color(0xFF1A73E8), width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: const Color(0xFF1A73E8),
            onChanged: (_) {
              ref.read(taskServiceProvider.notifier).toggleComplete(task);
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '● ', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
                      TextSpan(
                        text: task.title,
                        style: TextStyle(
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(l.taskCardLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (task.notes?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(task.notes!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.taskDeleteTitle),
        content: Text(l.taskDeleteMessage(task.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.deleteButton),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(taskServiceProvider.notifier).deleteTask(task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showAutoDismissSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.taskDeletedSnack)),
        );
      }
    }
  }
}
