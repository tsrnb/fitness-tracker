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
