// Unit tests for every AI-insight trigger rule (domain/insight_rules.dart)
// — each rule is a pure function of AppData, so these check both that a
// rule fires when it genuinely should and, just as importantly, that it
// stays quiet on data that only superficially resembles the trigger.
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/app/app_state.dart';
import 'package:cuttracker/features/insights/domain/insight.dart';
import 'package:cuttracker/features/insights/domain/insight_rules.dart';
import 'package:cuttracker/features/insights/domain/insights_engine.dart';

Map<String, dynamic> _meal(int kcal, {int protein = 0}) => {'kcal': kcal, 'protein': protein};

AppData _data({
  Map<String, dynamic> settings = const {},
  Map<String, dynamic>? plan,
  List<Map<String, dynamic>> weight = const [],
  Map<String, dynamic> diet = const {},
  Map<String, dynamic> activity = const {},
  Map<String, dynamic> history = const {},
}) =>
    AppData(settings: settings, plan: plan, weight: weight, diet: diet, activity: activity, history: history);

void main() {
  group('checkWeightLogGap', () {
    test('maintain goal never fires, regardless of gap', () {
      final data = _data(settings: {'goalType': 'maintain'}, weight: [
        {'date': '2026-01-01', 'weight': 80.0}
      ]);
      expect(checkWeightLogGap(data, '2026-08-20'), isNull);
    });

    test('no weigh-in logged at all -> the "never logged" message', () {
      final data = _data(settings: {'goalType': 'fatLoss'});
      final i = checkWeightLogGap(data, '2026-08-20');
      expect(i, isNotNull);
      expect(i!.message, contains("haven't logged"));
      expect(i.actionLabel, 'Log weight');
    });

    test('a recent weigh-in (< 10 days) does not fire', () {
      final data = _data(settings: {'goalType': 'fatLoss'}, weight: [
        {'date': '2026-08-12', 'weight': 80.0}
      ]);
      expect(checkWeightLogGap(data, '2026-08-20'), isNull); // 8 days
    });

    test('a 10+ day gap fires with the gap length in the message', () {
      final data = _data(settings: {'goalType': 'fatLoss'}, weight: [
        {'date': '2026-08-09', 'weight': 80.0}
      ]);
      final i = checkWeightLogGap(data, '2026-08-20'); // 11 days
      expect(i, isNotNull);
      expect(i!.message, contains('11 days'));
      expect(i.id, 'weight-log-gap:2026-08-20');
    });

    test('picks the most recent entry even when the weight log is unsorted', () {
      final data = _data(settings: {'goalType': 'weightGain'}, weight: [
        {'date': '2026-08-01', 'weight': 70.0},
        {'date': '2026-08-18', 'weight': 71.0}, // most recent, 2 days ago
        {'date': '2026-08-05', 'weight': 70.5},
      ]);
      expect(checkWeightLogGap(data, '2026-08-20'), isNull);
    });
  });

  group('checkSustainedDeficit', () {
    // bmr 1600, sex male -> floor = max(1600, 1500) = 1600
    Map<String, dynamic> planWith(double bmr) => {'bmr': bmr, 'tdee': 2400};

    test('not a fatLoss goal -> never fires', () {
      final diet = {for (var i = 1; i <= 7; i++) '2026-08-1$i': [_meal(1000)]};
      final data = _data(settings: {'goalType': 'weightGain', 'sex': 'male'}, plan: planWith(1600), diet: diet);
      expect(checkSustainedDeficit(data, '2026-08-20'), isNull);
    });

    test('no plan/bmr on file -> never fires (nothing to compute a floor from)', () {
      final diet = {for (var i = 1; i <= 7; i++) '2026-08-1$i': [_meal(1000)]};
      final data = _data(settings: {'goalType': 'fatLoss', 'sex': 'male'}, diet: diet);
      expect(checkSustainedDeficit(data, '2026-08-20'), isNull);
    });

    test('eating comfortably above the floor all week -> quiet', () {
      final dates = ['2026-08-14', '2026-08-15', '2026-08-16', '2026-08-17', '2026-08-18', '2026-08-19', '2026-08-20'];
      final diet = {for (final d in dates) d: [_meal(2000)]}; // well above the 1600 floor
      final data = _data(settings: {'goalType': 'fatLoss', 'sex': 'male'}, plan: planWith(1600), diet: diet);
      expect(checkSustainedDeficit(data, '2026-08-20'), isNull);
    });

    test('under the floor on 5+ of the last 7 logged days fires', () {
      final dates = ['2026-08-14', '2026-08-15', '2026-08-16', '2026-08-17', '2026-08-18', '2026-08-19', '2026-08-20'];
      final diet = {for (final d in dates) d: [_meal(1200)]}; // under the 1600 floor every day
      final data = _data(settings: {'goalType': 'fatLoss', 'sex': 'male'}, plan: planWith(1600), diet: diet);
      final i = checkSustainedDeficit(data, '2026-08-20');
      expect(i, isNotNull);
      expect(i!.message, contains('7 of your last 7'));
    });

    test('only 3 of 7 days under the floor -> not "sustained" yet', () {
      final diet = {
        '2026-08-18': [_meal(1200)],
        '2026-08-19': [_meal(1200)],
        '2026-08-20': [_meal(1200)],
      };
      final data = _data(settings: {'goalType': 'fatLoss', 'sex': 'male'}, plan: planWith(1600), diet: diet);
      expect(checkSustainedDeficit(data, '2026-08-20'), isNull);
    });
  });

  group('checkProteinShortfall', () {
    test('no protein goal set -> never fires', () {
      final dates = ['2026-08-17', '2026-08-18', '2026-08-19', '2026-08-20'];
      final diet = {for (final d in dates) d: [_meal(1800, protein: 20)]};
      final data = _data(settings: {'goalType': 'fatLoss', 'proteinGoal': 0}, diet: diet);
      expect(checkProteinShortfall(data, '2026-08-20'), isNull);
    });

    test('hitting protein goal most days -> quiet', () {
      final dates = ['2026-08-17', '2026-08-18', '2026-08-19', '2026-08-20'];
      final diet = {for (final d in dates) d: [_meal(1800, protein: 150)]}; // >= 90% of 150
      final data = _data(settings: {'goalType': 'fatLoss', 'proteinGoal': 150}, diet: diet);
      expect(checkProteinShortfall(data, '2026-08-20'), isNull);
    });

    test('missing goal 4+ of the last 7 logged days fires', () {
      final diet = {
        '2026-08-17': [_meal(1800, protein: 60)],
        '2026-08-18': [_meal(1800, protein: 65)],
        '2026-08-19': [_meal(1800, protein: 70)],
        '2026-08-20': [_meal(1800, protein: 55)],
      };
      final data = _data(settings: {'goalType': 'fatLoss', 'proteinGoal': 150}, diet: diet);
      final i = checkProteinShortfall(data, '2026-08-20');
      expect(i, isNotNull);
      expect(i!.message, contains('4 of your last 4'));
    });
  });

  group('checkPlateauDespiteDeficit', () {
    test('fewer than 2 weigh-ins -> never fires', () {
      final data = _data(settings: {'goalType': 'fatLoss'}, plan: {'tdee': 2000}, weight: [
        {'date': '2026-08-01', 'weight': 80.0}
      ]);
      expect(checkPlateauDespiteDeficit(data, '2026-08-20'), isNull);
    });

    test('the scale actually moved -> not a plateau, even with a matching deficit', () {
      final weight = [
        {'date': '2026-07-01', 'weight': 82.0},
        {'date': '2026-07-25', 'weight': 80.0}, // real 2kg loss
      ];
      final diet = {'2026-07-10': [_meal(0)]}; // ~7700/7700 = 1kg implied
      final data = _data(settings: {'goalType': 'fatLoss'}, plan: {'tdee': 2000}, weight: weight, diet: diet);
      expect(checkPlateauDespiteDeficit(data, '2026-08-20'), isNull);
    });

    test('flat scale but a real implied loss over 3+ weeks fires', () {
      final weight = [
        {'date': '2026-07-01', 'weight': 80.0},
        {'date': '2026-07-25', 'weight': 80.1}, // 24 days, essentially flat
      ];
      final diet = {'2026-07-10': [_meal(0)]}; // tdee 2000 -> 2000 deficit that day alone
      final data = _data(settings: {'goalType': 'fatLoss'}, plan: {'tdee': 7700 + 2000}, weight: weight, diet: diet);
      final i = checkPlateauDespiteDeficit(data, '2026-08-20');
      expect(i, isNotNull);
      expect(i!.tone, InsightTone.explain);
    });

    test('flat scale but the food log implies well under 1kg -> not worth flagging', () {
      final weight = [
        {'date': '2026-07-01', 'weight': 80.0},
        {'date': '2026-07-25', 'weight': 80.1},
      ];
      final diet = {'2026-07-10': [_meal(1900)]}; // tdee 2000 -> only 100kcal that day
      final data = _data(settings: {'goalType': 'fatLoss'}, plan: {'tdee': 2000}, weight: weight, diet: diet);
      expect(checkPlateauDespiteDeficit(data, '2026-08-20'), isNull);
    });
  });

  group('checkLoggingStreak', () {
    Map<String, dynamic> streakDiet(String today, int days) {
      final base = DateTime.parse('${today}T00:00:00');
      final out = <String, dynamic>{};
      for (var i = 0; i < days; i++) {
        final d = base.subtract(Duration(days: i));
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        out[key] = [_meal(2000)];
      }
      return out;
    }

    test('a non-milestone streak length is quiet', () {
      final data = _data(diet: streakDiet('2026-08-20', 5));
      expect(checkLoggingStreak(data, '2026-08-20'), isNull);
    });

    test('hitting exactly 7 fires with the count in the id and message', () {
      final data = _data(diet: streakDiet('2026-08-20', 7));
      final i = checkLoggingStreak(data, '2026-08-20');
      expect(i, isNotNull);
      expect(i!.id, 'streak:7');
      expect(i.message, contains('7 days'));
      expect(i.tone, InsightTone.recognition);
    });

    test('a gap anywhere in the run breaks the streak count', () {
      final diet = streakDiet('2026-08-20', 7);
      diet.remove('2026-08-16'); // breaks what would otherwise be a 7-day streak
      final data = _data(diet: diet);
      expect(checkLoggingStreak(data, '2026-08-20'), isNull); // only 4 consecutive days from today back
    });

    test('a streak that overshoots a milestone (e.g. 8 days) does not fire', () {
      final data = _data(diet: streakDiet('2026-08-20', 8));
      expect(checkLoggingStreak(data, '2026-08-20'), isNull);
    });
  });

  group('checkTrainingImbalance', () {
    Map<String, dynamic> sessionEntry(String date, int sets) => {
          'date': date,
          'sets': List.generate(sets, (_) => {'weight': 40, 'reps': 8}),
        };

    test('not enough total volume this week -> quiet even if lopsided', () {
      final history = {
        'Barbell Bench Press': [sessionEntry('2026-08-19', 3)],
      };
      final data = _data(history: history);
      expect(checkTrainingImbalance(data, '2026-08-20'), isNull);
    });

    test('balanced push/pull volume -> quiet', () {
      final history = {
        'Barbell Bench Press': [sessionEntry('2026-08-18', 6)], // push (chest)
        'Wide Grip Lat Pulldown': [sessionEntry('2026-08-19', 6)], // pull (lats)
      };
      final data = _data(history: history);
      expect(checkTrainingImbalance(data, '2026-08-20'), isNull);
    });

    test('push trained 3x+ more than pull this week fires', () {
      final history = {
        'Barbell Bench Press': [sessionEntry('2026-08-18', 12)], // push
        'Wide Grip Lat Pulldown': [sessionEntry('2026-08-19', 3)], // pull
      };
      final data = _data(history: history);
      final i = checkTrainingImbalance(data, '2026-08-20');
      expect(i, isNotNull);
      expect(i!.message, contains('Push trained 12 sets'));
      expect(i.message, contains('pull just 3'));
    });

    test('sessions outside the trailing 7-day window are ignored', () {
      final history = {
        // A huge old push session would make this look lopsided if it
        // weren't excluded by date — the in-window volume alone is a
        // balanced 3-push/3-pull week.
        'Barbell Bench Press': [sessionEntry('2026-07-01', 20), sessionEntry('2026-08-19', 3)],
        'Wide Grip Lat Pulldown': [sessionEntry('2026-08-18', 3)],
      };
      final data = _data(history: history);
      expect(checkTrainingImbalance(data, '2026-08-20'), isNull);
    });

    test('an exercise name not in the library is ignored, not a crash', () {
      final history = {
        'Some Made Up Exercise': [sessionEntry('2026-08-19', 20)],
      };
      final data = _data(history: history);
      expect(checkTrainingImbalance(data, '2026-08-20'), isNull);
    });
  });

  group('InsightsEngine', () {
    test('evaluateAll returns every rule that currently fires', () {
      final data = _data(settings: {'goalType': 'fatLoss'});
      final all = InsightsEngine.evaluateAll(data, '2026-08-20');
      expect(all.any((i) => i.id.startsWith('weight-log-gap:')), isTrue);
    });

    test('active excludes anything dismissed', () {
      final data = _data(settings: {
        'goalType': 'fatLoss',
        'insightsDismissed': {'weight-log-gap:2026-08-20': true},
      });
      expect(InsightsEngine.active(data, '2026-08-20').any((i) => i.id.startsWith('weight-log-gap:')), isFalse);
      expect(InsightsEngine.evaluateAll(data, '2026-08-20').any((i) => i.id.startsWith('weight-log-gap:')), isTrue);
    });

    test('active respects the limit', () {
      final data = _data(settings: {'goalType': 'fatLoss'});
      expect(InsightsEngine.active(data, '2026-08-20', limit: 1).length, lessThanOrEqualTo(1));
    });

    test('withDismissed/withRestored round-trip', () {
      final data = _data(settings: {'goalType': 'fatLoss'});
      final dismissedSettings = InsightsEngine.withDismissed(data, 'weight-log-gap:2026-08-20');
      final afterDismiss = _data(settings: {...data.settings, 'insightsDismissed': dismissedSettings});
      expect(InsightsEngine.isDismissed(afterDismiss, 'weight-log-gap:2026-08-20'), isTrue);

      final restoredSettings = InsightsEngine.withRestored(afterDismiss, 'weight-log-gap:2026-08-20');
      final afterRestore = _data(settings: {...afterDismiss.settings, 'insightsDismissed': restoredSettings});
      expect(InsightsEngine.isDismissed(afterRestore, 'weight-log-gap:2026-08-20'), isFalse);
    });
  });
}
