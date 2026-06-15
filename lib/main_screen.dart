import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api_client.dart';
import 'core/mail_poller.dart';
import 'core/notification_service.dart';
import 'features/tasks/task_service.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/tasks/add_task_sheet.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/calendar/calendar_service.dart';
import 'features/calendar/event_form_screen.dart';
import 'features/calendar/event_detail_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'features/gmail/gmail_screen.dart';
import 'features/gmail/gmail_service.dart';
import 'features/gmail/email_detail_screen.dart';
import 'l10n/app_localizations.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  MailPoller? _poller;

  static const _channel = MethodChannel('widget_channel');

  static const _screens = <Widget>[
    TasksScreen(),
    CalendarScreen(),
    GmailScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleMethodCall);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.requestPermission();
      NotificationService.setOnTapCallback((int? id, String? payload) {
        if (mounted) setState(() => _index = 2);
      });
      _poller = MailPoller(
        ref.read(apiClientProvider),
        onNewMail: () async {
          if (mounted) {
            await ref.read(gmailProvider.notifier).loadMessages();
          }
        },
      );
      _poller!.start();
      _applyInitialIntent();
    });
  }

  Future<void> _applyInitialIntent() async {
    try {
      final emailId = await _channel.invokeMethod<String>('getInitialEmailId') ?? '';
      if (emailId.isNotEmpty && mounted) {
        setState(() => _index = 2);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => EmailDetailScreen(messageId: emailId, )));
        }
        return;
      }

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
        } else if (action == 'compose_email') {
          await launchUrl(Uri.parse('mailto:'), mode: LaunchMode.externalApplication);
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
      'openEmail',
      'openCalendarDate',
      'openCreateTask',
      'openCreateEvent',
      'openComposeEmail'
    };
    if (navMethods.contains(call.method) && mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }

    switch (call.method) {
      case 'refreshData':
        if (mounted) {
          ref.read(taskServiceProvider.notifier).loadTasks();
          ref.read(calendarProvider.notifier).loadEvents();
          ref.read(gmailProvider.notifier).loadMessages();
          ref.read(gmailProvider.notifier).loadLabelCounts();
        }
      case 'gmailDeleted':
        if (mounted) {
          ref.read(gmailProvider.notifier).loadMessages();
          ref.read(gmailProvider.notifier).loadLabelCounts();
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
        if (tab != null && tab >= 0 && tab < 3 && mounted) setState(() => _index = tab);

      case 'openEmail':
        final emailId = call.arguments as String?;
        if (emailId != null && emailId.isNotEmpty && mounted) {
          setState(() => _index = 2);
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => EmailDetailScreen(messageId: emailId, )));
          }
        }

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

      case 'openComposeEmail':
        await launchUrl(Uri.parse('mailto:'), mode: LaunchMode.externalApplication);
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
      _poller?.start();
      ref.read(taskServiceProvider.notifier).syncPendingFromWidget();
      ref.read(gmailProvider.notifier).loadLabelCounts();
    } else if (state == AppLifecycleState.paused) {
      _poller?.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskServiceProvider).value ?? [];
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
                const NavigationRailDestination(
                  icon: Icon(Icons.email_outlined),
                  selectedIcon: Icon(Icons.email),
                  label: Text('Gmail'),
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
