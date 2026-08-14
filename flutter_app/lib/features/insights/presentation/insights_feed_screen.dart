import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../domain/insight.dart';
import '../domain/insights_engine.dart';
import 'widgets/insight_card.dart';

/// Settings → Insights — every insight currently firing, dismissed or not,
/// rather than a true historical log of everything ever shown. Rules are
/// re-evaluated live off today's [AppData] (see `InsightsEngine`), so an
/// insight that was true last week but no longer is (e.g. a gap that's
/// since closed) simply won't be here — this is "what's true right now",
/// with a restore option for anything swiped away by mistake, not a diary.
class InsightsFeedScreen extends StatelessWidget {
  final AppState app;
  final AppController controller;
  const InsightsFeedScreen({super.key, required this.app, required this.controller});

  // Guarded on a loaded active user, same reasoning as NextKgScreen's
  // kgMilestonesSeen persistence — `controller`'s own state can briefly
  // disagree with the `app` snapshot this screen was pushed with, and
  // patchSettings reaches for `state.user!.id`.
  void _dismiss(Insight insight) {
    if (controller.current.user == null) return;
    controller.patchSettings('insightsDismissed', InsightsEngine.withDismissed(app.data, insight.id));
  }

  void _restore(Insight insight) {
    if (controller.current.user == null) return;
    controller.patchSettings('insightsDismissed', InsightsEngine.withRestored(app.data, insight.id));
  }

  @override
  Widget build(BuildContext context) {
    final today = todayStr(app.data.settings);
    final all = InsightsEngine.evaluateAll(app.data, today);

    return pageScaffold(
      context: context,
      title: 'Insights',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('Everything the AI currently notices about your log — active and dismissed.', style: Type.caption),
          ),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Nothing to flag right now — check back as you log more.', style: TextStyle(color: T.muted, fontSize: 13))),
            )
          else
            for (final insight in all)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InsightCard(
                  insight: insight,
                  dismissed: InsightsEngine.isDismissed(app.data, insight.id),
                  onDismiss: () => _dismiss(insight),
                  onRestore: () => _restore(insight),
                ),
              ),
        ],
      ),
    );
  }
}
