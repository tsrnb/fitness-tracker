import 'package:flutter/material.dart';
import '../../theme.dart';
import '../pressable_scale.dart';
import 'layout.dart';
import 'motion.dart';

const primaryBtnDecoration = BoxDecoration(color: T.accent, borderRadius: BorderRadius.all(Radius.circular(T.pill)));

class PrimaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double opacity;
  final EdgeInsetsGeometry padding;
  const PrimaryButton({super.key, required this.child, this.onTap, this.opacity = 1, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: fastAnim,
      curve: easeCurve,
      child: PressableScale(
        onTap: opacity < 1 ? null : onTap,
        downScale: 0.97,
        child: Container(
          padding: padding,
          decoration: primaryBtnDecoration,
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            child: IconTheme(data: const IconThemeData(color: Colors.white), child: child),
          ),
        ),
      ),
    );
  }
}

class OptBtn extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final Widget? icon;
  final String label;
  final String? sub;
  const OptBtn({super.key, required this.active, required this.onTap, this.icon, required this.label, this.sub});

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: fastAnim,
      curve: easeCurve,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: active ? T.accentDim : T.surface,
        border: Border.all(color: active ? T.hero : T.line),
        borderRadius: BorderRadius.circular(T.pill),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            IconBubble(icon: icon!, size: 38, background: active ? T.hero : T.surface2),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: T.text)),
                if (sub != null) Padding(padding: EdgeInsets.only(top: 2), child: Text(sub!, style: TextStyle(fontSize: 12, color: T.muted))),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: fastAnim,
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: active
                ? const IconBubble(key: ValueKey('active'), icon: Icon(Icons.check, size: 14, color: Colors.white, key: ValueKey('check')), size: 26, background: T.hero)
                : const SizedBox.shrink(key: ValueKey('inactive')),
          ),
        ],
      ),
    );
    return PressableScale(onTap: onTap, downScale: 0.98, child: content);
  }
}
