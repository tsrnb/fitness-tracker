import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';

/// Working-set weight/reps to prefill for an exercise, carried forward from
/// the last logged session and padded/truncated to [targetSets] — or a
/// default first-time baseline (empty-bar-ish weight, low end of the rep
/// range) if there's no history yet.
List<Map<String, num>> initialWorkingSets(Map<String, dynamic> history, String exerciseName, {required int targetSets, required String repRange}) {
  final hist = List<dynamic>.from(history[exerciseName] ?? []);
  final prev = hist.isNotEmpty ? hist.last : null;
  List<Map<String, num>> rows;
  if (prev != null) {
    rows = List<Map<String, dynamic>>.from(prev['sets']).map((x) => <String, num>{'weight': (x['weight'] as num).toDouble(), 'reps': (x['reps'] as num).toInt()}).toList();
  } else {
    rows = List.generate(targetSets, (_) => <String, num>{'weight': 20, 'reps': lowReps(repRange)});
  }
  while (rows.length < targetSets) {
    rows.add(Map<String, num>.from(rows.last));
  }
  return rows.sublist(0, targetSets);
}

/// Appends today's logged sets for [exerciseName] (replacing any existing
/// entry for today) and records the session in `sessions`.
Future<void> logTrainingSession(
  AppController controller, {
  required String exerciseName,
  required String dayType,
  required String today,
  required List<Map<String, dynamic>> sets,
}) async {
  await controller.update('history', (prev) {
    final h = Map<String, dynamic>.from(prev ?? {});
    final existing = List<dynamic>.from(h[exerciseName] ?? []).where((e) => e['date'] != today).toList();
    h[exerciseName] = [...existing, {'date': today, 'sets': sets}];
    return h;
  });
  await controller.update('sessions', (prev) {
    final s = Map<String, dynamic>.from(prev ?? {});
    s[today] = {'day': dayType, 'at': DateTime.now().millisecondsSinceEpoch};
    return s;
  });
}
