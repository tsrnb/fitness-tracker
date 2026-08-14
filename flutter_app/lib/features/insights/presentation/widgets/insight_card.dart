import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../nutrition/presentation/widgets/ai_gradient.dart' show aiColor1, aiColor2, aiColor3;
import '../../domain/insight.dart';

/// The one card every AI insight renders as, wherever it shows up —
/// gradient sparkle, a tag, a message, an optional action, always
/// dismissible. Tone changes copy/emphasis upstream (each rule picks its
/// own [Insight.tag]); it doesn't change this widget's shape, so an
/// insight reads as "the AI noticed something" no matter which screen it's
/// on. The gradient itself is a static copy of `AiGradient`'s palette
/// rather than that widget's own animated sliding version — this can
/// appear several-at-once in the Insights feed, and a sparkle icon doesn't
/// need its own per-card AnimationController to read as "AI".
class InsightCard extends StatelessWidget {
  final Insight insight;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool dismissed;
  final VoidCallback? onRestore;

  const InsightCard({
    super.key,
    required this.insight,
    this.onAction,
    this.onDismiss,
    this.dismissed = false,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dismissed ? 0.45 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rL),
        child: DecoratedBox(
          decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rL)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A slim accent bar down the left edge is enough for a card
                // to read as "different" scanning down a list, without the
                // sparkle icon having to carry that alone.
                Container(width: 3, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [aiColor1, aiColor3]))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 13, 12, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [aiColor1, aiColor2, aiColor3])),
                              alignment: Alignment.center,
                              child: const Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(insight.tag, style: mono(fontSize: 9, fontWeight: FontWeight.w700, color: T.faint).copyWith(letterSpacing: 0.5)),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(insight.message, style: TextStyle(fontSize: 12.5, color: T.text, height: 1.45)),
                                  ),
                                ],
                              ),
                            ),
                            if (dismissed && onRestore != null)
                              _iconButton(icon: Icons.refresh, onTap: onRestore!)
                            else if (onDismiss != null)
                              _iconButton(icon: Icons.close, onTap: onDismiss!),
                          ],
                        ),
                        if (!dismissed && insight.actionLabel != null && onAction != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10, left: 36),
                            child: GestureDetector(
                              onTap: onAction,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(999)),
                                child: Text(insight.actionLabel!, style: mono(fontSize: 11, fontWeight: FontWeight.w700, color: aiColor2)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: T.faint),
      ),
    );
  }
}
