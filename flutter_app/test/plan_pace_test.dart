// Unit tests for the Settings pace slider's math: the combined safety
// floor, and generatePlan's direct deficit/surplus input (paceKcal) versus
// its original target-date-derived fallback.
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/features/plan/data/plan_generator.dart';

void main() {
  group('safetyFloorKcal', () {
    test('uses 1.2×BMR when it exceeds the flat minimum', () {
      // 1.2 * 2000 = 2400, well above either flat floor.
      expect(safetyFloorKcal(2000, 'male'), 2400);
      expect(safetyFloorKcal(2000, 'female'), 2400);
    });

    test('falls back to the flat minimum when 1.2×BMR would dip under it', () {
      // A light/small person: 1.2 * 950 = 1140, under both flat floors.
      expect(safetyFloorKcal(950, 'female'), 1200);
      expect(safetyFloorKcal(950, 'male'), 1500);
    });
  });

  group('generatePlan — fat loss with a direct pace', () {
    test('uses the requested deficit when it stays above the safety floor', () {
      final plan = generatePlan(
        currentWeight: 90,
        targetWeight: 80,
        height: 180,
        age: 30,
        sex: 'male',
        activity: 'moderate',
        goalType: 'fatLoss',
        dietPref: 'veg',
        targetDate: '',
        paceKcal: 500,
      );
      // calorieGoal rounds to the nearest 10, so dailyPace lands close to
      // 500 but not necessarily exactly on it.
      expect(plan.dailyPace, closeTo(500, 10));
      expect(plan.paceCapped, isFalse);
      expect(plan.calorieGoal, closeTo(plan.tdee - 500, 10));
      expect(plan.tentativeDate, isNotNull);
    });

    test('never overrides the requested deficit, but flags paceCapped when it pushes the goal under the safety floor', () {
      // Small, light, older woman -> low BMR/TDEE, so a 1000 kcal deficit
      // pushes the calorie goal under the safety floor — that's now just a
      // warning flag, not a reason to silently give her a smaller deficit.
      final plan = generatePlan(
        currentWeight: 50,
        targetWeight: 45,
        height: 155,
        age: 55,
        sex: 'female',
        activity: 'sedentary',
        goalType: 'fatLoss',
        dietPref: 'veg',
        targetDate: '',
        paceKcal: 1000,
      );
      expect(plan.paceCapped, isTrue);
      expect(plan.dailyPace, closeTo(1000, 10));
      expect(plan.calorieGoal, lessThan(plan.safetyFloorKcal));
    });

    test('a paceKcal outside 100-1000 gets clamped into range before anything else', () {
      final tooLow = generatePlan(
        currentWeight: 90, targetWeight: 80, height: 180, age: 30, sex: 'male',
        activity: 'moderate', goalType: 'fatLoss', dietPref: 'veg', targetDate: '', paceKcal: 10,
      );
      expect(tooLow.dailyPace, closeTo(100, 10));

      final tooHigh = generatePlan(
        currentWeight: 90, targetWeight: 80, height: 180, age: 30, sex: 'male',
        activity: 'moderate', goalType: 'fatLoss', dietPref: 'veg', targetDate: '', paceKcal: 5000,
      );
      // The 100-1000 input range still holds regardless of the safety floor
      // (rounding to the nearest 10 kcal calorie goal can land it a few
      // kcal past 1000, same tolerance as elsewhere in this file).
      expect(tooHigh.dailyPace, lessThanOrEqualTo(1010));
    });

    test('falls back to the target-date-derived deficit when no pace is given (unchanged legacy behavior)', () {
      final plan = generatePlan(
        currentWeight: 90,
        targetWeight: 80,
        height: 180,
        age: 30,
        sex: 'male',
        activity: 'moderate',
        goalType: 'fatLoss',
        dietPref: 'veg',
        targetDate: '',
      );
      expect(plan.dailyPace, greaterThan(0));
      expect(plan.tentativeDate, isNotNull);
    });
  });

  group('generatePlan — muscle gain with a direct pace', () {
    test('uses the requested surplus and computes a tentative date to the target weight', () {
      final plan = generatePlan(
        currentWeight: 70,
        targetWeight: 75,
        height: 178,
        age: 25,
        sex: 'male',
        activity: 'active',
        goalType: 'weightGain',
        dietPref: 'veg',
        targetDate: '',
        paceKcal: 300,
      );
      expect(plan.dailyPace, 300);
      expect(plan.calorieGoal, plan.tdee + 300);
      expect(plan.tentativeDate, isNotNull);
      expect(plan.paceCapped, isFalse); // no safety floor going up
    });

    test('a paceKcal outside 150-500 gets clamped', () {
      final plan = generatePlan(
        currentWeight: 70, targetWeight: 75, height: 178, age: 25, sex: 'male',
        activity: 'active', goalType: 'weightGain', dietPref: 'veg', targetDate: '', paceKcal: 900,
      );
      expect(plan.dailyPace, 500);
    });
  });

  group('generatePlan — maintain', () {
    test('ignores paceKcal entirely and has no tentative date', () {
      final plan = generatePlan(
        currentWeight: 75, targetWeight: 75, height: 175, age: 28, sex: 'male',
        activity: 'moderate', goalType: 'maintain', dietPref: 'veg', targetDate: '', paceKcal: 700,
      );
      expect(plan.dailyPace, 0);
      expect(plan.tentativeDate, isNull);
      expect(plan.calorieGoal, closeTo(plan.tdee, 10));
    });
  });
}
