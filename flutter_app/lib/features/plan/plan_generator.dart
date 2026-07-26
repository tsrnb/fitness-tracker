import '../../shared/lib/helpers.dart';

class MealItem {
  final String time;
  final String name;
  final int kcal;
  final int protein;
  const MealItem(this.time, this.name, this.kcal, this.protein);

  Map<String, dynamic> toJson() => {'time': time, 'name': name, 'kcal': kcal, 'protein': protein};
  factory MealItem.fromJson(Map<String, dynamic> j) =>
      MealItem(j['time'], j['name'], (j['kcal'] as num).toInt(), (j['protein'] as num).toInt());
}

/// Sample "bachelor-simple" meal day per preference (portions scale to the calorie target).
final Map<String, List<MealItem>> _mealDays = {
  'veg': const [
    MealItem('Breakfast', 'Oats + whey + banana', 435, 38),
    MealItem('Lunch', 'Rice + dal + paneer bhurji', 620, 33),
    MealItem('Snack', 'Greek yogurt + peanut butter', 310, 28),
    MealItem('Dinner', 'Roti + rajma + salad', 500, 22),
    MealItem('Before bed', 'Milk + whey', 270, 32),
  ],
  'egg': const [
    MealItem('Breakfast', '3-egg omelette + 2 toast', 400, 26),
    MealItem('Lunch', 'Rice + dal + paneer', 600, 34),
    MealItem('Snack', 'Greek yogurt + banana', 260, 22),
    MealItem('Dinner', 'Roti + soya curry', 480, 30),
    MealItem('Before bed', 'Milk + whey', 270, 32),
  ],
  'nonveg': const [
    MealItem('Breakfast', '3 eggs + 2 toast', 380, 26),
    MealItem('Lunch', 'Rice + chicken curry + salad', 620, 45),
    MealItem('Snack', 'Greek yogurt + peanut butter', 310, 28),
    MealItem('Dinner', 'Roti + fish/chicken + veg', 500, 38),
    MealItem('Before bed', 'Milk + whey', 270, 32),
  ],
};

class Plan {
  final int tdee;
  final int bmr;
  final int calorieGoal;
  final int proteinGoal;
  final int carbGoal;
  final int fatGoal;
  final int fiberGoal;
  final int stepGoal;
  final double weeklyRate;
  final bool feasible;
  final String? suggestedDate;
  final String headline;
  final String cardioNote;
  final String splitNote;
  final List<MealItem> meals;

  Plan({
    required this.tdee,
    required this.bmr,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbGoal,
    required this.fatGoal,
    required this.fiberGoal,
    required this.stepGoal,
    required this.weeklyRate,
    required this.feasible,
    required this.suggestedDate,
    required this.headline,
    required this.cardioNote,
    required this.splitNote,
    required this.meals,
  });

  Map<String, dynamic> toJson() => {
        'tdee': tdee,
        'bmr': bmr,
        'calorieGoal': calorieGoal,
        'proteinGoal': proteinGoal,
        'carbGoal': carbGoal,
        'fatGoal': fatGoal,
        'fiberGoal': fiberGoal,
        'stepGoal': stepGoal,
        'weeklyRate': weeklyRate,
        'feasible': feasible,
        'suggestedDate': suggestedDate,
        'headline': headline,
        'cardioNote': cardioNote,
        'splitNote': splitNote,
        'meals': meals.map((m) => m.toJson()).toList(),
      };

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        tdee: (j['tdee'] as num).toInt(),
        bmr: (j['bmr'] as num).toInt(),
        calorieGoal: (j['calorieGoal'] as num).toInt(),
        proteinGoal: (j['proteinGoal'] as num).toInt(),
        carbGoal: (j['carbGoal'] as num?)?.toInt() ?? 0,
        fatGoal: (j['fatGoal'] as num?)?.toInt() ?? 0,
        fiberGoal: (j['fiberGoal'] as num?)?.toInt() ?? 0,
        stepGoal: (j['stepGoal'] as num).toInt(),
        weeklyRate: (j['weeklyRate'] as num).toDouble(),
        feasible: j['feasible'] as bool,
        suggestedDate: j['suggestedDate'] as String?,
        headline: j['headline'] as String,
        cardioNote: j['cardioNote'] as String,
        splitNote: j['splitNote'] as String,
        meals: (j['meals'] as List).map((m) => MealItem.fromJson(m as Map<String, dynamic>)).toList(),
      );
}

/// Kcal-buffer options users can add on top of their computed maintenance/goal
/// calories, since the TDEE formula is only an estimate.
const calorieBufferOptions = [0, 50, 100, 150, 200];

/// The single source of truth for goal labels — onboarding, Settings > Goals,
/// and the Training Plan chooser all read this instead of each spelling out
/// their own wording (previously "Lose fat"/"Build muscle" in onboarding vs.
/// "Fat loss"/"Muscle gain" in Settings vs. "Muscle growth" in the chooser —
/// three different names for the same `goalType` values).
const goalOptions = [
  MapEntry('fatLoss', 'Fat loss'),
  MapEntry('weightGain', 'Muscle gain'),
  MapEntry('maintain', 'Maintain'),
];

/// Standard Mifflin-St Jeor activity multipliers. Missing a "sedentary" tier
/// forced genuinely inactive users into "Light" (1.375), overestimating
/// their real maintenance calories — every tier from the standard table is
/// included here so the closest-fitting one is always available.
const activityFactors = {
  'sedentary': 1.2,
  'light': 1.375,
  'moderate': 1.55,
  'active': 1.725,
  'veryActive': 1.9,
};

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

  final meals = _mealDays[dietPref] ?? _mealDays['veg']!;

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
