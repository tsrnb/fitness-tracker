import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../../progress/domain/kg_progress.dart' show kcalPerKg, estimatedWeightOnDate;

/// The 14-Day Calibration's math — pure functions over [AppData]/`today`,
/// no Flutter imports, mirroring the shape `kg_progress.dart` already
/// established (compute-once functions fed plain data, consumed by
/// presentation screens that just format the result).

const int calibrationWindowDays = 14;
const int calibrationExtensionDays = 7;

/// How long a finished study sticks around after it becomes terminal — the
/// user can reopen the results screen from the Weight page until then, at
/// which point the record auto-clears and the entry point goes back to a
/// fresh "Start a calibration" CTA.
const int calibrationRetentionDays = 7;

/// The date a calibration became terminal — its window closed and a result
/// was frozen, or it was ended early. `null` while it's still running, and
/// for legacy records with no explicit marker and no frozen `result`.
String? calibrationTerminalDate(Map<String, dynamic> calibration) {
  final marked = calibration['terminalOn'] as String?;
  if (marked != null) return marked;
  final result = calibration['result'];
  if (result is Map && result['computedOn'] is String) return result['computedOn'] as String;
  return null;
}

/// The date a finished study will be cleared, or `null` if it won't yet
/// (still running, or terminal date unknown).
String? calibrationClearsOn(Map<String, dynamic> calibration) {
  final t = calibrationTerminalDate(calibration);
  return t == null ? null : _addDays(t, calibrationRetentionDays);
}

/// Whole days from `today` until a finished study clears, clamped to
/// `[0, calibrationRetentionDays]`; `null` if it isn't on a clear-out clock.
int? daysUntilCalibrationCleared(Map<String, dynamic> calibration, String today) {
  final clears = calibrationClearsOn(calibration);
  return clears == null ? null : daysBetween(today, clears).clamp(0, calibrationRetentionDays);
}

/// True once a finished study has aged past [calibrationRetentionDays] and
/// should be swept.
bool calibrationExpired(Map<String, dynamic> calibration, String today) {
  final clears = calibrationClearsOn(calibration);
  return clears != null && today.compareTo(clears) >= 0;
}

/// Same TDEE fallback chain used everywhere else this number is read
/// (`next_kg_screen.dart`'s `_tdee`, `checkPlateauDespiteDeficit`,
/// `dashboard_stats.dart`'s `balance`): plan's own TDEE first, then the
/// calorie goal, then a hardcoded default.
num _tdeeFor(AppData data) => (data.plan?['tdee'] as num?) ?? (data.settings['calorieGoal'] as num?) ?? 2000;

String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _addDays(String date, int n) => _fmtDate(DateTime.parse('${date}T00:00:00').add(Duration(days: n)));

List<String> _lastNDates(String today, int n) {
  final base = DateTime.parse('${today}T00:00:00');
  return List.generate(n, (i) => _fmtDate(base.subtract(Duration(days: n - 1 - i))));
}

num _kcalEaten(dynamic meals) {
  if (meals is! List) return 0;
  return meals.fold<num>(0, (a, b) => a + (((b as Map)['kcal'] as num?) ?? 0));
}

/// The "current model" snapshot captured once, at the moment a calibration
/// starts — what `AppData.calibration['baseline']` holds. Intake is
/// averaged over the last 7 logged days (same window `checkSustainedDeficit`
/// uses in `insight_rules.dart`) rather than just today, so one unusually
/// light or heavy day doesn't skew the whole 14-day comparison.
Map<String, dynamic> computeBaseline(AppData data, String today) {
  final tdee = _tdeeFor(data);
  var loggedDays = 0;
  num kcalSum = 0;
  for (final date in _lastNDates(today, 7)) {
    final meals = data.diet[date];
    if (meals is! List || meals.isEmpty) continue;
    loggedDays++;
    kcalSum += _kcalEaten(meals);
  }
  final intake = loggedDays > 0 ? kcalSum / loggedDays : tdee;
  final deficit = tdee - intake;
  final startWeight = estimatedWeightOnDate(
    weightLog: data.weight,
    diet: data.diet,
    activity: data.activity,
    tdee: tdee,
    date: today,
    fallbackBaseline: (data.settings['currentWeight'] as num?)?.toDouble(),
  );
  return {
    'intakeKcal': intake,
    'expenditureKcal': tdee,
    // The calorie goal in force on Day 1 — frozen here so the end-of-window
    // "apply to plan" preview always re-anchors to the plan as it was when
    // the study started, never to a plan this study already updated (which
    // would re-apply the same gap on every revisit — see
    // computePlanApplyPreview).
    'calorieGoal': (data.settings['calorieGoal'] as num?) ?? tdee,
    'deficitKcal': deficit,
    'expectedKgChange': -(deficit * calibrationWindowDays) / kcalPerKg,
    'startWeight': startWeight,
  };
}

/// A fresh `calibration` record, ready to persist via
/// `controller.update('calibration', (_) => startCalibration(...))`.
Map<String, dynamic> startCalibration(AppData data, String today, String mode) {
  return {
    'mode': mode,
    // `modeSince` anchors the 7-day switch lock — set here on Day 1, and
    // re-set to `today` by [switchMode] whenever a switch actually goes
    // through, so each switch starts its own fresh lock window.
    'modeSince': today,
    'status': 'running',
    'startDate': today,
    'endDate': _addDays(today, calibrationWindowDays - 1),
    'baseline': computeBaseline(data, today),
  };
}

const int modeLockDays = 7;

/// True while the mode can't be switched — for [modeLockDays] days after it
/// was last set (either Day 1, or the last successful switch). Existing
/// records from before this field existed fall back to `startDate`, same
/// as if the current mode had been picked on Day 1.
bool isModeLocked(Map<String, dynamic> calibration, String today) {
  final since = calibration['modeSince'] as String? ?? calibration['startDate'] as String;
  return daysBetween(since, today) < modeLockDays;
}

/// Days left until the mode can be switched again — 0 once it's unlocked.
int daysUntilModeUnlock(Map<String, dynamic> calibration, String today) {
  final since = calibration['modeSince'] as String? ?? calibration['startDate'] as String;
  return (modeLockDays - daysBetween(since, today)).clamp(0, modeLockDays);
}

/// Switches mode and restarts the lock from `today` — a no-op (returns
/// [calibration] unchanged) if it's still locked or already that mode, so
/// callers can call this unconditionally without checking first.
Map<String, dynamic> switchMode(Map<String, dynamic> calibration, String nextMode, String today) {
  if (nextMode == calibration['mode'] || isModeLocked(calibration, today)) return calibration;
  final next = Map<String, dynamic>.from(calibration);
  next['mode'] = nextMode;
  next['modeSince'] = today;
  return next;
}

int totalDays(Map<String, dynamic> calibration) {
  final start = calibration['startDate'] as String;
  final end = calibration['endDate'] as String;
  return daysBetween(start, end) + 1;
}

/// 1-based day-of-window, clamped so a screen opened after `endDate` still
/// reads as the last day rather than counting past the window.
int dayNumber(Map<String, dynamic> calibration, String today) {
  final start = calibration['startDate'] as String;
  return (daysBetween(start, today) + 1).clamp(1, totalDays(calibration));
}

bool isFinished(Map<String, dynamic> calibration, String today) {
  final end = calibration['endDate'] as String;
  return today.compareTo(end) >= 0;
}

/// Extends a running calibration by another [calibrationExtensionDays] —
/// "Continue calibrating" on the results screen. Keeps the same baseline
/// (the model being tested doesn't change, only the window does) and clears
/// any frozen `result`, since it's no longer the final word.
Map<String, dynamic> extendCalibration(Map<String, dynamic> calibration) {
  final next = Map<String, dynamic>.from(calibration);
  next['endDate'] = _addDays(calibration['endDate'] as String, calibrationExtensionDays);
  next['status'] = 'running';
  next.remove('result');
  next.remove('terminalOn'); // back on the clock — no longer a finished study
  return next;
}

Map<String, dynamic> endCalibrationEarly(Map<String, dynamic> calibration, String today) {
  final next = Map<String, dynamic>.from(calibration);
  next['status'] = 'ended_early';
  next['terminalOn'] = today; // starts the retention countdown
  return next;
}

/// Mid-window snapshot for the Day X/14 dashboard.
class CalibrationProgress {
  final int day;
  final int totalDays;
  final double? currentWeight;
  final double? startWeight;

  /// Signed kg change so far — negative is loss, matching
  /// `baseline.expectedKgChange`'s sign convention.
  final double observedKgSoFar;
  final double expectedKgSoFar;

  /// 'within_range' | 'ahead' | 'behind' — ahead/behind are relative to the
  /// expected pace, not a verdict; the dashboard copy stays reassuring for
  /// both, this just picks which stat chip label to show.
  final String status;
  final bool weightLoggedToday;
  final bool foodLoggedToday;

  const CalibrationProgress({
    required this.day,
    required this.totalDays,
    required this.currentWeight,
    required this.startWeight,
    required this.observedKgSoFar,
    required this.expectedKgSoFar,
    required this.status,
    required this.weightLoggedToday,
    required this.foodLoggedToday,
  });
}

CalibrationProgress computeProgress(AppData data, Map<String, dynamic> calibration, String today) {
  final tdee = _tdeeFor(data);
  final baseline = Map<String, dynamic>.from(calibration['baseline'] as Map);
  final startWeight = (baseline['startWeight'] as num?)?.toDouble();
  // Same anchor-to-nearest-real-weigh-in estimate `KgProgress.currentWeight`
  // already uses for its "calibrated" trend reading — it smooths day-to-day
  // scale noise by construction, which is exactly the "trend, not one
  // weigh-in" behavior this dashboard needs, without a second rolling-
  // average implementation.
  final currentWeight = estimatedWeightOnDate(
    weightLog: data.weight,
    diet: data.diet,
    activity: data.activity,
    tdee: tdee,
    date: today,
    fallbackBaseline: startWeight,
  );
  final day = dayNumber(calibration, today);
  final total = totalDays(calibration);
  final expectedTotal = (baseline['expectedKgChange'] as num).toDouble();
  final expectedSoFar = expectedTotal * day / total;
  final observedSoFar = (startWeight != null && currentWeight != null) ? currentWeight - startWeight : 0.0;
  final diff = (observedSoFar - expectedSoFar).abs();
  final status = diff <= 0.3 ? 'within_range' : (observedSoFar < expectedSoFar ? 'ahead' : 'behind');
  final foodToday = data.diet[today] is List && (data.diet[today] as List).isNotEmpty;
  final weightToday = data.weight.any((w) => w['date'] == today);
  return CalibrationProgress(
    day: day,
    totalDays: total,
    currentWeight: currentWeight,
    startWeight: startWeight,
    observedKgSoFar: observedSoFar,
    expectedKgSoFar: expectedSoFar,
    status: status,
    weightLoggedToday: weightToday,
    foodLoggedToday: foodToday,
  );
}

/// End-of-window comparison, frozen into `calibration.result` the first
/// time it's computed so it doesn't keep drifting as later data comes in.
class CalibrationResult {
  final double expectedKgChange;
  final double observedKgChange;

  /// `observed - expected` — positive means less progress than expected
  /// (lost less / gained more), same sign convention as `KgGapInsight.gapKg`
  /// in `kg_progress.dart`.
  final double gapKg;
  final List<String> explanations; // ranked, most-likely first

  const CalibrationResult({
    required this.expectedKgChange,
    required this.observedKgChange,
    required this.gapKg,
    required this.explanations,
  });

  Map<String, dynamic> toMap(String today) => {
        'observedKgChange': observedKgChange,
        'gapKg': gapKg,
        'explanations': explanations,
        'computedOn': today,
      };
}

CalibrationResult computeResults(AppData data, Map<String, dynamic> calibration, String today) {
  final tdee = _tdeeFor(data);
  final baseline = Map<String, dynamic>.from(calibration['baseline'] as Map);
  final startDate = calibration['startDate'] as String;
  final endDate = calibration['endDate'] as String;
  final expected = (baseline['expectedKgChange'] as num).toDouble();
  final startWeight = (baseline['startWeight'] as num?)?.toDouble();
  // Evaluate at whichever is earlier — the window's own end, or today, if
  // this is being computed (e.g. previewed) before the window is actually
  // over.
  final evalDate = endDate.compareTo(today) < 0 ? endDate : today;
  final endWeight = estimatedWeightOnDate(
    weightLog: data.weight,
    diet: data.diet,
    activity: data.activity,
    tdee: tdee,
    date: evalDate,
    fallbackBaseline: startWeight,
  );
  final observed = (startWeight != null && endWeight != null) ? endWeight - startWeight : 0.0;
  final gap = observed - expected;

  // Deterministic, ranked explanations from data already on hand — not an
  // AI call (that's the separate, opt-in "Ask AI to dig into your data").
  // Rule-triggered ones lead; the two general, always-plausible ones fill
  // out the rest so the list never comes back empty.
  final windowDays = totalDays(calibration);
  var loggedDays = 0;
  num activityKcal = 0;
  for (final date in _lastNDates(endDate, windowDays)) {
    if (date.compareTo(startDate) < 0) continue;
    final meals = data.diet[date];
    if (meals is List && meals.isNotEmpty) loggedDays++;
    activityKcal += ((data.activity[date] as Map?)?['kcal'] as num?) ?? 0;
  }
  final loggingRate = windowDays > 0 ? loggedDays / windowDays : 0.0;
  final avgDailyDeficit = (baseline['deficitKcal'] as num).toDouble();
  final exerciseShare = avgDailyDeficit > 0 ? (activityKcal / windowDays) / avgDailyDeficit : 0.0;

  final explanations = <String>[];
  if (loggingRate < 0.7) {
    explanations.add('Actual intake may be higher than logged — only $loggedDays of $windowDays days were logged.');
  }
  if (exerciseShare > 0.25) {
    explanations.add('Exercise calories may be overestimated — a large share of your deficit assumes activity burn.');
  }
  explanations.add('Your real expenditure may run a bit lower than the estimate this plan was built on.');
  explanations.add('Water and glycogen shifts can mask some fat loss over a 14-day window.');

  return CalibrationResult(expectedKgChange: expected, observedKgChange: observed, gapKg: gap, explanations: explanations);
}

enum CalibrationDayLogStatus {
  both, // weight and food both logged that day
  partial, // one of the two
  missed, // neither, and the day has already passed
  future, // hasn't happened yet — nothing to log yet
}

class CalibrationDayLog {
  final String date;
  final int dayNumber; // 1-based, matches the Day X/Y pill
  final CalibrationDayLogStatus status;
  const CalibrationDayLog({required this.date, required this.dayNumber, required this.status});
}

/// Every day of the calibration window, oldest first, with whether that
/// day's weight/food actually got logged — the data behind the "Your
/// calibration log" grid. A 14-day comparison is only as trustworthy as
/// the logging behind it, so this is the one thing on the dashboard that
/// answers "did I actually keep this up," not just "how's the trend."
List<CalibrationDayLog> computeDayLog(AppData data, Map<String, dynamic> calibration, String today) {
  final start = calibration['startDate'] as String;
  final total = totalDays(calibration);
  final weightDates = data.weight.map((w) => w['date'] as String).toSet();
  return List.generate(total, (i) {
    final date = _addDays(start, i);
    final dayNumber = i + 1;
    if (date.compareTo(today) > 0) {
      return CalibrationDayLog(date: date, dayNumber: dayNumber, status: CalibrationDayLogStatus.future);
    }
    final weightLogged = weightDates.contains(date);
    final meals = data.diet[date];
    final foodLogged = meals is List && meals.isNotEmpty;
    final status = weightLogged && foodLogged
        ? CalibrationDayLogStatus.both
        : (weightLogged || foodLogged)
            ? CalibrationDayLogStatus.partial
            : CalibrationDayLogStatus.missed;
    return CalibrationDayLog(date: date, dayNumber: dayNumber, status: status);
  });
}

/// How far a day's logged number can sit from the target and still count
/// as "held steady" — tight enough to mean something, loose enough that an
/// ordinary day doesn't trip it. Same band used for the tracker's flags and
/// the day-log grid's controlled dot.
const double controlledBandFraction = 0.10;

/// Fraction of already-elapsed days that need to be on-target before a
/// Controlled study's results are trusted enough to write back to the plan.
const double controlledApplyThreshold = 0.70;

bool _withinBand(num actual, num target) => target <= 0 ? true : (actual - target).abs() <= target * controlledBandFraction;

/// One metric's actual-vs-target for one day — [ControlledDayCheck] bundles
/// the three the app already tracks well enough to hold steady (calories,
/// protein, steps). Same defaults `dashboard_stats.dart` falls back to when
/// a goal isn't set, so a day without a custom goal isn't unfairly flagged.
class ControlledDayCheck {
  final num calories;
  final num calorieTarget;
  final num protein;
  final num proteinTarget;
  final num steps;
  final num stepTarget;
  const ControlledDayCheck({
    required this.calories,
    required this.calorieTarget,
    required this.protein,
    required this.proteinTarget,
    required this.steps,
    required this.stepTarget,
  });

  bool get caloriesOk => _withinBand(calories, calorieTarget);
  bool get proteinOk => _withinBand(protein, proteinTarget);
  bool get stepsOk => _withinBand(steps, stepTarget);
  bool get allOk => caloriesOk && proteinOk && stepsOk;
}

ControlledDayCheck computeControlledDayCheck(AppData data, String date) {
  final settings = data.settings;
  final meals = data.diet[date];
  num kcal = 0, protein = 0;
  if (meals is List) {
    for (final m in meals) {
      kcal += ((m as Map)['kcal'] as num?) ?? 0;
      protein += (m['protein'] as num?) ?? 0;
    }
  }
  final steps = ((data.activity[date] as Map?)?['steps'] as num?) ?? 0;
  return ControlledDayCheck(
    calories: kcal,
    calorieTarget: (settings['calorieGoal'] as num?) ?? 2000,
    protein: protein,
    proteinTarget: (settings['proteinGoal'] as num?) ?? 150,
    steps: steps,
    stepTarget: (settings['stepGoal'] as num?) ?? 10000,
  );
}

class ControlledAdherence {
  final int onTargetDays;
  final int elapsedDays;
  const ControlledAdherence({required this.onTargetDays, required this.elapsedDays});
  double get fraction => elapsedDays <= 0 ? 0 : onTargetDays / elapsedDays;
}

/// Already-elapsed window days that landed within band on all three
/// metrics, out of how many have happened so far — the counts both the
/// running dashboard's day-log dots and the results screen's "enough to
/// apply" gate are built from. Days that haven't happened yet don't count
/// against it either way.
ControlledAdherence computeControlledAdherenceDetail(AppData data, Map<String, dynamic> calibration, String today) {
  final start = calibration['startDate'] as String;
  final endDate = calibration['endDate'] as String;
  final lastDay = endDate.compareTo(today) < 0 ? endDate : today;
  final elapsedDays = daysBetween(start, lastDay) + 1;
  if (elapsedDays <= 0) return const ControlledAdherence(onTargetDays: 0, elapsedDays: 0);
  var onTarget = 0;
  for (var i = 0; i < elapsedDays; i++) {
    final date = _addDays(start, i);
    if (computeControlledDayCheck(data, date).allOk) onTarget++;
  }
  return ControlledAdherence(onTargetDays: onTarget, elapsedDays: elapsedDays);
}

double computeControlledAdherence(AppData data, Map<String, dynamic> calibration, String today) =>
    computeControlledAdherenceDetail(data, calibration, today).fraction;

/// The before/after this calibration would write to the plan if applied —
/// re-anchors TDEE to what this window actually observed (holding the same
/// kcal-below-TDEE gap the calorie goal already had), rather than replacing
/// the goal with an unrelated number.
class PlanApplyPreview {
  final num oldTdee;
  final num newTdee;
  final num oldCalorieGoal;
  final num newCalorieGoal;
  const PlanApplyPreview({required this.oldTdee, required this.newTdee, required this.oldCalorieGoal, required this.newCalorieGoal});
}

PlanApplyPreview computePlanApplyPreview(AppData data, Map<String, dynamic> calibration, CalibrationResult result) {
  final baseline = Map<String, dynamic>.from(calibration['baseline'] as Map);
  // Anchor to the plan as it was on Day 1 (frozen in `baseline`), NOT the
  // live plan — otherwise re-opening this screen after applying computes the
  // gap adjustment on top of the already-updated TDEE and the numbers drift
  // by ~dailyGapKcal every visit. Legacy records without the frozen goal
  // fall back to the live values.
  final oldTdee = (baseline['expenditureKcal'] as num?) ?? _tdeeFor(data);
  final oldGoal = (baseline['calorieGoal'] as num?) ?? (data.settings['calorieGoal'] as num?) ?? oldTdee;
  // Positive gapKg = less progress than expected, i.e. the real deficit ran
  // smaller than modeled — meaning actual TDEE is likely lower than the
  // estimate by roughly this much per day (and the reverse when negative).
  final dailyGapKcal = (result.gapKg * kcalPerKg) / totalDays(calibration);
  final newTdee = (oldTdee - dailyGapKcal).round();
  final offset = oldGoal - oldTdee; // the deficit-below-maintenance the plan already targets
  final newGoal = (newTdee + offset).round();
  return PlanApplyPreview(oldTdee: oldTdee, newTdee: newTdee, oldCalorieGoal: oldGoal, newCalorieGoal: newGoal);
}

/// True once a Controlled study has enough on-target days for its result to
/// be trustworthy enough to write back to the plan — see [controlledApplyThreshold].
bool canApplyToPlan(AppData data, Map<String, dynamic> calibration, String today) {
  if (calibration['mode'] != 'controlled') return false;
  return computeControlledAdherence(data, calibration, today) >= controlledApplyThreshold;
}
