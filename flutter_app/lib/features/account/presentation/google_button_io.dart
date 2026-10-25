import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../shared/lib/cloud/api_client.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/pressable_scale.dart';

class GoogleSignInButton extends StatefulWidget {
  final void Function(String idToken) onToken;
  final void Function(String message) onError;
  const GoogleSignInButton({super.key, required this.onToken, required this.onError});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final gs = GoogleSignIn(scopes: const ['email'], serverClientId: CloudConfig.googleWebClientId);
      await gs.signOut(); // always show the account chooser
      final acct = await gs.signIn();
      if (acct == null) return; // cancelled
      final token = (await acct.authentication).idToken;
      if (token == null) {
        widget.onError("Google didn't return a sign-in token. Try again.");
      } else {
        widget.onToken(token);
      }
    } catch (_) {
      widget.onError("Couldn't reach Google. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: _tap,
      downScale: 0.97,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: T.paper, borderRadius: BorderRadius.all(Radius.circular(T.pill))),
        child: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: T.paperInk))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GPainter())),
                const SizedBox(width: 12),
                const Text('Continue with Google', style: TextStyle(color: T.paperInk, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
      ),
    );
  }
}

/// The four-colour Google "G", drawn from arcs so no asset is needed.
class _GPainter extends CustomPainter {
  const _GPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rect = Rect.fromCircle(center: Offset(w / 2, w / 2), radius: w * 0.38);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.21;
    void arc(Color c, double startDeg, double sweepDeg) {
      canvas.drawArc(rect, startDeg * math.pi / 180, sweepDeg * math.pi / 180, false, stroke..color = c);
    }

    arc(const Color(0xFFEA4335), 200, 70); // top-left to top
    arc(const Color(0xFFFBBC05), 135, 65); // left
    arc(const Color(0xFF34A853), 45, 90); // bottom
    arc(const Color(0xFF4285F4), -45, 75); // right
    canvas.drawRect(
      Rect.fromLTWH(w * 0.5, w * 0.41, w * 0.45, w * 0.18),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
