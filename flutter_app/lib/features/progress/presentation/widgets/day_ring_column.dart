import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import 'dual_ring_painter.dart';

class DayRingColumn extends StatefulWidget {
  final int index;
  final String label;
  final double kcalPct;
  final double proteinPct;
  final bool bothHit;
  final bool empty;
  final bool active;
  final VoidCallback onTap;
  const DayRingColumn({
    super.key,
    required this.index,
    required this.label,
    required this.kcalPct,
    required this.proteinPct,
    required this.bothHit,
    required this.empty,
    required this.active,
    required this.onTap,
  });

  @override
  State<DayRingColumn> createState() => _DayRingColumnState();
}

class _DayRingColumnState extends State<DayRingColumn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _outer;
  late Animation<double> _inner;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _outer = Tween<double>(begin: 0, end: widget.empty ? 0 : widget.kcalPct.clamp(0, 100)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _inner = Tween<double>(begin: 0, end: widget.empty ? 0 : widget.proteinPct.clamp(0, 100)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _checkScale = CurvedAnimation(parent: _c, curve: const Interval(0.78, 1.0, curve: Curves.elasticOut));
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    Future.delayed(reduceMotion ? Duration.zero : Duration(milliseconds: 90 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didUpdateWidget(covariant DayRingColumn old) {
    super.didUpdateWidget(old);
    if (old.kcalPct != widget.kcalPct || old.proteinPct != widget.proteinPct || old.empty != widget.empty) {
      _outer = Tween<double>(begin: _outer.value, end: widget.empty ? 0 : widget.kcalPct.clamp(0, 100)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
      _inner = Tween<double>(begin: _inner.value, end: widget.empty ? 0 : widget.proteinPct.clamp(0, 100)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: widget.active ? T.surface : Colors.transparent,
          border: Border.all(color: widget.active ? T.accentSoft : Colors.transparent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.active ? T.text : T.muted)),
            const SizedBox(height: 6),
            SizedBox(
              width: 44,
              height: 44,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Stack(alignment: Alignment.center, children: [
                  CustomPaint(size: const Size(44, 44), painter: DualRingPainter(outerPct: _outer.value, innerPct: _inner.value)),
                  if (widget.bothHit)
                    Transform.scale(scale: _checkScale.value, child: const Icon(Icons.check_circle, size: 15, color: T.success)),
                  if (widget.empty) Text('—', style: TextStyle(fontSize: 12, color: T.faint)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
