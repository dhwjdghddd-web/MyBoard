import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';

class WidgetSettingsScreen extends ConsumerStatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  ConsumerState<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends ConsumerState<WidgetSettingsScreen> {
  static const _channel = MethodChannel('widget_channel');

  List<Map<String, dynamic>> _widgets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    try {
      final raw = await _channel.invokeMethod<List>('getWidgetConfigs') ?? [];
      setState(() {
        _widgets = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _setSetting(int id, String setting) async {
    try {
      await _channel.invokeMethod('setWidgetConfig', {'id': id, 'setting': setting});
      await _loadConfigs();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfigs,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 화면 테마
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              title: const Text('화면 테마'),
              subtitle: Text(isDark ? '다크 모드' : '라이트 모드'),
              trailing: Switch(
                value: isDark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
          ),
          // 위젯 화면 설정
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '홈 위젯',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          const Text(
            '위젯마다 커버화면/홈화면 여부를 수동으로 지정할 수 있어요.\n'
            '자동 감지는 폴더블 기기에서 위젯 크기로 판단해요.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_widgets.isEmpty)
            const Center(child: Text('등록된 위젯이 없습니다'))
          else
            ..._widgets.map((w) => _WidgetCard(
                  widgetId: w['id'] as int,
                  width: w['width'] as int,
                  height: w['height'] as int,
                  manual: w['manual'] as String,
                  isCover: w['isCover'] as bool,
                  onChanged: (setting) => _setSetting(w['id'] as int, setting),
                )),
        ],
      ),
    );
  }
}

class _WidgetCard extends StatelessWidget {
  final int widgetId;
  final int width;
  final int height;
  final String manual;
  final bool isCover;
  final void Function(String) onChanged;

  const _WidgetCard({
    required this.widgetId,
    required this.width,
    required this.height,
    required this.manual,
    required this.isCover,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCover ? Icons.phone_android : Icons.home,
                  size: 18,
                  color: isCover ? Colors.blueAccent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Widget #$widgetId',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCover ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCover ? '커버화면' : '홈화면',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCover ? Colors.blueAccent : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '크기: ${width}dp × ${height}dp',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cover', label: Text('커버화면'), icon: Icon(Icons.phone_android, size: 14)),
                ButtonSegment(value: 'home',  label: Text('홈화면'),   icon: Icon(Icons.home, size: 14)),
                ButtonSegment(value: 'auto',  label: Text('자동'),     icon: Icon(Icons.auto_fix_high, size: 14)),
              ],
              selected: {manual},
              onSelectionChanged: (s) => onChanged(s.first),
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
