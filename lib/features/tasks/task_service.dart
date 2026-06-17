import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';
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
  ref.watch(authUserIdProvider); // 계정 변경 시 재생성
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
    state = const AsyncValue<List<Task>>.loading().copyWithPrevious(state);
    try {
      final lists = await _api.get('$_base/users/@me/lists');
      if (!mounted) return;
      final items = lists['items'] as List?;
      if (items == null || items.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }
      _listId = items[0]['id'] as String; // 기본 리스트(첫 번째)만 사용 — 다중 리스트 지원은 미구현
      await WidgetService.saveTaskListId(_listId!);
      final data = await _api.get(
        '$_base/lists/$_listId/tasks',
        params: {'showCompleted': 'true', 'maxResults': '100'},
      );
      final tasks = ((data['items'] as List?) ?? [])
          .map((j) => Task.fromJson(j as Map<String, dynamic>))
          .toList();
      final sorted = _sorted(tasks);
      if (!mounted) return;
      state = AsyncValue.data(sorted);
      await WidgetService.updateTasks(sorted);

      // 위젯에서 체크한 태스크 동기화
      final pending = await WidgetService.getPendingCompletions();
      if (pending.isNotEmpty) {
        await WidgetService.clearPendingCompletions();
        for (final taskId in pending) {
          try {
            final task = sorted.firstWhere((t) => t.id == taskId && !t.isCompleted);
            await toggleComplete(task);
          } catch (e) { debugPrint('위젯 완료 동기화 실패: $e'); }
        }
      }
    } catch (e, st) {
      if (!mounted) return;
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
      if (!mounted) return;
      final newTask = Task.fromJson(data as Map<String, dynamic>);
      final current = state.valueOrNull ?? [];
      final sorted = _sorted([newTask, ...current]);
      state = AsyncValue.data(sorted);
      await WidgetService.updateTasks(sorted);
    } catch (e) {
      debugPrint('addTask 실패: $e');
      rethrow;
    }
  }

  Future<void> toggleComplete(Task task) async {
    if (_listId == null) return;
    final newStatus = task.isCompleted ? 'needsAction' : 'completed';
    final body = <String, dynamic>{'status': newStatus};
    if (newStatus == 'needsAction') body['completed'] = null;

    // 낙관적 업데이트
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      _sorted(current.map((t) => t.id == task.id ? t.copyWith(status: newStatus) : t).toList()),
    );

    try {
      await _api.patch('$_base/lists/$_listId/tasks/${task.id}', body: body);
      if (!mounted) return;
      await WidgetService.updateTasks(state.valueOrNull ?? []);
    } catch (e) {
      debugPrint('태스크 상태 변경 실패: $e');
      if (!mounted) return;
      state = AsyncValue.data(_sorted(current)); // 실패 시 원복
    }
  }

  Future<void> syncPendingFromWidget() async {
    // 완료 동기화
    final completions = await WidgetService.getPendingCompletions();
    if (completions.isNotEmpty) {
      await WidgetService.clearPendingCompletions();
      final current = state.valueOrNull ?? [];
      for (final taskId in completions) {
        try {
          final task = current.firstWhere((t) => t.id == taskId && !t.isCompleted);
          await toggleComplete(task);
        } catch (e) { debugPrint('태스크 완료 동기화 실패: $e'); }
      }
    }

    // 삭제 동기화
    final deletions = await WidgetService.getPendingDeletions();
    if (deletions.isNotEmpty) {
      await WidgetService.clearPendingDeletions();
      for (final taskId in deletions) {
        try { await deleteTask(taskId); } catch (e) { debugPrint('태스크 삭제 실패: $e'); }
      }
    }

    // 위젯에서 추가한 태스크 동기화 (API 호출 실패했던 경우)
    final newTasks = await WidgetService.getPendingNewTasks();
    if (newTasks.isNotEmpty) {
      await WidgetService.clearPendingNewTasks();
      for (final title in newTasks) {
        try { await addTask(title); } catch (e) { debugPrint('태스크 추가 실패: $e'); }
      }
    }

    // 항상 최신 태스크 목록 서버에서 가져와 동기화
    await loadTasks();
  }

  Future<void> deleteTask(String taskId) async {
    if (_listId == null) return;
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((t) => t.id != taskId).toList());

    try {
      await _api.delete('$_base/lists/$_listId/tasks/$taskId');
      if (!mounted) return;
      await WidgetService.updateTasks(state.valueOrNull ?? []);
    } catch (e) {
      debugPrint('태스크 삭제 API 실패: $e');
      if (!mounted) return;
      state = AsyncValue.data(current); // 실패 시 원복
    }
  }

  void markTaskCompletedLocal(String taskId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      _sorted(current.map((t) => t.id == taskId ? t.copyWith(status: 'completed') : t).toList()),
    );
  }

  void deleteTaskLocal(String taskId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((t) => t.id != taskId).toList());
  }

  List<Task> _sorted(List<Task> tasks) {
    final active = tasks.where((t) => !t.isCompleted).toList();
    final done = tasks.where((t) => t.isCompleted).toList();
    return [...active, ...done];
  }
}
