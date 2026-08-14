import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../../plan/data/plan_generator.dart' show safetyFloorKcal;
import '../../progress/domain/kg_progress.dart' show foodLogKgLostBetween;
import '../../exercises/data/exercise_library_data.dart' as exercise_lib;
import 'insight.dart';

/// Every rule reads only [AppData]/[today] — no controller, no side
/// effects. `InsightsEngine` is what turns "which rules currently fire"
/// into "which of those has the user not dismissed yet".
typedef InsightRule = Insight? Function(AppData data, String today);

const List<InsightRule> allInsightRules = [
  checkWeightLogGap,
  checkSustainedDeficit,
  checkProteinShortfall,
  checkPlateauDespiteDeficit,
  checkLoggingStreak,
  checkTrainingImbalance,
];

List<String> _lastNDates(String today, int n) {
  final base = DateTime.parse('${today}T00:00:00');
  return List.generate(n, (i) {
    final d = base.subtract(Duration(days: n - 1 - i));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  });
}

String _dayBefore(String date) {
  final d = DateTime.parse('${date}T00:00:00').subtract(const Duration(days: 1));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

bool _hasWeightGoal(Map<String, dynamic> settings) {
  final goal = settings['goalType'] as String? ?? 'fatLoss';
  return goal == 'fatLoss' || goal == 'weightGain';
}

/// Nudge to log a weigh-in — the seed idea. Only for goals with a weight
/// target; "maintain" has nothing this would sharpen. Dated into the id so
/// dismissing today's nudge doesn't silence tomorrow's if the gap is still
/// open (or a new one opens up later).
Insight? checkWeightLogGap(AppData data, String today) {
  if (!_hasWeightGoal(data.settings)) return null;
  final weights = List<Map<String, dynamic>>.from(data.weight);
  if (weights.isEmpty) {
    return Insight(
      id: 'weight-log-gap:$today',
      tone: InsightTone.suggestion,
      tag: 'Suggestion',
      message: "You haven't logged a weigh-in yet — want to log one?",
      actionLabel: 'Log weight',
    );
  }
  weights.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  final lastDate = weights.last['date'] as String;
  final gap = daysBetween(lastDate, today);
  if (gap < 10) return null;
  return Insight(
    id: 'weight-log-gap:$today',
    tone: InsightTone.suggestion,
    tag: 'Suggestion',
    message: "It's been $gap days since your last weigh-in — want to log one?",
    actionLabel: 'Log weight',
  );
}

/// Eating under the safety floor most days for a week straight — a
/// per-day recomputation against the current plan's BMR/sex rather than a
/// stored history of the plan's own `paceCapped` flag (which only ever
/// reflects *today's* settings, not what was actually eaten on past days).
Insight? checkSustainedDeficit(AppData data, String today) {
  if ((data.settings['goalType'] as String? ?? 'fatLoss') != 'fatLoss') return null;
  final bmr = (data.plan?['bmr'] as num?)?.toDouble();
  if (bmr == null) return null;
  final sex = data.settings['sex'] as String? ?? 'male';
  final floor = safetyFloorKcal(bmr, sex);

  var logged = 0, under = 0;
  for (final date in _lastNDates(today, 7)) {
    final meals = data.diet[date];
    if (meals is! List || meals.isEmpty) continue;
    logged++;
    final kcal = meals.fold<int>(0, (a, b) => a + (((b as Map)['kcal'] as num?) ?? 0).toInt());
    if (kcal < floor) under++;
  }
  if (logged < 5 || under < 5) return null;

  return Insight(
    id: 'sustained-deficit:$today',
    tone: InsightTone.suggestion,
    tag: 'Worth a look',
    message: "You've eaten under your safety minimum on $under of your last $logged logged days. A short diet break can help energy and adherence.",
    actionLabel: 'Review pace',
  );
}

/// Protein goal missed on most logged days this week — the number that
/// actually predicts muscle loss on a cut, not just "ate too much/little".
Insight? checkProteinShortfall(AppData data, String today) {
  if (!_hasWeightGoal(data.settings)) return null;
  final proteinGoal = (data.settings['proteinGoal'] as num?) ?? 0;
  if (proteinGoal <= 0) return null;

  var logged = 0, missed = 0;
  for (final date in _lastNDates(today, 7)) {
    final meals = data.diet[date];
    if (meals is! List || meals.isEmpty) continue;
    logged++;
    final protein = meals.fold<int>(0, (a, b) => a + (((b as Map)['protein'] as num?) ?? 0).toInt());
    if (protein < proteinGoal * 0.9) missed++;
  }
  if (logged < 4 || missed < 4) return null;

  return Insight(
    id: 'protein-shortfall:$today',
    tone: InsightTone.suggestion,
    tag: 'Worth a look',
    message: 'Protein goal missed $missed of your last $logged logged days — muscle retention risk while cutting.',
  );
}

/// Scale essentially flat over a stretch of ≥21 days while the food log
/// implies real loss over the same window — the exact situation the Next
/// Kg screen's "gap" card flags at the day-to-day level, generalized to a
/// longer, plateau-shaped version of the same comparison.
Insight? checkPlateauDespiteDeficit(AppData data, String today) {
  if ((data.settings['goalType'] as String? ?? 'fatLoss') != 'fatLoss') return null;
  final tdee = (data.plan?['tdee'] as num?) ?? (data.settings['calorieGoal'] as num?);
  if (tdee == null) return null;

  final weights = List<Map<String, dynamic>>.from(data.weight)..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  if (weights.length < 2) return null;
  final latest = weights.last;
  final latestDate = latest['date'] as String;

  // Earliest weigh-in at least 21 days before the latest one.
  Map<String, dynamic>? anchor;
  for (final w in weights) {
    if (daysBetween(w['date'] as String, latestDate) >= 21) {
      anchor = w;
      break;
    }
  }
  if (anchor == null) return null;
  final anchorDate = anchor['date'] as String;

  final netChange = (latest['weight'] as num).toDouble() - (anchor['weight'] as num).toDouble();
  if (netChange.abs() >= 0.3) return null; // the scale actually moved — not a plateau

  final impliedLoss = foodLogKgLostBetween(data.diet, data.activity, tdee, anchorDate, latestDate);
  if (impliedLoss < 1.0) return null;

  final days = daysBetween(anchorDate, latestDate);
  return Insight(
    id: 'plateau:$today',
    tone: InsightTone.explain,
    tag: 'Worth knowing',
    message: "Your weight's barely moved in $days days despite a logged deficit — plateaus like this are common, and usually temporary.",
    actionLabel: 'See why',
  );
}

const _streakMilestones = [7, 14, 30, 60, 90, 120, 180, 365];

/// Consecutive days (ending today) with at least one meal logged, hitting
/// a round milestone. Keyed by the streak length itself, not the date, so
/// dismissing "14 days" doesn't suppress "30 days" later — but does mean
/// this only ever fires once per milestone, the day it's crossed.
Insight? checkLoggingStreak(AppData data, String today) {
  var streak = 0;
  var date = today;
  while (true) {
    final meals = data.diet[date];
    if (meals is! List || meals.isEmpty) break;
    streak++;
    date = _dayBefore(date);
  }
  if (!_streakMilestones.contains(streak)) return null;
  return Insight(
    id: 'streak:$streak',
    tone: InsightTone.recognition,
    tag: 'Nice streak',
    message: '$streak days of logging in a row 🔥',
  );
}

// Upper-body push/pull only — legs, abs, forearms, and calves are their
// own thing and would just add noise to a push/pull-specific comparison.
const _pushTags = {'chest', 'frontDelts', 'sideDelts', 'triceps'};
const _pullTags = {'lats', 'upperBack', 'rearDelts', 'traps', 'biceps'};

/// One side of an upper-body push/pull pair trained 3x+ more (by set
/// count) than the other over the last 7 days — a lopsided week, not
/// necessarily a lopsided program (a single push-heavy week is normal;
/// this only looks at the trailing week, same as the rest of this file).
Insight? checkTrainingImbalance(AppData data, String today) {
  final window = _lastNDates(today, 7).toSet();
  var pushSets = 0, pullSets = 0;

  data.history.forEach((name, rawEntries) {
    final info = exercise_lib.lib[name];
    if (info == null) return;
    final tags = {...info.primary, ...info.secondary};
    final isPush = tags.any(_pushTags.contains);
    final isPull = tags.any(_pullTags.contains);
    if (!isPush && !isPull) return;

    for (final entry in List<dynamic>.from(rawEntries as List)) {
      final e = entry as Map;
      if (!window.contains(e['date'])) continue;
      final setCount = (e['sets'] as List).length;
      if (isPush) pushSets += setCount;
      if (isPull) pullSets += setCount;
    }
  });

  final total = pushSets + pullSets;
  if (total < 6) return null; // not enough volume this week to say anything meaningful

  final biggerIsPush = pushSets >= pullSets;
  final biggerN = biggerIsPush ? pushSets : pullSets;
  final smallerN = biggerIsPush ? pullSets : pushSets;
  if (biggerN < smallerN * 3) return null;

  return Insight(
    id: 'imbalance:$today',
    tone: InsightTone.suggestion,
    tag: 'Worth a look',
    message: '${biggerIsPush ? 'Push' : 'Pull'} trained $biggerN sets this week, ${biggerIsPush ? 'pull' : 'push'} just $smallerN — worth balancing before next week.',
  );
}
