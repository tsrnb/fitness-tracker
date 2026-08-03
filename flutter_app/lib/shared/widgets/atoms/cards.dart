import 'package:flutter/material.dart';
import '../../theme.dart';
import '../pressable_scale.dart';
import 'motion.dart';

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.background,
    this.borderColor,
    this.radius = T.rL,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: fastAnim,
      curve: easeCurve,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? T.surface,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.98, child: content);
  }
}

/// Card == Surface with the default surface look (used everywhere as `Card` in the React app).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Surface(
      padding: padding,
      background: T.surface,
      borderColor: borderColor ?? T.line,
      onTap: onTap,
      child: child,
    );
  }
}

enum HeroTone { hero, lav, paper }

class HeroCard extends StatelessWidget {
  final Widget child;
  final HeroTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const HeroCard({super.key, required this.child, this.tone = HeroTone.hero, this.padding = const EdgeInsets.all(18), this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = tone == HeroTone.lav ? T.lav : (tone == HeroTone.paper ? T.paper : T.hero);
    final ink = tone == HeroTone.lav ? T.lavInk : (tone == HeroTone.paper ? T.paperInk : Colors.white);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(T.rXL)),
      child: DefaultTextStyle(style: TextStyle(color: ink), child: IconTheme(data: IconThemeData(color: ink), child: child)),
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.97, child: content);
  }
}

class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const PaperCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(color: T.paper, borderRadius: BorderRadius.circular(T.rXL)),
      child: DefaultTextStyle(style: const TextStyle(color: T.paperInk), child: child),
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.97, child: content);
  }
}
