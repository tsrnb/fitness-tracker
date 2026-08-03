import 'package:flutter/material.dart';
import '../domain/program.dart';
import '../domain/training_split.dart';

const defaultSplitId = 'ppul5';

final List<TrainingSplit> trainingSplits = [
  TrainingSplit(
    id: 'fullBody3',
    name: 'Full Body',
    shortTag: '3 days/week',
    daysPerWeek: 3,
    tagline: 'Train everything, every session',
    description:
        'Every major muscle group gets worked each workout. The lowest weekly time commitment, the easiest to recover from, and — thanks to the calorie burn of full-body sessions — the top pick for fat loss and general fitness.',
    icon: Icons.all_inclusive,
    dayOrder: const ['Full Body A', 'Full Body B', 'Full Body C'],
    weekday: const {1: 'Full Body A', 3: 'Full Body B', 5: 'Full Body C'},
    dayAbbr: const {'Full Body A': 'A', 'Full Body B': 'B', 'Full Body C': 'C'},
    program: const {
      'Full Body A': ProgramDay('Squat · Push · Pull', [
        ProgramItem('Barbell Squat', 4, '6-8'),
        ProgramItem('Barbell Bench Press', 3, '8-10'),
        ProgramItem('Chest Supported Row', 3, '8-10'),
        ProgramItem('Dumbbell Lateral Raise', 3, '12-15'),
        ProgramItem('Lying Leg Curl', 3, '10-12'),
        ProgramItem('Cable Crunch', 3, '12-15'),
      ]),
      'Full Body B': ProgramDay('Hinge · Push · Pull', [
        ProgramItem('Hip Thrust', 4, '8-10'),
        ProgramItem('Incline Dumbbell Press', 3, '8-10'),
        ProgramItem('Wide Grip Lat Pulldown', 3, '8-10'),
        ProgramItem('Leg Press', 3, '10-12'),
        ProgramItem('Barbell Curl', 3, '10-12'),
        ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
      ]),
      'Full Body C': ProgramDay('Squat · Press · Row', [
        ProgramItem('Front Squat', 4, '6-8'),
        ProgramItem('Overhead Press', 3, '8-10'),
        ProgramItem('Seated Cable Row', 3, '10-12'),
        ProgramItem('Leg Extension', 3, '12-15'),
        ProgramItem('Standing Calf Raise', 4, '15-20'),
        ProgramItem('Hanging Leg Raise', 3, '12-15'),
      ]),
    },
  ),
  TrainingSplit(
    id: 'upperLower4',
    name: 'Upper / Lower',
    shortTag: '4 days/week',
    daysPerWeek: 4,
    tagline: 'Balanced strength and size',
    description:
        'Two upper days and two lower days a week. Each muscle group gets trained twice, which the evidence favors over once-weekly training — enough volume to grow, enough recovery for heavy compounds. The standard pick for general strength and muscle.',
    icon: Icons.swap_vert,
    dayOrder: const ['Upper A', 'Lower A', 'Upper B', 'Lower B'],
    weekday: const {1: 'Upper A', 2: 'Lower A', 4: 'Upper B', 5: 'Lower B'},
    dayAbbr: const {'Upper A': 'UA', 'Lower A': 'LA', 'Upper B': 'UB', 'Lower B': 'LB'},
    program: const {
      'Upper A': ProgramDay('Chest · Back · Shoulders (heavy)', [
        ProgramItem('Barbell Bench Press', 4, '6-8'),
        ProgramItem('Chest Supported Row', 4, '6-8'),
        ProgramItem('Overhead Press', 3, '8-10'),
        ProgramItem('Wide Grip Lat Pulldown', 3, '8-10'),
        ProgramItem('Barbell Curl', 3, '10-12'),
        ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
      ]),
      'Lower A': ProgramDay('Quads · Hamstrings (heavy)', [
        ProgramItem('Barbell Squat', 4, '6-8'),
        ProgramItem('Lying Leg Curl', 4, '8-10'),
        ProgramItem('Leg Press', 3, '10-12'),
        ProgramItem('Standing Calf Raise', 4, '15-20'),
        ProgramItem('Cable Crunch', 3, '12-15'),
      ]),
      'Upper B': ProgramDay('Chest · Back · Shoulders (volume)', [
        ProgramItem('Incline Dumbbell Press', 3, '8-10'),
        ProgramItem('Seated Cable Row', 3, '10-12'),
        ProgramItem('Machine Shoulder Press', 3, '10-12'),
        ProgramItem('Lat Pulldown', 3, '10-12'),
        ProgramItem('Dumbbell Lateral Raise', 3, '12-15'),
        ProgramItem('Hammer Curl', 3, '10-12'),
        ProgramItem('Overhead Cable Tricep Extension', 3, '10-12'),
      ]),
      'Lower B': ProgramDay('Glutes · Hamstrings (volume)', [
        ProgramItem('Hip Thrust', 4, '8-10'),
        ProgramItem('Hack Squat', 3, '10-12'),
        ProgramItem('Leg Extension', 3, '12-15'),
        ProgramItem('Seated Leg Curl', 3, '10-12'),
        ProgramItem('Seated Calf Raise', 4, '15-20'),
      ]),
    },
  ),
  TrainingSplit(
    id: 'ppul5',
    name: 'Push / Pull / Upper / Lower',
    shortTag: '5 days/week',
    daysPerWeek: 5,
    tagline: 'The all-rounder',
    description:
        'A dedicated push and pull day for chest/back volume, a leg day, then an upper/lower finisher for extra weekly frequency. A strong blend of volume and recoverability that suits most intermediate lifters.',
    icon: Icons.dashboard_customize,
    dayOrder: const ['Push', 'Pull', 'Legs', 'Upper', 'Lower'],
    weekday: const {1: 'Push', 2: 'Pull', 3: 'Legs', 4: 'Upper', 5: 'Lower'},
    dayAbbr: const {'Push': 'Ps', 'Pull': 'Pl', 'Legs': 'Lg', 'Upper': 'Up', 'Lower': 'Lo'},
    program: const {
      'Push': ProgramDay('Chest · Shoulders · Triceps', [
        ProgramItem('Barbell Bench Press', 4, '6-8'),
        ProgramItem('Incline Dumbbell Press', 3, '8-10'),
        ProgramItem('Pec Deck Fly', 3, '10-12'),
        ProgramItem('Dumbbell Lateral Raise', 4, '12-15'),
        ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
        ProgramItem('Overhead Cable Tricep Extension', 3, '10-12'),
      ]),
      'Pull': ProgramDay('Back · Rear Delts · Biceps', [
        ProgramItem('Wide Grip Lat Pulldown', 4, '8-10'),
        ProgramItem('Chest Supported Row', 4, '8-10'),
        ProgramItem('Seated Cable Row', 3, '10-12'),
        ProgramItem('Face Pull', 3, '12-15'),
        ProgramItem('Rear Delt Fly', 3, '12-15'),
        ProgramItem('Barbell Curl', 3, '8-10'),
        ProgramItem('Hammer Curl', 3, '10-12'),
      ]),
      'Legs': ProgramDay('Quads · Hamstrings · Calves', [
        ProgramItem('Barbell Squat', 4, '6-8'),
        ProgramItem('Leg Press', 4, '10-12'),
        ProgramItem('Leg Extension', 3, '12-15'),
        ProgramItem('Lying Leg Curl', 4, '10-12'),
        ProgramItem('Standing Calf Raise', 4, '15-20'),
        ProgramItem('Seated Calf Raise', 3, '15-20'),
      ]),
      'Upper': ProgramDay('Chest · Back · Shoulders · Arms', [
        ProgramItem('Incline Barbell Press', 3, '8-10'),
        ProgramItem('Lat Pulldown', 3, '8-10'),
        ProgramItem('Seated Cable Row', 3, '10-12'),
        ProgramItem('Machine Shoulder Press', 3, '8-10'),
        ProgramItem('Dumbbell Lateral Raise', 3, '12-15'),
        ProgramItem('EZ Bar Curl', 3, '10-12'),
        ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
      ]),
      'Lower': ProgramDay('Quads · Glutes · Hamstrings', [
        ProgramItem('Hack Squat', 4, '8-10'),
        ProgramItem('Leg Press', 3, '10-12'),
        ProgramItem('Lying Leg Curl', 4, '10-12'),
        ProgramItem('Hip Thrust', 3, '8-10'),
        ProgramItem('Leg Extension', 3, '12-15'),
        ProgramItem('Seated Calf Raise', 4, '15-20'),
      ]),
    },
  ),
  TrainingSplit(
    id: 'ppl6',
    name: 'Push / Pull / Legs',
    shortTag: '6 days/week',
    daysPerWeek: 6,
    tagline: 'Maximum hypertrophy volume',
    description:
        'Push, pull and legs, twice each across six sessions. Trains every muscle group twice a week at high volume — the research-backed top pick for pure muscle growth if your schedule and recovery can support it.',
    icon: Icons.repeat,
    dayOrder: const ['Push', 'Pull', 'Legs'],
    weekday: const {1: 'Push', 2: 'Pull', 3: 'Legs', 4: 'Push', 5: 'Pull', 6: 'Legs'},
    dayAbbr: const {'Push': 'Ps', 'Pull': 'Pl', 'Legs': 'Lg'},
    program: const {
      'Push': ProgramDay('Chest · Shoulders · Triceps', [
        ProgramItem('Barbell Bench Press', 4, '6-8'),
        ProgramItem('Machine Shoulder Press', 3, '8-10'),
        ProgramItem('Incline Dumbbell Press', 3, '8-10'),
        ProgramItem('Dumbbell Lateral Raise', 4, '12-15'),
        ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
      ]),
      'Pull': ProgramDay('Back · Rear Delts · Biceps', [
        ProgramItem('Wide Grip Lat Pulldown', 4, '8-10'),
        ProgramItem('Chest Supported Row', 4, '8-10'),
        ProgramItem('Face Pull', 3, '12-15'),
        ProgramItem('Barbell Curl', 3, '8-10'),
        ProgramItem('Hammer Curl', 3, '10-12'),
      ]),
      'Legs': ProgramDay('Quads · Hamstrings · Calves', [
        ProgramItem('Barbell Squat', 4, '6-8'),
        ProgramItem('Leg Press', 3, '10-12'),
        ProgramItem('Lying Leg Curl', 4, '10-12'),
        ProgramItem('Leg Extension', 3, '12-15'),
        ProgramItem('Standing Calf Raise', 4, '15-20'),
      ]),
    },
  ),
  TrainingSplit(
    id: 'arnold6',
    name: 'Arnold Split',
    shortTag: '6 days/week',
    daysPerWeek: 6,
    tagline: 'Old-school chest/back combo',
    description:
        'Chest & back paired, then shoulders & arms, then legs — repeated twice a week. A classic bodybuilding split that gives arms and shoulders extra direct volume, at the cost of a heavier weekly time commitment.',
    icon: Icons.fitness_center,
    dayOrder: const ['Chest & Back', 'Shoulders & Arms', 'Legs'],
    weekday: const {1: 'Chest & Back', 2: 'Shoulders & Arms', 3: 'Legs', 4: 'Chest & Back', 5: 'Shoulders & Arms', 6: 'Legs'},
    dayAbbr: const {'Chest & Back': 'CB', 'Shoulders & Arms': 'SA', 'Legs': 'Lg'},
    program: const {
      'Chest & Back': ProgramDay('Chest · Back', [
        ProgramItem('Barbell Bench Press', 4, '6-8'),
        ProgramItem('Chest Supported Row', 4, '6-8'),
        ProgramItem('Incline Dumbbell Press', 3, '8-10'),
        ProgramItem('Wide Grip Lat Pulldown', 3, '8-10'),
        ProgramItem('Cable Crossover', 3, '12-15'),
        ProgramItem('Straight Arm Pulldown', 3, '12-15'),
      ]),
      'Shoulders & Arms': ProgramDay('Shoulders · Biceps · Triceps', [
        ProgramItem('Arnold Press', 4, '8-10'),
        ProgramItem('Dumbbell Lateral Raise', 4, '12-15'),
        ProgramItem('Rear Delt Fly', 3, '12-15'),
        ProgramItem('Barbell Curl', 3, '8-10'),
        ProgramItem('Skull Crushers', 3, '8-10'),
        ProgramItem('Hammer Curl', 3, '10-12'),
        ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
      ]),
      'Legs': ProgramDay('Quads · Hamstrings · Calves', [
        ProgramItem('Barbell Squat', 4, '6-8'),
        ProgramItem('Leg Press', 4, '10-12'),
        ProgramItem('Lying Leg Curl', 4, '10-12'),
        ProgramItem('Leg Extension', 3, '12-15'),
        ProgramItem('Standing Calf Raise', 4, '15-20'),
      ]),
    },
  ),
  TrainingSplit(
    id: 'broSplit5',
    name: 'Bro Split',
    shortTag: '5 days/week',
    daysPerWeek: 5,
    tagline: 'One muscle, all-out',
    description:
        'One muscle group per day — chest, back, shoulders, arms, legs. Huge per-session volume and a strong mind-muscle focus, but each muscle only gets trained once a week, which the evidence ranks behind the other splits here for growth or fat loss.',
    icon: Icons.view_agenda_outlined,
    dayOrder: const ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs'],
    weekday: const {1: 'Chest', 2: 'Back', 3: 'Shoulders', 4: 'Arms', 5: 'Legs'},
    dayAbbr: const {'Chest': 'Ch', 'Back': 'Bk', 'Shoulders': 'Sh', 'Arms': 'Ar', 'Legs': 'Lg'},
    program: const {
      'Chest': ProgramDay('Full chest volume', [
        ProgramItem('Barbell Bench Press', 4, '6-8'),
        ProgramItem('Incline Dumbbell Press', 4, '8-10'),
        ProgramItem('Pec Deck Fly', 3, '10-12'),
        ProgramItem('Cable Crossover', 3, '12-15'),
        ProgramItem('Weighted Dips', 3, '8-10'),
      ]),
      'Back': ProgramDay('Full back volume', [
        ProgramItem('Pull-Up', 4, '6-8'),
        ProgramItem('Barbell Row', 4, '8-10'),
        ProgramItem('Seated Cable Row', 3, '10-12'),
        ProgramItem('Straight Arm Pulldown', 3, '12-15'),
        ProgramItem('Machine High Row', 3, '10-12'),
      ]),
      'Shoulders': ProgramDay('Full shoulder volume', [
        ProgramItem('Overhead Press', 4, '6-8'),
        ProgramItem('Dumbbell Lateral Raise', 4, '12-15'),
        ProgramItem('Cable Lateral Raise', 3, '12-15'),
        ProgramItem('Rear Delt Fly', 3, '12-15'),
        ProgramItem('Upright Row', 3, '10-12'),
      ]),
      'Arms': ProgramDay('Biceps · Triceps volume', [
        ProgramItem('Barbell Curl', 4, '8-10'),
        ProgramItem('Close Grip Bench Press', 4, '8-10'),
        ProgramItem('Incline Dumbbell Curl', 3, '10-12'),
        ProgramItem('Overhead Cable Tricep Extension', 3, '10-12'),
        ProgramItem('Hammer Curl', 3, '10-12'),
        ProgramItem('Rope Tricep Pushdown', 3, '10-12'),
      ]),
      'Legs': ProgramDay('Full leg volume', [
        ProgramItem('Barbell Squat', 4, '6-8'),
        ProgramItem('Hack Squat', 3, '10-12'),
        ProgramItem('Lying Leg Curl', 4, '10-12'),
        ProgramItem('Hip Thrust', 3, '8-10'),
        ProgramItem('Leg Extension', 3, '12-15'),
        ProgramItem('Standing Calf Raise', 4, '15-20'),
      ]),
    },
  ),
];

TrainingSplit splitById(String? id) {
  for (final s in trainingSplits) {
    if (s.id == id) return s;
  }
  return trainingSplits.firstWhere((s) => s.id == defaultSplitId);
}

TrainingSplit activeSplit(Map<String, dynamic> settings) => splitById(settings['trainingSplitId'] as String?);

/// Reads the user's (possibly reshuffled) weekly schedule from settings,
/// falling back to [split]'s default if they've never customized it or if
/// it still refers to a different split's day types.
List<String?> scheduleFromSettings(Map<String, dynamic> settings, TrainingSplit split) {
  final raw = settings['schedule'];
  if (raw is List && raw.length == 7 && raw.every((d) => d == null || split.dayOrder.contains(d))) {
    return List<String?>.generate(7, (i) => raw[i] as String?);
  }
  return split.defaultSchedule();
}

/// The first matching prescription for [exerciseName] from any split's
/// program — used where there's no settings/active-split context (e.g. the
/// exercise library's detail sheet) to still show a representative
/// sets/reps starting point.
ProgramItem? findAnyPrescription(String exerciseName) {
  for (final split in trainingSplits) {
    for (final d in split.dayOrder) {
      final match = split.program[d]!.items.where((x) => x.name == exerciseName);
      if (match.isNotEmpty) return match.first;
    }
  }
  return null;
}
