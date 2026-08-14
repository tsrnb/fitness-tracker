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
}
