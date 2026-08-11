/// One day's nutrition rollup for the weekly ring strip — kcal/protein
/// eaten vs. that day's (activity-adjusted) goals, plus what it actually
/// takes to compute both of the app's two energy numbers for that day:
/// the true deficit/surplus vs. maintenance, and how much of the day's
/// calorie budget was left. See `BudgetChip`'s doc comment for why those
/// two are kept distinct rather than collapsed into one "deficit" figure.
class DayStat {
  final String date;
  final int kcal;
  final int protein;
  final int mealsCount;
  final num adjustedGoal;
  final num proteinGoal;
  final num tdee;
  final num burned;
  const DayStat({
    required this.date,
    required this.kcal,
    required this.protein,
    required this.mealsCount,
    required this.adjustedGoal,
    required this.proteinGoal,
    required this.tdee,
    required this.burned,
  });

  double get kcalPct => adjustedGoal > 0 ? (kcal / adjustedGoal * 100) : 0;
  double get proteinPct => proteinGoal > 0 ? (protein / proteinGoal * 100) : 0;
  bool get bothHit => mealsCount > 0 && kcal <= adjustedGoal && proteinPct >= 90;

  /// Budget remaining vs. the day's calorie goal — positive = under budget.
  num get vsGoal => adjustedGoal - kcal;

  /// True deficit vs. maintenance (TDEE) — positive = deficit, negative =
  /// surplus. The number that actually predicts weight change, unlike
  /// [vsGoal] which just tracks adherence to the (already deficit-loaded) plan.
  num get trueDeficit => tdee - (kcal - burned);
}
