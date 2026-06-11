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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final themeBg = theme.scaffoldBackgroundColor;
    final themeSurface = theme.cardColor;
    final accentColor = theme.colorScheme.primary;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        backgroundColor: themeBg,
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
            color: themeSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(120), width: 1),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: isDark ? accentColor : null,
              ),
              title: const Text('화면 테마'),
              subtitle: Text(isDark ? '다크 모드' : '라이트 모드'),
              trailing: Switch(
                value: isDark,
                activeThumbColor: accentColor,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
          ),
          // 위젯 화면 설정
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              '홈 위젯 화면 모드',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? accentColor : Colors.grey[700],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              '위젯마다 커버화면/홈화면 여부를 수동으로 지정할 수 있어요.\n'
              '자동 감지는 폴더블 기기에서 위젯 크기로 판단해요.',
              style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.4),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_widgets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  '등록된 위젯이 없습니다',
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
            )
          else
            ..._widgets.map((w) => _WidgetCard(
                  widgetId: w['id'] as int,
                  width: w['width'] as int,
                  height: w['height'] as int,
                  manual: w['manual'] as String,
                  isCover: w['isCover'] as bool,
                  isTablet: w['isTablet'] as bool? ?? false,
                  isDark: isDark,
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
  final bool isTablet;
  final bool isDark;
  final void Function(String) onChanged;

  const _WidgetCard({
    required this.widgetId,
    required this.width,
    required this.height,
    required this.manual,
    required this.isCover,
    required this.isTablet,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeSurface = theme.cardColor;
    final accentColor = theme.colorScheme.primary;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;

    return Card(
      color: themeSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(120), width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCover ? Icons.phone_android : (isTablet ? Icons.tablet : Icons.home),
                  size: 18,
                  color: isCover ? accentColor : (isTablet ? Colors.teal : secondaryTextColor),
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
                    color: isCover
                        ? accentColor.withValues(alpha: 0.15)
                        : (isTablet
                            ? Colors.teal.withValues(alpha: 0.15)
                            : secondaryTextColor.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCover ? '커버화면' : (isTablet ? '태블릿' : '홈화면'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCover ? accentColor : (isTablet ? Colors.teal : secondaryTextColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '크기: ${width}dp × ${height}dp',
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cover', label: Text('커버'), icon: Icon(Icons.phone_android, size: 14)),
                  ButtonSegment(value: 'home',  label: Text('홈'),   icon: Icon(Icons.home, size: 14)),
                  ButtonSegment(value: 'tablet', label: Text('태블릿'), icon: Icon(Icons.tablet, size: 14)),
                  ButtonSegment(value: 'auto',  label: Text('자동'),     icon: Icon(Icons.auto_fix_high, size: 14)),
                ],
                selected: {manual},
                onSelectionChanged: (s) => onChanged(s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: accentColor.withValues(alpha: 0.15),
                  selectedForegroundColor: accentColor,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
