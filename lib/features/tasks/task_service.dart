import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';
import '../../core/widget_service.dart';

const _base = 'https://tasks.googleapis.com/tasks/v1';

// ── 모델 ──────────────────────────────────────────────────────────────────

class Task {
  final String id;
  final String listId;
  final String title;
  final String status;
  final DateTime? due;
  final String? notes;

  const Task({
    required this.id,
    required this.listId,
    required this.title,
    required this.status,
    this.due,
    this.notes,
  });

  bool get isCompleted => status == 'completed';

  bool get isOverdue =>
      due != null && !isCompleted && due!.isBefore(DateTime.now());

  factory Task.fromJson(Map<String, dynamic> j, {required String listId}) => Task(
        id: j['id'] as String,
        listId: listId,
        title: (j['title'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'needsAction',
        due: j['due'] != null ? DateTime.tryParse(j['due'] as String) : null,
        notes: j['notes'] as String?,
      );

  Task copyWith({String? status}) => Task(
        id: id,
        listId: listId,
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

class TaskListInfo {
  final String id;
  final String title;
  const TaskListInfo({required this.id, required this.title});
}

class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  TaskNotifier(this._api) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  final ApiClient _api;
  String? _listId; // 신규 추가 기본 대상(첫 번째 목록)
  List<TaskListInfo> taskLists = const []; // 추가 시트의 목록 선택용

  String? get defaultListId => _listId;

  Future<void> loadTasks() async {
    state = const AsyncValue<List<Task>>.loading().copyWithPrevious(state);
    try {
      final lists = await _api.get('$_base/users/@me/lists');
      if (!mounted) return;
      final items = (lists['items'] as List?) ?? [];
      if (items.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }
      taskLists = items
          .map((e) => TaskListInfo(
                id: (e as Map<String, dynamic>)['id'] as String,
                title: (e['title'] as String?) ?? '',
              ))
          .toList();
      _listId = taskLists.first.id;
      await WidgetService.saveTaskListId(_listId!);

      // 모든 목록의 태스크를 병렬 조회해 병합한다.
      final perList = await Future.wait(taskLists.map((tl) async {
        try {
          final data = await _api.get(
            '$_base/lists/${tl.id}/tasks',
            params: {'showCompleted': 'true', 'maxResults': '100'},
          );
          return ((data['items'] as List?) ?? [])
              .map((j) => Task.fromJson(j as Map<String, dynamic>, listId: tl.id))
              .toList();
        } catch (e) {
          debugPrint('태스크 목록 로드 실패 (${tl.id}): $e');
          return <Task>[];
        }
      }));
      if (!mounted) return;
      final sorted = _sorted(perList.expand((x) => x).toList());
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

  Future<void> addTask(String title, {DateTime? due, String? notes, String? listId}) async {
    // 목록 로드 전/실패 상태에서 추가 시도 시 조용히 무시하지 않고 예외를 던져
    // 호출부(시트)가 실패를 사용자에게 안내하도록 한다.
    final targetList = listId ?? _listId;
    if (targetList == null) {
      throw StateError('task list not loaded');
    }
    final body = <String, dynamic>{'title': title};
    if (due != null) {
      body['due'] = DateTime(due.year, due.month, due.day).toUtc().toIso8601String();
    }
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    try {
      final data = await _api.post('$_base/lists/$targetList/tasks', body: body);
      if (!mounted) return;
      final newTask = Task.fromJson(data as Map<String, dynamic>, listId: targetList);
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
    final newStatus = task.isCompleted ? 'needsAction' : 'completed';
    final body = <String, dynamic>{'status': newStatus};
    if (newStatus == 'needsAction') body['completed'] = null;

    // 낙관적 업데이트
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      _sorted(current.map((t) => t.id == task.id ? t.copyWith(status: newStatus) : t).toList()),
    );

    try {
      await _api.patch('$_base/lists/${task.listId}/tasks/${task.id}', body: body);
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

    // 삭제 동기화 (위젯이 네이티브에서 이미 API 삭제했을 수 있으므로 목록에 남아있을 때만)
    final deletions = await WidgetService.getPendingDeletions();
    if (deletions.isNotEmpty) {
      await WidgetService.clearPendingDeletions();
      final cur = state.valueOrNull ?? [];
      for (final taskId in deletions) {
        try {
          final task = cur.firstWhere((t) => t.id == taskId);
          await deleteTask(task);
        } catch (e) { debugPrint('태스크 삭제 실패: $e'); }
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

  Future<void> deleteTask(Task task) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((t) => t.id != task.id).toList());

    try {
      await _api.delete('$_base/lists/${task.listId}/tasks/${task.id}');
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
