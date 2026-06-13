import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'gmail_service.dart';

const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

String _sanitizeHtml(String html) {
  var s = html;
  // 위험 태그 제거
  s = s.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<script[^>]*/>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<iframe[\s\S]*?</iframe>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<iframe[^>]*/>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<object[\s\S]*?</object>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<embed[^>]*/?>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<form[\s\S]*?</form>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<applet[\s\S]*?</applet>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<base[^>]*/?>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<link[^>]*stylesheet[^>]*/?>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<svg[\s\S]*?</svg>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<math[\s\S]*?</math>', caseSensitive: false), '');
  // 인라인 이벤트 핸들러 제거
  s = s.replaceAll(RegExp(r'\s+on\w+\s*=\s*"[^"]*"', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r"""\s+on\w+\s*=\s*'[^']*'""", caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'\s+on\w+\s*=\s*\S+', caseSensitive: false), '');
  // javascript: URI 제거
  s = s.replaceAll(RegExp(r'href\s*=\s*"javascript:[^"]*"', caseSensitive: false), 'href="#"');
  s = s.replaceAll(RegExp(r"href\s*=\s*'javascript:[^']*'", caseSensitive: false), "href='#'");
  // style 속성의 expression() 제거
  s = s.replaceAll(RegExp(r'expression\s*\(', caseSensitive: false), '');
  return s;
}

String _wrapHtml(String body, bool isDark) {
  final bg = isDark ? '#151524' : '#ffffff';
  final text = isDark ? '#E0E0FF' : '#202124';
  final link = isDark ? '#82B1FF' : '#1a73e8';
  final imgOpacity = isDark ? '0.85' : '1.0';
  final colorScheme = isDark ? 'only dark' : 'only light';

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="$colorScheme">
  <style>
    :root { color-scheme: $colorScheme; }
    html, body {
      margin: 0; padding: 0;
      background: $bg !important;
      color: $text !important;
    }
    body {
      padding: 14px;
      font-family: sans-serif;
      font-size: 14px;
      line-height: 1.6;
      word-break: break-word;
    }
    * { max-width: 100%; box-sizing: border-box; }
    img { max-width: 100%; height: auto; opacity: $imgOpacity; }
    a { color: $link; }
    pre { white-space: pre-wrap; font-family: inherit; }
  </style>
</head>
<body>${_sanitizeHtml(body)}</body>
</html>
''';
}

class EmailDetailScreen extends ConsumerStatefulWidget {
  const EmailDetailScreen({
    super.key,
    required this.messageId,
  });

  final String messageId;

  @override
  ConsumerState<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends ConsumerState<EmailDetailScreen> {
  static const _saveChannel = MethodChannel('widget_channel');

  Map<String, dynamic>? _full;
  bool _loading = true;
  String? _error;
  List<Attachment> _attachments = [];
  final Set<String> _downloading = {};
  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          final url = req.url;
          if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('mailto:')) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));

    _loadFull();
  }

  Future<void> _loadFull() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ref.read(apiClientProvider).get(
        '$_base/messages/${widget.messageId}',
        params: {'format': 'full'},
      );
      final full = data as Map<String, dynamic>;
      final payload = full['payload'] as Map<String, dynamic>? ?? {};
      final body = getEmailBody(payload) ?? '<p style="padding:16px;color:#999">본문이 없습니다</p>';
      final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
      setState(() {
        _full = full;
        _attachments = getAttachments(payload);
        _loading = false;
      });
      await _webController.loadHtmlString(_wrapHtml(body, isDark));
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openFile(String filePath, String mimeType, ScaffoldMessengerState messenger) async {
    try {
      await _saveChannel.invokeMethod<void>('openFile', {
        'uri': filePath,
        'mimeType': mimeType,
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('파일 열기 실패: $e')));
    }
  }

  Future<void> _downloadAttachment(Attachment att) async {
    if (_downloading.contains(att.attachmentId)) return;

    // 기존 파일 존재 여부 확인
    final existingUri = await _saveChannel.invokeMethod<String>(
      'findExistingDownload', att.filename,
    );
    if (existingUri != null && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final redownload = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('이미 다운로드된 파일'),
          content: Text('"${att.filename}"이 이미 다운로드되어 있어요.\n다시 받을까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('바로 열기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('다시 받기'),
            ),
          ],
        ),
      );
      if (redownload == null) return; // 취소
      if (redownload == false) {
        await _openFile(existingUri, att.mimeType, messenger);
        return;
      }
    }

    setState(() => _downloading.add(att.attachmentId));
    try {
      final resp = await ref.read(apiClientProvider).get(
        '$_base/messages/${widget.messageId}/attachments/${att.attachmentId}',
      );
      final data = resp['data'] as String;
      final uri = await _saveChannel.invokeMethod<String>('saveAttachment', {
        'filename': att.filename,
        'mimeType': att.mimeType,
        'data': data,
      });
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('"${att.filename}" 다운로드 완료'),
            action: uri != null
                ? SnackBarAction(
                    label: '열기',
                    onPressed: () => _openFile(uri, att.mimeType, messenger),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(att.attachmentId));
    }
  }

  String _header(String name) {
    final headers = (_full?['payload']?['headers'] as List?) ?? [];
    return headers.cast<Map>()
        .firstWhere((h) => (h['name'] as String).toLowerCase() == name.toLowerCase(),
            orElse: () => {'value': ''})['value'] as String;
  }

  Future<void> _openGmailApp() async {
    final uri = Uri.parse('googlegmail://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(Uri.parse('https://mail.google.com'), mode: LaunchMode.externalApplication);
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
                  // 헤더: 수신자가 많아도 스크롤 가능하도록 최대 높이 제한
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.28,
                    ),
                    child: SingleChildScrollView(
                      child: Container(
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
                          OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Gmail 앱 열기'),
                            onPressed: _openGmailApp,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 38),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  Expanded(child: WebViewWidget(controller: _webController)),
                  if (_attachments.isNotEmpty)
                    _AttachmentBar(
                      attachments: _attachments,
                      downloading: _downloading,
                      onDownload: _downloadAttachment,
                    ),
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
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}


class _AttachmentBar extends StatelessWidget {
  const _AttachmentBar({
    required this.attachments,
    required this.downloading,
    required this.onDownload,
  });

  final List<Attachment> attachments;
  final Set<String> downloading;
  final void Function(Attachment) onDownload;

  IconData _iconFor(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.video_file_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description_outlined;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) return Icons.table_chart_outlined;
    if (mimeType.contains('zip') || mimeType.contains('compressed')) return Icons.folder_zip_outlined;
    return Icons.attach_file;
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(color: outline),
          bottom: BorderSide(color: outline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '첨부파일 ${attachments.length}개',
            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: attachments.map((att) {
                final isLoading = downloading.contains(att.attachmentId);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: isLoading ? null : () => onDownload(att),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconFor(att.mimeType), size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              att.filename,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sizeLabel(att.size),
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 6),
                          isLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.download_outlined, size: 16, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
