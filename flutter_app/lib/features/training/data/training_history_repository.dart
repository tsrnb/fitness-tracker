import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';

/// Working-set weight/reps to prefill for an exercise. If there's history,
/// the last session is carried forward verbatim — including how many sets it
/// had, since adding/dropping a set on the card is a deliberate choice that
/// should stick on reopen rather than snapping back to the split's default.
/// With no history, falls back to [targetSets] rows of a first-time baseline
/// (empty-bar-ish weight, low end of the rep range).
List<Map<String, num>> initialWorkingSets(Map<String, dynamic> history, String exerciseName, {required int targetSets, required String repRange}) {
  final hist = List<dynamic>.from(history[exerciseName] ?? []);
  final prev = hist.isNotEmpty ? hist.last : null;
  if (prev != null) {
    final rows = List<Map<String, dynamic>>.from(prev['sets'])
        .map((x) => <String, num>{'weight': (x['weight'] as num).toDouble(), 'reps': (x['reps'] as num).toInt()})
        .toList();
    if (rows.isNotEmpty) return rows;
  }
  return List.generate(targetSets, (_) => <String, num>{'weight': 20, 'reps': lowReps(repRange)});
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
