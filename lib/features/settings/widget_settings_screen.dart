import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_service.dart';
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
    } catch (e) {
      debugPrint('위젯 설정 로드 실패: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _setSetting(int id, String setting) async {
    try {
      await _channel.invokeMethod('setWidgetConfig', {'id': id, 'setting': setting});
      await _loadConfigs();
    } catch (e) { debugPrint('위젯 설정 변경 실패: $e'); }
  }

  Future<void> _setTheme(int id, String theme) async {
    try {
      await _channel.invokeMethod('setWidgetTheme', {'id': id, 'theme': theme});
      await _loadConfigs();
    } catch (e) { debugPrint('위젯 테마 변경 실패: $e'); }
  }

  Future<void> _setOpacity(int id, double opacity) async {
    try {
      await _channel.invokeMethod('setWidgetOpacity', {'id': id, 'opacity': opacity});
      await _loadConfigs();
    } catch (e) { debugPrint('위젯 투명도 변경 실패: $e'); }
  }

  void _showPrivacyPolicy(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('개인정보 처리방침'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('마이보드 개인정보 처리방침', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 12),
              Text('최종 수정일: 2026년 6월 12일', style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 16),
              Text('1. 수집하는 정보', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('본 앱은 Google 계정을 통해 다음 정보에 접근합니다:\n'
                   '• Google Tasks: 할 일 목록 조회 및 관리\n'
                   '• Google Calendar: 일정 조회 및 관리\n'
                   '• Gmail: 이메일 조회, 전송, 삭제\n\n'
                   '이 정보는 기기에서만 처리되며, 외부 서버로 전송되지 않습니다.'),
              SizedBox(height: 12),
              Text('2. 데이터 저장', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• 인증 토큰: 기기의 암호화된 저장소(EncryptedSharedPreferences)에 저장\n'
                   '• 위젯 데이터: 기기의 SharedPreferences에 캐시\n'
                   '• 모든 데이터는 기기에만 저장되며 외부로 전송되지 않습니다.'),
              SizedBox(height: 12),
              Text('3. 데이터 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('로그아웃 시 저장된 인증 토큰이 삭제됩니다. '
                   '앱을 삭제하면 모든 로컬 데이터가 완전히 제거됩니다.'),
              SizedBox(height: 12),
              Text('4. 제3자 제공', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('본 앱은 사용자 데이터를 제3자에게 제공하거나 판매하지 않습니다. '
                   'Google API를 통한 통신 외에 외부 서버와의 데이터 교환은 없습니다.'),
              SizedBox(height: 12),
              Text('5. Google API 정책 준수', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('본 앱의 Google 사용자 데이터 사용 및 전송은 '
                   'Google API Services User Data Policy(제한적 사용 요건 포함)를 준수합니다.'),
              SizedBox(height: 12),
              Text('6. 문의', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('개인정보 관련 문의: dhwjdghddd@gmail.com'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ),
    );
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
        foregroundColor: isDark ? Colors.white : Colors.black87,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
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
                  widgetTheme: w['theme'] as String? ?? 'system',
                  opacity: (w['opacity'] as num?)?.toDouble() ?? 1.0,
                  isCover: w['isCover'] as bool,
                  isTablet: w['isTablet'] as bool? ?? false,
                  isDark: isDark,
                  onChanged: (setting) => _setSetting(w['id'] as int, setting),
                  onThemeChanged: (theme) => _setTheme(w['id'] as int, theme),
                  onOpacityChanged: (opacity) => _setOpacity(w['id'] as int, opacity),
                )),
          const SizedBox(height: 24),
          // 앱 정보 & 법적 고지
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              '앱 정보',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? accentColor : Colors.grey[700],
              ),
            ),
          ),
          Card(
            color: themeSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(120), width: 1),
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: isDark ? accentColor : null),
                  title: const Text('개인정보 처리방침'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _showPrivacyPolicy(context, isDark),
                ),
                Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withAlpha(80)),
                ListTile(
                  leading: Icon(Icons.description_outlined, color: isDark ? accentColor : null),
                  title: const Text('오픈소스 라이선스'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: '마이보드',
                    applicationVersion: '1.0.0',
                  ),
                ),
                Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withAlpha(80)),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('로그아웃'),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('로그아웃'),
                        content: const Text('로그아웃하면 저장된 인증 정보가 삭제됩니다. 계속할까요?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('로그아웃')),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      ref.read(authServiceProvider.notifier).signOut();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetCard extends StatefulWidget {
  final int widgetId;
  final int width;
  final int height;
  final String manual;
  final String widgetTheme;
  final double opacity;
  final bool isCover;
  final bool isTablet;
  final bool isDark;
  final void Function(String) onChanged;
  final void Function(String) onThemeChanged;
  final void Function(double) onOpacityChanged;

  const _WidgetCard({
    required this.widgetId,
    required this.width,
    required this.height,
    required this.manual,
    required this.widgetTheme,
    required this.opacity,
    required this.isCover,
    required this.isTablet,
    required this.isDark,
    required this.onChanged,
    required this.onThemeChanged,
    required this.onOpacityChanged,
  });

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard> {
  late double _localOpacity;

  @override
  void initState() {
    super.initState();
    _localOpacity = widget.opacity;
  }

  @override
  void didUpdateWidget(covariant _WidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opacity != widget.opacity) {
      _localOpacity = widget.opacity;
    }
  }

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
                  widget.isCover ? Icons.phone_android : (widget.isTablet ? Icons.tablet : Icons.home),
                  size: 18,
                  color: widget.isCover ? accentColor : (widget.isTablet ? Colors.teal : secondaryTextColor),
                ),
                const SizedBox(width: 8),
                Text(
                  'Widget #${widget.widgetId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.isCover
                        ? accentColor.withValues(alpha: 0.15)
                        : (widget.isTablet
                            ? Colors.teal.withValues(alpha: 0.15)
                            : secondaryTextColor.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.isCover ? '커버화면' : (widget.isTablet ? '태블릿' : '홈화면'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isCover ? accentColor : (widget.isTablet ? Colors.teal : secondaryTextColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '크기: ${widget.width}dp × ${widget.height}dp',
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
                selected: {widget.manual},
                onSelectionChanged: (s) => widget.onChanged(s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: accentColor.withValues(alpha: 0.15),
                  selectedForegroundColor: accentColor,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '위젯 테마 설정',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? accentColor : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('시스템'), icon: Icon(Icons.settings_suggest, size: 14)),
                  ButtonSegment(value: 'light',  label: Text('라이트'), icon: Icon(Icons.light_mode, size: 14)),
                  ButtonSegment(value: 'dark',   label: Text('다크'),   icon: Icon(Icons.dark_mode, size: 14)),
                ],
                selected: {widget.widgetTheme},
                onSelectionChanged: (s) => widget.onThemeChanged(s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: accentColor.withValues(alpha: 0.15),
                  selectedForegroundColor: accentColor,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '위젯 배경 투명도 설정',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? accentColor : Colors.grey[700],
                  ),
                ),
                Text(
                  '${(_localOpacity * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? accentColor : Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accentColor,
                inactiveTrackColor: theme.colorScheme.outlineVariant.withAlpha(100),
                thumbColor: accentColor,
                overlayColor: accentColor.withAlpha(30),
                trackHeight: 4,
              ),
              child: Slider(
                value: _localOpacity,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                onChanged: (v) => setState(() => _localOpacity = v),
                onChangeEnd: widget.onOpacityChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
