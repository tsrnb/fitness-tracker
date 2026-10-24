// Unit tests for the Muscle feature's math (features/muscle/domain): the
// pace regression, the tape verdict and lift summaries. These decide what
// the app tells someone about their gains, so they are worth testing hard.
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/features/muscle/domain/muscle_models.dart';

List<Map<String, dynamic>> _weights(Map<String, double> byDate) => [
      for (final e in byDate.entries) {'date': e.key, 'weight': e.value}
    ];

void main() {
  group('weightPaceKgPerWeek', () {
    test('a steady 0.25 kg/week climb reads as 0.25', () {
      final w = _weights({
        '2026-09-17': 72.0, '2026-09-24': 72.25, '2026-10-01': 72.5, '2026-10-08': 72.75, '2026-10-15': 73.0,
      });
      expect(weightPaceKgPerWeek(w, '2026-10-15'), closeTo(0.25, 0.001));
    });

    test('fewer than three distinct days is not enough', () {
      final w = _weights({'2026-10-08': 72.0, '2026-10-15': 72.5});
      expect(weightPaceKgPerWeek(w, '2026-10-15'), isNull);
    });

    test('three readings crammed into under a week is not enough', () {
      final w = _weights({'2026-10-12': 72.0, '2026-10-13': 72.1, '2026-10-15': 72.2});
      expect(weightPaceKgPerWeek(w, '2026-10-15'), isNull);
    });

    test('readings older than the window are ignored', () {
      final w = _weights({'2026-06-01': 60.0, '2026-10-01': 72.0, '2026-10-08': 72.2, '2026-10-15': 72.4});
      expect(weightPaceKgPerWeek(w, '2026-10-15'), closeTo(0.2, 0.001));
    });
  });

  group('paceState', () {
    final l = muscleLevelOf('intermediate'); // 0.1-0.3
    test('below, inside and above the band', () {
      expect(paceState(0.05, l), PaceState.tooSlow);
      expect(paceState(0.2, l), PaceState.onPace);
      expect(paceState(0.45, l), PaceState.fast);
    });
  });

  group('tapeVerdict', () {
    TapeEntry t(String d, {double? arm, double? chest, double? waist}) =>
        TapeEntry(d, {if (arm != null) 'arm': arm, if (chest != null) 'chest': chest, if (waist != null) 'waist': waist});

    test('needs two entries', () {
      expect(tapeVerdict([t('2026-10-01', arm: 35, waist: 81)]), isNull);
    });

    test('arms growing at least twice as fast as the waist is mostly lean', () {
      final v = tapeVerdict([t('2026-10-01', arm: 35, chest: 98, waist: 81), t('2026-10-15', arm: 36.1, chest: 99.6, waist: 81.4)]);
      expect(v!.label, 'Mostly lean');
    });

    test('waist growing as fast as arms is mostly fat', () {
      final v = tapeVerdict([t('2026-10-01', arm: 35, waist: 81), t('2026-10-15', arm: 35.6, waist: 82.4)]);
      expect(v!.label, 'Mostly fat');
    });

    test('in between is mixed', () {
      final v = tapeVerdict([t('2026-10-01', arm: 35, waist: 81), t('2026-10-15', arm: 36.0, waist: 81.8)]);
      expect(v!.label, 'Mixed');
    });

    test('changes under 0.5 cm are within tape error', () {
      final v = tapeVerdict([t('2026-10-01', arm: 35, waist: 81), t('2026-10-15', arm: 35.3, waist: 81.2)]);
      expect(v!.label, 'Within tape error');
    });

    test('no verdict without a waist reading in both entries', () {
      expect(tapeVerdict([t('2026-10-01', arm: 35), t('2026-10-15', arm: 36, waist: 81)]), isNull);
    });
  });

  group('tapeDue', () {
    final tape = [TapeEntry('2026-10-08', {'waist': 81})];
    test('due exactly a week after the last entry, not before', () {
      expect(tapeDue(tape, '2026-10-14'), isFalse);
      expect(tapeDue(tape, '2026-10-15'), isTrue);
    });
    test('never due with no entries', () => expect(tapeDue(const [], '2026-10-15'), isFalse));
  });

  group('lifts', () {
    Map<String, dynamic> hist(List<(String, double, int)> sessions) => {
          'Bench': [
            for (final s in sessions)
              {
                'date': s.$1,
                'sets': [
                  {'weight': s.$2, 'reps': s.$3},
                ],
              }
          ],
        };

    test('series uses the best set per session by Epley', () {
      final h = {
        'Bench': [
          {
            'date': '2026-10-01',
            'sets': [
              {'weight': 60, 'reps': 10},
              {'weight': 80, 'reps': 5},
            ],
          }
        ],
      };
      final p = liftSeries(h, 'Bench').single;
      expect(p.e1rm, 93); // 80 * (1 + 5/30)
      expect(p.topWeight, 80);
      expect(p.topReps, 5);
    });

    test('delta, PR and progressed flag come from the last two sessions', () {
      final l = LiftSummary('Bench', liftSeries(hist([('2026-10-01', 70, 8), ('2026-10-08', 72.5, 8)]), 'Bench'));
      expect(l.delta, greaterThan(0));
      expect(l.isPr, isTrue);
      expect(l.progressed('2026-10-12'), isTrue);
      expect(l.progressed('2026-11-12'), isFalse); // stale: not "this week" any more
    });

    test('a dip is not a PR and does not count as progress', () {
      final l = LiftSummary('Bench', liftSeries(hist([('2026-10-01', 75, 8), ('2026-10-08', 70, 8)]), 'Bench'));
      expect(l.delta, lessThan(0));
      expect(l.isPr, isFalse);
      expect(l.progressed('2026-10-09'), isFalse);
    });

    test('next target adds 2.5 kg at the same reps', () {
      final l = LiftSummary('Bench', liftSeries(hist([('2026-10-08', 74, 8)]), 'Bench'));
      expect(l.nextTarget, (76.5, 8));
      expect(l.nextAltTarget, (74.0, 9));
    });

    test('a single session has no delta and no PR', () {
      final l = LiftSummary('Bench', liftSeries(hist([('2026-10-08', 74, 8)]), 'Bench'));
      expect(l.delta, 0);
      expect(l.isPr, isFalse);
    });

    test('exercisesByUse ranks by session count and drops empty lifts', () {
      final h = {
        'A': [
          {'date': '2026-10-01', 'sets': [{'weight': 50, 'reps': 8}]},
        ],
        'B': [
          {'date': '2026-10-01', 'sets': [{'weight': 50, 'reps': 8}]},
          {'date': '2026-10-08', 'sets': [{'weight': 55, 'reps': 8}]},
        ],
        'C': [
          {'date': '2026-10-01', 'sets': <Map<String, dynamic>>[]},
        ],
      };
      expect(exercisesByUse(h), ['B', 'A']);
    });
  });

  group('MuscleProfile', () {
    test('survives a JSON round trip', () {
      final p = MuscleProfile(
        level: 'advanced',
        tracked: const ['Bench'],
        setupDate: '2026-10-01',
        goalGainKg: 3,
        tape: const [TapeEntry('2026-10-01', {'arm': 35.5, 'waist': 81})],
        chats: const [
          {'id': 1, 'title': 'hi', 'msgs': []}
        ],
      );
      final q = MuscleProfile.fromJson(p.toJson());
      expect(q.level, 'advanced');
      expect(q.tracked, ['Bench']);
      expect(q.goalGainKg, 3);
      expect(q.tape.single.cm['arm'], 35.5);
      expect(q.chats.single['title'], 'hi');
    });
  });
}
