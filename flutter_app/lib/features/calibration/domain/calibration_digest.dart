import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../../insights/domain/insights_engine.dart';
import 'calibration_engine.dart';

/// Compact, model-facing summaries of a calibration's data — the payloads
/// behind every AI surface in the feature. Pure functions over [AppData]
/// plus the `calibration` record, no Flutter, same shape convention as
/// `calibration_engine.dart`.
///
/// Three builders, three jobs:
///  - [buildCalibrationDigest] — derived daily totals + splits, fed to the
///    end-of-window result analysis. Small.
///  - [buildFullCalibrationContext] — the raw record (individual meals,
///    every weigh-in with its time, each workout's sets), fed to the
///    user-triggered "Ask AI" deep dive and its follow-up chat.
///  - [buildPreflightDigest] — logging history + intake spread over the
///    3 weeks before Day 1, fed to the mode screen's pre-flight check.

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _addDays(String date, int n) =>
    _fmtDate(DateTime.parse('${date}T00:00:00').add(Duration(days: n)));

/// 1 = Mon … 6 = Sat, 7 = Sun.
bool _isWeekend(String date) {
  final wd = DateTime.parse('${date}T00:00:00').weekday;
  return wd == 6 || wd == 7;
}

num _tdeeFor(AppData data) =>
    (data.plan?['tdee'] as num?) ?? (data.settings['calorieGoal'] as num?) ?? 2000;

List<Map<String, dynamic>> _mealsFor(AppData data, String date) {
  final raw = data.diet[date];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

_DayTotals _totalsFor(AppData data, String date) {
  num kcal = 0, protein = 0, carb = 0, fat = 0;
  final meals = _mealsFor(data, date);
  for (final m in meals) {
    kcal += (m['kcal'] as num?) ?? 0;
    protein += (m['protein'] as num?) ?? 0;
    carb += (m['carb'] as num?) ?? 0;
    fat += (m['fat'] as num?) ?? 0;
  }
  return _DayTotals(kcal: kcal, protein: protein, carb: carb, fat: fat, mealCount: meals.length, logged: meals.isNotEmpty);
}

class _DayTotals {
  final num kcal, protein, carb, fat;
  final int mealCount;
  final bool logged;
  const _DayTotals({
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
    required this.mealCount,
    required this.logged,
  });
}

/// Elapsed window days, oldest first, clamped to today so an unfinished
/// window doesn't emit empty future rows.
List<String> _elapsedDates(Map<String, dynamic> calibration, String today) {
  final start = calibration['startDate'] as String;
  final total = totalDays(calibration);
  final out = <String>[];
  for (var i = 0; i < total; i++) {
    final d = _addDays(start, i);
    if (d.compareTo(today) > 0) break;
    out.add(d);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 1. End-of-window digest — derived totals + the splits the analysis leans on
// ---------------------------------------------------------------------------

Map<String, dynamic> buildCalibrationDigest(AppData data, Map<String, dynamic> calibration, String today) {
  final baseline = Map<String, dynamic>.from(calibration['baseline'] as Map);
  final tdee = _tdeeFor(data);
  final goal = (data.settings['calorieGoal'] as num?) ?? tdee;
  final dates = _elapsedDates(calibration, today);

  final days = <Map<String, dynamic>>[];
  num weekdayDeficitSum = 0, weekendDeficitSum = 0;
  int weekdayCount = 0, weekendCount = 0, loggedCount = 0;

  for (var i = 0; i < dates.length; i++) {
    final date = dates[i];
    final t = _totalsFor(data, date);
    final act = data.activity[date] as Map?;
    final steps = (act?['steps'] as num?)?.round() ?? 0;
    final actKcal = (act?['kcal'] as num?)?.round() ?? 0;
    final weighIn = data.weight.where((w) => w['date'] == date).map((w) => (w['weight'] as num).toDouble()).toList();
    final weekend = _isWeekend(date);

    if (t.logged) {
      loggedCount++;
      final deficit = (tdee + actKcal) - t.kcal;
      if (weekend) {
        weekendDeficitSum += deficit;
        weekendCount++;
      } else {
        weekdayDeficitSum += deficit;
        weekdayCount++;
      }
    }

    days.add({
      'd': i + 1,
      'date': date,
      'dow': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.parse('${date}T00:00:00').weekday - 1],
      if (t.logged) 'kcal': t.kcal.round(),
      if (t.logged) 'protein': t.protein.round(),
      if (t.logged) 'carb': t.carb.round(),
      if (t.logged) 'fat': t.fat.round(),
      'steps': steps,
      if (actKcal > 0) 'activityKcal': actKcal,
      if (weighIn.isNotEmpty) 'kg': double.parse(weighIn.first.toStringAsFixed(2)),
      'logged': t.logged,
    });
  }

  return {
    'window': totalDays(calibration),
    'mode': calibration['mode'] ?? 'observe',
    'baseline': {
      'intakeKcal': (baseline['intakeKcal'] as num?)?.round(),
      'tdee': (baseline['expenditureKcal'] as num?)?.round(),
      'deficitKcal': (baseline['deficitKcal'] as num?)?.round(),
      'expectedKgChange': (baseline['expectedKgChange'] as num?)?.toStringAsFixed(2),
      'startWeight': (baseline['startWeight'] as num?)?.toStringAsFixed(2),
    },
    'plan': {'tdee': tdee.round(), 'calorieGoal': goal.round()},
    'loggedDays': loggedCount,
    'weekdayDeficitAvg': weekdayCount > 0 ? (weekdayDeficitSum / weekdayCount).round() : null,
    'weekendDeficitAvg': weekendCount > 0 ? (weekendDeficitSum / weekendCount).round() : null,
    'days': days,
    'ruleFlags': _ruleFlags(data, today),
  };
}

// ---------------------------------------------------------------------------
// 2. Full raw context — the deep-dive payload
// ---------------------------------------------------------------------------

Map<String, dynamic> buildFullCalibrationContext(AppData data, Map<String, dynamic> calibration, String today) {
  final baseline = Map<String, dynamic>.from(calibration['baseline'] as Map);
  final start = calibration['startDate'] as String;
  final dates = _elapsedDates(calibration, today);

  final weighins = <Map<String, dynamic>>[];
  for (final w in data.weight) {
    final date = w['date'] as String?;
    if (date == null || date.compareTo(start) < 0 || date.compareTo(today) > 0) continue;
    weighins.add({
      'd': daysBetween(start, date) + 1,
      'date': date,
      'kg': double.parse((w['weight'] as num).toStringAsFixed(2)),
      if (w['at'] != null) 'at': w['at'],
    });
  }
  weighins.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

  final days = <Map<String, dynamic>>[];
  for (var i = 0; i < dates.length; i++) {
    final date = dates[i];
    final t = _totalsFor(data, date);
    final meals = _mealsFor(data, date)
        .map((m) => {
              'name': (m['name'] as String?)?.trim() ?? 'item',
              'kcal': ((m['kcal'] as num?) ?? 0).round(),
              'p': ((m['protein'] as num?) ?? 0).round(),
              'c': ((m['carb'] as num?) ?? 0).round(),
              'f': ((m['fat'] as num?) ?? 0).round(),
            })
        .toList();
    final act = data.activity[date] as Map?;
    final sess = data.sessions[date] as Map?;

    Map<String, dynamic>? workout;
    if (sess != null) {
      final dayType = sess['day'] as String?;
      final exercises = <Map<String, dynamic>>[];
      data.history.forEach((exName, entries) {
        if (entries is! List) return;
        for (final e in entries) {
          if (e is Map && e['date'] == date) {
            final sets = (e['sets'] as List?)
                    ?.whereType<Map>()
                    .map((s) => {'w': (s['weight'] as num?)?.toDouble() ?? 0, 'reps': (s['reps'] as num?)?.round() ?? 0})
                    .toList() ??
                const [];
            exercises.add({'ex': exName, 'sets': sets});
          }
        }
      });
      workout = {if (dayType != null) 'type': dayType, 'exercises': exercises};
    }

    days.add({
      'd': i + 1,
      'date': date,
      'dow': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.parse('${date}T00:00:00').weekday - 1],
      'meals': meals,
      if (t.logged) 'kcal': t.kcal.round(),
      if (t.logged) 'protein': t.protein.round(),
      if (t.logged) 'carb': t.carb.round(),
      if (t.logged) 'fat': t.fat.round(),
      'steps': (act?['steps'] as num?)?.round() ?? 0,
      if ((act?['kcal'] as num?) != null) 'activityKcal': (act!['kcal'] as num).round(),
      if ((act?['min'] as num?) != null && (act!['min'] as num) > 0) 'cardioMin': (act['min'] as num).round(),
      if (workout != null) 'workout': workout,
      'logged': t.logged,
    });
  }

  return {
    'day': dayNumber(calibration, today),
    'window': totalDays(calibration),
    'mode': calibration['mode'] ?? 'observe',
    if (calibration['modeSince'] != null && calibration['modeSince'] != start)
      'modeSwitchedOn': calibration['modeSince'],
    'baseline': {
      'intakeKcal': (baseline['intakeKcal'] as num?)?.round(),
      'tdee': (baseline['expenditureKcal'] as num?)?.round(),
      'deficitKcal': (baseline['deficitKcal'] as num?)?.round(),
      'expectedKgChange': (baseline['expectedKgChange'] as num?)?.toStringAsFixed(2),
      'startWeight': (baseline['startWeight'] as num?)?.toStringAsFixed(2),
    },
    'plan': {
      'tdee': _tdeeFor(data).round(),
      'calorieGoal': (data.settings['calorieGoal'] as num?)?.round(),
      'proteinGoal': (data.settings['proteinGoal'] as num?)?.round(),
      'stepGoal': (data.settings['stepGoal'] as num?)?.round(),
    },
    'weighins': weighins,
    'days': days,
    'ruleFlags': _ruleFlags(data, today),
  };
}

// ---------------------------------------------------------------------------
// 3. Pre-flight digest — the 21 days before Day 1
// ---------------------------------------------------------------------------

/// Deterministic readiness read on its own — the non-AI fallback the mode
/// screen shows when the proxy is unset.
class PreflightReadiness {
  final int windowDays;
  final int foodLoggedDays;
  final int weighInDays;
  final int weekendDays;
  final int weekendLoggedDays;
  final double intakeCv; // coefficient of variation across logged days
  final int avgIntake;

  const PreflightReadiness({
    required this.windowDays,
    required this.foodLoggedDays,
    required this.weighInDays,
    required this.weekendDays,
    required this.weekendLoggedDays,
    required this.intakeCv,
    required this.avgIntake,
  });

  double get foodRate => windowDays > 0 ? foodLoggedDays / windowDays : 0;
  double get weighInRate => windowDays > 0 ? weighInDays / windowDays : 0;

  /// Enough signal to calibrate at all — matches the 0.7 logging bar the
  /// result explanations already use as their "trust this" threshold.
  bool get readyToCalibrate => foodRate >= 0.7 && weighInRate >= 0.6;

  /// A swingy eater gets more out of Observe; a steady one can hold a
  /// Controlled window without fighting their own habits.
  String get suggestedMode => intakeCv >= 0.18 ? 'observe' : 'controlled';
}

const int preflightWindowDays = 21;

PreflightReadiness computePreflightReadiness(AppData data, String today) {
  var food = 0, weighIns = 0, weekend = 0, weekendLogged = 0;
  final intakes = <num>[];
  final weightDates = data.weight.map((w) => w['date'] as String?).whereType<String>().toSet();

  for (var i = 0; i < preflightWindowDays; i++) {
    final date = _addDays(today, -(i + 1));
    final weekendDay = _isWeekend(date);
    if (weekendDay) weekend++;
    final t = _totalsFor(data, date);
    if (t.logged) {
      food++;
      intakes.add(t.kcal);
      if (weekendDay) weekendLogged++;
    }
    if (weightDates.contains(date)) weighIns++;
  }

  double cv = 0;
  int avg = 0;
  if (intakes.isNotEmpty) {
    final mean = intakes.reduce((a, b) => a + b) / intakes.length;
    avg = mean.round();
    if (mean > 0 && intakes.length > 1) {
      final variance = intakes.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / intakes.length;
      cv = _sqrt(variance) / mean;
    }
  }

  return PreflightReadiness(
    windowDays: preflightWindowDays,
    foodLoggedDays: food,
    weighInDays: weighIns,
    weekendDays: weekend,
    weekendLoggedDays: weekendLogged,
    intakeCv: double.parse(cv.toStringAsFixed(3)),
    avgIntake: avg,
  );
}

double _sqrt(num x) {
  if (x <= 0) return 0;
  var g = x.toDouble();
  for (var i = 0; i < 24; i++) {
    g = (g + x / g) / 2;
  }
  return g;
}

Map<String, dynamic> buildPreflightDigest(AppData data, String today) {
  final r = computePreflightReadiness(data, today);
  return {
    'window': r.windowDays,
    'foodLogged': '${r.foodLoggedDays} / ${r.windowDays}',
    'weighIns': '${r.weighInDays} / ${r.windowDays}',
    'weekendLogged': '${r.weekendLoggedDays} / ${r.weekendDays}',
    'avgIntakeKcal': r.avgIntake,
    'intakeCv': r.intakeCv,
    'plan': {
      'tdee': _tdeeFor(data).round(),
      'calorieGoal': (data.settings['calorieGoal'] as num?)?.round(),
    },
  };
}

// ---------------------------------------------------------------------------

List<String> _ruleFlags(AppData data, String today) {
  try {
    return InsightsEngine.evaluateAll(data, today).map((i) => i.message).toList();
  } catch (_) {
    return const [];
  }
}
