// Unit tests for the "switch exercise" data layer: reading/merging swap
// overrides and finding same-muscle-group alternatives. Pure logic, no
// widget/backend harness needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/features/training/data/exercise_swaps.dart';
import 'package:cuttracker/features/training/domain/program.dart';

void main() {
  group('swapsForDay', () {
    test('reads the map for the given split + day, ignoring other days/splits', () {
      final settings = {
        'exerciseSwaps': {
          'ppul5|Push': {'Incline Dumbbell Press': 'Flat Dumbbell Press'},
          'ppul5|Pull': {'Barbell Curl': 'Hammer Curl'},
          'ppl6|Push': {'Incline Dumbbell Press': 'Cable Crossover'},
        },
      };
      expect(swapsForDay(settings, 'ppul5', 'Push'), {'Incline Dumbbell Press': 'Flat Dumbbell Press'});
      expect(swapsForDay(settings, 'ppul5', 'Pull'), {'Barbell Curl': 'Hammer Curl'});
      expect(swapsForDay(settings, 'ppl6', 'Push'), {'Incline Dumbbell Press': 'Cable Crossover'});
    });

    test('returns empty for a day with no swaps, missing settings, or malformed data', () {
      expect(swapsForDay({}, 'ppul5', 'Push'), isEmpty);
      expect(swapsForDay({'exerciseSwaps': 'not a map'}, 'ppul5', 'Push'), isEmpty);
      expect(swapsForDay({'exerciseSwaps': {'ppul5|Push': 'not a map'}}, 'ppul5', 'Push'), isEmpty);
    });
  });

  group('applySwaps', () {
    test('substitutes the exercise name for a swapped slot, keeping its sets/reps', () {
      const items = [
        ProgramItem('Barbell Bench Press', 4, '6-8'),
        ProgramItem('Incline Dumbbell Press', 3, '8-10'),
      ];
      final result = applySwaps(items, {'Incline Dumbbell Press': 'Flat Dumbbell Press'});
      expect(result[0].name, 'Barbell Bench Press'); // untouched
      expect(result[1].name, 'Flat Dumbbell Press'); // swapped
      expect(result[1].sets, 3); // prescription carried over, not the substitute's own
      expect(result[1].reps, '8-10');
    });

    test('leaves the list unchanged when there are no swaps', () {
      const items = [ProgramItem('Barbell Squat', 4, '6-8')];
      expect(applySwaps(items, const {}), items);
    });
  });

  group('sameGroupAlternatives', () {
    test('only returns exercises in the same muscle group, excluding itself', () {
      final alts = sameGroupAlternatives('Incline Dumbbell Press');
      expect(alts, isNotEmpty);
      expect(alts, isNot(contains('Incline Dumbbell Press')));
      expect(alts, contains('Flat Dumbbell Press')); // another chest exercise
      expect(alts, isNot(contains('Barbell Squat'))); // a legs exercise
    });

    test('excludes names passed via exclude (e.g. the rest of the day\'s lineup)', () {
      final alts = sameGroupAlternatives('Incline Dumbbell Press', exclude: const ['Flat Dumbbell Press']);
      expect(alts, isNot(contains('Flat Dumbbell Press')));
    });

    test('returns nothing for a name that is not in the exercise library', () {
      expect(sameGroupAlternatives('Not A Real Exercise'), isEmpty);
    });
  });
}
