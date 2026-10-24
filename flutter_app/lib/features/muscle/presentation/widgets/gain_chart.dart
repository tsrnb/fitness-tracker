import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/lib/helpers.dart';
import '../../domain/muscle_models.dart';

/// Weigh-ins since the goal started (never the history before it), drawn
/// against the green corridor the person's experience level says is a
/// healthy lean-gain pace. The corridor fans out from the baseline weight on
/// [startDate], so a goal older than the window is simply clipped by it.
class GainChart extends StatelessWidget {
  final List<Map<String, dynamic>> weight;
  final String today;
  final int weeks;
  final MuscleLevel level;
  final String startDate;
  final double baseline;
  const GainChart({
    super.key,
    required this.weight,
    required this.today,
    required this.weeks,
    required this.level,
    required this.startDate,
    required this.baseline,
  });

  @override
  Widget build(BuildContext context) {
    final sinceStart = startDate.isEmpty ? 1 << 30 : daysBetween(startDate, today);
    // Window: the last [weeks] weeks, but never reaching before the goal began.
    final span = (sinceStart < weeks * 7 ? (sinceStart < 7 ? 7 : sinceStart) : weeks * 7);
    final startX = (span - sinceStart).toDouble(); // goal start on the x axis (<= 0 when clipped)
    final pts = <(double, double)>[]; // (day offset from window start, kg)
    for (final w in weight) {
      final d = w['date'] as String;
      final age = daysBetween(d, today);
      if (age < 0 || age > span) continue;
      if (startDate.isNotEmpty && d.compareTo(startDate) < 0) continue;
      pts.add(((span - age).toDouble(), (w['weight'] as num).toDouble()));
    }
    if (pts.isEmpty || (pts.length < 2 && startX < 0)) {
      return SizedBox(
        height: 150,
        child: Center(child: Text('Log two or more weigh-ins since your goal started to see your trend.', textAlign: TextAlign.center, style: TextStyle(color: T.muted, fontSize: 13))),
      );
    }
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: CustomPaint(
        painter: _GainPainter(
          pts: pts,
          span: span.toDouble(),
          startX: startX,
          baseline: baseline,
          lo: level.lo,
          hi: level.hi,
          line: T.accent,
          band: T.success,
          grid: T.line,
          label: T.faint,
        ),
      ),
    );
  }
}

class _GainPainter extends CustomPainter {
  final List<(double, double)> pts;
  final double span, startX, baseline, lo, hi;
  final Color line, band, grid, label;
  _GainPainter({
    required this.pts,
    required this.span,
    required this.startX,
    required this.baseline,
    required this.lo,
    required this.hi,
    required this.line,
    required this.band,
    required this.grid,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, bottom = 6.0, top = 6.0, right = 8.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    // Corridor edge at window x, growing from the goal-start baseline.
    double bandAt(double x, double perWeek) => baseline + perWeek * (x - startX) / 7;
    final bx0 = startX < 0 ? 0.0 : startX;

    var mn = baseline, mx = baseline;
    for (final p in pts) {
      if (p.$2 < mn) mn = p.$2;
      if (p.$2 > mx) mx = p.$2;
    }
    for (final v in [bandAt(bx0, lo), bandAt(span, lo), bandAt(bx0, hi), bandAt(span, hi)]) {
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }
    mn -= 0.4;
    mx += 0.4;
    double px(double x) => left + x / span * w;
    double py(double v) => top + h - (v - mn) / (mx - mn) * h;

    // Gridlines at whole kilos.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final step = (mx - mn) > 6 ? 2 : 1;
    for (var v = (mn / step).ceil() * step; v <= mx; v += step) {
      final y = py(v.toDouble());
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), Paint()..color = grid..strokeWidth = 1);
      tp.text = TextSpan(text: '$v', style: TextStyle(color: label, fontSize: 10));
      tp.layout();
      tp.paint(canvas, Offset(left - tp.width - 5, y - tp.height / 2));
    }

    // Corridor: a fan that deepens in colour the further it runs from the
    // goal start, with crisp edges so it reads on any theme.
    final topA = Offset(px(bx0), py(bandAt(bx0, hi))), botA = Offset(px(bx0), py(bandAt(bx0, lo)));
    final topB = Offset(px(span), py(bandAt(span, hi))), botB = Offset(px(span), py(bandAt(span, lo)));
    final bandPath = Path()
      ..moveTo(topA.dx, topA.dy)
      ..lineTo(topB.dx, topB.dy)
      ..lineTo(botB.dx, botB.dy)
      ..lineTo(botA.dx, botA.dy)
      ..close();
    canvas.drawPath(
      bandPath,
      Paint()
        ..shader = LinearGradient(colors: [band.withValues(alpha: 0.10), band.withValues(alpha: 0.42)]).createShader(Rect.fromLTRB(px(bx0), top, px(span), top + h)),
    );
    final edge = Paint()..color = band.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    canvas.drawLine(topA, topB, edge);
    canvas.drawLine(botA, botB, edge);

    // Goal-start marker.
    if (startX >= 0) {
      final x = px(startX);
      final dash = Paint()..color = label..strokeWidth = 1;
      for (var y = top; y < top + h; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 3), dash);
      }
      canvas.drawCircle(Offset(x, py(baseline)), 3.5, Paint()..color = label);
    }

    // Weigh-ins, joined to the baseline when the goal start is in view.
    final line0 = startX >= 0 && pts.first.$1 > startX ? (startX, baseline) : pts.first;
    final path = Path()..moveTo(px(line0.$1), py(line0.$2));
    for (final p in (identical(line0, pts.first) ? pts.skip(1) : pts)) {
      path.lineTo(px(p.$1), py(p.$2));
    }
    canvas.drawPath(path, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(Offset(px(pts.last.$1), py(pts.last.$2)), 5, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_GainPainter old) =>
      old.pts != pts || old.span != span || old.startX != startX || old.baseline != baseline || old.lo != lo || old.hi != hi || old.line != line || old.grid != grid;
}
