import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'task_service.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({super.key});

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _titleFocus.requestFocus());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _titleFocus.requestFocus();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(taskServiceProvider.notifier).addTask(
            title,
            due: _dueDate,
            notes: _notesCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.taskAddFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final l = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, bottom + 20),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.addTaskTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: l.titleHint,
              prefixIcon: const Icon(Icons.check_box_outline_blank),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    _dueDate == null
                        ? l.dueDateHint
                        : l.dateFormat(_dueDate!.year, _dueDate!.month, _dueDate!.day),
                    style: TextStyle(
                      color: _dueDate == null ? scheme.onSurfaceVariant : null,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_dueDate != null)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l.memoHint,
              prefixIcon: const Icon(Icons.notes),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.addButton),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
