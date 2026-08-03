/// One day's nutrition rollup for the weekly ring strip — kcal/protein
/// eaten vs. that day's (activity-adjusted) goals.
class DayStat {
  final String date;
  final int kcal;
  final int protein;
  final int mealsCount;
  final num adjustedGoal;
  final num proteinGoal;
  const DayStat({required this.date, required this.kcal, required this.protein, required this.mealsCount, required this.adjustedGoal, required this.proteinGoal});

  double get kcalPct => adjustedGoal > 0 ? (kcal / adjustedGoal * 100) : 0;
  double get proteinPct => proteinGoal > 0 ? (protein / proteinGoal * 100) : 0;
  bool get bothHit => mealsCount > 0 && kcal <= adjustedGoal && proteinPct >= 90;
  num get vsGoal => adjustedGoal - kcal; // positive = under budget (deficit), negative = over
}
