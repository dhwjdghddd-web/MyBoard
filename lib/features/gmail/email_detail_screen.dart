import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api_client.dart';
import '../../core/snackbar_helper.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'gmail_service.dart';

const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

String _sanitizeHtml(String html) {
  var s = html;
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
  s = s.replaceAll(RegExp(r'\s+on\w+\s*=\s*"[^"]*"', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r"""\s+on\w+\s*=\s*'[^']*'""", caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'\s+on\w+\s*=\s*\S+', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'href\s*=\s*"javascript:[^"]*"', caseSensitive: false), 'href="#"');
  s = s.replaceAll(RegExp(r"href\s*=\s*'javascript:[^']*'", caseSensitive: false), "href='#'");
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
      var body = getEmailBody(payload) ?? '<p style="padding:16px;color:#999">No content</p>';
      // 인라인 이미지(cid:) 를 실제 데이터로 치환 (로고/서명/뉴스레터 이미지)
      body = await _inlineCidImages(body, payload);
      // 외부 http 이미지는 cleartext 차단으로 안 보이므로 https 로 업그레이드
      // (Gmail 도 이미지를 https 프록시로 바꿔 표시함)
      body = _upgradeHttpImages(body);
      final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
      if (!mounted) return;
      setState(() {
        _full = full;
        _attachments = getAttachments(payload);
        _loading = false;
      });
      // 메일을 열면 로컬 읽음 처리 (앱 목록·위젯·라벨 배지에 읽음으로 표시). initState 가
      // 아닌 로드 완료(await 이후) 시점에 호출해야 "빌드 중 provider 수정" 오류가 안 난다.
      // readonly 권한이라 Gmail 서버는 그대로, MyBoard 안에서만 읽음으로 보인다.
      final labels = (full['labelIds'] as List?)?.cast<String>() ?? const <String>[];
      ref.read(gmailProvider.notifier).markRead(widget.messageId, labels);
      await _webController.loadHtmlString(_wrapHtml(body, isDark));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // 외부 이미지의 http:// 주소를 https:// 로 업그레이드 (img src 와 CSS url()).
  // 앱이 cleartext(http) 를 차단해 http 이미지가 안 뜨던 문제 해결. 대부분의
  // 이미지 호스트가 https 를 지원하므로 안전하며, 안 되는 소수는 기존과 동일(미표시).
  String _upgradeHttpImages(String html) {
    var s = html;
    s = s.replaceAllMapped(
      RegExp(r'''(src\s*=\s*["'])http://''', caseSensitive: false),
      (m) => '${m[1]}https://',
    );
    s = s.replaceAllMapped(
      RegExp(r'''(url\(\s*["']?)http://''', caseSensitive: false),
      (m) => '${m[1]}https://',
    );
    return s;
  }

  // 본문 HTML 의 <img src="cid:..."> 를 data URI 로 치환한다. Gmail 첨부 데이터는
  // base64url 이므로 -/_ → +// 로 변환해 표준 base64 data URI 로 만든다.
  Future<String> _inlineCidImages(String body, Map<String, dynamic> payload) async {
    if (!body.contains('cid:')) return body;
    final images = getInlineImages(payload);
    if (images.isEmpty) return body;
    var result = body;
    for (final img in images) {
      var b64 = img.data;
      if ((b64 == null || b64.isEmpty) && img.attachmentId != null) {
        try {
          final att = await ref.read(apiClientProvider).get(
            '$_base/messages/${widget.messageId}/attachments/${img.attachmentId}',
          );
          b64 = (att as Map<String, dynamic>)['data'] as String?;
        } catch (e) {
          debugPrint('인라인 이미지 로드 실패(${img.contentId}): $e');
        }
      }
      if (b64 != null && b64.isNotEmpty) {
        final std = b64.replaceAll('-', '+').replaceAll('_', '/');
        final dataUri = 'data:${img.mimeType};base64,$std';
        result = result.replaceAll('cid:${img.contentId}', dataUri);
      }
    }
    return result;
  }

  Future<void> _openFile(String filePath, String mimeType, ScaffoldMessengerState messenger) async {
    final l = AppLocalizations.of(context)!;
    try {
      await _saveChannel.invokeMethod<void>('openFile', {
        'uri': filePath,
        'mimeType': mimeType,
      });
    } catch (e) {
      messenger.showAutoDismissSnackBar(SnackBar(content: Text(l.fileOpenError(e.toString()))));
    }
  }

  Future<void> _downloadAttachment(Attachment att) async {
    if (_downloading.contains(att.attachmentId)) return;

    final existingUri = await _saveChannel.invokeMethod<String>(
      'findExistingDownload', att.filename,
    );
    if (existingUri != null && mounted) {
      final l = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.of(context);
      final redownload = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l.fileAlreadyDownloadedTitle),
          content: Text(l.fileAlreadyDownloadedMessage(att.filename)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.openFileButton),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.redownloadButton),
            ),
          ],
        ),
      );
      if (redownload == null) return;
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
        final l = AppLocalizations.of(context)!;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showAutoDismissSnackBar(
          SnackBar(
            content: Text(l.downloadCompleted(att.filename)),
            action: uri != null
                ? SnackBarAction(
                    label: l.openButton,
                    onPressed: () => _openFile(uri, att.mimeType, messenger),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAutoDismissSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.downloadError(e.toString()))),
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
    try {
      final launched = await _saveChannel.invokeMethod<bool>('launchGmail') ?? false;
      if (launched) return;
    } catch (_) {}
    await launchUrl(Uri.parse('https://mail.google.com'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.emailTitle),
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
                  Text(l.emailLoadError, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _loadFull, child: Text(l.retryButton)),
                ]))
              : Column(children: [
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
                            _header('Subject').isEmpty ? l.noSubject : _header('Subject'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(l.emailFrom, _header('From')),
                          _InfoRow(l.emailTo, _header('To')),
                          _InfoRow(l.emailDateHeader, formatEmailDate(_header('Date'), isEnglish: isEnglish)),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(l.openInGmail),
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
    final l = AppLocalizations.of(context)!;
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
            l.attachmentCount(attachments.length),
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
