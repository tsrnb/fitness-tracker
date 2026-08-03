import '../domain/parsed_meal_item.dart';

/// Parses lines like "2 Rotis, 240, 6, 30, 4, 3" -> {name, kcal, protein, carb, fat, fiber}.
/// Trailing fields are optional and default to 0, right-aligned in the order
/// kcal, protein, carb, fat, fiber — so "Name, 240" and "Name, 240, 6" still work.
List<ParsedMealItem> parseMealLines(String raw) {
  final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
  final items = <ParsedMealItem>[];
  for (final line in lines) {
    final parts = line.split(',').map((p) => p.trim()).where((p) => p != '').toList();
    if (parts.length < 2) continue;
    final numCount = (parts.length - 1).clamp(1, 5);
    final nameEnd = parts.length - numCount;
    final nums = parts.sublist(nameEnd).map((p) => double.tryParse(p)).toList();
    final kcal = nums[0];
    final name = parts.sublist(0, nameEnd).join(', ').trim();
    if (name.isEmpty || kcal == null || kcal < 0) continue;
    final protein = numCount >= 2 ? (nums[1] ?? 0) : 0.0;
    final carb = numCount >= 3 ? (nums[2] ?? 0) : 0.0;
    final fat = numCount >= 4 ? (nums[3] ?? 0) : 0.0;
    final fiber = numCount >= 5 ? (nums[4] ?? 0) : 0.0;
    items.add(ParsedMealItem(name, kcal.round(), protein.round(), carb.round(), fat.round(), fiber.round()));
  }
  return items;
}
