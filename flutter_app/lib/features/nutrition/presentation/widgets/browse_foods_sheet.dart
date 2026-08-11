import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../../app/app_state.dart';
import '../../domain/food_item.dart';
import '../../data/meal_repository.dart';
import 'edit_food_sheet.dart';

/// Nested sheet opened from "Browse foods" — the grid of the user's own
/// saved foods (there's no built-in catalog: this is only what's been saved
/// from Manual entry, so it grows with actual use instead of showing items
/// nobody asked for). Tapping a card adds it immediately: that card morphs
/// green with a checkmark, then both this sheet and the picker beneath it
/// auto-dismiss — "quick" means one tap and done, not staying in a sheet to
/// add several. The trailing "Add food" tile (and the empty-state button)
/// jump straight to Manual entry via [onAddNew] — it's a real action, not a
/// decorative plus.
class BrowseFoodsSheet extends StatefulWidget {
  final AppState app;
  final AppController controller;
  final VoidCallback onAddNew;
  const BrowseFoodsSheet({super.key, required this.app, required this.controller, required this.onAddNew});

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

  Widget _addTile() => GestureDetector(
        onTap: widget.onAddNew,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: T.line, width: 1.5), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add, size: 16, color: T.accent),
            const SizedBox(width: 6),
            Text('Add food', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.accent)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final quick = widget.app.foods
        .map((f) => (FoodItem(f.name, f.kcal.round(), f.protein.round(), f.carb.round(), f.fat.round(), f.fiber.round()), f.id))
        .toList();

    if (quick.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse foods', style: Type.h2),
          Padding(padding: const EdgeInsets.only(top: 4, bottom: 16), child: Text('Nothing saved yet.', style: Type.caption)),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Foods you save from Manual entry show up here for one-tap logging.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: T.muted, height: 1.5)),
                const SizedBox(height: 14),
                PrimaryButton(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  onTap: widget.onAddNew,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 16),
                    SizedBox(width: 6),
                    Text('Add your first food'),
                  ]),
                ),
              ],
            ),
          ),
        ],
      );
    }

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
          children: [
            ...quick.asMap().entries.map((entry) {
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
            }),
          ],
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: _addTile()),
      ],
    );
  }
}
