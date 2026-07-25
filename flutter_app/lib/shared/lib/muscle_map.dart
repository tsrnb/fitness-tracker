import 'package:flutter/material.dart';
import '../theme.dart';

abstract class _Shape {
  final String? region;
  const _Shape(this.region);
}

class _Circle extends _Shape {
  final double cx, cy, r;
  const _Circle(this.cx, this.cy, this.r, {String? region}) : super(region);
}

class _Rect extends _Shape {
  final double x, y, w, h, rx;
  const _Rect(this.x, this.y, this.w, this.h, this.rx, {String? region}) : super(region);
}

class _Poly extends _Shape {
  final List<Offset> pts;
  const _Poly(this.pts, {String? region}) : super(region);
}

List<Offset> _pts(String s) {
  return s.trim().split(RegExp(r'\s+')).map((pair) {
    final parts = pair.split(',');
    return Offset(double.parse(parts[0]), double.parse(parts[1]));
  }).toList();
}

final List<_Shape> _front = [
  const _Circle(100, 30, 15),
  const _Rect(93, 43, 14, 10, 4),
  const _Rect(72, 60, 56, 86, 14),
  const _Rect(72, 144, 56, 22, 8),
  _Poly(_pts('84,55 116,55 124,72 76,72'), region: 'traps'),
  const _Circle(62, 70, 12, region: 'frontDelts'),
  const _Circle(138, 70, 12, region: 'frontDelts'),
  const _Circle(52, 74, 9, region: 'sideDelts'),
  const _Circle(148, 74, 9, region: 'sideDelts'),
  const _Rect(74, 64, 23, 28, 10, region: 'chest'),
  const _Rect(103, 64, 23, 28, 10, region: 'chest'),
  const _Rect(86, 96, 28, 46, 6, region: 'abs'),
  const _Rect(48, 78, 15, 32, 7, region: 'biceps'),
  const _Rect(137, 78, 15, 32, 7, region: 'biceps'),
  const _Rect(45, 112, 14, 40, 7, region: 'forearms'),
  const _Rect(141, 112, 14, 40, 7, region: 'forearms'),
  const _Rect(75, 166, 23, 66, 11, region: 'quads'),
  const _Rect(102, 166, 23, 66, 11, region: 'quads'),
  const _Rect(78, 234, 18, 60, 8, region: 'calves'),
  const _Rect(104, 234, 18, 60, 8, region: 'calves'),
];

final List<_Shape> _back = [
  const _Circle(100, 30, 15),
  const _Rect(93, 43, 14, 10, 4),
  const _Rect(72, 60, 56, 86, 14),
  const _Rect(72, 144, 56, 22, 8),
  _Poly(_pts('86,56 114,56 126,84 74,84'), region: 'traps'),
  const _Circle(62, 70, 12, region: 'rearDelts'),
  const _Circle(138, 70, 12, region: 'rearDelts'),
  const _Circle(52, 74, 9, region: 'sideDelts'),
  const _Circle(148, 74, 9, region: 'sideDelts'),
  const _Rect(84, 84, 32, 22, 6, region: 'upperBack'),
  _Poly(_pts('74,90 99,90 93,140 78,132'), region: 'lats'),
  _Poly(_pts('126,90 101,90 107,140 122,132'), region: 'lats'),
  const _Rect(90, 126, 20, 20, 6, region: 'lowerBack'),
  const _Rect(48, 78, 15, 32, 7, region: 'triceps'),
  const _Rect(137, 78, 15, 32, 7, region: 'triceps'),
  const _Rect(45, 112, 14, 40, 7, region: 'forearms'),
  const _Rect(141, 112, 14, 40, 7, region: 'forearms'),
  const _Rect(76, 146, 23, 32, 11, region: 'glutes'),
  const _Rect(101, 146, 23, 32, 11, region: 'glutes'),
  const _Rect(75, 178, 23, 56, 11, region: 'hamstrings'),
  const _Rect(102, 178, 23, 56, 11, region: 'hamstrings'),
  const _Rect(78, 236, 18, 58, 8, region: 'calves'),
  const _Rect(104, 236, 18, 58, 8, region: 'calves'),
];

class MuscleMap extends StatelessWidget {
  final String view; // front | back
  final List<String> primary;
  final List<String> secondary;
  final double size;

  const MuscleMap({
    super.key,
    this.view = 'front',
    this.primary = const [],
    this.secondary = const [],
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.45),
      painter: _MuscleMapPainter(view: view, primary: primary, secondary: secondary),
    );
  }
}

class _MuscleMapPainter extends CustomPainter {
  final String view;
  final List<String> primary;
  final List<String> secondary;
  _MuscleMapPainter({required this.view, required this.primary, required this.secondary});

  Color _colorFor(String? region) {
    if (region == null) return T.muscleBase;
    if (primary.contains(region)) return T.accent;
    if (secondary.contains(region)) return T.accentSoft;
    return T.muscleBase;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 200;
    final scaleY = size.height / 305;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    final shapes = view == 'back' ? _back : _front;
    final strokePaint = Paint()
      ..color = T.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (final s in shapes) {
      final fill = Paint()..color = _colorFor(s.region);
      if (s is _Circle) {
        canvas.drawCircle(Offset(s.cx, s.cy), s.r, fill);
        canvas.drawCircle(Offset(s.cx, s.cy), s.r, strokePaint);
      } else if (s is _Rect) {
        final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(s.x, s.y, s.w, s.h), Radius.circular(s.rx));
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, strokePaint);
      } else if (s is _Poly) {
        final path = Path()..addPolygon(s.pts, true);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, strokePaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MuscleMapPainter old) =>
      old.view != view || old.primary != primary || old.secondary != secondary;
}
