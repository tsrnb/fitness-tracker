import '../../../shared/lib/helpers.dart';
import '../domain/plan.dart';
import 'plan_options.dart';

/// Coach: generates the full training/nutrition plan from onboarding/settings profile data.
Plan generatePlan({
  required double currentWeight,
  required double targetWeight,
  required double height,
  required double age,
  required String sex,
  required String activity,
  required String goalType,
  required String dietPref,
  required String targetDate,
  int calorieBuffer = 0,
}) {
  final kg = currentWeight, tgt = targetWeight, cm = height;
  final male = sex != 'female';
  final bmr = 10 * kg + 6.25 * cm - 5 * age + (male ? 5 : -161);
  final af = activityFactors[activity] ?? activityFactors['moderate']!;
  final tdee = bmr * af;
  final today = todayStr();
  final days = [14, daysBetween(today, targetDate.isEmpty ? today : targetDate)].reduce((a, b) => a > b ? a : b);
  final effDays = days == 0 ? 84 : days;
  final useDays = effDays < 14 ? 14 : effDays;

  int calorieGoal;
  double weeklyRate;
  bool feasible = true;
  String? suggestedDate;
  String headline;

  if (goalType == 'fatLoss') {
    final kgToLose = (kg - tgt) > 0 ? (kg - tgt) : 0;
    final reqDeficit = (kgToLose * 7700) / useDays;
    final safeMax = (0.25 * tdee) < 850 ? 0.25 * tdee : 850;
    final deficitRaw = reqDeficit > 0 ? reqDeficit : 400;
    final deficit = clamp(deficitRaw, 250, safeMax);
    calorieGoal = round10(tdee - deficit > 1.2 * bmr ? tdee - deficit : 1.2 * bmr);
    weeklyRate = double.parse((((tdee - calorieGoal) * 7) / 7700).toStringAsFixed(2));
    feasible = reqDeficit <= safeMax + 1;
    if (!feasible) {
      final need = ((kgToLose * 7700) / safeMax).ceil();
      suggestedDate = DateTime.now().add(Duration(days: need)).toIso8601String().substring(0, 10);
    }
    headline = 'Lose ~${weeklyRate}kg/week in a ${(tdee - calorieGoal).round()} kcal daily deficit.';
  } else if (goalType == 'weightGain') {
    final kgToGain = (tgt - kg) > 0 ? (tgt - kg) : 0;
    final reqSurplus = (kgToGain * 7700) / useDays;
    final surplusRaw = reqSurplus > 0 ? reqSurplus : 300;
    final surplus = clamp(surplusRaw, 150, 500);
    calorieGoal = round10(tdee + surplus);
    weeklyRate = double.parse(((surplus * 7) / 7700).toStringAsFixed(2));
    feasible = reqSurplus <= 500 + 1;
    if (!feasible) {
      final need = ((kgToGain * 7700) / 500).ceil();
      suggestedDate = DateTime.now().add(Duration(days: need)).toIso8601String().substring(0, 10);
    }
    headline = 'Gain ~${weeklyRate}kg/week in a ${(calorieGoal - tdee).round()} kcal daily surplus (lean bulk).';
  } else {
    calorieGoal = round10(tdee);
    weeklyRate = 0;
    headline = 'Maintain around $calorieGoal kcal/day.';
  }

  // Manual nudge on top of the TDEE-derived target — the formula is only an
  // estimate, so let the user dial it in a little.
  calorieGoal = round10((calorieGoal + calorieBuffer).toDouble());

  final proteinPerKg = goalType == 'fatLoss' ? 2.0 : 1.8;
  final proteinGoalRaw = (proteinPerKg * kg).round();
  final proteinGoal = proteinGoalRaw > 130 ? proteinGoalRaw : 130;
  final stepGoal = goalType == 'fatLoss' ? 10000 : 8000;

  // Fat floor of ~0.8g/kg bodyweight; remaining calories (after protein and
  // fat) go to carbs, with a sane minimum if the math goes negative on a very
  // low calorie goal.
  final fatGoal = (0.8 * kg).round();
  final carbCaloriesRaw = calorieGoal - proteinGoal * 4 - fatGoal * 9;
  final carbGoal = ((carbCaloriesRaw > 200 ? carbCaloriesRaw : 200) / 4).round();

  // Institute of Medicine / Academy of Nutrition and Dietetics guideline:
  // ~14g fiber per 1000 kcal consumed, floored at a sane minimum.
  final fiberGoalRaw = (14 * calorieGoal / 1000).round();
  final fiberGoal = fiberGoalRaw > 20 ? fiberGoalRaw : 20;

  final cardioNote = goalType == 'fatLoss'
      ? "2–3 easy 15–20 min incline walks after lifting, plus daily steps. Don't overdo cardio — muscle retention is the priority."
      : 'Keep cardio light (steps + warm-ups). Extra cardio just eats into your surplus.';
  // Goal-based rep-range guidance — deliberately doesn't name a split, since
  // the caller shows the user's actual chosen split (see TrainingSplit)
  // right alongside this note.
  final splitNote = goalType == 'weightGain'
      ? 'Lower reps on the first lift of each session (6–8), push progressive overload every week.'
      : 'Keep the main lifts heavy (6–8) to hold strength, higher reps on isolation work.';

  final meals = mealDays[dietPref] ?? mealDays['veg']!;

  return Plan(
    tdee: tdee.round(),
    bmr: bmr.round(),
    calorieGoal: calorieGoal,
    proteinGoal: proteinGoal,
    carbGoal: carbGoal,
    fatGoal: fatGoal,
    fiberGoal: fiberGoal,
    stepGoal: stepGoal,
    weeklyRate: weeklyRate,
    feasible: feasible,
    suggestedDate: suggestedDate,
    headline: headline,
    cardioNote: cardioNote,
    splitNote: splitNote,
    meals: meals,
  );
}

/// Parses the string-keyed profile fields out of a `settings`/draft map and
/// calls [generatePlan] — the exact parse-then-generate shape that Settings
/// and the Training Plan chooser each re-implemented separately. Pass
/// [goalType] to override `settings['goalType']` (e.g. a not-yet-saved
/// selection in the training plan chooser).
Plan buildPlanFromSettings(Map<String, dynamic> settings, {String? goalType}) {
  final currentWeight = double.tryParse('${settings['currentWeight'] ?? ''}') ?? 0;
  final targetWeight = double.tryParse('${settings['targetWeight'] ?? ''}') ?? currentWeight;
  final height = double.tryParse('${settings['height'] ?? ''}') ?? 0;
  final age = double.tryParse('${settings['age'] ?? ''}') ?? 0;
  return generatePlan(
    currentWeight: currentWeight,
    targetWeight: targetWeight,
    height: height,
    age: age,
    sex: settings['sex'] ?? 'male',
    activity: settings['activity'] ?? 'moderate',
    goalType: goalType ?? settings['goalType'] ?? 'fatLoss',
    dietPref: settings['dietPref'] ?? 'veg',
    targetDate: settings['targetDate'] ?? '',
    calorieBuffer: (settings['calorieBuffer'] as num?)?.toInt() ?? 0,
  );
}
