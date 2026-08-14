/// The food-log-driven weight-loss tracker's math — entirely separate from
/// the scale-based `weight` log. 7,700 kcal of true deficit ≈ 1 kg, the same
/// conversion `plan_generator.dart` already uses for the weekly-rate math.
const int kcalPerKg = 7700;

/// One whole kg reached — permanent once recorded. A later surplus run can
/// stall (or even go negative on) progress toward the *next* kg, but it
/// never un-earns one already reached; see [computeKgProgress].
class KgMilestone {
  final int number;
  final String date; // yyyy-MM-dd it was crossed
  const KgMilestone(this.number, this.date);
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

  const KgProgress({required this.reached, required this.currentKcal});

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

/// Walks every logged day in [diet], oldest first, summing true deficit —
/// only days with at least one logged meal count at all; a day with nothing
/// logged is skipped entirely rather than treated as a full-TDEE deficit
/// (which would make *not* logging look like progress, exactly backwards).
KgProgress computeKgProgress({
  required Map<String, dynamic> diet,
  required Map<String, dynamic> activity,
  required num tdee,
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
      reached.add(KgMilestone(reached.length + 1, date));
    }
  }
  return KgProgress(reached: reached, currentKcal: sinceLast);
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
