import '../../../shared/lib/helpers.dart';
import '../domain/plan.dart';
import 'plan_options.dart';

/// The lowest calorie goal this app will ever set, regardless of how big a
/// deficit is requested — `max(1.2×BMR, the flat 1200/1500 minimum by sex)`.
/// 1.2×BMR alone can dip under that flat minimum for someone with a low BMR
/// (light, small), under-protecting exactly who it's meant to protect;
/// taking whichever is higher covers both. Neither number is a citation —
/// see the Settings pace card's own notes for that honesty.
int safetyFloorKcal(double bmr, String sex) {
  final flat = sex == 'female' ? 1200.0 : 1500.0;
  final scaled = 1.2 * bmr;
  return round10(scaled > flat ? scaled : flat);
}

/// Coach: generates the full training/nutrition plan from onboarding/settings profile data.
///
/// [paceKcal] is the direct deficit (fat loss) or surplus (muscle gain) from
/// the Settings pace slider, 100–1000 / 150–500 respectively. When null,
/// falls back to the original behavior of deriving a pace from
/// [targetWeight]/[targetDate] — onboarding and the training-plan chooser
/// don't set a pace yet, so they're unaffected.
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
  num? paceKcal,
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
  int dailyPace = 0;
  bool paceCapped = false;
  int floorKcal = 0;
  String? tentativeDate;

  if (goalType == 'fatLoss') {
    final kgToLose = (kg - tgt) > 0 ? (kg - tgt) : 0;
    floorKcal = safetyFloorKcal(bmr, sex);
    double deficit;
    if (paceKcal != null) {
      deficit = paceKcal.toDouble().clamp(100, 1000).toDouble();
    } else {
      final reqDeficit = (kgToLose * 7700) / useDays;
      final safeMax = (0.25 * tdee) < 850 ? 0.25 * tdee : 850;
      final deficitRaw = reqDeficit > 0 ? reqDeficit : 400;
      deficit = clamp(deficitRaw, 250, safeMax).toDouble();
      feasible = reqDeficit <= safeMax + 1;
      if (!feasible) {
        final need = ((kgToLose * 7700) / safeMax).ceil();
        suggestedDate = DateTime.now().add(Duration(days: need)).toIso8601String().substring(0, 10);
      }
    }
    // The requested pace always applies exactly as asked — no silent
    // clamping to the safety floor. [paceCapped] just flags that this
    // deficit pushes the goal under the floor, so the UI can warn about it
    // instead of quietly overriding what was chosen.
    calorieGoal = round10(tdee - deficit);
    weeklyRate = double.parse((((tdee - calorieGoal) * 7) / 7700).toStringAsFixed(2));
    dailyPace = (tdee - calorieGoal).round();
    paceCapped = calorieGoal < floorKcal;
    if (kgToLose > 0 && dailyPace > 0) {
      final need = ((kgToLose * 7700) / dailyPace).ceil();
      tentativeDate = DateTime.now().add(Duration(days: need)).toIso8601String().substring(0, 10);
    }
    headline = 'Lose ~${weeklyRate}kg/week in a $dailyPace kcal daily deficit.';
  } else if (goalType == 'weightGain') {
    final kgToGain = (tgt - kg) > 0 ? (tgt - kg) : 0;
    double surplus;
    if (paceKcal != null) {
      surplus = paceKcal.toDouble().clamp(150, 500).toDouble();
    } else {
      final reqSurplus = (kgToGain * 7700) / useDays;
      final surplusRaw = reqSurplus > 0 ? reqSurplus : 300;
      surplus = clamp(surplusRaw, 150, 500).toDouble();
      feasible = reqSurplus <= 500 + 1;
      if (!feasible) {
        final need = ((kgToGain * 7700) / 500).ceil();
        suggestedDate = DateTime.now().add(Duration(days: need)).toIso8601String().substring(0, 10);
      }
    }
    calorieGoal = round10(tdee + surplus);
    weeklyRate = double.parse(((surplus * 7) / 7700).toStringAsFixed(2));
    dailyPace = surplus.round();
    if (kgToGain > 0) {
      final need = ((kgToGain * 7700) / surplus).ceil();
      tentativeDate = DateTime.now().add(Duration(days: need)).toIso8601String().substring(0, 10);
    }
    headline = 'Gain ~${weeklyRate}kg/week in a $dailyPace kcal daily surplus (lean bulk).';
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
    dailyPace: dailyPace,
    paceCapped: paceCapped,
    safetyFloorKcal: floorKcal,
    tentativeDate: tentativeDate,
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
  final effectiveGoal = goalType ?? settings['goalType'] ?? 'fatLoss';
  // Kept as two separate keys (rather than one shared "pace") so switching
  // goal types doesn't leak a fat-loss deficit in as a muscle-gain surplus
  // or vice versa — each remembers its own last-set pace independently.
  final paceKey = effectiveGoal == 'weightGain' ? 'paceSurplusKcal' : 'paceDeficitKcal';
  return generatePlan(
    currentWeight: currentWeight,
    targetWeight: targetWeight,
    height: height,
    age: age,
    sex: settings['sex'] ?? 'male',
    activity: settings['activity'] ?? 'moderate',
    goalType: effectiveGoal,
    dietPref: settings['dietPref'] ?? 'veg',
    targetDate: settings['targetDate'] ?? '',
    calorieBuffer: (settings['calorieBuffer'] as num?)?.toInt() ?? 0,
    paceKcal: settings[paceKey] as num?,
  );
}
