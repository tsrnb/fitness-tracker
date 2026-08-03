import '../domain/meal_item.dart';

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

/// The one shared lookup from a `goalType` key to its display label —
/// previously reimplemented separately in Settings, the training plan
/// chooser, onboarding, and the dashboard.
String goalLabel(String? key, {String fallback = ''}) =>
    goalOptions.firstWhere((o) => o.key == key, orElse: () => MapEntry('', fallback)).value;

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

/// Sample "bachelor-simple" meal day per preference (portions scale to the calorie target).
final Map<String, List<MealItem>> mealDays = {
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
