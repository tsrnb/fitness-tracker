// Unit tests for the Next Kg screen's math (domain/kg_progress.dart) —
// the part actually worth testing hard, since a bug here either shows
// someone a kg they haven't earned or silently withholds one they have.
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/features/progress/domain/kg_progress.dart';

Map<String, dynamic> _meals(int kcal) => {
      'x': [
        {'kcal': kcal, 'protein': 0}
      ]
    };

void main() {
  group('computeKgProgress', () {
    test('no diet entries at all -> nothing reached, nothing in progress', () {
      final p = computeKgProgress(diet: {}, activity: {}, tdee: 2000);
      expect(p.reached, isEmpty);
      expect(p.currentKcal, 0);
      expect(p.currentFraction, 0);
      expect(p.currentNumber, 1);
    });

    test('a day with an empty meal list is skipped, not treated as a full-TDEE deficit', () {
      final diet = {'2026-08-01': <dynamic>[]};
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000);
      expect(p.reached, isEmpty);
      expect(p.currentKcal, 0);
    });

    test('logged days accumulate true deficit (tdee - (kcal - burned))', () {
      final diet = {
        '2026-08-01': _meals(1500)['x'], // 500 deficit at tdee 2000
        '2026-08-02': _meals(1600)['x'], // 400 deficit
      };
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000);
      expect(p.currentKcal, 900);
      expect(p.reached, isEmpty);
    });

    test('activity burned on a day adds to that day\'s deficit', () {
      final diet = {'2026-08-01': _meals(1800)['x']}; // 200 deficit before activity
      final activity = {
        '2026-08-01': {'kcal': 300}
      };
      final p = computeKgProgress(diet: diet, activity: activity, tdee: 2000);
      expect(p.currentKcal, 500); // 2000 - (1800 - 300)
    });

    test('crossing exactly 7,700 kcal reaches kg 1 with zero left over', () {
      final diet = {'2026-08-01': _meals(2000 - kcalPerKg)['x']}; // one huge single-day deficit
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000);
      expect(p.reached.length, 1);
      expect(p.reached.single.number, 1);
      expect(p.reached.single.date, '2026-08-01');
      expect(p.currentKcal, 0);
    });

    test('a single day can cross more than one kg at once', () {
      final diet = {'2026-08-01': _meals(2000 - (2 * kcalPerKg + 500))['x']};
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000);
      expect(p.reached.map((m) => m.number), [1, 2]);
      expect(p.reached.every((m) => m.date == '2026-08-01'), isTrue);
      expect(p.currentKcal, 500);
    });

    test('milestones are dated on the day they were crossed, across multiple days', () {
      final diet = {
        '2026-08-01': _meals(2000 - 5000)['x'], // +5000, running total 5000
        '2026-08-02': _meals(2000 - 3000)['x'], // +3000, running total 8000 -> crosses kg 1 with 300 left
      };
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000);
      expect(p.reached.single.date, '2026-08-02');
      expect(p.currentKcal, 300);
    });

    test('a reached milestone is never un-earned by later surplus days', () {
      final diet = {
        '2026-08-01': _meals(2000 - kcalPerKg)['x'], // reaches kg 1 exactly
        '2026-08-02': _meals(4000)['x'], // big surplus afterwards
      };
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000);
      expect(p.reached.length, 1);
      // currentKcal goes negative (a stalled/regressed current leg), but the
      // earned kg stays earned.
      expect(p.currentKcal, lessThan(0));
      expect(p.currentFraction, 0); // clamped for display
    });

    test('unsorted map keys are still processed in date order', () {
      final diet = {
        '2026-08-03': _meals(2000 - 1000)['x'],
        '2026-08-01': _meals(2000 - 1000)['x'],
        '2026-08-02': _meals(2000 - 1000)['x'],
      };
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000);
      expect(p.currentKcal, 3000);
    });
  });

  group('computeKgWindow', () {
    test('un-logged days show as logged:false and are excluded from the average', () {
      final diet = {
        '2026-08-13': _meals(1500)['x'], // 500 deficit
        // 08-14 missing entirely
      };
      final w = computeKgWindow(diet: diet, activity: {}, tdee: 2000, today: '2026-08-14', remainingKcal: 5000, windowSize: 2);
      expect(w.days.map((d) => d.date), ['2026-08-13', '2026-08-14']);
      expect(w.days[0].logged, isTrue);
      expect(w.days[1].logged, isFalse);
      expect(w.daysLogged, 1);
      expect(w.avgDeficitPerLoggedDay, 500);
    });

    test('eta is null when there is no positive average to project from', () {
      final w = computeKgWindow(diet: {}, activity: {}, tdee: 2000, today: '2026-08-14', remainingKcal: 5000, windowSize: 7);
      expect(w.daysLogged, 0);
      expect(w.etaDays, isNull);
    });

    test('eta is 0 once remaining kcal is already covered', () {
      final w = computeKgWindow(diet: {}, activity: {}, tdee: 2000, today: '2026-08-14', remainingKcal: -50, windowSize: 7);
      expect(w.etaDays, 0);
    });

    test('eta projects remaining kcal at the trailing logged-day average, rounded up', () {
      final diet = {
        '2026-08-13': _meals(1500)['x'], // 500 deficit
        '2026-08-14': _meals(1500)['x'], // 500 deficit
      };
      final w = computeKgWindow(diet: diet, activity: {}, tdee: 2000, today: '2026-08-14', remainingKcal: 950, windowSize: 2);
      expect(w.avgDeficitPerLoggedDay, 500);
      expect(w.etaDays, 2); // ceil(950 / 500)
    });

    test('a net-surplus window (negative average) has no eta, not a negative one', () {
      final diet = {
        '2026-08-13': _meals(3000)['x'], // -1000 (surplus) at tdee 2000
      };
      final w = computeKgWindow(diet: diet, activity: {}, tdee: 2000, today: '2026-08-13', remainingKcal: 5000, windowSize: 1);
      expect(w.avgDeficitPerLoggedDay, -1000);
      expect(w.etaDays, isNull);
    });
  });

  group('computeKgDayDetail', () {
    test('reports eaten/tdee/burned/deficit for a single date', () {
      final diet = {'2026-08-13': _meals(1840)['x']};
      final activity = {
        '2026-08-13': {'kcal': 210}
      };
      final d = computeKgDayDetail(diet, activity, '2026-08-13', 2470);
      expect(d.eaten, 1840);
      expect(d.tdee, 2470);
      expect(d.burned, 210);
      expect(d.deficit, 840); // 2470 - (1840 - 210)
    });

    test('a date with nothing logged reports zero eaten, not an error', () {
      final d = computeKgDayDetail({}, {}, '2026-08-13', 2000);
      expect(d.eaten, 0);
      expect(d.deficit, 2000);
    });
  });

  group('estimatedWeightOnDate', () {
    test('no weight log and no fallback -> null', () {
      final w = estimatedWeightOnDate(weightLog: [], diet: {}, activity: {}, tdee: 2000, date: '2026-08-14');
      expect(w, isNull);
    });

    test('no weight log, but a fallback baseline given -> the fallback', () {
      final w = estimatedWeightOnDate(weightLog: [], diet: {}, activity: {}, tdee: 2000, date: '2026-08-14', fallbackBaseline: 80.0);
      expect(w, 80.0);
    });

    test('the exact anchor date returns that weigh-in verbatim, ignoring the food log', () {
      final weightLog = [
        {'date': '2026-08-10', 'weight': 78.5}
      ];
      final diet = {'2026-08-10': _meals(500)['x']}; // would otherwise suggest a huge deficit
      final w = estimatedWeightOnDate(weightLog: weightLog, diet: diet, activity: {}, tdee: 2000, date: '2026-08-10');
      expect(w, 78.5);
    });

    test('a date after the anchor subtracts food-log kg lost since then', () {
      final weightLog = [
        {'date': '2026-08-10', 'weight': 78.0}
      ];
      final diet = {
        '2026-08-11': _meals(2000 - 3850)['x'], // 3850 deficit -> 0.5kg
        '2026-08-12': _meals(2000 - 3850)['x'], // another 0.5kg
      };
      final w = estimatedWeightOnDate(weightLog: weightLog, diet: diet, activity: {}, tdee: 2000, date: '2026-08-12');
      expect(w, closeTo(77.0, 0.001));
    });

    test('a date before the anchor adds back food-log kg lost between then and the anchor', () {
      final weightLog = [
        {'date': '2026-08-12', 'weight': 77.0}
      ];
      final diet = {
        '2026-08-11': _meals(2000 - 3850)['x'],
        '2026-08-12': _meals(2000 - 3850)['x'],
      };
      final w = estimatedWeightOnDate(weightLog: weightLog, diet: diet, activity: {}, tdee: 2000, date: '2026-08-10');
      expect(w, closeTo(78.0, 0.001));
    });

    test('picks whichever logged weigh-in is nearest in either direction', () {
      final weightLog = [
        {'date': '2026-08-01', 'weight': 82.0},
        {'date': '2026-08-20', 'weight': 76.0},
      ];
      // 2026-08-15 is 14 days after the first entry and 5 days before the
      // second -> anchors to Aug 20, not Aug 1, regardless of map order.
      final w = estimatedWeightOnDate(weightLog: weightLog.reversed.toList(), diet: {}, activity: {}, tdee: 2000, date: '2026-08-15');
      expect(w, 76.0); // no diet entries in range -> no drift applied, exact anchor value
    });
  });

  group('computeKgProgress — weight calibration', () {
    test('a milestone gets a real weight label anchored to the weigh-in nearest its date', () {
      final diet = {'2026-08-10': _meals(2000 - kcalPerKg)['x']}; // reaches kg 1 on 08-10
      final weightLog = [
        {'date': '2026-08-10', 'weight': 79.0}
      ];
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000, weightLog: weightLog);
      expect(p.reached.single.weight, 79.0);
    });

    test('with no weight log and no fallback, milestone weight is null (abstract "kg N" fallback)', () {
      final diet = {'2026-08-10': _meals(2000 - kcalPerKg)['x']};
      final p = computeKgProgress(diet: diet, activity: {}, tdee: 2000);
      expect(p.reached.single.weight, isNull);
    });

    test('currentWeight is only computed when `today` is provided', () {
      final weightLog = [
        {'date': '2026-08-10', 'weight': 79.0}
      ];
      final withoutToday = computeKgProgress(diet: {}, activity: {}, tdee: 2000, weightLog: weightLog);
      expect(withoutToday.currentWeight, isNull);

      final withToday = computeKgProgress(diet: {}, activity: {}, tdee: 2000, weightLog: weightLog, today: '2026-08-10');
      expect(withToday.currentWeight, 79.0);
    });
  });

  group('computeLatestGap', () {
    test('fewer than two weigh-ins -> null', () {
      final g = computeLatestGap(weightLog: [
        {'date': '2026-08-10', 'weight': 79.0}
      ], diet: {}, activity: {}, tdee: 2000);
      expect(g, isNull);
    });

    test('actual matches the food-log prediction within the threshold -> null', () {
      final weightLog = [
        {'date': '2026-08-01', 'weight': 80.0},
        {'date': '2026-08-08', 'weight': 79.5}, // food log predicts ~79.5 too
      ];
      final diet = <String, dynamic>{};
      for (var i = 2; i <= 7; i++) {
        diet['2026-08-0$i'] = _meals(2000 - (500 / 6).round())['x']; // ~0.5kg total over the week
      }
      final g = computeLatestGap(weightLog: weightLog, diet: diet, activity: {}, tdee: 2000);
      expect(g, isNull);
    });

    test('a real gap beyond the threshold is reported with the right numbers', () {
      final weightLog = [
        {'date': '2026-08-01', 'weight': 80.0},
        {'date': '2026-08-08', 'weight': 80.2}, // scale barely moved (even ticked up)...
      ];
      final diet = {
        '2026-08-03': _meals(2000 - kcalPerKg)['x'], // ...despite the food log implying a full kg lost
      };
      final g = computeLatestGap(weightLog: weightLog, diet: diet, activity: {}, tdee: 2000);
      expect(g, isNotNull);
      expect(g!.previousDate, '2026-08-01');
      expect(g.previousWeight, 80.0);
      expect(g.latestDate, '2026-08-08');
      expect(g.actualWeight, 80.2);
      expect(g.predictedWeight, closeTo(79.0, 0.001));
      expect(g.gapKg, closeTo(1.2, 0.001)); // actual - predicted
      expect(g.daysBetween, 7);
      expect(g.daysLogged, 1);
    });

    test('a custom, tighter threshold catches smaller gaps', () {
      final weightLog = [
        {'date': '2026-08-01', 'weight': 80.0},
        {'date': '2026-08-08', 'weight': 79.7}, // 0.2kg off the ~79.5 prediction below
      ];
      final diet = <String, dynamic>{};
      for (var i = 2; i <= 7; i++) {
        diet['2026-08-0$i'] = _meals(2000 - (500 / 6).round())['x'];
      }
      final loose = computeLatestGap(weightLog: weightLog, diet: diet, activity: {}, tdee: 2000);
      expect(loose, isNull);
      final tight = computeLatestGap(weightLog: weightLog, diet: diet, activity: {}, tdee: 2000, thresholdKg: 0.1);
      expect(tight, isNotNull);
    });
  });

  group('computeNextWholeKg', () {
    test('null current weight -> null', () {
      expect(computeNextWholeKg(null), isNull);
    });

    test('a fractional weight targets the whole number just below it', () {
      final r = computeNextWholeKg(75.4);
      expect(r, isNotNull);
      expect(r!.target, 75.0);
      expect(r.gap, closeTo(0.4, 0.001));
    });

    test('sitting exactly on a whole number targets a full kg further down, not 0', () {
      final r = computeNextWholeKg(75.0);
      expect(r, isNotNull);
      expect(r!.target, 74.0);
      expect(r.gap, closeTo(1.0, 0.001));
    });

    test('the gap is always positive, regardless of how close', () {
      final r = computeNextWholeKg(75.001);
      expect(r!.gap, greaterThan(0));
      expect(r.target, 75.0);
    });
  });
}
