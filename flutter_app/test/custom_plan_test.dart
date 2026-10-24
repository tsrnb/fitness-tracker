import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/features/training/data/custom_plan.dart';
import 'package:cuttracker/features/training/data/training_splits_data.dart';

void main() {
  test('custom plan round-trips into an active split', () {
    final plan = CustomPlan(
      name: 'Mine',
      days: [
        CustomDay('Upper', [CustomExercise('Barbell Bench Press', sets: 4, reps: '6-8', kg: 70)]),
        CustomDay('Upper', [CustomExercise('Barbell Curl')]),
      ],
      schedule: [null, 0, null, 1, null, null, null],
    );
    final settings = {'trainingSplitId': customSplitId, 'customPlan': plan.toJson()};
    final split = activeSplit(settings);
    expect(split.id, customSplitId);
    expect(split.dayOrder, ['Upper', 'Upper 2']); // duplicate names made unique
    expect(split.weekday, {1: 'Upper', 3: 'Upper 2'});
    expect(split.program['Upper']!.items.first.kg, 70);
    expect(split.program['Upper']!.items.first.reps, '6-8');
  });

  test('missing or corrupt customPlan falls back to a built-in split', () {
    expect(activeSplit({'trainingSplitId': customSplitId}).id, isNot(customSplitId));
    expect(activeSplit({'trainingSplitId': customSplitId, 'customPlan': {'days': []}}).id, isNot(customSplitId));
  });
}
