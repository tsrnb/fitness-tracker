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
