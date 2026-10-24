import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../domain/muscle_models.dart';

MuscleProfile? muscleProfileOf(AppData data) {
  final m = data.muscle;
  return m == null ? null : MuscleProfile.fromJson(m);
}

Future<void> saveMuscleProfile(AppController c, MuscleProfile p) => c.update('muscle', (_) => p.toJson());

/// The profile for someone who skips setup: Intermediate, their most-trained
/// lifts, and a +2 kg gain goal.
MuscleProfile defaultMuscleProfile(AppData data, String today, {String? level, List<String>? tracked, double? goalGainKg}) => MuscleProfile(
      level: level ?? 'intermediate',
      tracked: tracked ?? exercisesByUse(data.history).take(6).toList(),
      setupDate: today,
      goalGainKg: goalGainKg ?? 2.0,
    );

/// Adds one tape reading (only the sites measured), replacing an earlier
/// reading from the same day. Creates a default profile if none exists yet.
Future<void> addTapeEntry(AppController c, Map<String, double> cm) async {
  if (cm.isEmpty) return;
  final data = c.current.data;
  final today = todayStr(data.settings);
  final p = muscleProfileOf(data) ?? defaultMuscleProfile(data, today);
  final tape = [...p.tape.where((t) => t.date != today), TapeEntry(today, cm)]..sort((a, b) => a.date.compareTo(b.date));
  await saveMuscleProfile(c, p.copyWith(tape: tape));
}

const _maxChats = 30;

/// Inserts or updates one saved Know-why conversation (newest first).
Future<void> upsertChat(AppController c, Map<String, dynamic> chat) async {
  final data = c.current.data;
  final p = muscleProfileOf(data) ?? defaultMuscleProfile(data, todayStr(data.settings));
  final chats = [for (final x in p.chats) if (x['id'] != chat['id']) x];
  chats.insert(0, chat);
  await saveMuscleProfile(c, p.copyWith(chats: chats.take(_maxChats).toList()));
}

Future<void> deleteChat(AppController c, Object id) async {
  final p = muscleProfileOf(c.current.data);
  if (p == null) return;
  await saveMuscleProfile(c, p.copyWith(chats: [for (final x in p.chats) if (x['id'] != id) x]));
}
