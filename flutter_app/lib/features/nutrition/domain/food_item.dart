class FoodItem {
  final String name;
  final int kcal;
  final int protein;
  final int carb;
  final int fat;
  final int fiber;
  const FoodItem(this.name, this.kcal, this.protein, [this.carb = 0, this.fat = 0, this.fiber = 0]);
}
