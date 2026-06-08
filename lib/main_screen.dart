import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api_client.dart';
import 'core/mail_poller.dart';
import 'core/notification_service.dart';
import 'features/tasks/task_service.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/gmail/gmail_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _index = 0;
  MailPoller? _poller;

  static const _screens = <Widget>[
    TasksScreen(),
    CalendarScreen(),
    GmailScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.requestPermission();
      _poller = MailPoller(ref.read(apiClientProvider));
      _poller!.start();
    });
  }

  @override
  void dispose() {
    _poller?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskServiceProvider).value ?? [];
    final activeCount = tasks.where((t) => !t.isCompleted).length;

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
            label: '태스크',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '캘린더',
          ),
          const NavigationDestination(
            icon: Icon(Icons.email_outlined),
            selectedIcon: Icon(Icons.email),
            label: 'Gmail',
          ),
        ],
      ),
    );
  }
}
