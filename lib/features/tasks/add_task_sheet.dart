import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    await ref.read(taskServiceProvider.notifier).addTask(
          title,
          due: _dueDate,
          notes: _notesCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
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
          Text('새 태스크', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // 제목
          TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: '제목 (필수)',
              prefixIcon: Icon(Icons.check_box_outline_blank),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),

          // 마감일
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
                        ? '마감일 선택 (선택사항)'
                        : '${_dueDate!.year}년 ${_dueDate!.month}월 ${_dueDate!.day}일',
                    style: TextStyle(
                      color: _dueDate == null ? scheme.onSurfaceVariant : null,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_dueDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _dueDate = null),
                      child: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 메모
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '메모 (선택사항)',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),

          // 저장 버튼
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('추가'),
            ),
          ),
        ],
      ),
    );
  }
}
