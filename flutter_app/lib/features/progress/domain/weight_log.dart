import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';

/// Appends one weigh-in to `data.weight` and updates `settings.currentWeight`
/// — the one definition of "log a weigh-in" both the inline Progress →
/// Weight tab field and `WeighInSheet` call into, instead of each hand-
/// rolling the same list-append/sort. Every log is kept as its own point
/// (never overwriting the day's earlier reading), same as before.
Future<void> logWeightEntry(AppController controller, Map<String, dynamic> settings, double value) async {
  final date = todayStr(settings);
  final loggedAt = DateTime.now().millisecondsSinceEpoch;
  await controller.update('weight', (prev) {
    final list = List<Map<String, dynamic>>.from(prev ?? []);
    list.add({'date': date, 'weight': value, 'loggedAt': loggedAt});
    list.sort((a, b) {
      final byDate = (a['date'] as String).compareTo(b['date'] as String);
      if (byDate != 0) return byDate;
      return ((a['loggedAt'] as num?) ?? 0).compareTo((b['loggedAt'] as num?) ?? 0);
    });
    return list;
  });
  await controller.patchSettings('currentWeight', value);
}
