// Unit tests for DayStat's two energy numbers — true deficit vs.
// maintenance, and budget remaining vs. goal. These are deliberately
// different quantities (see the class doc comment); the tests pin down
// that they don't collapse into each other.
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/features/progress/domain/day_stat.dart';

void main() {
  group('DayStat', () {
    test('trueDeficit is positive (a deficit) when under maintenance', () {
      // tdee 2800, ate 1800, burned 200 extra -> 2800 - (1800-200) = 1200
      final s = DayStat(date: '2026-01-01', kcal: 1800, protein: 0, mealsCount: 1, adjustedGoal: 2300, proteinGoal: 150, tdee: 2800, burned: 200);
      expect(s.trueDeficit, 1200);
      expect(s.vsGoal, 500); // (2300) - 1800
    });

    test('trueDeficit goes negative (a surplus) once eaten minus burned exceeds maintenance', () {
      final s = DayStat(date: '2026-01-01', kcal: 3200, protein: 0, mealsCount: 1, adjustedGoal: 2300, proteinGoal: 150, tdee: 2800, burned: 0);
      expect(s.trueDeficit, -400);
      expect(s.vsGoal, -900);
    });

    test('trueDeficit and vsGoal are independent — a day can be under budget but still in surplus', () {
      // Small goal (aggressive cut) but ate right up to a high-TDEE maintenance line.
      final s = DayStat(date: '2026-01-01', kcal: 2000, protein: 0, mealsCount: 1, adjustedGoal: 2000, proteinGoal: 150, tdee: 1900, burned: 0);
      expect(s.vsGoal, 0); // exactly on budget
      expect(s.trueDeficit, -100); // but still a surplus vs. real maintenance
    });
  });
}
