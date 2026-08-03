import '../../../shared/lib/helpers.dart';

class PersonalRecord {
  final String name;
  final int best; // estimated 1RM (Epley)
  final num bestWeight;
  const PersonalRecord({required this.name, required this.best, required this.bestWeight});
}

/// One estimated-1RM record per exercise in `history`, strongest first.
/// Exercises with no valid logged sets are omitted.
List<PersonalRecord> computePersonalRecords(Map<String, dynamic> history) {
  final list = history.entries.map((entry) {
    final hist = List<Map<String, dynamic>>.from(entry.value);
    int best = 0;
    num bestW = 0;
    for (final e in hist) {
      for (final x in List<Map<String, dynamic>>.from(e['sets'])) {
        final oneRm = epley(x['weight'] as num, x['reps'] as num);
        if (oneRm > best) best = oneRm;
        if ((x['weight'] as num) > bestW) bestW = x['weight'] as num;
      }
    }
    return PersonalRecord(name: entry.key, best: best, bestWeight: bestW);
  }).where((p) => p.best > 0).toList()
    ..sort((a, b) => b.best.compareTo(a.best));
  return list;
}
