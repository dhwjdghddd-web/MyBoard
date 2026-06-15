import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_service.dart';
import '../../core/snackbar_helper.dart';
import '../../l10n/app_localizations.dart';

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
        ScaffoldMessenger.of(context).showAutoDismissSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.loginError)),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/ic_launcher_foreground.png',
                    width: 80,
                    height: 80,
                  ),
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
                    : _GoogleSignInButton(label: l.loginButton, onTap: _signIn),
                const SizedBox(height: 16),
                Text(
                  l.loginDescription,
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
  final String label;
  final VoidCallback? onTap;
  const _GoogleSignInButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg     = isDark ? const Color(0xFF131314) : Colors.white;
    final btnBorder = isDark ? const Color(0xFF8E918F) : const Color(0xFFDADCE0);
    final txtColor  = isDark ? Colors.white : const Color(0xFF3C4043);

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
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            elevation: 1,
            shadowColor: Colors.black12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _GoogleGIcon(),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: txtColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Google G 아이콘 — CustomPaint로 공식 색상 재현
class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.32;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, _deg(127), _deg(283), false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, _deg(50), _deg(77), false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, _deg(195), _deg(57), false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, _deg(90), _deg(37), false, paint);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    final barTop    = cy - r * 0.16;
    final barBottom = cy + r * 0.16;
    final barLeft   = cx;
    final barRight  = cx + r;
    canvas.drawRect(Rect.fromLTRB(barLeft, barTop, barRight, barBottom), paint);
  }

  static double _deg(double d) => d * 3.14159265 / 180;

  @override
  bool shouldRepaint(_GoogleGPainter old) => false;
}
