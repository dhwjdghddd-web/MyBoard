import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'email_detail_screen.dart';
import 'gmail_compose_screen.dart';
import 'gmail_service.dart';
import '../settings/widget_settings_screen.dart';

const _avatarColors = [
  Color(0xFFEA4335), Color(0xFF4285F4), Color(0xFF34A853),
  Color(0xFFFBBC04), Color(0xFF9C27B0), Color(0xFFFF6D00),
];

Color _avatarColor(String initial) =>
    _avatarColors[initial.codeUnitAt(0) % _avatarColors.length];

const _labels = [
  ('INBOX', '📥', '받은편지함'),
  ('STARRED', '⭐', '중요'),
  ('SENT', '📤', '보낸편지함'),
  ('SPAM', '🚫', '스팸'),
  ('TRASH', '🗑️', '휴지통'),
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

  Future<void> _batchDelete() async {
    final ids = ref.read(gmailProvider).selectedIds.toList();
    try {
      await ref.read(gmailProvider.notifier).batchDelete(ids);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('이미 휴지통에 있습니다. 30일 후 자동 삭제됩니다.'),
      ));
    }
  }

  Future<void> _confirmEmptyTrash() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('휴지통 비우기'),
        content: const Text('모든 메일을 영구 삭제할까요?\n복구할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('비우기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(gmailProvider.notifier).emptyTrash();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('휴지통 비우기는 추가 권한이 필요합니다. Gmail 앱을 이용해주세요.'),
        ));
      }
    }
  }

  void _openEmail(GmailMessage msg) {
    if (msg.isUnread) ref.read(gmailProvider.notifier).markRead(msg.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailDetailScreen(
          messageId: msg.id,
          isInTrash: ref.read(gmailProvider).isInTrash,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gmail = ref.watch(gmailProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '메일 검색…',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _search(),
              )
            : Text(_labelName(gmail.label)),
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
            if (gmail.isInTrash)
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                onPressed: _confirmEmptyTrash,
                child: const Text('비우기', style: TextStyle(color: Colors.white)),
              ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.widgets_outlined),
              tooltip: '위젯 설정',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WidgetSettingsScreen())),
            ),
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
            const ThemeToggleButton(),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GmailComposeScreen())),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('작성'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // 라벨 선택 스트립
        _LabelStrip(
          currentLabel: gmail.label,
          labelCounts: gmail.labelCounts,
          onSelect: (l) => ref.read(gmailProvider.notifier).selectLabel(l),
        ),

        // 일괄 선택 바
        if (gmail.hasSelection)
          _BatchBar(
            count: gmail.selectedIds.length,
            isInTrash: gmail.isInTrash,
            onDelete: _batchDelete,
            onRead: () => ref.read(gmailProvider.notifier).batchMarkRead(gmail.selectedIds.toList()),
            onClear: () => ref.read(gmailProvider.notifier).clearSelection(),
          ),

        // 메시지 목록
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
                                    isInTrash: gmail.isInTrash,
                                    onTap: () {
                                      if (gmail.hasSelection) {
                                        ref.read(gmailProvider.notifier).toggleSelect(msg.id);
                                      } else {
                                        _openEmail(msg);
                                      }
                                    },
                                    onLongPress: () => ref.read(gmailProvider.notifier).toggleSelect(msg.id),
                                    onDismissDelete: () {
                                      if (gmail.isInTrash) {
                                        ref.read(gmailProvider.notifier).removeMessageLocal(msg.id);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text('이미 휴지통에 있습니다. 30일 후 자동 삭제됩니다.'),
                                        ));
                                      } else {
                                        ref.read(gmailProvider.notifier).trashMessage(msg.id);
                                      }
                                    },
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

  String _labelName(String label) {
    return _labels.firstWhere((l) => l.$1 == label, orElse: () => (label, '', label)).$3;
  }
}

// ── 라벨 스트립 ───────────────────────────────────────────────────────────

class _LabelStrip extends StatelessWidget {
  const _LabelStrip({required this.currentLabel, required this.labelCounts, required this.onSelect});
  final String currentLabel;
  final Map<String, int> labelCounts;
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
        children: _labels.map((l) {
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

// ── 일괄 작업 바 ─────────────────────────────────────────────────────────

class _BatchBar extends StatelessWidget {
  const _BatchBar({required this.count, required this.isInTrash, required this.onDelete, required this.onRead, required this.onClear});
  final int count;
  final bool isInTrash;
  final VoidCallback onDelete, onRead, onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Text('$count개 선택', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        TextButton.icon(
          icon: const Icon(Icons.delete, size: 16),
          label: Text(isInTrash ? '영구삭제 불가' : '삭제'),
          onPressed: onDelete,
          style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
        ),
        TextButton.icon(
          icon: const Icon(Icons.mark_email_read, size: 16),
          label: const Text('읽음'),
          onPressed: onRead,
        ),
        const Spacer(),
        IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onClear),
      ]),
    );
  }
}

// ── 메시지 타일 ───────────────────────────────────────────────────────────

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message, required this.selected, required this.isInTrash,
    required this.onTap, required this.onLongPress,
    required this.onDismissDelete,
  });

  final GmailMessage message;
  final bool selected, isInTrash;
  final VoidCallback onTap, onLongPress, onDismissDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = message.initial;
    final avatarColor = _avatarColor(initial);
    final isUnread = message.isUnread;

    return Dismissible(
      key: ValueKey(message.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red[100],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) => onDismissDelete(),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: selected
              ? scheme.primaryContainer.withAlpha(100)
              : (isUnread ? scheme.primaryContainer.withAlpha(30) : null),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 아바타
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
            // 본문
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
                    formatEmailDate(message.date),
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
                  message.subject.isEmpty ? '(제목 없음)' : message.subject,
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
            // 별표
            if (message.isStarred)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Icon(Icons.star, size: 16, color: Colors.amber[600]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.mail_outline, size: 64, color: scheme.outlineVariant),
        const SizedBox(height: 16),
        Text('메일이 없어요', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
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
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off, size: 48, color: scheme.outline),
        const SizedBox(height: 16),
        Text('메일을 불러올 수 없어요', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
      ]),
    );
  }
}
