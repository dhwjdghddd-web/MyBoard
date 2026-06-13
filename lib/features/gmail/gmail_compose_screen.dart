import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gmail_service.dart';

class GmailComposeScreen extends ConsumerStatefulWidget {
  final String initialTo;
  const GmailComposeScreen({super.key, this.initialTo = ''});

  @override
  ConsumerState<GmailComposeScreen> createState() => _GmailComposeScreenState();
}

class _GmailComposeScreenState extends ConsumerState<GmailComposeScreen> {
  final _toCtrl      = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _toCtrl.text = widget.initialTo;
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to      = _toCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final body    = _bodyCtrl.text;

    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('받는 사람 주소를 입력해주세요')));
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(gmailProvider.notifier).sendEmail(
        to: to, subject: subject, body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메일을 보냈습니다 ✓')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e')));
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _sending ? null : () => Navigator.pop(context),
        ),
        title: const Text('새 메일', style: TextStyle(fontSize: 16)),
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            )
          else
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF4285F4)),
              tooltip: '보내기',
              onPressed: _send,
            ),
        ],
      ),
      body: Column(
        children: [
          _FieldRow(
            label: '받는 사람',
            controller: _toCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: widget.initialTo.isEmpty,
            enabled: !_sending,
          ),
          const Divider(height: 1),
          _FieldRow(
            label: '제목',
            controller: _subjectCtrl,
            autofocus: widget.initialTo.isNotEmpty,
            enabled: !_sending,
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _bodyCtrl,
                enabled: !_sending,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool enabled;

  const _FieldRow({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              autofocus: autofocus,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
