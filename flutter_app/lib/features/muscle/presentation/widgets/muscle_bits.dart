import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../domain/muscle_models.dart';

/// Small tinted label ("On pace", "Mostly lean", "PR").
class MuscleChip extends StatelessWidget {
  final String text;
  final Color color;
  const MuscleChip(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(T.pill)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

Color toneColor(String tone) => switch (tone) {
      'ok' => T.success,
      'bad' => T.danger,
      'warn' => T.lavAccent,
      _ => T.muted,
    };

(String, Color) paceChip(PaceState? s) => switch (s) {
      PaceState.onPace => ('On pace', T.success),
      PaceState.tooSlow => ('Too slow', T.lavAccent),
      PaceState.fast => ('Gaining fast', T.danger),
      null => ('Not enough weigh-ins', T.muted),
    };

String signed(num v, {int digits = 1}) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(digits)}';

/// Thin progress bar used for the fuel check and the Know-why chips.
class MuscleBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  const MuscleBar(this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: T.surface2, valueColor: AlwaysStoppedAnimation(color)),
        ),
      );
}

/// A tiny line with an emphasized end point.
class Sparkline extends StatelessWidget {
  final List<num> values;
  final Color color;
  final double width;
  final double height;
  const Sparkline(this.values, {super.key, required this.color, this.width = 70, this.height = 26});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(width, height), painter: _SparkPainter(values.map((v) => v.toDouble()).toList(), color));
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  _SparkPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final mn = v.reduce((a, b) => a < b ? a : b), mx = v.reduce((a, b) => a > b ? a : b);
    final range = (mx - mn) == 0 ? 1.0 : mx - mn;
    Offset pt(int i) => Offset(2 + i / (v.length - 1) * (size.width - 4), size.height - 3 - (v[i] - mn) / range * (size.height - 8));
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(pt(v.length - 1), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.v != v || old.color != color;
}
