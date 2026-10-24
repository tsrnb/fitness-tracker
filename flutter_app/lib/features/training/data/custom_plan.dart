import 'package:flutter/material.dart';
import '../../exercises/data/exercise_library_data.dart';
import '../domain/program.dart';
import '../domain/training_split.dart';

const customSplitId = 'custom';

/// One exercise row in the custom plan editor. Reps are kept as a
/// "8-10" style string, same as [ProgramItem.reps].
class CustomExercise {
  String name;
  int sets;
  String reps;
  double kg;
  CustomExercise(this.name, {this.sets = 3, this.reps = '8-10', this.kg = 20});

  Map<String, dynamic> toJson() => {'name': name, 'sets': sets, 'reps': reps, 'kg': kg};

  factory CustomExercise.fromJson(Map j) => CustomExercise(
        j['name'] as String,
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        reps: (j['reps'] as String?) ?? '8-10',
        kg: (j['kg'] as num?)?.toDouble() ?? 0,
      );
}

class CustomDay {
  String name;
  List<CustomExercise> items;
  CustomDay(this.name, [List<CustomExercise>? items]) : items = items ?? [];
}

/// The user's own plan: named days of exercises plus which weekday each day
/// lands on (`schedule[0]` = Sunday, same as [TrainingSplit.weekday]).
class CustomPlan {
  String name;
  List<CustomDay> days;
  List<int?> schedule; // index into [days], null = rest
  CustomPlan({required this.name, required this.days, List<int?>? schedule})
      : schedule = schedule ?? List<int?>.filled(7, null);

  factory CustomPlan.blank() => CustomPlan(
        name: 'My plan',
        days: [CustomDay('Day 1')],
        schedule: [null, 0, null, null, null, null, null],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'days': days.map((d) => {'name': d.name, 'items': d.items.map((e) => e.toJson()).toList()}).toList(),
        'schedule': schedule,
      };

  static CustomPlan? fromJson(dynamic raw) {
    if (raw is! Map || raw['days'] is! List) return null;
    final days = <CustomDay>[];
    for (final d in raw['days'] as List) {
      if (d is! Map || d['name'] is! String) return null;
      days.add(CustomDay(d['name'] as String, [
        for (final e in (d['items'] as List? ?? const []))
          if (e is Map && e['name'] is String) CustomExercise.fromJson(e),
      ]));
    }
    if (days.isEmpty) return null;
    final sched = raw['schedule'];
    final schedule = List<int?>.generate(7, (i) {
      final v = sched is List && i < sched.length ? sched[i] : null;
      return v is int && v >= 0 && v < days.length ? v : null;
    });
    return CustomPlan(name: (raw['name'] as String?) ?? 'My plan', days: days, schedule: schedule);
  }

  int get totalSets => days.fold(0, (a, d) => a + d.items.fold(0, (x, i) => x + i.sets));

  /// Day names must be unique (they key the program map); returns a copy of
  /// [days] with " 2", " 3"... appended to repeats and blanks replaced.
  List<String> uniqueDayNames() {
    final seen = <String>{};
    return [
      for (var i = 0; i < days.length; i++)
        () {
          var base = days[i].name.trim().isEmpty ? 'Day ${i + 1}' : days[i].name.trim();
          var n = base, k = 2;
          while (!seen.add(n)) {
            n = '$base $k';
            k++;
          }
          return n;
        }(),
    ];
  }

  TrainingSplit toSplit() {
    final names = uniqueDayNames();
    final program = <String, ProgramDay>{};
    for (var i = 0; i < days.length; i++) {
      final groupsHit = <String>[];
      for (final e in days[i].items) {
        final g = lib[e.name]?.group;
        if (g != null && !groupsHit.contains(g)) groupsHit.add(g);
      }
      program[names[i]] = ProgramDay(
        groupsHit.isEmpty ? 'Custom day' : groupsHit.take(3).join(' · '),
        [for (final e in days[i].items) ProgramItem(e.name, e.sets, e.reps, e.kg)],
      );
    }
    final weekday = <int, String>{
      for (var d = 0; d < 7; d++)
        if (schedule[d] != null) d: names[schedule[d]!],
    };
    final trainingDays = weekday.length;
    return TrainingSplit(
      id: customSplitId,
      name: name.trim().isEmpty ? 'My plan' : name.trim(),
      shortTag: '$trainingDays days/week',
      daysPerWeek: trainingDays,
      tagline: 'Built by you',
      description: 'Your own plan: ${days.length} training days, $totalSets sets in total.',
      icon: Icons.tune,
      program: program,
      dayOrder: names,
      weekday: weekday,
      dayAbbr: {
        for (final n in names) n: customDayAbbr(n),
      },
    );
  }
}

CustomPlan? customPlanFromSettings(Map<String, dynamic> settings) => CustomPlan.fromJson(settings['customPlan']);

TrainingSplit? customSplitFromSettings(Map<String, dynamic> settings) => customPlanFromSettings(settings)?.toSplit();

String customDayAbbr(String n) {
  final words = n.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final letters = words.map((w) => w[0]).join().toUpperCase();
  return letters.length > 2 ? letters.substring(0, 2) : letters;
}
