import 'package:flutter/material.dart';
import '../../theme.dart';
import '../pressable_scale.dart';
import 'cards.dart';
import 'motion.dart';

class ChecklistPill extends StatelessWidget {
  final String label;
  final String? sub;
  final bool done;
  final VoidCallback? onTap;
  final HeroTone tone;
  const ChecklistPill({super.key, required this.label, this.sub, required this.done, this.onTap, this.tone = HeroTone.hero});

  @override
  Widget build(BuildContext context) {
    final bg = tone == HeroTone.lav ? const Color(0x1A1C1E3A) : const Color(0x29FFFFFF);
    final ink = tone == HeroTone.lav ? T.lavInk : Colors.white;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(T.pill)),
      child: Row(
        children: [
          AnimatedContainer(
            duration: fastAnim,
            curve: easeCurve,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? ink : Colors.transparent,
              border: done ? null : Border.all(color: ink.withValues(alpha: 0.7), width: 2),
            ),
            child: AnimatedSwitcher(
              duration: fastAnim,
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: done
                  ? Icon(Icons.check, size: 13, color: tone == HeroTone.lav ? T.lav : T.hero, key: const ValueKey('on'))
                  : const SizedBox.shrink(key: ValueKey('off')),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 14, height: 1.2), overflow: TextOverflow.ellipsis),
                if (sub != null) Text(sub!, style: TextStyle(color: ink.withValues(alpha: 0.8), fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.96, child: content);
  }
}

/// Small neutral "how much of today's eating plan is left" chip — the
/// secondary, budget-vs-goal half of the app's two energy stats (the other
/// being true deficit/surplus vs. maintenance, which stays the bold primary
/// number wherever this chip appears). Deliberately always the same neutral
/// blue regardless of over/under: whether you've got room left in today's
/// plan isn't itself a verdict the way the true deficit number is — it's
/// just informational, so it doesn't compete with the green/red judgment
/// call sitting right next to it.
class BudgetChip extends StatelessWidget {
  final num budgetLeft; // positive = under budget, negative = over
  final bool isToday;
  const BudgetChip({super.key, required this.budgetLeft, this.isToday = true});

  @override
  Widget build(BuildContext context) {
    final over = budgetLeft < 0;
    final label = over
        ? (isToday ? '${(-budgetLeft).round()} kcal over today\'s plan' : '${(-budgetLeft).round()} kcal over budget')
        : (isToday ? '${budgetLeft.round()} kcal left today' : '${budgetLeft.round()} kcal under budget');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🍽', style: TextStyle(fontSize: 11)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: T.blue)),
      ]),
    );
  }
}

class ActionPill extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;
  const ActionPill({super.key, required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: T.paperInk, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFF141416), shape: BoxShape.circle),
            child: icon ?? const Icon(Icons.chevron_right, size: 17, color: Colors.white),
          ),
        ],
      ),
    );
    return PressableScale(onTap: onTap, downScale: 0.95, child: content);
  }
}

/// Rounded-full segmented control with a sliding highlight pill (equal-width
/// items only — the `scroll` variant has variable-width items so it instead
/// cross-fades each item's own background color).
class PillTabs extends StatelessWidget {
  final List<MapEntry<String, String>> options;
  final String value;
  final ValueChanged<String> onChange;
  final bool scroll;
  const PillTabs({super.key, required this.options, required this.value, required this.onChange, this.scroll = false});

  @override
  Widget build(BuildContext context) {
    if (scroll) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((o) {
              final active = value == o.key;
              return GestureDetector(
                onTap: () => onChange(o.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: fastAnim,
                  curve: easeCurve,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: active ? T.hero : Colors.transparent, borderRadius: BorderRadius.circular(T.pill)),
                  child: AnimatedDefaultTextStyle(
                    duration: fastAnim,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : T.muted),
                    child: Text(o.value, textAlign: TextAlign.center),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
    final index = options.indexWhere((o) => o.key == value).clamp(0, options.length - 1);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth - 8) / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: medAnim,
                curve: easeCurve,
                left: index * w,
                width: w,
                top: 0,
                bottom: 0,
                child: DecoratedBox(decoration: BoxDecoration(color: T.hero, borderRadius: BorderRadius.circular(T.pill))),
              ),
              Row(
                children: options.map((o) {
                  final active = value == o.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChange(o.key),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: AnimatedDefaultTextStyle(
                          duration: fastAnim,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : T.muted),
                          child: Text(o.value, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
