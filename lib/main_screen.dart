import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/tasks/task_service.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/tasks/add_task_sheet.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/calendar/calendar_service.dart';
import 'features/calendar/event_form_screen.dart';
import 'features/calendar/event_detail_sheet.dart';
import 'l10n/app_localizations.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _channel = MethodChannel('widget_channel');

  static const _screens = <Widget>[
    TasksScreen(),
    CalendarScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleMethodCall);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _applyInitialIntent();
    });
  }

  Future<void> _applyInitialIntent() async {
    try {
      final eventId = await _channel.invokeMethod<String>('getInitialEventId') ?? '';
      final dateKey = await _channel.invokeMethod<String>('getInitialDateKey') ?? '';
      if (dateKey.isNotEmpty && mounted) {
        setState(() => _index = 1);
        await Future.delayed(const Duration(milliseconds: 400));
        _openCalendarDate(eventId, dateKey);
        return;
      }

      final action = await _channel.invokeMethod<String>('getInitialAction') ?? '';
      if (action.isNotEmpty && mounted) {
        if (action == 'create_task') {
          setState(() => _index = 0);
          await Future.delayed(const Duration(milliseconds: 300));
          _showAddTaskSheet();
        } else if (action == 'create_event') {
          setState(() => _index = 1);
          await Future.delayed(const Duration(milliseconds: 300));
          final dateKey = await _channel.invokeMethod<String>('getInitialDateKey') ?? '';
          _showCreateEventScreen(dateKey: dateKey.isNotEmpty ? dateKey : null);
        }
        return;
      }

      final tab = await _channel.invokeMethod<int>('getInitialTab') ?? -1;
      if (tab >= 0 && mounted) setState(() => _index = tab);
    } catch (e) { debugPrint('초기 인텐트 처리 실패: $e'); }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final navMethods = {
      'switchTab',
      'openCalendarDate',
      'openCreateTask',
      'openCreateEvent',
    };
    if (navMethods.contains(call.method) && mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }

    switch (call.method) {
      case 'refreshData':
        if (mounted) {
          ref.read(taskServiceProvider.notifier).loadTasks();
          ref.read(calendarProvider.notifier).loadEvents();
        }
      case 'taskCompleted':
        final taskId = call.arguments as String?;
        if (taskId != null && mounted) {
          ref.read(taskServiceProvider.notifier).markTaskCompletedLocal(taskId);
        }
      case 'taskDeleted':
        final taskId = call.arguments as String?;
        if (taskId != null && mounted) {
          ref.read(taskServiceProvider.notifier).deleteTaskLocal(taskId);
        }
      case 'switchTab':
        final tab = call.arguments as int?;
        if (tab != null && tab >= 0 && tab < 2 && mounted) setState(() => _index = tab);

      case 'openCalendarDate':
        final args = call.arguments as Map?;
        if (args == null) break;
        final eventId = args['eventId'] as String? ?? '';
        final dateKey = args['dateKey'] as String? ?? '';
        if (mounted) {
          setState(() => _index = 1);
          await Future.delayed(const Duration(milliseconds: 200));
          _openCalendarDate(eventId, dateKey);
        }

      case 'openCreateTask':
        if (mounted) {
          setState(() => _index = 0);
          await Future.delayed(const Duration(milliseconds: 200));
          _showAddTaskSheet();
        }

      case 'openCreateEvent':
        final dateKey = call.arguments as String?;
        if (mounted) {
          setState(() => _index = 1);
          await Future.delayed(const Duration(milliseconds: 200));
          _showCreateEventScreen(dateKey: dateKey);
        }
    }
  }

  void _openCalendarDate(String eventId, String dateKey) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => EventDetailSheet(dateKey: dateKey),
    );
  }

  void _showAddTaskSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const AddTaskSheet(),
    );
  }

  void _showCreateEventScreen({String? dateKey}) {
    if (!mounted) return;
    final targetDate = dateKey ??
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => EventFormScreen(initialDateKey: targetDate)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(taskServiceProvider.notifier).syncPendingFromWidget();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskServiceProvider).valueOrNull ?? [];
    final activeCount = tasks.where((t) => !t.isCompleted).length;
    final bool isTablet = MediaQuery.of(context).size.width >= 600;
    final l = AppLocalizations.of(context)!;

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: activeCount > 0,
                    label: Text('$activeCount'),
                    child: const Icon(Icons.check_circle_outline),
                  ),
                  selectedIcon: const Icon(Icons.check_circle),
                  label: Text(l.navTasks),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.calendar_today_outlined),
                  selectedIcon: const Icon(Icons.calendar_today),
                  label: Text(l.navCalendar),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(index: _index, children: _screens),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.check_circle_outline),
            ),
            selectedIcon: const Icon(Icons.check_circle),
            label: l.navTasks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: l.navCalendar,
          ),
        ],
      ),
    );
  }
}
