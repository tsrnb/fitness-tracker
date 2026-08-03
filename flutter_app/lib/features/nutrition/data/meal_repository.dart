import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../domain/parsed_meal_item.dart';

/// Shared "append a meal to a day's diet log" logic, used by the full
/// Nutrition screen, the home screen's quick-log sheet, and the Progress
/// tab's past-day editor so they stay in sync with a single source of
/// truth. Defaults to today (per the day-boundary setting) when [date] is
/// omitted; the past-day editor passes an explicit date instead.
void addMealEntry(AppController controller, String name, num k, num p, [num c = 0, num f = 0, num fi = 0, String? date]) {
  final day = date ?? todayStr(controller.current.data.settings);
  controller.update('diet', (prev) {
    final d = Map<String, dynamic>.from(prev ?? {});
    final list = List<Map<String, dynamic>>.from(d[day] ?? []);
    list.add({
      'id': DateTime.now().millisecondsSinceEpoch + list.length,
      'name': name,
      'kcal': k.round(),
      'protein': p.round(),
      'carb': c.round(),
      'fat': f.round(),
      'fiber': fi.round(),
    });
    d[day] = list;
    return d;
  });
}

void addMealEntries(AppController controller, List<ParsedMealItem> items, [String? date]) {
  final day = date ?? todayStr(controller.current.data.settings);
  controller.update('diet', (prev) {
    final d = Map<String, dynamic>.from(prev ?? {});
    final list = List<Map<String, dynamic>>.from(d[day] ?? []);
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
    d[day] = list;
    return d;
  });
}

/// Removes a single meal from [date]'s diet log by id.
void removeMealEntry(AppController controller, String date, dynamic id) {
  controller.update('diet', (prev) {
    final d = Map<String, dynamic>.from(prev ?? {});
    final list = List<Map<String, dynamic>>.from(d[date] ?? []).where((m) => m['id'] != id).toList();
    d[date] = list;
    return d;
  });
}
