import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_service.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

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
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.privacyPolicy),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.privacyPolicyTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Text(l.privacyPolicyLastModified, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Text(l.privacySection1Title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l.privacySection1Body),
              const SizedBox(height: 12),
              Text(l.privacySection2Title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l.privacySection2Body),
              const SizedBox(height: 12),
              Text(l.privacySection3Title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l.privacySection3Body),
              const SizedBox(height: 12),
              Text(l.privacySection4Title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l.privacySection4Body),
              const SizedBox(height: 12),
              Text(l.privacySection5Title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l.privacySection5Body),
              const SizedBox(height: 12),
              Text(l.privacySection6Title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l.privacySection6Body),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.closeButton)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context)!;

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
        title: Text(l.settingsTitle),
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
              title: Text(l.themeTitle),
              subtitle: Text(isDark ? l.darkMode : l.lightMode),
              trailing: Switch(
                value: isDark,
                activeThumbColor: accentColor,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              l.widgetScreenMode,
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
              l.widgetScreenModeDesc,
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
                  l.noWidgets,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              l.appInfoSection,
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
                  title: Text(l.privacyPolicy),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _showPrivacyPolicy(context, isDark),
                ),
                Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withAlpha(80)),
                ListTile(
                  leading: Icon(Icons.description_outlined, color: isDark ? accentColor : null),
                  title: Text(l.openSourceLicense),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'MyBoard',
                    applicationVersion: '1.0.0',
                  ),
                ),
                Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withAlpha(80)),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: Text(l.logout),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(l.logout),
                        content: Text(l.logoutConfirmMessage),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancelButton)),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.logout)),
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
    final l = AppLocalizations.of(context)!;
    final themeSurface = theme.cardColor;
    final accentColor = theme.colorScheme.primary;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;

    final screenLabel = widget.isCover ? l.coverScreen : (widget.isTablet ? l.tabletLabel : l.homeScreen);

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
                    screenLabel,
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
              l.widgetSize(widget.width, widget.height),
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'cover',  label: Text(l.coverButton),  icon: const Icon(Icons.phone_android, size: 14)),
                  ButtonSegment(value: 'home',   label: Text(l.homeButton),   icon: const Icon(Icons.home, size: 14)),
                  ButtonSegment(value: 'tablet', label: Text(l.tabletLabel),  icon: const Icon(Icons.tablet, size: 14)),
                  ButtonSegment(value: 'auto',   label: Text(l.autoButton),   icon: const Icon(Icons.auto_fix_high, size: 14)),
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
              l.widgetThemeSetting,
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
                segments: [
                  ButtonSegment(value: 'system', label: Text(l.widgetSystemTheme), icon: const Icon(Icons.settings_suggest, size: 14)),
                  ButtonSegment(value: 'light',  label: Text(l.widgetLightTheme),  icon: const Icon(Icons.light_mode, size: 14)),
                  ButtonSegment(value: 'dark',   label: Text(l.widgetDarkTheme),   icon: const Icon(Icons.dark_mode, size: 14)),
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
                  l.widgetOpacitySetting,
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
