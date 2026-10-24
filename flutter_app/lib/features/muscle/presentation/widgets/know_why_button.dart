import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/pressable_scale.dart';

/// The entry point to the Know-why assistant: a pill with a twinkling
/// sparkle, a breathing glow and a light sweep every few seconds so it reads
/// as the AI action on screen. Honors reduced motion by drawing it static.
class KnowWhyButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const KnowWhyButton({super.key, required this.onTap, this.compact = false});

  @override
  State<KnowWhyButton> createState() => _KnowWhyButtonState();
}

class _KnowWhyButtonState extends State<KnowWhyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduced) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.compact ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : const EdgeInsets.symmetric(horizontal: 13, vertical: 8);
    return PressableScale(
      onTap: widget.onTap,
      downScale: 0.94,
      child: Semantics(
        button: true,
        label: 'Know why',
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _reduced ? 0.0 : _c.value;
            final pulse = 0.5 - 0.5 * math.cos(t * 2 * math.pi); // 0..1..0 over one cycle
            final sweep = ((t - 0.15) / 0.55).clamp(0.0, 1.0); // sweep runs in the first ~70%
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(T.pill),
                boxShadow: [BoxShadow(color: T.accent.withValues(alpha: 0.10 + 0.25 * pulse), blurRadius: 6 + 10 * pulse)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(T.pill),
                child: Stack(
                  children: [
                    Container(
                      padding: pad,
                      decoration: BoxDecoration(color: T.accentDim, border: Border.all(color: T.accentSoft), borderRadius: BorderRadius.circular(T.pill)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Transform.rotate(
                          angle: pulse * math.pi / 2,
                          child: Transform.scale(scale: 1 + 0.25 * pulse, child: const Icon(Icons.auto_awesome, size: 14, color: T.accent)),
                        ),
                        const SizedBox(width: 6),
                        const Text('Know why', style: TextStyle(color: T.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ]),
                    ),
                    if (!_reduced)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: FractionallySizedBox(
                            alignment: Alignment(-1.6 + 3.8 * sweep, 0),
                            widthFactor: 0.4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [Colors.transparent, T.accent.withValues(alpha: 0.4), Colors.transparent]),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
