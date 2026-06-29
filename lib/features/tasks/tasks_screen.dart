import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/snackbar_helper.dart';
import '../../l10n/app_localizations.dart';
import 'add_task_sheet.dart';
import 'task_service.dart';
import '../settings/widget_settings_screen.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  static const _prefKey = 'tasks_show_completed';
  bool _showCompleted = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final v = prefs.getBool(_prefKey) ?? true;
      if (mounted && v != _showCompleted) setState(() => _showCompleted = v);
    });
  }

  Future<void> _toggleShowCompleted() async {
    setState(() => _showCompleted = !_showCompleted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _showCompleted);
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskServiceProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navTasks),
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(_showCompleted ? Icons.visibility : Icons.visibility_off),
            tooltip: _showCompleted ? l.tasksHideCompleted : l.tasksShowCompleted,
            onPressed: _toggleShowCompleted,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.refresh),
            tooltip: l.refreshTooltip,
            onPressed: () => ref.read(taskServiceProvider.notifier).loadTasks(),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.settings),
            tooltip: l.settingsTitle,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WidgetSettingsScreen())),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.read(taskServiceProvider.notifier).loadTasks(),
        ),
        data: (tasks) => _TaskListView(tasks: tasks, showCompleted: _showCompleted),
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
  const _TaskListView({required this.tasks, required this.showCompleted});
  final List<Task> tasks;
  final bool showCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    if (tasks.isEmpty) {
      return const _EmptyView();
    }

    final active = tasks.where((t) => !t.isCompleted).toList();
    final done = tasks.where((t) => t.isCompleted).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(taskServiceProvider.notifier).loadTasks(),
      child: ListView(
        children: [
          for (final task in active)
            _TaskItem(task: task),

          if (showCompleted && done.isNotEmpty) ...[
            _SectionHeader(l.taskCompletedSection(done.length)),
            for (final task in done)
              _TaskItem(task: task),
          ],

          const SizedBox(height: 80),
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
    final l = AppLocalizations.of(context)!;

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
        final notifier = ref.read(taskServiceProvider.notifier);
        notifier.deleteTaskLocal(task.id);
        ScaffoldMessenger.of(context).showAutoDismissSnackBar(
          SnackBar(
            content: Text(l.taskItemDeletedSnack(task.title)),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: l.cancelButton,
              onPressed: () {}, // 닫힘 사유(action)로 분기하므로 비워둠
            ),
          ),
        ).closed.then((reason) {
          if (reason == SnackBarClosedReason.action) {
            notifier.loadTasks(); // 실행취소
          } else {
            notifier.deleteTask(task.id);
          }
        });
      },
      child: ListTile(
        leading: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: task.isCompleted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            activeColor: Colors.green,
            onChanged: (_) => ref.read(taskServiceProvider.notifier).toggleComplete(task),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : null,
            fontSize: 14,
          ),
        ),
        subtitle: _buildSubtitle(task, context),
        onTap: () => ref.read(taskServiceProvider.notifier).toggleComplete(task),
      ),
    );
  }

  Widget? _buildSubtitle(Task task, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final parts = <Widget>[];

    if (task.due != null) {
      final due = task.due!.toLocal();
      final label = l.taskDueDate(due.month, due.day);
      final overdue = task.isOverdue;
      parts.add(Builder(builder: (ctx) {
        final muted = Theme.of(ctx).colorScheme.onSurfaceVariant;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today, size: 11, color: overdue ? Colors.red : muted),
          const SizedBox(width: 3),
          Text(
            overdue ? '$label (${l.taskOverdue})' : label,
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

// ── 빈 화면 / 오류 화면 ──────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.checklist, size: 64, color: scheme.outlineVariant),
        const SizedBox(height: 16),
        Text(l.taskEmptyTitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
        const SizedBox(height: 8),
        Text(l.taskEmptyHint, style: TextStyle(color: scheme.outline, fontSize: 13)),
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
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off, size: 48, color: scheme.outline),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: Text(l.retryButton)),
      ]),
    );
  }
}
