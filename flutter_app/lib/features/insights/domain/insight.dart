/// How an [Insight] should read — same card shape everywhere, different
/// posture. See `insight_card.dart` for how each maps to color/copy.
enum InsightTone {
  /// A nudge toward doing something ("log your weight").
  suggestion,

  /// Context on a number the user can already see elsewhere ("why did the
  /// scale and food log disagree this week").
  explain,

  /// Positive, no action needed — just noticed.
  recognition,
}

/// One AI insight, as produced by a rule in `insight_rules.dart`.
class Insight {
  /// Stable per-instance id used for dismissal (`InsightsEngine.dismiss`)
  /// and as a `Key` in lists. Each rule bakes enough context into this
  /// (usually a date, sometimes a milestone number) that dismissing one
  /// instance doesn't permanently silence the rule — see the rule doc
  /// comments in `insight_rules.dart` for the reasoning per rule.
  final String id;
  final InsightTone tone;
  final String tag;
  final String message;
  final String? actionLabel;

  const Insight({
    required this.id,
    required this.tone,
    required this.tag,
    required this.message,
    this.actionLabel,
  });
}
