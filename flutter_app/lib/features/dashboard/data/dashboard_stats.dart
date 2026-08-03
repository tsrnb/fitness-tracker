import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../../../shared/lib/macro_totals.dart';
import '../../training/domain/program.dart';
import '../../training/data/training_splits_data.dart';

/// Everything the Dashboard's hero row, stats card, and weekly-sessions card
/// need for "today" — computed once so `build()` just renders it instead of
/// deriving ~30 lines of settings/history/activity lookups inline.
class DashboardSnapshot {
  final String? todayDay;
  final List<ProgramItem> exercises;
  final num kcalToday;
  final num protToday;
  final num protGoal;
  final num adjustedCalGoal;
  final num tdee;
  /// Positive = under maintenance (deficit), negative = over maintenance (surplus).
  final int balance;
  final dynamic goalType;
  final num? currentWeight;
  final num? targetWeight;
  final int? daysLeft;
  final Map<String, dynamic> activityToday;
  final num stepGoal;
  final int sessionsLast7Days;

  const DashboardSnapshot({
    required this.todayDay,
    required this.exercises,
    required this.kcalToday,
    required this.protToday,
    required this.protGoal,
    required this.adjustedCalGoal,
    required this.tdee,
    required this.balance,
    required this.goalType,
    required this.currentWeight,
    required this.targetWeight,
    required this.daysLeft,
    required this.activityToday,
    required this.stepGoal,
    required this.sessionsLast7Days,
  });
}

DashboardSnapshot computeDashboardSnapshot(AppState app) {
  final st = app.data.settings;
  final today = todayStr(st);
  final jsDow = DateTime.now().weekday % 7; // JS getDay(): 0=Sun..6=Sat
  final split = activeSplit(st);
  final todayDay = scheduleFromSettings(st, split)[jsDow];
  final exercises = todayDay != null ? split.program[todayDay]!.items : <ProgramItem>[];

  final meals = List<Map<String, dynamic>>.from(app.data.diet[today] ?? []);
  final todayTotals = sumMacros(meals);
  final calGoal = (st['calorieGoal'] ?? 2000) as num;
  final protGoal = (st['proteinGoal'] ?? 150) as num;
  final actToday = Map<String, dynamic>.from(app.data.activity[today] ?? {});
  final burnedToday = (actToday['kcal'] ?? 0) as num;
  final adjustedCalGoal = calGoal + burnedToday;
  final tdee = (app.data.plan?['tdee'] ?? calGoal) as num;
  final balance = (tdee - (todayTotals.kcal - burnedToday)).round();

  final weightList = app.data.weight;
  final lastWeight = weightList.isNotEmpty ? weightList.last['weight'] as num? : null;
  final cur = (st['currentWeight'] as num?) ?? lastWeight;
  final tgt = st['targetWeight'] as num?;
  final daysLeft = st['targetDate'] != null ? daysBetween(today, st['targetDate']).clamp(0, 1 << 30) : null;

  final act = actToday.isNotEmpty ? actToday : {'steps': 0, 'kcal': 0, 'min': 0};
  final stepGoal = (st['stepGoal'] ?? 10000) as num;
  final last7 = lastNDaysEntries(app.data.sessions, today, 7).length;

  return DashboardSnapshot(
    todayDay: todayDay,
    exercises: exercises,
    kcalToday: todayTotals.kcal,
    protToday: todayTotals.protein,
    protGoal: protGoal,
    adjustedCalGoal: adjustedCalGoal,
    tdee: tdee,
    balance: balance,
    goalType: st['goalType'],
    currentWeight: cur,
    targetWeight: tgt,
    daysLeft: daysLeft,
    activityToday: act,
    stepGoal: stepGoal,
    sessionsLast7Days: last7,
  );
}
