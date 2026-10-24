import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../../../shared/lib/macro_totals.dart';
import 'muscle_models.dart';

class FuelCheck {
  final double surplusKcal; // average intake minus maintenance
  final double proteinPerKg;
  final double avgProtein;
  final int days;
  const FuelCheck(this.surplusKcal, this.proteinPerKg, this.avgProtein, this.days);
}

/// Average over the last 7 days that have food logged. Null below 3 logged
/// days: two meals-days say nothing about a surplus.
FuelCheck? computeFuel(AppData data, String today, double weightKg) {
  var days = 0;
  double kcal = 0, protein = 0;
  for (final e in data.diet.entries) {
    final age = daysBetween(e.key, today);
    if (age < 0 || age >= 7) continue;
    final meals = List<Map<String, dynamic>>.from(e.value as List);
    if (meals.isEmpty) continue;
    final t = sumMacros(meals);
    days++;
    kcal += t.kcal;
    protein += t.protein;
  }
  if (days < 3 || weightKg <= 0) return null;
  final tdee = ((data.plan?['tdee'] ?? data.settings['calorieGoal'] ?? 2000) as num).toDouble();
  return FuelCheck(kcal / days - tdee, protein / days / weightKg, protein / days, days);
}

class GainSnapshot {
  final String startDate; // when the goal began
  final double startWeight;
  final double currentWeight;
  final double goalWeight;
  final double? pace; // kg per week
  final PaceState? state;
  final double nextWholeKg;
  final double? weeksToNext;
  final int weekNumber;
  final FuelCheck? fuel;
  const GainSnapshot({
    required this.startDate,
    required this.startWeight,
    required this.currentWeight,
    required this.goalWeight,
    required this.pace,
    required this.state,
    required this.nextWholeKg,
    required this.weeksToNext,
    required this.weekNumber,
    required this.fuel,
  });

  double get gained => currentWeight - startWeight;
  double get goalGain => goalWeight - startWeight;
  double get fraction => goalGain <= 0 ? 0 : (gained / goalGain).clamp(0.0, 1.0);
  double get remaining => (goalWeight - currentWeight).clamp(0.0, double.infinity);
}

/// Null until there is at least one weigh-in.
GainSnapshot? computeGain(AppData data, MuscleProfile p, String today) {
  final w = data.weight;
  if (w.isEmpty) return null;
  final start = weightOnOrBefore(w, p.setupDate) ?? (w.first['weight'] as num).toDouble();
  final cur = (w.last['weight'] as num).toDouble();
  // Only readings since the goal began say anything about its pace.
  final phase = p.setupDate.isEmpty ? w : [for (final e in w) if ((e['date'] as String).compareTo(p.setupDate) >= 0) e];
  final pace = weightPaceKgPerWeek(phase, today);
  final next = cur.floorToDouble() + 1;
  return GainSnapshot(
    startDate: p.setupDate,
    startWeight: start,
    currentWeight: cur,
    goalWeight: start + p.goalGainKg,
    pace: pace,
    state: pace == null ? null : paceState(pace, p.levelInfo),
    nextWholeKg: next,
    weeksToNext: pace != null && pace > 0.02 ? (next - cur) / pace : null,
    weekNumber: p.setupDate.isEmpty ? 1 : daysBetween(p.setupDate, today) ~/ 7 + 1,
    fuel: computeFuel(data, today, cur),
  );
}

/// What the "Know why" assistant is allowed to see: a compact digest, not
/// the raw logs. Everything here is also visible on the Muscle screen.
Map<String, dynamic> buildMuscleDigest(AppData data, MuscleProfile p, String today, {String? focusLift}) {
  final g = computeGain(data, p, today);
  final lifts = summarizeLifts(data.history, p.tracked);
  final (vc, vp) = volumeLoadWindows(data.history, p.tracked, today);
  final tv = tapeVerdict(p.tape);
  double r1(double v) => double.parse(v.toStringAsFixed(1));
  return {
    'today': today,
    'units': data.settings['units'] ?? 'kg',
    'goalType': data.settings['goalType'],
    'experience': p.level,
    'targetPaceKgPerWeek': {'low': p.levelInfo.lo, 'high': p.levelInfo.hi},
    if (focusLift != null) 'focusLift': focusLift,
    'weight': {
      'recent': [
        for (final e in data.weight.length > 16 ? data.weight.sublist(data.weight.length - 16) : data.weight) {'date': e['date'], 'kg': e['weight']}
      ],
      if (g != null) ...{
        'start': r1(g.startWeight),
        'current': r1(g.currentWeight),
        'goal': r1(g.goalWeight),
        'gainedKg': r1(g.gained),
        'weekOfPhase': g.weekNumber,
        if (g.pace != null) 'paceKgPerWeek': double.parse(g.pace!.toStringAsFixed(2)),
        if (g.state != null) 'paceVerdict': g.state!.name,
      },
    },
    'lifts': [
      for (final l in lifts)
        {
          'name': l.name,
          'e1rmLast8Sessions': l.recentE1rm(),
          'deltaVsPreviousSession': l.delta,
          'newPr': l.isPr,
          'lastTopSet': '${l.last.topWeight} kg x ${l.last.topReps}',
          'lastSessionDate': l.last.date,
          if (l.volumeChangePct != null) 'volumeChangePct': r1(l.volumeChangePct!),
        }
    ],
    'weeklyVolumeLoad': {'thisWeek': vc.round(), 'lastWeek': vp.round()},
    if (g?.fuel != null)
      'fuel': {
        'avgSurplusKcal': g!.fuel!.surplusKcal.round(),
        'avgProteinG': g.fuel!.avgProtein.round(),
        'proteinGPerKg': r1(g.fuel!.proteinPerKg),
        'daysLogged': g.fuel!.days,
      },
    'tape': {
      'entries': [for (final t in p.tape) t.toJson()],
      if (tv != null) 'verdict': tv.label,
      if (tv != null) 'changesCm': tv.deltas,
    },
    'sessionsLast7Days': lastNDaysEntries(data.sessions, today, 7).length,
  };
}
