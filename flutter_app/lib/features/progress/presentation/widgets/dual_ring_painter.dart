import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';

class DualRingPainter extends CustomPainter {
  final double outerPct;
  final double innerPct;
  DualRingPainter({required this.outerPct, required this.innerPct});

  void _ring(Canvas canvas, Offset center, double r, double pct, Color stroke) {
    final trackPaint = Paint()
      ..color = T.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, r, trackPaint);
    final clamped = pct.clamp(0, 100) / 100;
    if (clamped <= 0.004) return;
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * clamped;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, sweep, false, strokePaint);
    // Leading dot at the current tip of the arc, so a ring mid-animation
    // reads as an active fill in progress rather than a static wedge.
    final angle = -math.pi / 2 + sweep;
    final dot = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    canvas.drawCircle(dot, 3, Paint()..color = stroke);
    canvas.drawCircle(dot, 3, Paint()
      ..color = T.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    _ring(canvas, center, size.width / 2 - 2, outerPct, T.hero);
    _ring(canvas, center, size.width / 2 - 9, innerPct, T.blue);
  }

  @override
  bool shouldRepaint(covariant DualRingPainter old) => old.outerPct != outerPct || old.innerPct != innerPct;
}
