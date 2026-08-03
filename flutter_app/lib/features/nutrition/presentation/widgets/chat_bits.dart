import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import 'ai_gradient.dart';

class AssistantOrb extends StatefulWidget {
  final double size;
  final bool pulse;
  const AssistantOrb({super.key, required this.size, this.pulse = false});

  @override
  State<AssistantOrb> createState() => _AssistantOrbState();
}

class _AssistantOrbState extends State<AssistantOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: widget.pulse);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(scale: widget.pulse ? 1 + _c.value * 0.08 : 1, child: child),
      child: AiGradient(
        builder: (context, gradient) => Container(
          width: widget.size,
          height: widget.size,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
          alignment: Alignment.center,
          child: Icon(Icons.auto_awesome, size: widget.size * 0.46, color: Colors.white),
        ),
      ),
    );
  }
}

class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AssistantOrb(size: 24),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
        )),
        child: const _TypingDots(),
      ),
    ]);
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
          final t = ((_c.value - i * 0.15) % 1.0 + 1.0) % 1.0;
          final bump = t < 0.3 ? math.sin(t / 0.3 * math.pi) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.translate(
              offset: Offset(0, -bump * 3),
              child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: T.muted.withValues(alpha: 0.4 + bump * 0.6))),
            ),
          );
        }));
      },
    );
  }
}

class GradientBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  const GradientBorder({super.key, required this.child, required this.radius});

  @override
  Widget build(BuildContext context) {
    return AiGradient(
      builder: (context, gradient) => Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), gradient: gradient),
        child: child,
      ),
    );
  }
}

class MiniRingPainter extends CustomPainter {
  final double pct;
  final Color color;
  MiniRingPainter(this.pct, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 1.75;
    final track = Paint()
      ..color = const Color(0xFF26252E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, r, track);
    if (pct <= 0) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * pct, false, stroke);
  }

  @override
  bool shouldRepaint(covariant MiniRingPainter old) => old.pct != pct || old.color != color;
}
