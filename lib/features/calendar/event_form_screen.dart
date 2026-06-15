import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_service.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({
    super.key,
    required this.initialDateKey,
    this.event,
  });

  final String initialDateKey;
  final CalendarEvent? event;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _notifMinCtrl = TextEditingController(text: '10');

  bool _allDay = true;
  DateTime _startDt = DateTime.now();
  DateTime _endDt = DateTime.now().add(const Duration(hours: 1));
  String _startDateStr = '';
  String _repeat = '';
  String _notifMethod = 'popup';
  String? _colorId;
  String _calendarId = 'primary';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    final parts = widget.initialDateKey.split('-');
    final initDate = parts.length == 3
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
        : DateTime.now();

    if (ev != null) {
      _titleCtrl.text = ev.summary;
      _locationCtrl.text = ev.location ?? '';
      _descCtrl.text = ev.description ?? '';
      _colorId = ev.colorId;
      _calendarId = ev.calendarId;
      _allDay = ev.isAllDay;
      if (ev.isAllDay) {
        _startDateStr = ev.startDate ?? widget.initialDateKey;
      } else {
        _startDt = ev.startDt?.toLocal() ?? initDate.copyWith(hour: 9);
        _endDt = ev.endDt?.toLocal() ?? initDate.copyWith(hour: 10);
      }
    } else {
      _startDateStr = widget.initialDateKey;
      _startDt = initDate.copyWith(hour: 9, minute: 0, second: 0);
      _endDt = initDate.copyWith(hour: 10, minute: 0, second: 0);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _guestsCtrl.dispose();
    _notifMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final parts = _startDateStr.split('-');
    final init = parts.length == 3
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDateStr = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
      });
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startDt : _endDt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startDt = dt;
        if (_endDt.isBefore(dt)) _endDt = dt.add(const Duration(hours: 1));
      } else {
        _endDt = dt;
      }
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.titleRequiredError)));
      return;
    }
    if (!_allDay && !_endDt.isAfter(_startDt)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.endTimeError)));
      return;
    }

    setState(() => _saving = true);
    try {
      final calState = ref.read(calendarProvider);
      final displayCalendars = calState.calendars.where((c) => c.isWritable).toList();
      if (displayCalendars.isNotEmpty && !displayCalendars.any((c) => c.id == _calendarId)) {
        _calendarId = displayCalendars.first.id;
      }

      final guests = _guestsCtrl.text.trim();
      final attendees = guests.isNotEmpty
          ? guests.split(',').map((e) => e.trim()).where((e) => e.contains('@')).toList()
          : null;
      final notifMin = int.tryParse(_notifMinCtrl.text.trim());

      await ref.read(calendarProvider.notifier).saveEvent(
        eventId: widget.event?.id,
        calendarId: _calendarId,
        originalCalendarId: widget.event?.calendarId,
        title: title,
        isAllDay: _allDay,
        startDt: _allDay ? null : _startDt,
        endDt: _allDay ? null : _endDt,
        startDate: _allDay ? _startDateStr : null,
        colorId: _colorId,
        location: _locationCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        recurrence: _repeat.isEmpty ? null : _repeat,
        attendeeEmails: attendees,
        notifMethod: _notifMethod,
        notifMinutes: notifMin,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final l2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l2.saveFailed(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDt(DateTime dt) {
    final l = AppLocalizations.of(context)!;
    final local = dt.toLocal();
    return l.dateTimeFormat(
      local.year, local.month, local.day,
      local.hour.toString().padLeft(2, '0'),
      local.minute.toString().padLeft(2, '0'),
    );
  }

  String _fmtAllDayDate() {
    final l = AppLocalizations.of(context)!;
    final parts = _startDateStr.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final d = int.tryParse(parts[2]) ?? 0;
      return l.dateFormat(y, m, d);
    }
    return _startDateStr;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final calState = ref.watch(calendarProvider);
    final calendars = calState.calendars;
    final isEdit = widget.event != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l.editEventTitle : l.newEventTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            ),
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.saveButton, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _titleCtrl,
            autofocus: !isEdit,
            decoration: InputDecoration(
              hintText: l.titleHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),

          Card(child: Column(children: [
            SwitchListTile(
              title: Text(l.allDay),
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            const Divider(height: 1),
            if (_allDay) ...[
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(_fmtAllDayDate()),
                onTap: _pickDate,
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(l.eventStart),
                subtitle: Text(_fmtDt(_startDt)),
                onTap: () => _pickDateTime(isStart: true),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.stop),
                title: Text(l.eventEnd),
                subtitle: Text(_fmtDt(_endDt)),
                onTap: () => _pickDateTime(isStart: false),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(l.eventRepeat),
              trailing: DropdownButton<String>(
                value: _repeat,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: '', child: Text(l.repeatNone)),
                  DropdownMenuItem(value: 'RRULE:FREQ=DAILY', child: Text(l.repeatDaily)),
                  DropdownMenuItem(value: 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', child: Text(l.repeatWeekdays)),
                  DropdownMenuItem(value: 'RRULE:FREQ=WEEKLY', child: Text(l.repeatWeekly)),
                  DropdownMenuItem(value: 'RRULE:FREQ=MONTHLY', child: Text(l.repeatMonthly)),
                  DropdownMenuItem(value: 'RRULE:FREQ=YEARLY', child: Text(l.repeatYearly)),
                ],
                onChanged: (v) => setState(() => _repeat = v ?? ''),
              ),
            ),
          ])),
          const SizedBox(height: 12),

          Card(child: Column(children: [
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                hintText: l.eventLocation,
                prefixIcon: const Icon(Icons.location_on),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const Divider(height: 1),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l.eventDescription,
                prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.notes)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ])),
          const SizedBox(height: 12),

          Card(child: Column(children: [
            TextField(
              controller: _guestsCtrl,
              decoration: InputDecoration(
                hintText: l.eventGuestsHint,
                prefixIcon: const Icon(Icons.people),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(l.eventNotification),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                DropdownButton<String>(
                  value: _notifMethod,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: 'popup', child: Text(l.notifPopup)),
                    DropdownMenuItem(value: 'email', child: Text(l.notifEmail)),
                  ],
                  onChanged: (v) => setState(() => _notifMethod = v ?? 'popup'),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _notifMinCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
                  ),
                ),
                const SizedBox(width: 4),
                Text(l.minutesBefore, style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ])),
          const SizedBox(height: 12),

          (() {
            final displayCalendars = calendars.where((c) => c.isWritable).toList();
            if (displayCalendars.isEmpty) return const SizedBox();
            return Card(child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(l.calendarLabel),
              trailing: DropdownButton<String>(
                value: displayCalendars.any((c) => c.id == _calendarId)
                    ? _calendarId
                    : (displayCalendars.isNotEmpty ? displayCalendars.first.id : _calendarId),
                underline: const SizedBox(),
                items: displayCalendars.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(c.summary, overflow: TextOverflow.ellipsis),
                  ]),
                )).toList(),
                onChanged: (v) { if (v != null) setState(() => _calendarId = v); },
              ),
            ));
          })(),
          const SizedBox(height: 12),

          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.eventColorLabel, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _ColorChip(
                  color: Colors.grey[400]!,
                  selected: _colorId == null,
                  isDefault: true,
                  onTap: () => setState(() => _colorId = null),
                ),
                for (final entry in kGoogleEventColors.entries)
                  _ColorChip(
                    color: hexToColor(entry.value),
                    selected: _colorId == entry.key,
                    onTap: () => setState(() => _colorId = _colorId == entry.key ? null : entry.key),
                  ),
              ]),
            ]),
          )),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.color, required this.selected, required this.onTap, this.isDefault = false});
  final Color color;
  final bool selected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBorderColor = isDark ? Colors.white : Colors.black87;
    final activeCheckColor = isDefault ? activeBorderColor : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: isDefault ? Colors.transparent : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? activeBorderColor : (isDefault ? Colors.grey : color),
            width: selected ? 3 : (isDefault ? 2 : 0),
          ),
        ),
        child: selected
            ? Icon(Icons.check, size: 14, color: activeCheckColor)
            : null,
      ),
    );
  }
}
