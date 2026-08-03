import '../domain/food_item.dart';

/// Foods for quick-add, filtered by diet preference (kcal, protein, carb, fat, fiber per portion).
final Map<String, List<FoodItem>> _foodDb = {
  'base': const [
    FoodItem('Oats 50g + whey', 330, 37, 30, 6, 4),
    FoodItem('Greek yogurt 200g', 120, 20, 7, 0, 0),
    FoodItem('Whey scoop', 120, 24, 3, 1, 0),
    FoodItem('Milk 250ml', 150, 8, 12, 8, 0),
    FoodItem('Peanut butter 2 tbsp', 190, 8, 6, 16, 2),
    FoodItem('Banana', 105, 1, 27, 0, 3),
    FoodItem('Rice 1 cup', 200, 4, 45, 0, 1),
    FoodItem('Roti (1)', 120, 3, 18, 4, 2),
    FoodItem('Dal 1 cup', 180, 12, 27, 3, 8),
  ],
  'veg': const [
    FoodItem('Paneer 100g', 265, 18, 6, 20, 0),
    FoodItem('Tofu 100g', 120, 12, 3, 7, 1),
    FoodItem('Soya chunks 50g dry', 175, 26, 15, 1, 4),
    FoodItem('Rajma 1 cup', 210, 13, 38, 1, 11),
    FoodItem('Chickpeas 1 cup', 210, 12, 35, 4, 10),
  ],
  'egg': const [
    FoodItem('Whole eggs (2)', 156, 12, 1, 11, 0),
    FoodItem('Egg whites (3)', 51, 11, 1, 0, 0),
    FoodItem('Paneer 100g', 265, 18, 6, 20, 0),
    FoodItem('Soya chunks 50g dry', 175, 26, 15, 1, 4),
  ],
  'nonveg': const [
    FoodItem('Chicken breast 100g', 165, 31, 0, 4, 0),
    FoodItem('Fish 100g', 180, 22, 0, 9, 0),
    FoodItem('Tuna can (100g)', 110, 25, 0, 1, 0),
    FoodItem('Whole eggs (2)', 156, 12, 1, 11, 0),
    FoodItem('Egg whites (3)', 51, 11, 1, 0, 0),
  ],
};

List<FoodItem> foodsForPref(String pref) => [..._foodDb['base']!, ...(_foodDb[pref] ?? _foodDb['veg']!)];
