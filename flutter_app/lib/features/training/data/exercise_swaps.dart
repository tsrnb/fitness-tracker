import '../../../app/app_state.dart';
import '../../exercises/data/exercise_library_data.dart';
import '../domain/program.dart';

/// Per-user "swap this exercise for another of the same muscle group"
/// overrides — e.g. the gym doesn't have an incline bench, so Incline
/// Dumbbell Press becomes Flat DB Press. Keyed by *day-type*, not by date,
/// so a swap made on any occurrence of a day (e.g. "Push day") applies to
/// every future Push day under that split until it's reverted — not just
/// today's session. [TrainingSplit.program]/[ProgramItem] stay `const`
/// shared data; this lives alongside the rest of the user's settings
/// instead, as `{ "<splitId>|<day>": { "<originalExercise>": "<substitute>" } }`.
String _swapKey(String splitId, String day) => '$splitId|$day';

/// original exercise name -> substitute, for one split + day-type.
Map<String, String> swapsForDay(Map<String, dynamic> settings, String splitId, String day) {
  final raw = settings['exerciseSwaps'];
  final all = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final forDay = all[_swapKey(splitId, day)];
  if (forDay is! Map) return const {};
  return Map<String, String>.from(forDay);
}

/// [items] (a day's prescribed [ProgramItem]s) with [swaps] applied — only
/// the exercise name changes per swapped slot, sets/reps stay whatever that
/// slot originally prescribed.
List<ProgramItem> applySwaps(List<ProgramItem> items, Map<String, String> swaps) {
  return items.map((it) {
    final sub = swaps[it.name];
    return sub == null ? it : ProgramItem(sub, it.sets, it.reps);
  }).toList();
}

Future<void> setExerciseSwap(AppController controller, String splitId, String day, String original, String substitute) {
  return controller.update('settings', (prev) {
    final s = Map<String, dynamic>.from(prev ?? {});
    final rawAll = s['exerciseSwaps'];
    final all = rawAll is Map ? Map<String, dynamic>.from(rawAll) : <String, dynamic>{};
    final key = _swapKey(splitId, day);
    final rawForDay = all[key];
    final forDay = rawForDay is Map ? Map<String, String>.from(rawForDay) : <String, String>{};
    forDay[original] = substitute;
    all[key] = forDay;
    s['exerciseSwaps'] = all;
    return s;
  });
}

Future<void> clearExerciseSwap(AppController controller, String splitId, String day, String original) {
  return controller.update('settings', (prev) {
    final s = Map<String, dynamic>.from(prev ?? {});
    final rawAll = s['exerciseSwaps'];
    final all = rawAll is Map ? Map<String, dynamic>.from(rawAll) : <String, dynamic>{};
    final key = _swapKey(splitId, day);
    final rawForDay = all[key];
    final forDay = rawForDay is Map ? Map<String, String>.from(rawForDay) : <String, String>{};
    forDay.remove(original);
    if (forDay.isEmpty) {
      all.remove(key);
    } else {
      all[key] = forDay;
    }
    s['exerciseSwaps'] = all;
    return s;
  });
}

/// Other exercises that share [exerciseName]'s primary muscle group, for the
/// "swap with" picker — excludes the exercise itself and anything in
/// [exclude] (typically the rest of that day's lineup, so you're not
/// offered something you're already doing).
List<String> sameGroupAlternatives(String exerciseName, {List<String> exclude = const []}) {
  final info = lib[exerciseName];
  if (info == null) return const [];
  final excludeSet = {exerciseName, ...exclude};
  return lib.entries.where((e) => e.value.group == info.group && !excludeSet.contains(e.key)).map((e) => e.key).toList();
}
