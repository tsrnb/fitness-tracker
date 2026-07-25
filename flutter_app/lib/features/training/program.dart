class ProgramItem {
  final String name;
  final int sets;
  final String reps;
  const ProgramItem(this.name, this.sets, this.reps);
}

class ProgramDay {
  final String focus;
  final List<ProgramItem> items;
  const ProgramDay(this.focus, this.items);
}

/// 5-day PPLUL program (loads/rep guidance adapt via goal, exercise list stays practical).
final Map<String, ProgramDay> program = {
  'Push': const ProgramDay('Chest · Shoulders · Triceps', [
    ProgramItem('Barbell Bench Press', 4, '6-8'),
    ProgramItem('Incline Dumbbell Press', 3, '8-10'),
    ProgramItem('Pec Deck Fly', 3, '10-12'),
    ProgramItem('Dumbbell Lateral Raise', 4, '12-15'),
    ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
    ProgramItem('Overhead Cable Tricep Extension', 3, '10-12'),
  ]),
  'Pull': const ProgramDay('Back · Rear Delts · Biceps', [
    ProgramItem('Wide Grip Lat Pulldown', 4, '8-10'),
    ProgramItem('Chest Supported Row', 4, '8-10'),
    ProgramItem('Seated Cable Row', 3, '10-12'),
    ProgramItem('Face Pull', 3, '12-15'),
    ProgramItem('Rear Delt Fly', 3, '12-15'),
    ProgramItem('Barbell Curl', 3, '8-10'),
    ProgramItem('Hammer Curl', 3, '10-12'),
  ]),
  'Legs': const ProgramDay('Quads · Hamstrings · Calves', [
    ProgramItem('Barbell Squat', 4, '6-8'),
    ProgramItem('Leg Press', 4, '10-12'),
    ProgramItem('Leg Extension', 3, '12-15'),
    ProgramItem('Lying Leg Curl', 4, '10-12'),
    ProgramItem('Standing Calf Raise', 4, '15-20'),
    ProgramItem('Seated Calf Raise', 3, '15-20'),
  ]),
  'Upper': const ProgramDay('Chest · Back · Shoulders · Arms', [
    ProgramItem('Incline Barbell Press', 3, '8-10'),
    ProgramItem('Lat Pulldown', 3, '8-10'),
    ProgramItem('Seated Cable Row', 3, '10-12'),
    ProgramItem('Machine Shoulder Press', 3, '8-10'),
    ProgramItem('Dumbbell Lateral Raise', 3, '12-15'),
    ProgramItem('EZ Bar Curl', 3, '10-12'),
    ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
  ]),
  'Lower': const ProgramDay('Quads · Glutes · Hamstrings', [
    ProgramItem('Hack Squat', 4, '8-10'),
    ProgramItem('Leg Press', 3, '10-12'),
    ProgramItem('Lying Leg Curl', 4, '10-12'),
    ProgramItem('Hip Thrust', 3, '8-10'),
    ProgramItem('Leg Extension', 3, '12-15'),
    ProgramItem('Seated Calf Raise', 4, '15-20'),
  ]),
};

const dayOrder = ['Push', 'Pull', 'Legs', 'Upper', 'Lower'];

/// Default weekly split, keyed by `DateTime.now().weekday % 7` (0=Sun..6=Sat).
/// Missing days (0, 6 here) are rest days.
const weekday = {1: 'Push', 2: 'Pull', 3: 'Legs', 4: 'Upper', 5: 'Lower'};

/// The default schedule as a 7-slot list (index 0=Sun..6=Sat), null = rest.
List<String?> defaultSchedule() => List.generate(7, (i) => weekday[i]);

/// Reads the user's (possibly reshuffled) weekly schedule from settings,
/// falling back to [defaultSchedule] if they've never customized it.
List<String?> scheduleFromSettings(Map<String, dynamic> settings) {
  final raw = settings['schedule'];
  if (raw is List && raw.length == 7) {
    return List<String?>.generate(7, (i) => raw[i] as String?);
  }
  return defaultSchedule();
}
