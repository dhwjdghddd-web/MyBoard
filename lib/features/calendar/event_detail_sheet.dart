import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'calendar_service.dart';
import 'event_form_screen.dart';

class EventDetailSheet extends ConsumerWidget {
  const EventDetailSheet({
    super.key,
    required this.dateKey,
    required this.events,
  });

  final String dateKey;
  final List<CalendarEvent> events;

  String _dateLabel() {
    final parts = dateKey.split('-');
    if (parts.length < 3) return dateKey;
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return '${dt.month}월 ${dt.day}일 (${weekdays[dt.weekday % 7]})';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) {
        return Column(
          children: [
            // 핸들
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
            // 날짜 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    _dateLabel(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('새 일정'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventFormScreen(initialDateKey: dateKey),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 이벤트 목록
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('이 날은 일정이 없어요', style: TextStyle(color: Colors.grey[500])),
                      ]),
                    )
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: events.length,
                      itemBuilder: (_, i) => _EventCard(
                        event: events[i],
                        onEdit: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventFormScreen(
                                initialDateKey: dateKey,
                                event: events[i],
                              ),
                            ),
                          );
                        },
                        onDelete: () async {
                          Navigator.pop(context);
                          await ref.read(calendarProvider.notifier).deleteEvent(
                                events[i].calendarId, events[i].id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('일정이 삭제되었습니다')),
                            );
                          }
                        },
                      ),
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
    final timeText = event.isAllDay
        ? '종일'
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
              label: const Text('수정', style: TextStyle(fontSize: 12)),
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
              label: Text('삭제', style: TextStyle(fontSize: 12, color: Colors.red[400])),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('"${event.summary}"을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
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
