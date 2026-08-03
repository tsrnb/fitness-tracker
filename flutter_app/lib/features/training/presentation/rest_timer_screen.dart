import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/widgets/pressable_scale.dart';

/// Full-screen rest timer shown as its own route after saving a set —
/// replaces the old small bottom pill with a big countdown, +/-15s nudges,
/// and a skip action.
class RestTimerScreen extends StatefulWidget {
  final int totalSeconds;
  final String? exerciseName;
  const RestTimerScreen({super.key, required this.totalSeconds, this.exerciseName});

  static Future<void> push(BuildContext context, {required int seconds, String? exerciseName}) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, anim, secondary) => RestTimerScreen(totalSeconds: seconds, exerciseName: exerciseName),
        transitionsBuilder: (context, anim, secondary, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  State<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends State<RestTimerScreen> {
  late int total;
  late int remaining;
  Timer? _ticker;
  bool paused = false;

  @override
  void initState() {
    super.initState();
    total = widget.totalSeconds;
    remaining = widget.totalSeconds;
    _tick();
  }

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (paused) return;
      if (remaining <= 1) {
        setState(() => remaining = 0);
        t.cancel();
        _finish();
        return;
      }
      setState(() => remaining -= 1);
    });
  }

  void _finish() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _adjust(int delta) {
    setState(() {
      remaining = (remaining + delta).clamp(0, 30 * 60);
      if (remaining > total) total = remaining;
    });
    if (remaining > 0 && (_ticker == null || !_ticker!.isActive)) _tick();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (1 - remaining / total).clamp(0.0, 1.0) : 1.0;
    final mm = remaining ~/ 60;
    final ss = remaining % 60;
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Resting', margin: EdgeInsets.zero),
                      if (widget.exerciseName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(widget.exerciseName!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.text)),
                        ),
                    ],
                  ),
                  IconBubble(
                    icon: Icon(Icons.close, size: 18, color: T.muted),
                    size: 40,
                    background: T.surface2,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const Spacer(),
              LayoutBuilder(builder: (context, constraints) {
                final size = math.min(constraints.maxWidth, 320.0);
                return SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => CustomPaint(
                          size: Size(size, size),
                          painter: _BigRingPainter(pct: v, done: remaining == 0),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}',
                            style: mono(fontSize: 64, fontWeight: FontWeight.w600, color: remaining == 0 ? T.success : T.text),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(remaining == 0 ? 'Ready' : (paused ? 'Paused' : 'seconds left'), style: TextStyle(fontSize: 13, color: T.muted)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundBtn(label: '-15s', onTap: () => _adjust(-15)),
                  _playPauseBtn(),
                  _roundBtn(label: '+15s', onTap: () => _adjust(15)),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Text('Skip rest'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundBtn({required String label, required VoidCallback onTap}) {
    return PressableScale(
      onTap: onTap,
      downScale: 0.9,
      child: Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), shape: BoxShape.circle),
        child: Text(label, style: mono(fontSize: 15, fontWeight: FontWeight.w600, color: T.text)),
      ),
    );
  }

  Widget _playPauseBtn() {
    return PressableScale(
      onTap: () => setState(() {
        paused = !paused;
        if (!paused) _tick();
      }),
      downScale: 0.92,
      child: Container(
        width: 92,
        height: 92,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: T.hero, shape: BoxShape.circle),
        child: Icon(paused ? Icons.play_arrow : Icons.pause, size: 36, color: Colors.white),
      ),
    );
  }
}

class _BigRingPainter extends CustomPainter {
  final double pct;
  final bool done;
  _BigRingPainter({required this.pct, required this.done});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 14;
    const strokeWidth = 14.0;
    final trackPaint = Paint()
      ..color = T.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, r, trackPaint);
    final color = done ? T.success : T.accent;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * pct;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), startAngle, sweep, false, strokePaint);
    // Android-12-style rounded "thumb" riding the head of the arc, on top of
    // the round stroke cap — this is what reads as a deliberate circular
    // progress control rather than a plain ring.
    if (pct > 0.004 && !done) {
      final headAngle = startAngle + sweep;
      final headCenter = center + Offset(math.cos(headAngle), math.sin(headAngle)) * r;
      canvas.drawCircle(headCenter, strokeWidth / 2 + 3, Paint()..color = T.bg);
      canvas.drawCircle(headCenter, strokeWidth / 2 + 3, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      canvas.drawCircle(headCenter, strokeWidth / 2 - 2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _BigRingPainter old) => old.pct != pct || old.done != done;
}
