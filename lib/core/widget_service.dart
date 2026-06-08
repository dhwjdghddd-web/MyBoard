import 'package:home_widget/home_widget.dart';
import '../features/tasks/task_service.dart';

class WidgetService {
  static Future<void> update(List<Task> tasks) async {
    try {
      final active = tasks.where((t) => !t.isCompleted).toList();
      // 미완료 먼저, 완료 뒤로
      final display = [...active, ...tasks.where((t) => t.isCompleted)].take(4).toList();

      await HomeWidget.saveWidgetData<String>('task_count', '${active.length}');

      for (var i = 0; i < 4; i++) {
        if (i < display.length) {
          await HomeWidget.saveWidgetData<String>('task_$i', display[i].title);
          await HomeWidget.saveWidgetData<String>(
              'task_${i}_done', display[i].isCompleted ? 'true' : 'false');
        } else {
          await HomeWidget.saveWidgetData<String>('task_$i', '');
          await HomeWidget.saveWidgetData<String>('task_${i}_done', 'false');
        }
      }

      await HomeWidget.updateWidget(androidName: 'HomeWidgetProvider');
    } catch (_) {}
  }
}
