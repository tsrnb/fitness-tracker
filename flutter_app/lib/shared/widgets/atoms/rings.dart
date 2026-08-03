import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Progress ring that animates its sweep + the number counting up whenever
/// [value]/[goal] change, and fills in from zero on first mount.
class Ring extends StatefulWidget {
  final double value;
  final double goal;
  final double size;
  final String? label;
  final String unit;
  final Color? color;
  final bool onPaper;
  const Ring({super.key, required this.value, required this.goal, this.size = 132, this.label, this.unit = '', this.color, this.onPaper = false});

  @override
  State<Ring> createState() => _RingState();
}

class _RingState extends State<Ring> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _valueAnim;
  late Animation<double> _pctAnim;

  double get _pct => widget.goal > 0 ? (widget.value / widget.goal).clamp(0.0, 1.0) : 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _valueAnim = Tween<double>(begin: 0, end: widget.value).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _pctAnim = Tween<double>(begin: 0, end: _pct).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant Ring old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.goal != widget.goal) {
      final fromValue = _valueAnim.value;
      final fromPct = _pctAnim.value;
      _valueAnim = Tween<double>(begin: fromValue, end: widget.value).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _pctAnim = Tween<double>(begin: fromPct, end: _pct).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final track = widget.onPaper ? const Color(0x1A15151A) : T.surface2;
    final ink = widget.onPaper ? T.paperInk : T.text;
    final sub = widget.onPaper ? T.paperMuted : T.muted;
    final compact = size < 80;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pct = _pctAnim.value;
          final displayValue = _valueAnim.value.round();
          final done = widget.goal > 0 && widget.value / widget.goal >= 1;
          final stroke = done ? T.success : (widget.color ?? T.accent);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: Size(size, size), painter: _RingPainter(pct: pct, track: track, stroke: stroke)),
              Padding(
                padding: EdgeInsets.all(size * 0.16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: compact
                      ? Text('$displayValue/${widget.goal.round()}${widget.unit}', style: mono(fontSize: 15, fontWeight: FontWeight.w600, color: done ? T.success : ink))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$displayValue', style: mono(fontSize: size > 110 ? 26 : 22, fontWeight: FontWeight.w600, color: done ? T.success : ink)),
                            Text('/ ${widget.goal.round()}${widget.unit}', style: mono(fontSize: 11, color: sub)),
                            if (widget.label != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.label!, style: TextStyle(fontSize: 10, color: sub))),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color track;
  final Color stroke;
  _RingPainter({required this.pct, required this.track, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, r, trackPaint);
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * pct;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, sweep, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct || old.stroke != stroke || old.track != track;
}
