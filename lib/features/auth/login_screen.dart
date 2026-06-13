import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider.notifier).signIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 실패. 다시 시도해주세요.')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 적응형 아이콘과 동일한 색상 체계
    final iconBg = isDark ? const Color(0xFF1A2C42) : const Color(0xFFF1F3F6);
    final iconColor = isDark ? Colors.white : const Color(0xFF1A73E8);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.dashboard, color: iconColor, size: 44),
                ),
                const SizedBox(height: 24),
                Text(
                  'MyBoard',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tasks · Calendar · Gmail',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 56),
                _loading
                    ? CircularProgressIndicator(color: scheme.primary)
                    : _GoogleSignInButton(onTap: _signIn),
                const SizedBox(height: 16),
                Text(
                  '로그인하면 Google 계정의 Tasks,\nCalendar, Gmail에 접근합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _GoogleSignInButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0xFF131314) : Colors.white;
    final btnBorder = isDark ? const Color(0xFF8E918F) : const Color(0xFFDADCE0);
    final txtColor = isDark ? Colors.white : const Color(0xFF3C4043);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: btnBg,
            side: BorderSide(color: btnBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 1,
            shadowColor: Colors.black12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                    TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
                    TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
                    TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
                    TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
                    TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '계정으로 로그인',
                style: TextStyle(
                  color: txtColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
