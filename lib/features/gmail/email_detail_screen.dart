import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api_client.dart';
import 'gmail_service.dart';

const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

String _wrapHtml(String body) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="only light">
  <style>
    :root { color-scheme: only light; }
    html, body {
      margin: 0; padding: 0;
      background: #ffffff !important;
      color: #202124 !important;
    }
    body {
      padding: 14px;
      font-family: sans-serif;
      font-size: 14px;
      line-height: 1.6;
      word-break: break-word;
    }
    * { max-width: 100%; box-sizing: border-box; }
    img { max-width: 100%; height: auto; }
    a { color: #1a73e8; }
    pre { white-space: pre-wrap; font-family: inherit; }
  </style>
</head>
<body>$body</body>
</html>
''';

class EmailDetailScreen extends ConsumerStatefulWidget {
  const EmailDetailScreen({
    super.key,
    required this.messageId,
    required this.isInTrash,
  });

  final String messageId;
  final bool isInTrash;

  @override
  ConsumerState<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends ConsumerState<EmailDetailScreen> {
  Map<String, dynamic>? _full;
  bool _loading = true;
  String? _error;
  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(const Color(0xFFFFFFFF));

    _loadFull();
  }

  Future<void> _loadFull() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ref.read(apiClientProvider).get(
        '$_base/messages/${widget.messageId}',
        params: {'format': 'full'},
      );
      setState(() { _full = data as Map<String, dynamic>; _loading = false; });
      final body = getEmailBody(_full?['payload'] as Map<String, dynamic>? ?? {}) ??
          '<p style="padding:16px;color:#999">본문이 없습니다</p>';
      await _webController.loadHtmlString(_wrapHtml(body));
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _header(String name) {
    final headers = (_full?['payload']?['headers'] as List?) ?? [];
    return headers.cast<Map>()
        .firstWhere((h) => (h['name'] as String).toLowerCase() == name.toLowerCase(),
            orElse: () => {'value': ''})['value'] as String;
  }

  List<String> get _labelIds => (_full?['labelIds'] as List?)?.cast<String>() ?? [];
  bool get _isSpam => _labelIds.contains('SPAM');
  bool get _isStarred => _labelIds.contains('STARRED');

  Future<void> _delete() async {
    if (widget.isInTrash) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('영구 삭제 불가'),
          content: const Text('이미 휴지통에 있습니다.\n30일 후 자동으로 영구 삭제됩니다.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('메일 삭제'),
        content: const Text('휴지통으로 이동할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(gmailProvider.notifier).trashMessage(widget.messageId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _spam() async {
    if (_isSpam) {
      await ref.read(gmailProvider.notifier).unmarkSpam(widget.messageId);
    } else {
      await ref.read(gmailProvider.notifier).markSpam(widget.messageId);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _star() async {
    await ref.read(gmailProvider.notifier).toggleStar(widget.messageId, _isStarred);
    if (mounted) {
      setState(() {
        final labels = List<String>.from(_labelIds);
        if (_isStarred) { labels.remove('STARRED'); } else { labels.add('STARRED'); }
        _full = {...?_full, 'labelIds': labels};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메일'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFull),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('메일을 불러올 수 없어요', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _loadFull, child: const Text('다시 시도')),
                ]))
              : Column(children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        _header('Subject').isEmpty ? '(제목 없음)' : _header('Subject'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow('보낸사람', _header('From')),
                      _InfoRow('받는사람', _header('To')),
                      _InfoRow('날짜', formatEmailDate(_header('Date'))),
                      const SizedBox(height: 10),
                      Row(children: [
                          Expanded(child: _ActionBtn(
                            icon: Icons.delete_outline,
                            label: widget.isInTrash ? '영구삭제 불가' : '삭제',
                            onTap: _delete,
                            color: Colors.red[400],
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _ActionBtn(
                            icon: _isSpam ? Icons.check_circle_outline : Icons.block,
                            label: _isSpam ? '스팸 해제' : '스팸',
                            onTap: _spam,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _ActionBtn(
                            icon: _isStarred ? Icons.star : Icons.star_border,
                            label: _isStarred ? '중요 해제' : '중요',
                            onTap: _star,
                            color: _isStarred ? Colors.amber : null,
                          )),
                        ]),
                    ]),
                  ),
                  Expanded(child: WebViewWidget(controller: _webController)),
                ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: const Size(double.infinity, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: color != null ? BorderSide(color: color!) : null,
      ),
    );
  }
}
