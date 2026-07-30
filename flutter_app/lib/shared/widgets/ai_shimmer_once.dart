import 'package:flutter/material.dart';
import '../../features/nutrition/ai_gradient.dart';

/// Plays the AI-brand gradient shimmer over [child] once whenever this
/// subtree becomes visible — a wash fade-in/hold/fade-out plus a light band
/// sweeping across — then vanishes completely, leaving [child] exactly as
/// it was. A ~1.8s "heads up, this leads somewhere AI-powered" tease on the
/// Log food buttons, not a permanent restyle. Clips to [borderRadius] so it
/// matches whatever shape [child] renders (both existing Log food buttons
/// are `T.pill` pills).
///
/// Bottom-nav tabs in this app stay mounted forever (see
/// `AnimatedIndexedStack`) and are only shown/hidden via `TickerMode`, so a
/// plain `initState().forward()` would only ever play once, on whichever
/// tab happens to be active at app launch. Watching `TickerMode.of(context)`
/// instead replays the shimmer every time this tab is switched back to.
class AiShimmerOnce extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  const AiShimmerOnce({super.key, required this.child, required this.borderRadius});

  @override
  State<AiShimmerOnce> createState() => _AiShimmerOnceState();
}

class _AiShimmerOnceState extends State<AiShimmerOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _done = false;
  bool? _wasVisible;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) setState(() => _done = true);
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && _wasVisible != true) {
      _done = false;
      _c
        ..reset()
        ..forward();
    }
    _wasVisible = visible;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
              return AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  final washOpacity = (t < 0.18 ? t / 0.18 : (t > 0.75 ? (1 - t) / 0.25 : 1.0)).clamp(0.0, 1.0) * 0.6;
                  const sweepStart = 0.083;
                  const sweepEnd = 0.45;
                  final sweepT = ((t - sweepStart) / (sweepEnd - sweepStart)).clamp(0.0, 1.0);
                  final showSweep = t >= sweepStart && t <= sweepEnd;
                  final bandWidth = w * 0.6;
                  final left = -bandWidth + sweepT * (w + bandWidth);
                  return Stack(fit: StackFit.expand, children: [
                    Opacity(
                      opacity: washOpacity,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [aiColor1, aiColor2, aiColor3, aiColor4],
                          ),
                        ),
                      ),
                    ),
                    if (showSweep)
                      Positioned(
                        left: left,
                        top: 0,
                        bottom: 0,
                        width: bandWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0),
                              ],
                              stops: const [0.2, 0.5, 0.8],
                            ),
                          ),
                        ),
                      ),
                  ]);
                },
              );
            }),
          ),
        ),
      ),
    ]);
  }
}
