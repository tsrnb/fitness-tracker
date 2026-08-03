import '../../exercises/exercise_library.dart' as exlib;
import '../domain/training_split.dart';
import 'training_splits_data.dart';

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

/// Effectiveness score (0-100) per goal: 'fatLoss' | 'weightGain' | 'maintain'.
/// Computed from the split's actual programmed exercises and weekly
/// schedule — not a hand-picked number. See the formula below and the
/// research each input is tied to.
Map<String, int> splitEffectiveness(TrainingSplit split) {
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

/// Total sets/week across the 5 major muscle groups — used only as a
/// display-order tiebreaker when two splits land on the same effectiveness
/// score (which happens for muscle growth once a split clears the
/// frequency/volume thresholds — see [splitEffectiveness]).
int splitTotalWeeklyVolume(TrainingSplit split) => _computeStats(split).weeklyVolumeByGroup.values.fold(0, (a, b) => a + b);

/// All splits ordered by effectiveness for [goal], most effective first —
/// the single source of truth for ranking, so the onboarding pre-selection
/// and the Settings chooser never disagree on order. Ties (common for
/// muscle growth once a split clears the frequency/volume thresholds) break
/// on total weekly volume.
List<TrainingSplit> rankedSplits(String goal) {
  final list = List<TrainingSplit>.from(trainingSplits);
  list.sort((a, b) {
    final cmp = (splitEffectiveness(b)[goal] ?? 0).compareTo(splitEffectiveness(a)[goal] ?? 0);
    if (cmp != 0) return cmp;
    return splitTotalWeeklyVolume(b).compareTo(splitTotalWeeklyVolume(a));
  });
  return list;
}
