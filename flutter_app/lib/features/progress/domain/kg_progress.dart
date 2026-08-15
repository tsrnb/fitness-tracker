/// The food-log-driven weight-loss tracker's math — entirely separate from
/// the scale-based `weight` log. 7,700 kcal of true deficit ≈ 1 kg, the same
/// conversion `plan_generator.dart` already uses for the weekly-rate math.
const int kcalPerKg = 7700;

/// How close [KgProgress.currentWeight] is to the next *round* kg below it
/// — 75.4 kg is [target] 75, [gap] 0.4. Deliberately separate from
/// [KgProgress.reached]/[KgProgress.currentKcal], which track cumulative
/// *banked* food-log deficit — a real, meaningful number, but not aligned
/// to a round figure on the scale, since actual weight during a leg
/// doesn't move in neat kg steps. This answers the more immediate
/// question a person actually has looking at the scale: how close am I to
/// the next whole number.
class NextWholeKg {
  final double target;
  final double gap; // always > 0
  const NextWholeKg({required this.target, required this.gap});
}

/// Null when there's no calibrated current weight to compute from (see
/// [KgProgress.currentWeight] / [estimatedWeightOnDate]).
NextWholeKg? computeNextWholeKg(double? currentWeight) {
  if (currentWeight == null) return null;
  var target = currentWeight.floorToDouble();
  // Already sitting on (or a hair above, past floating-point noise) a
  // whole number — the "next" one is a full kg further down, not 0.0 away.
  if (target >= currentWeight - 1e-9) target -= 1;
  return NextWholeKg(target: target, gap: currentWeight - target);
}

/// One whole kg reached — permanent once recorded. A later surplus run can
/// stall (or even go negative on) progress toward the *next* kg, but it
/// never un-earns one already reached; see [computeKgProgress].
class KgMilestone {
  final int number;
  final String date; // yyyy-MM-dd it was crossed

  /// The real, scale-grounded weight at [date] — see [estimatedWeightOnDate]
  /// for how it's derived. Null only when there's no weigh-in anywhere in
  /// the log and no fallback baseline to anchor to, in which case callers
  /// fall back to the abstract "kg N" framing.
  final double? weight;

  const KgMilestone(this.number, this.date, {this.weight});
}

/// Lifetime rollup: every whole kg crossed so far, in order, plus how far
/// into the next one the log currently sits.
class KgProgress {
  final List<KgMilestone> reached;

  /// Raw signed running total toward the *next* kg — can go negative if a
  /// stretch of surplus days outweighs the deficit banked since the last
  /// milestone. Never reduces [reached]; a bad week stalls the current leg,
  /// it doesn't erase a kg already earned.
  final double currentKcal;

  /// Today's calibrated weight estimate — same anchor-to-your-nearest-real-
  /// weigh-in logic as each [KgMilestone.weight], just evaluated for today
  /// instead of a past milestone date. This is what makes "how much have I
  /// actually lost" answer from real scale data plus the food log's
  /// day-by-day shape, rather than the food log extrapolated in isolation
  /// further and further from the last time anyone actually weighed in.
  final double? currentWeight;

  const KgProgress({required this.reached, required this.currentKcal, this.currentWeight});

  int get currentNumber => reached.length + 1;

  /// 0–1, floored at 0 for display — [currentKcal] itself stays signed so
  /// callers that want the raw number (e.g. "340 kcal to go negative") can
  /// still get at it.
  double get currentFraction => currentKcal <= 0 ? 0.0 : (currentKcal / kcalPerKg).clamp(0.0, 1.0);

  double get totalKg => reached.length + currentFraction;
}

int _kcalEaten(dynamic meals) {
  if (meals is! List) return 0;
  return meals.fold<int>(0, (a, b) => a + (((b as Map)['kcal'] as num?) ?? 0).toInt());
}

num _kcalBurned(Map<String, dynamic> activity, String date) => ((activity[date] as Map?)?['kcal'] as num?) ?? 0;

/// True deficit for one date — [DayStat.trueDeficit]'s formula, duplicated
/// rather than shared because this only ever needs kcal in/out (no protein,
/// no goals), across arbitrarily many dates rather than one week's worth.
num _deficitForDate(Map<String, dynamic> diet, Map<String, dynamic> activity, String date, num tdee) {
  final kcal = _kcalEaten(diet[date]);
  final burned = _kcalBurned(activity, date);
  return tdee - (kcal - burned);
}

List<Map<String, dynamic>> _sortedWeightLog(List<Map<String, dynamic>> weight) {
  final list = List<Map<String, dynamic>>.from(weight);
  list.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  return list;
}

/// Total food-log kg lost strictly after [fromDateExclusive] and up to
/// [toDateInclusive] — always evaluated forward in time; callers going
/// "backward" from a later anchor negate the sign themselves. Un-logged
/// days are excluded, same rule as everywhere else in this file. Public
/// because the insights engine (`features/insights/domain/insight_rules.dart`)
/// reuses it for the plateau-despite-a-logged-deficit check.
double foodLogKgLostBetween(Map<String, dynamic> diet, Map<String, dynamic> activity, num tdee, String fromDateExclusive, String toDateInclusive) {
  double kcalSum = 0;
  for (final date in diet.keys) {
    if (date.compareTo(fromDateExclusive) <= 0 || date.compareTo(toDateInclusive) > 0) continue;
    final meals = diet[date];
    if (meals is! List || meals.isEmpty) continue;
    kcalSum += _deficitForDate(diet, activity, date, tdee);
  }
  return kcalSum / kcalPerKg;
}

/// The real-world weigh-in nearest [date] (by calendar days either
/// direction) — the anchor [estimatedWeightOnDate] walks the food log out
/// from, on the theory that a real scale reading close in time to the date
/// in question is more trustworthy than one further away, whichever side
/// it falls on.
Map<String, dynamic>? _nearestAnchor(List<Map<String, dynamic>> sortedWeightLog, String date) {
  if (sortedWeightLog.isEmpty) return null;
  final target = DateTime.parse('${date}T00:00:00');
  Map<String, dynamic>? best;
  int? bestDiff;
  for (final w in sortedWeightLog) {
    final diff = DateTime.parse('${w['date']}T00:00:00').difference(target).inDays.abs();
    if (bestDiff == null || diff < bestDiff) {
      best = w;
      bestDiff = diff;
    }
  }
  return best;
}

/// The best estimate of actual weight on [date] — anchored to the closest
/// real weigh-in (in either direction) and walked to [date] using the food
/// log's day-by-day deficit over the days between, rather than trusting the
/// food log's cumulative estimate in isolation, which drifts further from
/// reality the longer it goes uncorrected by an actual scale reading.
/// Falls back to [fallbackBaseline] (typically the profile's on-file
/// current weight) when there's no weigh-in logged at all, and to null when
/// there's neither.
double? estimatedWeightOnDate({
  required List<Map<String, dynamic>> weightLog,
  required Map<String, dynamic> diet,
  required Map<String, dynamic> activity,
  required num tdee,
  required String date,
  double? fallbackBaseline,
}) {
  final sorted = _sortedWeightLog(weightLog);
  final anchor = _nearestAnchor(sorted, date);
  if (anchor == null) return fallbackBaseline;
  final anchorDate = anchor['date'] as String;
  final anchorWeight = (anchor['weight'] as num).toDouble();
  if (date == anchorDate) return anchorWeight;
  if (date.compareTo(anchorDate) < 0) {
    // date is before the anchor: it was heavier by whatever the food log
    // says was lost between then and the anchor.
    return anchorWeight + foodLogKgLostBetween(diet, activity, tdee, date, anchorDate);
  }
  return anchorWeight - foodLogKgLostBetween(diet, activity, tdee, anchorDate, date);
}

/// Walks every logged day in [diet], oldest first, summing true deficit —
/// only days with at least one logged meal count at all; a day with nothing
/// logged is skipped entirely rather than treated as a full-TDEE deficit
/// (which would make *not* logging look like progress, exactly backwards).
/// [weightLog] (raw `AppData.weight` entries) and [fallbackBaseline] feed
/// [estimatedWeightOnDate] for each milestone's real-weight label and
/// [KgProgress.currentWeight]; omit them and every weight comes back null,
/// which callers treat as "show the abstract kg count instead."
KgProgress computeKgProgress({
  required Map<String, dynamic> diet,
  required Map<String, dynamic> activity,
  required num tdee,
  List<Map<String, dynamic>> weightLog = const [],
  double? fallbackBaseline,
  String? today,
}) {
  final dates = diet.keys.toList()..sort();
  final reached = <KgMilestone>[];
  double sinceLast = 0;
  for (final date in dates) {
    final meals = diet[date];
    if (meals is! List || meals.isEmpty) continue;
    sinceLast += _deficitForDate(diet, activity, date, tdee);
    // >= rather than a single decrement: one very large deficit day can
    // cross more than one kg at once.
    while (sinceLast >= kcalPerKg) {
      sinceLast -= kcalPerKg;
      final n = reached.length + 1;
      final weight = estimatedWeightOnDate(
        weightLog: weightLog,
        diet: diet,
        activity: activity,
        tdee: tdee,
        date: date,
        fallbackBaseline: fallbackBaseline,
      );
      reached.add(KgMilestone(n, date, weight: weight));
    }
  }
  final currentWeight = today == null
      ? null
      : estimatedWeightOnDate(weightLog: weightLog, diet: diet, activity: activity, tdee: tdee, date: today, fallbackBaseline: fallbackBaseline);
  return KgProgress(reached: reached, currentKcal: sinceLast, currentWeight: currentWeight);
}

/// One day of the trailing window shown in the day-strip — [logged] false
/// means nothing was logged that day (drawn as a flat, excluded bar); when
/// true, [deficit] is that day's true deficit (negative = surplus).
class KgDayBar {
  final String date;
  final bool logged;
  final num deficit;
  const KgDayBar({required this.date, required this.logged, this.deficit = 0});
}

class KgWindow {
  final List<KgDayBar> days; // chronological, oldest first
  final int daysLogged;
  final double avgDeficitPerLoggedDay;

  /// Days to close out the current leg at [avgDeficitPerLoggedDay] — null
  /// when there's no positive trailing average to project from (nothing
  /// logged in the window, or it's net surplus), 0 when the leg's already
  /// effectively done.
  final int? etaDays;

  const KgWindow({required this.days, required this.daysLogged, required this.avgDeficitPerLoggedDay, required this.etaDays});
}

/// The trailing [windowSize]-day view behind the day-strip and the
/// "X/Y days logged" / "avg kcal/day" / "~N days to next kg" stat chips —
/// deliberately separate from [KgProgress]: the lifetime current-leg total
/// can span far more than a couple of weeks, while the strip only ever
/// shows a recent slice of it.
KgWindow computeKgWindow({
  required Map<String, dynamic> diet,
  required Map<String, dynamic> activity,
  required num tdee,
  required String today,
  required double remainingKcal,
  int windowSize = 14,
}) {
  final base = DateTime.parse('${today}T00:00:00');
  final dates = List.generate(windowSize, (i) {
    final d = base.subtract(Duration(days: windowSize - 1 - i));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  });

  final bars = <KgDayBar>[];
  var loggedCount = 0;
  double loggedSum = 0;
  for (final date in dates) {
    final meals = diet[date];
    if (meals is! List || meals.isEmpty) {
      bars.add(KgDayBar(date: date, logged: false));
      continue;
    }
    final deficit = _deficitForDate(diet, activity, date, tdee);
    bars.add(KgDayBar(date: date, logged: true, deficit: deficit));
    loggedCount++;
    loggedSum += deficit;
  }

  final avg = loggedCount > 0 ? loggedSum / loggedCount : 0.0;
  final int? eta;
  if (remainingKcal <= 0) {
    eta = 0;
  } else if (avg > 0) {
    eta = (remainingKcal / avg).ceil();
  } else {
    eta = null;
  }
  return KgWindow(days: bars, daysLogged: loggedCount, avgDeficitPerLoggedDay: avg, etaDays: eta);
}

/// The breakdown behind one day's bar, for the tap-through detail sheet.
class KgDayDetail {
  final String date;
  final int eaten;
  final num tdee;
  final num burned;
  final num deficit;
  const KgDayDetail({required this.date, required this.eaten, required this.tdee, required this.burned, required this.deficit});
}

KgDayDetail computeKgDayDetail(Map<String, dynamic> diet, Map<String, dynamic> activity, String date, num tdee) {
  final eaten = _kcalEaten(diet[date]);
  final burned = _kcalBurned(activity, date);
  return KgDayDetail(date: date, eaten: eaten, tdee: tdee, burned: burned, deficit: tdee - (eaten - burned));
}

/// A meaningful mismatch between what the food log predicted and what the
/// scale actually showed at the most recent weigh-in — see [computeLatestGap].
class KgGapInsight {
  final String previousDate;
  final double previousWeight;
  final String latestDate;
  final double predictedWeight;
  final double actualWeight;
  final int daysBetween;
  final int daysLogged;
  const KgGapInsight({
    required this.previousDate,
    required this.previousWeight,
    required this.latestDate,
    required this.predictedWeight,
    required this.actualWeight,
    required this.daysBetween,
    required this.daysLogged,
  });

  /// Positive = the scale showed more than the food log predicted (lost
  /// less than expected, or gained); negative = lost more than expected.
  double get gapKg => actualWeight - predictedWeight;
}

/// Compares the two most recent weigh-ins: what the food log alone would
/// have predicted for the latest one (anchored to the one before it) versus
/// what the scale actually showed. Null when there aren't at least two
/// weigh-ins to compare, or when the gap is within [thresholdKg] — ordinary
/// water/sodium/timing noise, not worth flagging. 1kg is deliberately a
/// bit above typical day-to-day scale noise, so this doesn't fire on every
/// routine fluctuation.
KgGapInsight? computeLatestGap({
  required List<Map<String, dynamic>> weightLog,
  required Map<String, dynamic> diet,
  required Map<String, dynamic> activity,
  required num tdee,
  double thresholdKg = 1.0,
}) {
  final sorted = _sortedWeightLog(weightLog);
  if (sorted.length < 2) return null;
  final previous = sorted[sorted.length - 2];
  final latest = sorted.last;
  final previousDate = previous['date'] as String;
  final latestDate = latest['date'] as String;
  final previousWeight = (previous['weight'] as num).toDouble();
  final actualWeight = (latest['weight'] as num).toDouble();
  final predictedWeight = previousWeight - foodLogKgLostBetween(diet, activity, tdee, previousDate, latestDate);

  final gap = actualWeight - predictedWeight;
  if (gap.abs() < thresholdKg) return null;

  var daysLogged = 0;
  for (final date in diet.keys) {
    if (date.compareTo(previousDate) <= 0 || date.compareTo(latestDate) > 0) continue;
    final meals = diet[date];
    if (meals is List && meals.isNotEmpty) daysLogged++;
  }

  return KgGapInsight(
    previousDate: previousDate,
    previousWeight: previousWeight,
    latestDate: latestDate,
    predictedWeight: predictedWeight,
    actualWeight: actualWeight,
    daysBetween: DateTime.parse('${latestDate}T00:00:00').difference(DateTime.parse('${previousDate}T00:00:00')).inDays,
    daysLogged: daysLogged,
  );
}
