import 'package:flutter/material.dart';
import '../../shared/theme.dart';

/// Full-screen, one-shot confirmation shown right after the day-boundary
/// setting is saved. This isn't decoration — changing "what day is it" is a
/// change with real reach (every screen that groups logs by day depends on
/// it), and a toast undersells that. A ripple expanding out from a clock and
/// lighting up each affected area is the same idea made visible: one change,
/// several places it now applies.
class DayStartAppliedScreen extends StatefulWidget {
  final String timeLabel;
  final bool isMidnight;
  const DayStartAppliedScreen({super.key, required this.timeLabel, required this.isMidnight});

  @override
  State<DayStartAppliedScreen> createState() => _DayStartAppliedScreenState();
}

class _AffectedRow {
  final IconData icon;
  final Color color;
  final String label;
  final String detail;
  const _AffectedRow(this.icon, this.color, this.label, this.detail);
}

class _DayStartAppliedScreenState extends State<DayStartAppliedScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final bool _reduceMotion;
  bool _dismissing = false;

  static const _rows = [
    _AffectedRow(Icons.restaurant, T.success, 'Diet', 'Meals & macros regroup under the new day'),
    _AffectedRow(Icons.fitness_center, T.lav, 'Training plan', 'Workout days realign to the new schedule'),
    _AffectedRow(Icons.insights, T.blue, 'Progress', 'Deficit & streaks recompute from here'),
    _AffectedRow(Icons.dashboard_rounded, T.hero, 'Dashboard', "Today's totals reflect the new boundary"),
  ];

  @override
  void initState() {
    super.initState();
    _reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    // Reveal runs most of the 5s window itself (not a quick reveal + long
    // static hold) so the whole thing reads as one deliberate sequence.
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: _reduceMotion ? 700 : 3400));
    _c.forward();
    Future.delayed(Duration(milliseconds: _reduceMotion ? 1300 : 5000), _dismiss);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    Navigator.of(context).maybePop();
  }

  Animation<double> _window(double start, double end, {Curve curve = Curves.easeOutCubic}) {
    return CurvedAnimation(parent: _c, curve: Interval(start.clamp(0, 1), end.clamp(0, 1), curve: curve));
  }

  Widget _ring(double startFraction) {
    final a = _window(startFraction, (startFraction + 0.55).clamp(0.0, 1.0), curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) {
        final t = a.value;
        if (t <= 0 || t >= 1) return const SizedBox.shrink();
        return Opacity(
          opacity: (1 - t) * 0.55,
          child: Transform.scale(
            scale: 1 + t * 3.2,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: T.hero, width: 2)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconAnim = _window(0, 0.22, curve: Curves.elasticOut);
    final timeAnim = _window(0.08, 0.34, curve: Curves.easeOutBack);
    final titleAnim = _window(0.16, 0.4);
    final captionAnim = _window(0.82, 1.0);
    final hintAnim = _window(0.88, 1.0);

    return GestureDetector(
      onTap: _dismiss,
      child: Scaffold(
        backgroundColor: T.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                SizedBox(
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!_reduceMotion) _ring(0.0),
                      if (!_reduceMotion) _ring(0.12),
                      if (!_reduceMotion) _ring(0.24),
                      AnimatedBuilder(
                        animation: iconAnim,
                        builder: (context, child) => Transform.scale(scale: iconAnim.value, child: child),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [T.hero, Color(0xFFFF7A52)])),
                          alignment: Alignment.center,
                          child: const Icon(Icons.schedule, color: Colors.white, size: 34),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: timeAnim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(timeAnim),
                    child: Text(widget.timeLabel, style: mono(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: titleAnim,
                  child: Column(children: [
                    Text('Day start updated', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.text)),
                    const SizedBox(height: 6),
                    Text(
                      widget.isMidnight ? 'Back to a standard midnight-to-midnight day.' : 'Late logs before this time now count toward yesterday.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: T.muted, height: 1.4),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
                Column(
                  children: List.generate(_rows.length, (i) {
                    final start = 0.38 + i * 0.1;
                    final rowAnim = _window(start, start + 0.28, curve: Curves.easeOutCubic);
                    final checkAnim = _window(start + 0.14, start + 0.34, curve: Curves.elasticOut);
                    final row = _rows[i];
                    return AnimatedBuilder(
                      animation: rowAnim,
                      builder: (context, child) => Opacity(
                        opacity: rowAnim.value,
                        child: Transform.translate(offset: Offset(0, (1 - rowAnim.value) * 14), child: child),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: row.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: Icon(row.icon, size: 16, color: row.color),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(row.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: T.text)),
                                  Text(row.detail, style: TextStyle(fontSize: 11, color: T.muted)),
                                ],
                              ),
                            ),
                            AnimatedBuilder(
                              animation: checkAnim,
                              builder: (context, _) => Transform.scale(
                                scale: checkAnim.value,
                                child: Icon(Icons.check_circle, size: 18, color: T.success),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
                const Spacer(flex: 2),
                FadeTransition(
                  opacity: captionAnim,
                  child: Text(
                    'One change, everywhere it matters.',
                    style: TextStyle(fontSize: 12.5, color: T.faint, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: hintAnim,
                  child: Text('tap to continue', style: mono(fontSize: 10.5, color: T.faint)),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
