import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/widget_service.dart';

const _base = 'https://tasks.googleapis.com/tasks/v1';

// ── 모델 ──────────────────────────────────────────────────────────────────

class Task {
  final String id;
  final String title;
  final String status;
  final DateTime? due;
  final String? notes;

  const Task({
    required this.id,
    required this.title,
    required this.status,
    this.due,
    this.notes,
  });

  bool get isCompleted => status == 'completed';

  bool get isOverdue =>
      due != null && !isCompleted && due!.isBefore(DateTime.now());

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'needsAction',
        due: j['due'] != null ? DateTime.tryParse(j['due'] as String) : null,
        notes: j['notes'] as String?,
      );

  Task copyWith({String? status}) => Task(
        id: id,
        title: title,
        status: status ?? this.status,
        due: due,
        notes: notes,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────

final taskServiceProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
  return TaskNotifier(ref.watch(apiClientProvider));
});

// ── Notifier ──────────────────────────────────────────────────────────────

class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  TaskNotifier(this._api) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  final ApiClient _api;
  String? _listId;

  Future<void> loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final lists = await _api.get('$_base/users/@me/lists');
      final items = lists['items'] as List?;
      if (items == null || items.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }
      _listId = items[0]['id'] as String;
      final data = await _api.get(
        '$_base/lists/$_listId/tasks',
        params: {'showCompleted': 'true', 'maxResults': '100'},
      );
      final tasks = ((data['items'] as List?) ?? [])
          .map((j) => Task.fromJson(j as Map<String, dynamic>))
          .toList();
      final sorted = _sorted(tasks);
      state = AsyncValue.data(sorted);
      WidgetService.update(sorted);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTask(String title, {DateTime? due, String? notes}) async {
    if (_listId == null) return;
    final body = <String, dynamic>{'title': title};
    if (due != null) {
      body['due'] = DateTime(due.year, due.month, due.day).toUtc().toIso8601String();
    }
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    try {
      final data = await _api.post('$_base/lists/$_listId/tasks', body: body);
      final newTask = Task.fromJson(data as Map<String, dynamic>);
      final current = state.value ?? [];
      final sorted = _sorted([newTask, ...current]);
      state = AsyncValue.data(sorted);
      WidgetService.update(sorted);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleComplete(Task task) async {
    if (_listId == null) return;
    final newStatus = task.isCompleted ? 'needsAction' : 'completed';
    final body = <String, dynamic>{'status': newStatus};
    if (newStatus == 'needsAction') body['completed'] = null;

    // 낙관적 업데이트
    final current = state.value ?? [];
    state = AsyncValue.data(
      _sorted(current.map((t) => t.id == task.id ? t.copyWith(status: newStatus) : t).toList()),
    );

    try {
      await _api.patch('$_base/lists/$_listId/tasks/${task.id}', body: body);
      WidgetService.update(state.value ?? []);
    } catch (_) {
      state = AsyncValue.data(_sorted(current)); // 실패 시 원복
    }
  }

  Future<void> deleteTask(String taskId) async {
    if (_listId == null) return;
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((t) => t.id != taskId).toList());

    try {
      await _api.delete('$_base/lists/$_listId/tasks/$taskId');
      WidgetService.update(state.value ?? []);
    } catch (_) {
      state = AsyncValue.data(current); // 실패 시 원복
    }
  }

  List<Task> _sorted(List<Task> tasks) {
    final active = tasks.where((t) => !t.isCompleted).toList();
    final done = tasks.where((t) => t.isCompleted).toList();
    return [...active, ...done];
  }
}
