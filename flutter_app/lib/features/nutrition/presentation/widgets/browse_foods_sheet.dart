import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../../app/app_state.dart';
import '../../domain/food_item.dart';
import '../../data/food_catalog.dart';
import '../../data/meal_repository.dart';
import 'edit_food_sheet.dart';

/// Nested sheet opened from "Browse foods" — the grid of suggested + saved
/// foods that used to sit permanently on the Nutrition page. Tapping a card
/// adds it immediately: that card morphs green with a checkmark, then both
/// this sheet and the picker beneath it auto-dismiss — "quick" means one tap
/// and done, not staying in a sheet to add several.
class BrowseFoodsSheet extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const BrowseFoodsSheet({super.key, required this.app, required this.controller});

  @override
  State<BrowseFoodsSheet> createState() => _BrowseFoodsSheetState();
}

class _BrowseFoodsSheetState extends State<BrowseFoodsSheet> {
  int? _addedIndex;

  void _tap(int index, FoodItem f) {
    if (_addedIndex != null) return;
    addMealEntry(widget.controller, f.name, f.kcal, f.protein, f.carb, f.fat, f.fiber);
    setState(() => _addedIndex = index);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!context.mounted) return;
      final nav = Navigator.of(context);
      nav.pop(); // this sheet
      nav.pop(); // the Log food picker underneath it
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.app.data.settings;
    final quick = <(FoodItem, int?)>[
      ...foodsForPref(st['dietPref'] ?? 'veg').map((f) => (f, null)),
      ...widget.app.foods.map((f) => (FoodItem(f.name, f.kcal.round(), f.protein.round(), f.carb.round(), f.fat.round(), f.fiber.round()), f.id)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Browse foods', style: Type.h2),
        Padding(padding: const EdgeInsets.only(top: 4, bottom: 16), child: Text('Tap to add to today. Tap the pencil to edit or save a copy.', style: Type.caption)),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: quick.asMap().entries.map((entry) {
            final index = entry.key;
            final f = entry.value.$1;
            final savedId = entry.value.$2;
            final isAdded = _addedIndex == index;
            return Stack(
              children: [
                GestureDetector(
                  onTap: () => _tap(index, f),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: FadeTransition(opacity: anim, child: child)),
                    child: isAdded
                        ? Container(
                            key: ValueKey('added-$index'),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: T.success, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Added', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ]),
                          )
                        : Container(
                            key: ValueKey('food-$index'),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Text(f.name, style: TextStyle(fontSize: 13, color: T.text), overflow: TextOverflow.ellipsis),
                                ),
                                Padding(padding: const EdgeInsets.only(top: 3), child: Text('${f.kcal} kcal · P${f.protein} C${f.carb} F${f.fat}', style: mono(fontSize: 11, color: T.muted), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                  ),
                ),
                if (!isAdded)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => showAppSheet(context, EditFoodSheet(controller: widget.controller, id: savedId, food: f)),
                      child: Icon(Icons.edit, size: 15, color: T.muted),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
