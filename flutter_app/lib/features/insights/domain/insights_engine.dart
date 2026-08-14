import '../../../app/app_state.dart';
import 'insight.dart';
import 'insight_rules.dart';

/// Runs every rule in [allInsightRules] against the current [AppData] and
/// filters out anything already dismissed — the one place that turns
/// "which rules currently fire" into "what's actually worth showing".
/// Rules themselves are pure and stateless; dismissal is the only
/// persisted state, stored as `settings['insightsDismissed']`
/// (`{id: true}`), the same "note it in a settings field" pattern the
/// Next Kg screen already uses for `kgMilestonesSeen`.
class InsightsEngine {
  const InsightsEngine._();

  static bool _isDismissed(Map<String, dynamic> settings, String id) {
    final dismissed = settings['insightsDismissed'] as Map?;
    return dismissed?[id] == true;
  }

  /// Every rule that currently fires, dismissed or not — the feed
  /// (Settings → Insights) wants to show both, so people can un-dismiss
  /// something they swiped away by mistake.
  static List<Insight> evaluateAll(AppData data, String today) {
    final out = <Insight>[];
    for (final rule in allInsightRules) {
      final insight = rule(data, today);
      if (insight != null) out.add(insight);
    }
    return out;
  }

  /// Firing, not dismissed, capped to [limit] — what a single contextual
  /// placement (Dashboard, Weight tab) actually renders. Rule order in
  /// [allInsightRules] doubles as priority order.
  static List<Insight> active(AppData data, String today, {int limit = 1}) {
    final all = evaluateAll(data, today).where((i) => !_isDismissed(data.settings, i.id)).toList();
    return all.length > limit ? all.sublist(0, limit) : all;
  }

  static bool isDismissed(AppData data, String id) => _isDismissed(data.settings, id);

  /// New settings map with [id] marked dismissed — callers pass this
  /// straight to `AppController.patchSettings('insightsDismissed', ...)`.
  static Map<String, dynamic> withDismissed(AppData data, String id) {
    final d = Map<String, dynamic>.from(data.settings['insightsDismissed'] as Map? ?? {});
    d[id] = true;
    return d;
  }

  /// New settings map with [id] un-dismissed — the feed's "restore" tap.
  static Map<String, dynamic> withRestored(AppData data, String id) {
    final d = Map<String, dynamic>.from(data.settings['insightsDismissed'] as Map? ?? {});
    d.remove(id);
    return d;
  }
}
