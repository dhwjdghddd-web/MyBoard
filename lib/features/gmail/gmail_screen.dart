import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import 'email_detail_screen.dart';
import 'gmail_service.dart';
import '../settings/widget_settings_screen.dart';

const _avatarColors = [
  Color(0xFFEA4335), Color(0xFF4285F4), Color(0xFF34A853),
  Color(0xFFFBBC04), Color(0xFF9C27B0), Color(0xFFFF6D00),
];

Color _avatarColor(String initial) =>
    _avatarColors[initial.codeUnitAt(0) % _avatarColors.length];

List<(String, String, String)> _labelsList(AppLocalizations l) => [
  ('INBOX',   '📥', l.gmailInbox),
  ('STARRED', '⭐', l.gmailStarred),
  ('SENT',    '📤', l.gmailSent),
  ('SPAM',    '🚫', l.gmailSpam),
  ('TRASH',   '🗑️', l.gmailTrash),
];

class GmailScreen extends ConsumerStatefulWidget {
  const GmailScreen({super.key});

  @override
  ConsumerState<GmailScreen> createState() => _GmailScreenState();
}

class _GmailScreenState extends ConsumerState<GmailScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      final query = _searching ? _searchCtrl.text.trim() : null;
      ref.read(gmailProvider.notifier).loadMoreMessages(query: query);
    }
  }

  void _search() {
    final q = _searchCtrl.text.trim();
    if (q.isNotEmpty) ref.read(gmailProvider.notifier).loadMessages(query: q);
  }

  void _openEmail(GmailMessage msg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailDetailScreen(messageId: msg.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gmail = ref.watch(gmailProvider);
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final labels = _labelsList(l);

    String labelName(String label) =>
        labels.firstWhere((x) => x.$1 == label, orElse: () => (label, '', label)).$3;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white),
                decoration: InputDecoration(
                  hintText: l.gmailSearchHint,
                  hintStyle: TextStyle(color: (Theme.of(context).appBarTheme.foregroundColor ?? Colors.white).withValues(alpha: 0.7)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _search(),
              )
            : Text(labelName(gmail.label)),
        actions: [
          if (_searching) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _searching = false);
                _searchCtrl.clear();
                ref.read(gmailProvider.notifier).loadMessages();
              },
            ),
          ] else ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(gmailProvider.notifier).loadMessages();
                ref.read(gmailProvider.notifier).loadLabelCounts();
              },
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.settings),
              tooltip: l.settingsTitle,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WidgetSettingsScreen())),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => launchUrl(Uri.parse('mailto:'), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l.composeButton),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Column(children: [
        _LabelStrip(
          currentLabel: gmail.label,
          labelCounts: gmail.labelCounts,
          labels: labels,
          onSelect: (label) => ref.read(gmailProvider.notifier).selectLabel(label),
        ),

        Expanded(
          child: gmail.loading
              ? const Center(child: CircularProgressIndicator())
              : gmail.error != null
                  ? _ErrorView(onRetry: () => ref.read(gmailProvider.notifier).loadMessages())
                  : gmail.messages.isEmpty
                      ? const _EmptyView()
                      : RefreshIndicator(
                          onRefresh: () async {
                            await ref.read(gmailProvider.notifier).loadMessages();
                            await ref.read(gmailProvider.notifier).loadLabelCounts();
                          },
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: EdgeInsets.zero,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: gmail.messages.length + (gmail.loadingMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= gmail.messages.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final msg = gmail.messages[i];
                              final selected = gmail.selectedIds.contains(msg.id);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _MessageTile(
                                    message: msg,
                                    selected: selected,
                                    onTap: () {
                                      if (gmail.hasSelection) {
                                        ref.read(gmailProvider.notifier).toggleSelect(msg.id);
                                      } else {
                                        _openEmail(msg);
                                      }
                                    },
                                    onLongPress: () => ref.read(gmailProvider.notifier).toggleSelect(msg.id),
                                  ),
                                  if (i < gmail.messages.length - 1)
                                    Divider(
                                      height: 1,
                                      indent: 68,
                                      color: scheme.outlineVariant.withAlpha(120),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

// ── 라벨 스트립 ───────────────────────────────────────────────────────────

class _LabelStrip extends StatelessWidget {
  const _LabelStrip({
    required this.currentLabel,
    required this.labelCounts,
    required this.labels,
    required this.onSelect,
  });
  final String currentLabel;
  final Map<String, int> labelCounts;
  final List<(String, String, String)> labels;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      color: scheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: labels.map((l) {
          final selected = l.$1 == currentLabel;
          final count = labelCounts[l.$1] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              selected: selected,
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${l.$2} ${l.$3}', style: const TextStyle(fontSize: 12)),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              onSelected: (_) => onSelect(l.$1),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 메시지 타일 ───────────────────────────────────────────────────────────

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message, required this.selected,
    required this.onTap, required this.onLongPress,
  });

  final GmailMessage message;
  final bool selected;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final initial = message.initial;
    final avatarColor = _avatarColor(initial);
    final isUnread = message.isUnread;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: selected
              ? scheme.primaryContainer.withAlpha(100)
              : (isUnread ? scheme.primaryContainer.withAlpha(30) : null),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: onLongPress,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: selected ? scheme.primary : avatarColor,
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      message.displayName,
                      style: TextStyle(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                        color: isUnread ? scheme.onSurface : scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatEmailDate(message.date, isEnglish: isEnglish),
                    style: TextStyle(
                      fontSize: 11,
                      color: isUnread ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(width: 4),
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF1A73E8), shape: BoxShape.circle)),
                  ],
                ]),
                const SizedBox(height: 1),
                Text(
                  message.subject.isEmpty ? l.noSubject : message.subject,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                    color: isUnread ? scheme.onSurface : scheme.onSurface.withAlpha(200),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (message.snippet.isNotEmpty)
                  Text(
                    message.snippet,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ]),
            ),
            if (message.isStarred)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Icon(Icons.star, size: 16, color: Colors.amber[600]),
              ),
          ]),
        ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.mail_outline, size: 64, color: scheme.outlineVariant),
        const SizedBox(height: 16),
        Text(l.gmailEmpty, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off, size: 48, color: scheme.outline),
        const SizedBox(height: 16),
        Text(l.gmailLoadError, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: Text(l.retryButton)),
      ]),
    );
  }
}
