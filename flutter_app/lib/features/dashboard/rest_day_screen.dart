import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';

/// Full-screen "rest day" moment, shown when the orange hero card is tapped
/// on a day with nothing programmed to train — a calm, motivating beat
/// instead of a dead-end tap. Mirrors the RestTimerScreen full-screen route
/// pattern (opaque, slides up from the bottom, dismissible via close/back).
class RestDayScreen extends StatefulWidget {
  const RestDayScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, anim, secondary) => const RestDayScreen(),
        transitionsBuilder: (context, anim, secondary, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  State<RestDayScreen> createState() => _RestDayScreenState();
}

class _RestDayScreenState extends State<RestDayScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.2,
            // A single hue fading straight to the background. Mixing in
            // T.lav (a cool, desaturated lavender) as a middle stop read as
            // a flat gray haze once blended over the near-black dark
            // background instead of a deliberate glow.
            colors: [T.hero.withValues(alpha: 0.15), T.bg],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              children: [
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.end,
                //   children: [
                //     IconBubble(
                //       icon: Icon(Icons.close, size: 18, color: T.muted),
                //       size: 40,
                //       background: T.surface2,
                //       onTap: () => Navigator.of(context).maybePop(),
                //     ),
                //   ],
                // ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _breath,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(_breath.value);
                    final scale = 0.88 + t * 0.16;
                    final opacity = 0.35 + t * 0.35;
                    return SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  T.hero.withValues(alpha: opacity * 0.5),
                                  T.hero.withValues(alpha: 0.0),
                                ],
                              ),
                              border: Border.all(color: T.hero.withValues(alpha: opacity * 0.6), width: 1.5),
                            ),
                            child: Center(
                              child: Icon(Icons.self_improvement, size: 56, color: T.hero.withValues(alpha: 0.7 + t * 0.3)),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text('Rest is part of the plan', textAlign: TextAlign.center, style: Type.h1),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'No training today — let your muscles recover so tomorrow\'s work counts. A walk, some stretching, and good sleep go a long way.',
                    textAlign: TextAlign.center,
                    style: Type.body.copyWith(color: T.muted),
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
