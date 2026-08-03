import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../../app/app_state.dart';
import '../../domain/food_item.dart';
import 'field_decoration.dart';

class EditFoodSheet extends StatefulWidget {
  final AppController controller;
  final int? id;
  final FoodItem food;
  const EditFoodSheet({super.key, required this.controller, required this.id, required this.food});

  @override
  State<EditFoodSheet> createState() => _EditFoodSheetState();
}

class _EditFoodSheetState extends State<EditFoodSheet> {
  late final TextEditingController cName = TextEditingController(text: widget.food.name);
  late String cK = widget.food.kcal.toString();
  late String cP = widget.food.protein.toString();
  late String cC = widget.food.carb.toString();
  late String cF = widget.food.fat.toString();
  late String cFi = widget.food.fiber.toString();

  @override
  void dispose() {
    cName.dispose();
    super.dispose();
  }

  void _save() async {
    final name = cName.text.trim();
    final k = double.tryParse(cK) ?? 0;
    final p = double.tryParse(cP) ?? 0;
    final c = double.tryParse(cC) ?? 0;
    final f = double.tryParse(cF) ?? 0;
    final fi = double.tryParse(cFi) ?? 0;
    if (name.isEmpty) return;
    final id = widget.id;
    if (id != null) {
      await widget.controller.updateFood(id, name, k, p, c, f, fi);
    } else {
      // Built-in quick-add items aren't in the user's library yet — editing
      // one forks a personal, editable copy instead of mutating shared data.
      await widget.controller.addFood(name, k, p, c, f, fi);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _delete() async {
    final id = widget.id;
    if (id == null) return;
    await widget.controller.removeFood(id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = widget.id != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isSaved ? 'Edit quick add' : 'Customize quick add', style: Type.h2),
        if (!isSaved)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text("This is a built-in item — saving adds your own editable copy to Quick add.", style: Type.caption),
          ),
        const SizedBox(height: 16),
        TextField(controller: cName, style: TextStyle(color: T.text, fontSize: 14), decoration: appFieldDecoration('Food name')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: NumIn(value: cK, onChange: (v) => setState(() => cK = v), ph: 'e.g. 250', suffix: 'kcal')),
          const SizedBox(width: 8),
          Expanded(child: NumIn(value: cP, onChange: (v) => setState(() => cP = v), ph: 'e.g. 20', suffix: 'g P')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: NumIn(value: cC, onChange: (v) => setState(() => cC = v), ph: 'e.g. 30', suffix: 'g C')),
          const SizedBox(width: 8),
          Expanded(child: NumIn(value: cF, onChange: (v) => setState(() => cF = v), ph: 'e.g. 8', suffix: 'g F')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: NumIn(value: cFi, onChange: (v) => setState(() => cFi = v), ph: 'e.g. 5', suffix: 'g Fib')),
          const SizedBox(width: 8),
          const Expanded(child: SizedBox()),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: PrimaryButton(
            padding: const EdgeInsets.all(12),
            onTap: _save,
            child: Text(isSaved ? 'Save changes' : 'Save as my own'),
          ),
        ),
        if (isSaved)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: GestureDetector(
                onTap: _delete,
                child: Text('Delete from library', style: TextStyle(color: T.danger, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ),
      ],
    );
  }
}
