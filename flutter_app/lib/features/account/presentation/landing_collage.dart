import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/theme.dart';

/// The landing page's product preview for tablet and desktop: four overlapping
/// cards (weight trend, today's calories and macros, the week's workouts, a
/// just-logged meal) that rise in one after another. Sample numbers, drawn on a
/// fixed 640x540 canvas and scaled to whatever room the layout gives it.
class LandingCollage extends StatefulWidget {
  const LandingCollage({super.key});

  @override
  State<LandingCollage> createState() => _LandingCollageState();
}

class _LandingCollageState extends State<LandingCollage> with SingleTickerProviderStateMixin {
  static const _totalMs = 3200.0;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Progress (0..1) of an animation that starts [startMs] in and lasts [durMs].
  double _t(double startMs, double durMs, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value * _totalMs - startMs) / durMs).clamp(0.0, 1.0));

  TextStyle get _label => mono(fontSize: 11, color: T.muted).copyWith(letterSpacing: 1.4);

  Widget _card({
    required double left,
    required double top,
    required double width,
    required double height,
    required double delayMs,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(22),
  }) {
    final t = _t(delayMs, 900);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - t)),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: T.surface2,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 48, offset: const Offset(0, 24))],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _weightCard() {
    return _card(
      left: 0,
      top: 70,
      width: 400,
      height: 250,
      delayMs: 100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('WEIGHT · 8 WEEKS', style: _label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: T.success.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(T.pill)),
            child: Text('-4.2 kg', style: TextStyle(color: T.success, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('78.4', style: Type.display.copyWith(fontSize: 44, letterSpacing: -1, height: 1)),
          const SizedBox(width: 6),
          Text('kg', style: Type.h3.copyWith(fontSize: 16, color: T.muted)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: 356,
          height: 112,
          child: CustomPaint(painter: _TrendPainter(line: _t(600, 1800, Curves.easeInOutCubic), dot: _t(2200, 500, Curves.easeOutBack))),
        ),
      ]),
    );
  }

  Widget _macro(String label, String value, double fraction, Color color) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: mono(fontSize: 11, color: T.muted)),
        Text(value, style: mono(fontSize: 11, color: T.muted)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(T.pill),
        child: SizedBox(
          height: 6,
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: T.line)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (fraction * _t(900, 1100)).clamp(0.0, 1.0),
                child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(T.pill))),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _todayCard() {
    return _card(
      left: 372,
      top: 0,
      width: 268,
      height: 300,
      delayMs: 300,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TODAY', style: _label),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 96, height: 96, child: CustomPaint(painter: _ArcPainter(progress: 0.836 * _t(700, 1400)))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('1,840', style: Type.display.copyWith(fontSize: 26, letterSpacing: -0.5, height: 1)),
              const SizedBox(height: 2),
              Text('of 2,200 kcal', style: Type.caption),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        _macro('PROTEIN', '128 / 150 g', 0.85, T.lavAccent),
        const SizedBox(height: 12),
        _macro('CARBS', '180 / 220 g', 0.82, T.success),
        const SizedBox(height: 12),
        _macro('FAT', '52 / 70 g', 0.74, T.blue),
      ]),
    );
  }

  // 0 done, 1 missed, 2 today, 3 rest
  static const _week = [('M', 0), ('T', 0), ('W', 1), ('T', 0), ('F', 0), ('S', 2), ('S', 3)];

  Widget _day(String letter, int kind) {
    final Widget dot = switch (kind) {
      0 => Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(color: T.accent, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 15, color: Colors.white),
        ),
      1 => Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: T.line, width: 2))),
      2 => Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: T.accent, width: 2))),
      _ => Container(width: 30, height: 30, decoration: BoxDecoration(color: T.line, shape: BoxShape.circle)),
    };
    return Column(children: [dot, const SizedBox(height: 8), Text(letter, style: mono(fontSize: 10.5, color: kind == 2 ? T.text : T.muted))]);
  }

  Widget _weekCard() {
    return _card(
      left: 40,
      top: 352,
      width: 340,
      height: 150,
      delayMs: 500,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('THIS WEEK', style: _label),
          Text('5 of 6 workouts', style: Type.caption.copyWith(color: T.text, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final d in _week) _day(d.$1, d.$2)]),
      ]),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(T.pill)),
        child: Text(text, style: mono(fontSize: 11, color: color)),
      );

  Widget _loggedCard() {
    return _card(
      left: 404,
      top: 330,
      width: 236,
      height: 130,
      delayMs: 700,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('JUST LOGGED', style: _label),
        const SizedBox(height: 10),
        Text('Dal, 2 rotis, curd', style: Type.h3),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [_chip('620 kcal', T.accent), _chip('34 g protein', T.lavAccent)]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 640,
        height: 540,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Stack(clipBehavior: Clip.none, children: [_weightCard(), _todayCard(), _weekCard(), _loggedCard()]),
        ),
      ),
    );
  }
}

/// The falling weight line and its target, drawn on a 356x112 box.
class _TrendPainter extends CustomPainter {
  final double line;
  final double dot;
  const _TrendPainter({required this.line, required this.dot});

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = T.faint
      ..strokeWidth = 1.5;
    for (double x = 0; x < 356; x += 10) {
      canvas.drawLine(Offset(x, 104), Offset(math.min(x + 4, 356), 104), dash);
    }

    final path = Path()
      ..moveTo(0, 12)
      ..cubicTo(40, 16, 60, 30, 90, 34)
      ..cubicTo(120, 38, 150, 52, 190, 56)
      ..cubicTo(230, 60, 250, 72, 290, 80)
      ..cubicTo(330, 88, 340, 90, 356, 94);
    final metric = path.computeMetrics().first;
    if (line > 0) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * line),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = T.accent,
      );
    }
    if (dot > 0) {
      const end = Offset(356, 94);
      canvas.drawCircle(end, 6 * dot, Paint()..color = T.accent);
      canvas.drawCircle(
        end,
        12 * dot,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = T.accent.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.line != line || old.dot != dot;
}

/// The calorie ring on the Today card (96x96).
class _ArcPainter extends CustomPainter {
  final double progress;
  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = T.line;
    canvas.drawCircle(c, 38, paint);
    if (progress > 0.005) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: 38), -math.pi / 2, 2 * math.pi * progress, false, paint..color = T.accent);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.progress != progress;
}
