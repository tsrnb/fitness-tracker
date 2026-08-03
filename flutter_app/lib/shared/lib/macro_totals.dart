/// Sum of kcal/protein/carb/fat/fiber across a list of meal-log entries —
/// the same "fold over a day's meals" shape was being hand-rolled in
/// nutrition, dashboard, plan, and progress screens.
class MacroTotals {
  final num kcal;
  final num protein;
  final num carb;
  final num fat;
  final num fiber;
  const MacroTotals({this.kcal = 0, this.protein = 0, this.carb = 0, this.fat = 0, this.fiber = 0});

  Map<String, int> toIntMap() => {
        'kcal': kcal.round(),
        'protein': protein.round(),
        'carb': carb.round(),
        'fat': fat.round(),
        'fiber': fiber.round(),
      };
}

MacroTotals sumMacros(Iterable<Map<String, dynamic>> items) {
  num kcal = 0, protein = 0, carb = 0, fat = 0, fiber = 0;
  for (final m in items) {
    kcal += (m['kcal'] as num?) ?? 0;
    protein += (m['protein'] as num?) ?? 0;
    carb += (m['carb'] as num?) ?? 0;
    fat += (m['fat'] as num?) ?? 0;
    fiber += (m['fiber'] as num?) ?? 0;
  }
  return MacroTotals(kcal: kcal, protein: protein, carb: carb, fat: fat, fiber: fiber);
}
