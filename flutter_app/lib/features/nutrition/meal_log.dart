import '../../app/app_state.dart';
import '../../shared/lib/helpers.dart';
import 'parse_meal_lines.dart';

/// Shared "append a meal to today's diet log" logic, used by both the full
/// Nutrition screen and the home screen's quick-log sheet so they stay in
/// sync with a single source of truth.
void addMealEntry(AppController controller, String name, num k, num p, [num c = 0, num f = 0, num fi = 0]) {
  final today = todayStr();
  controller.update('diet', (prev) {
    final d = Map<String, dynamic>.from(prev ?? {});
    final list = List<Map<String, dynamic>>.from(d[today] ?? []);
    list.add({
      'id': DateTime.now().millisecondsSinceEpoch + list.length,
      'name': name,
      'kcal': k.round(),
      'protein': p.round(),
      'carb': c.round(),
      'fat': f.round(),
      'fiber': fi.round(),
    });
    d[today] = list;
    return d;
  });
}

void addMealEntries(AppController controller, List<ParsedMealItem> items) {
  final today = todayStr();
  controller.update('diet', (prev) {
    final d = Map<String, dynamic>.from(prev ?? {});
    final list = List<Map<String, dynamic>>.from(d[today] ?? []);
    for (final it in items) {
      list.add({
        'id': DateTime.now().millisecondsSinceEpoch + list.length,
        'name': it.name,
        'kcal': it.kcal,
        'protein': it.protein,
        'carb': it.carb,
        'fat': it.fat,
        'fiber': it.fiber,
      });
    }
    d[today] = list;
    return d;
  });
}
