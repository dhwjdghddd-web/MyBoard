import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'add_task_sheet.dart';
import 'task_service.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('태스크'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(taskServiceProvider.notifier).loadTasks(),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.read(taskServiceProvider.notifier).loadTasks(),
        ),
        data: (tasks) => _TaskListView(tasks: tasks),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => const AddTaskSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── 목록 ──────────────────────────────────────────────────────────────────

class _TaskListView extends ConsumerWidget {
  const _TaskListView({required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return const _EmptyView();
    }

    final active = tasks.where((t) => !t.isCompleted).toList();
    final done = tasks.where((t) => t.isCompleted).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(taskServiceProvider.notifier).loadTasks(),
      child: ListView(
        children: [
          if (active.isEmpty && done.isNotEmpty)
            const _AllDoneView(),

          for (final task in active)
            _TaskItem(task: task),

          if (done.isNotEmpty) ...[
            _SectionHeader('완료 (${done.length})'),
            for (final task in done)
              _TaskItem(task: task),
          ],

          const SizedBox(height: 80), // FAB 여백
        ],
      ),
    );
  }
}

// ── 태스크 아이템 ────────────────────────────────────────────────────────

class _TaskItem extends ConsumerWidget {
  const _TaskItem({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(taskServiceProvider.notifier).deleteTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${task.title}" 삭제됨'), duration: const Duration(seconds: 2)),
        );
      },
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          shape: const CircleBorder(),
          activeColor: Colors.green,
          onChanged: (_) => ref.read(taskServiceProvider.notifier).toggleComplete(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : null,
            fontSize: 14,
          ),
        ),
        subtitle: _buildSubtitle(task),
        onTap: () => ref.read(taskServiceProvider.notifier).toggleComplete(task),
      ),
    );
  }

  Widget? _buildSubtitle(Task task) {
    final parts = <Widget>[];

    if (task.due != null) {
      final due = task.due!.toLocal();
      final label = '${due.month}월 ${due.day}일';
      final overdue = task.isOverdue;
      parts.add(Builder(builder: (ctx) {
        final muted = Theme.of(ctx).colorScheme.onSurfaceVariant;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today, size: 11, color: overdue ? Colors.red : muted),
          const SizedBox(width: 3),
          Text(
            overdue ? '$label (기한 초과)' : label,
            style: TextStyle(fontSize: 12, color: overdue ? Colors.red : muted),
          ),
        ]);
      }));
    }

    if (task.notes != null && task.notes!.isNotEmpty) {
      parts.add(Builder(builder: (ctx) {
        final muted = Theme.of(ctx).colorScheme.onSurfaceVariant;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notes, size: 11, color: muted),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              task.notes!,
              style: TextStyle(fontSize: 12, color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]);
      }));
    }

    if (parts.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((w) => Padding(padding: const EdgeInsets.only(top: 2), child: w)).toList(),
    );
  }
}

// ── 섹션 헤더 ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── 빈 화면 / 완료 화면 / 오류 화면 ─────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.checklist, size: 64, color: scheme.outlineVariant),
        const SizedBox(height: 16),
        Text('태스크가 없어요', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
        const SizedBox(height: 8),
        Text('+ 버튼으로 추가해보세요', style: TextStyle(color: scheme.outline, fontSize: 13)),
      ]),
    );
  }
}

class _AllDoneView extends StatelessWidget {
  const _AllDoneView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        Text('모두 완료!', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off, size: 48, color: scheme.outline),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
      ]),
    );
  }
}
