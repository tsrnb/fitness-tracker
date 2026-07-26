import 'package:flutter/material.dart';
import '../exercises/exercise_library.dart' as exlib;
import 'program.dart';

/// A selectable weekly training split (e.g. Push/Pull/Legs, Upper/Lower).
/// Each split owns its own day-type -> [ProgramDay] map and default weekly
/// layout, so switching splits swaps the whole training experience (which
/// exercises show up, how many days/week, the calendar strip colors/labels)
/// without touching any other part of the app.
class TrainingSplit {
  final String id;
  final String name;
  final String shortTag; // e.g. "5 days/week"
  final int daysPerWeek;
  final String tagline;
  final String description;
  final IconData icon;

  final Map<String, ProgramDay> program;
  final List<String> dayOrder;

  /// Default schedule, keyed by `DateTime.now().weekday % 7` (0=Sun..6=Sat).
  /// Missing days are rest days.
  final Map<int, String> weekday;

  /// Short 2-letter code per day type, for the weekly calendar strip.
  final Map<String, String> dayAbbr;

  const TrainingSplit({
    required this.id,
    required this.name,
    required this.shortTag,
    required this.daysPerWeek,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.program,
    required this.dayOrder,
    required this.weekday,
    required this.dayAbbr,
  });

  List<String?> defaultSchedule() => List.generate(7, (i) => weekday[i]);

  /// Effectiveness score (0-100) per goal: 'fatLoss' | 'weightGain' | 'maintain'.
  /// Computed from this split's actual programmed exercises and weekly
  /// schedule — not a hand-picked number. See [_effectivenessFor] for the
  /// exact formula and the research each input is tied to.
  Map<String, int> get effectiveness => _effectivenessFor(this);

  /// Total sets/week across the 5 major muscle groups — used only as a
  /// display-order tiebreaker when two splits land on the same effectiveness
  /// score (which happens for muscle growth once a split clears the
  /// frequency/volume thresholds — see [_effectivenessFor]).
  int get totalWeeklyVolume => _computeStats(this).weeklyVolumeByGroup.values.fold(0, (a, b) => a + b);
}

/// The 5 muscle groups tracked for scoring (matches exercise_library.dart's
/// `groups`, minus Core — no split here programs Core as a primary target).
const _majorGroups = ['Chest', 'Back', 'Shoulders', 'Legs', 'Arms'];

class _SplitStats {
  final int sessionsPerWeek;
  final Map<String, int> weeklyVolumeByGroup; // sets/week, per major group
  final Map<String, int> weeklyFrequencyByGroup; // sessions/week touching that group
  final double avgGroupsPerSession; // of the 5 major groups
  const _SplitStats(this.sessionsPerWeek, this.weeklyVolumeByGroup, this.weeklyFrequencyByGroup, this.avgGroupsPerSession);
}

/// Walks the split's actual 7-day default schedule (so a 6-day split's
/// repeated day-types, e.g. Push on both Monday and Thursday, are counted
/// twice) and tallies real sets/week and sessions/week per muscle group,
/// using exercise_library.dart's exercise -> group mapping.
_SplitStats _computeStats(TrainingSplit split) {
  final volume = {for (final g in _majorGroups) g: 0};
  final freqDays = {for (final g in _majorGroups) g: <int>{}};
  int sessions = 0;
  double groupsSum = 0;
  for (var dow = 0; dow < 7; dow++) {
    final dayType = split.weekday[dow];
    if (dayType == null) continue;
    sessions++;
    final day = split.program[dayType]!;
    final groupsThisSession = <String>{};
    for (final item in day.items) {
      final group = exlib.lib[item.name]?.group;
      if (group == null || !_majorGroups.contains(group)) continue;
      volume[group] = volume[group]! + item.sets;
      freqDays[group]!.add(dow);
      groupsThisSession.add(group);
    }
    groupsSum += groupsThisSession.length;
  }
  final freqCount = {for (final g in _majorGroups) g: freqDays[g]!.length};
  final avgGroupsPerSession = sessions == 0 ? 0.0 : groupsSum / sessions;
  return _SplitStats(sessions, volume, freqCount, avgGroupsPerSession);
}

double _avg(Map<String, int> m) => m.isEmpty ? 0 : m.values.reduce((a, b) => a + b) / m.length;

int _pct(double v) => v.clamp(0, 100).round();

Map<String, int> _effectivenessFor(TrainingSplit split) {
  final stats = _computeStats(split);
  final avgFreq = _avg(stats.weeklyFrequencyByGroup); // sessions/week per muscle
  final avgVolume = _avg(stats.weeklyVolumeByGroup); // sets/week per muscle

  // Training a muscle >=2x/week beats 1x/week for hypertrophy at matched
  // volume (Schoenfeld & Grgic, 2018 meta-analysis) — scales 1x/week to 50,
  // 2x/week and above to 100.
  final freqScore = _pct(avgFreq / 2.0 * 100);

  // Volume-hypertrophy dose-response reviews commonly cite ~10-20 hard
  // sets/muscle/week as the productive range; scored against a 16-set
  // midpoint, saturating (not penalizing) beyond it.
  final volumeScore = _pct(avgVolume / 16 * 100);

  // Share of the 5 major muscle groups worked in an average session —
  // proxies the "more total muscle mass per session" mechanism behind
  // full-body training's fat-loss edge over split routines at equal
  // weekly volume (Carneiro et al., Eur J Sport Sci, 2024).
  final engagementScore = _pct(stats.avgGroupsPerSession / _majorGroups.length * 100);

  // Fewer weekly sessions is easier to sustain long-term — weighted in for
  // "maintain" since adherence, not maximizing stimulus, is the priority.
  final sustainabilityScore = _pct((7 - stats.sessionsPerWeek) / 4 * 100);
  final sessionCountScore = _pct(stats.sessionsPerWeek / 6 * 100);

  return {
    'weightGain': _pct(0.5 * freqScore + 0.5 * volumeScore),
    'fatLoss': _pct(0.45 * engagementScore + 0.35 * freqScore + 0.20 * sessionCountScore),
    'maintain': _pct(0.45 * freqScore + 0.25 * volumeScore + 0.30 * sustainabilityScore),
  };
}

/// All splits ordered by effectiveness for [goal], most effective first —
/// the single source of truth for ranking, so the onboarding pre-selection
/// and the Settings chooser never disagree on order. Ties (common for
/// muscle growth once a split clears the frequency/volume thresholds) break
/// on total weekly volume.
List<TrainingSplit> rankedSplits(String goal) {
  final list = List<TrainingSplit>.from(trainingSplits);
  list.sort((a, b) {
    final cmp = (b.effectiveness[goal] ?? 0).compareTo(a.effectiveness[goal] ?? 0);
    if (cmp != 0) return cmp;
    return b.totalWeeklyVolume.compareTo(a.totalWeeklyVolume);
  });
  return list;
}

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
