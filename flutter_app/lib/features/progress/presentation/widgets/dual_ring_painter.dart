import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';

class DualRingPainter extends CustomPainter {
  final double outerPct;
  final double innerPct;
  // Absolute stroke width in px. Left at the original 4 for the small strip
  // rings; the long-press peek ring passes a thicker value so the two rings
  // stay proportionate (and legible) at a much larger canvas size instead of
  // reading as two hairlines hugging the edge with a hollow middle.
  final double strokeWidth;
  DualRingPainter({required this.outerPct, required this.innerPct, this.strokeWidth = 4});

  void _ring(Canvas canvas, Offset center, double r, double pct, Color stroke) {
    final trackPaint = Paint()
      ..color = T.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, r, trackPaint);
    final clamped = pct.clamp(0, 100) / 100;
    if (clamped <= 0.004) return;
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * clamped;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, sweep, false, strokePaint);
    // Leading dot at the current tip of the arc, so a ring mid-animation
    // reads as an active fill in progress rather than a static wedge.
    final angle = -math.pi / 2 + sweep;
    final dotR = strokeWidth * 0.75;
    final dot = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    canvas.drawCircle(dot, dotR, Paint()..color = stroke);
    canvas.drawCircle(dot, dotR, Paint()
      ..color = T.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerR = size.width / 2 - strokeWidth / 2;
    final innerR = outerR - strokeWidth * 1.75;
    _ring(canvas, center, outerR, outerPct, T.hero);
    _ring(canvas, center, innerR, innerPct, T.blue);
  }

  @override
  bool shouldRepaint(covariant DualRingPainter old) =>
      old.outerPct != outerPct || old.innerPct != innerPct || old.strokeWidth != strokeWidth;
}
