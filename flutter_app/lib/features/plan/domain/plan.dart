import 'meal_item.dart';

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

  /// The actual daily deficit (fat loss) or surplus (muscle gain) this plan
  /// runs on, in kcal — after the safety floor is applied, so it's what's
  /// really happening, not necessarily what was asked for. 0 for maintain.
  final int dailyPace;

  /// True when [calorieGoal] falls below [safetyFloorKcal] — a warning
  /// flag only. The requested pace (from the Settings pace slider, or the
  /// target-date-derived default) is never silently reduced; this just
  /// tells the UI to say so.
  final bool paceCapped;

  /// This plan's safety-floor calorie minimum — `max(1.2×BMR, 1200/1500 by
  /// sex)`. Only meaningful for fat loss (nothing stops muscle-gain surplus
  /// from going up), 0 otherwise.
  final int safetyFloorKcal;

  /// Projected date to reach the target weight at [dailyPace], assuming it's
  /// held every day — the "tentative goal date" shown next to the pace
  /// slider. Null for maintain, or once the target weight's already met.
  final String? tentativeDate;

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
    this.dailyPace = 0,
    this.paceCapped = false,
    this.safetyFloorKcal = 0,
    this.tentativeDate,
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
        'dailyPace': dailyPace,
        'paceCapped': paceCapped,
        'safetyFloorKcal': safetyFloorKcal,
        'tentativeDate': tentativeDate,
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
        // Older persisted plans (saved before the pace slider shipped) won't
        // have these keys — default to "no pace info" rather than crash.
        dailyPace: (j['dailyPace'] as num?)?.toInt() ?? 0,
        paceCapped: j['paceCapped'] as bool? ?? false,
        safetyFloorKcal: (j['safetyFloorKcal'] as num?)?.toInt() ?? 0,
        tentativeDate: j['tentativeDate'] as String?,
      );
}
