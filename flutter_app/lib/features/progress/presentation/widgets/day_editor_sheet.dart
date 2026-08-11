import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../../app/app_state.dart';
import '../../../nutrition/data/meal_repository.dart';
import '../../../nutrition/data/meal_line_parser.dart';
import '../../../nutrition/domain/parsed_meal_item.dart';
import '../../../nutrition/presentation/widgets/field_decoration.dart';

/// Add/remove meals for a specific past (or present) date — the same
/// `diet` map today's log uses, just addressed by an explicit date instead
/// of always defaulting to today.
class DayEditorSheet extends StatefulWidget {
  final AppController controller;
  final String date;
  final String dateLabel;
  final num adjustedGoal;
  final num proteinGoal;
  final List<Map<String, dynamic>> initialMeals;
  const DayEditorSheet({
    super.key,
    required this.controller,
    required this.date,
    required this.dateLabel,
    required this.adjustedGoal,
    required this.proteinGoal,
    required this.initialMeals,
  });

  @override
  State<DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<DayEditorSheet> {
  late List<Map<String, dynamic>> meals = List<Map<String, dynamic>>.from(widget.initialMeals);
  final cName = TextEditingController();
  final cK = TextEditingController();
  final cP = TextEditingController();
  final logTextCtrl = TextEditingController();
  bool showAdd = false;
  // null = choosing between the two entry modes; set once a mode is picked.
  String? addMode;

  @override
  void dispose() {
    cName.dispose();
    cK.dispose();
    cP.dispose();
    logTextCtrl.dispose();
    super.dispose();
  }

  void _remove(dynamic id) {
    removeMealEntry(widget.controller, widget.date, id);
    setState(() => meals.removeWhere((m) => m['id'] == id));
  }

  void _closeAdd() {
    showAdd = false;
    addMode = null;
  }

  void _add() {
    final name = cName.text.trim();
    final k = double.tryParse(cK.text);
    if (name.isEmpty || k == null || k < 0) return;
    final p = double.tryParse(cP.text) ?? 0;
    addMealEntry(widget.controller, name, k, p, 0, 0, 0, widget.date);
    setState(() {
      meals.add({'id': DateTime.now().millisecondsSinceEpoch, 'name': name, 'kcal': k.round(), 'protein': p.round(), 'carb': 0, 'fat': 0, 'fiber': 0});
      cName.clear();
      cK.clear();
      cP.clear();
      _closeAdd();
    });
  }

  void _logQuick(List<ParsedMealItem> items) {
    if (items.isEmpty) return;
    addMealEntries(widget.controller, items, widget.date);
    setState(() {
      for (final it in items) {
        meals.add({'id': DateTime.now().millisecondsSinceEpoch + meals.length, 'name': it.name, 'kcal': it.kcal, 'protein': it.protein, 'carb': it.carb, 'fat': it.fat, 'fiber': it.fiber});
      }
      logTextCtrl.clear();
      _closeAdd();
    });
  }

  Widget _modeButton(String label, String sub, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: T.accent),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text)),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: TextStyle(fontSize: 10, color: T.muted), textAlign: TextAlign.center)),
          ]),
        ),
      );

  Widget _backHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => addMode = null),
            child: Icon(Icons.chevron_left, size: 20, color: T.muted),
          ),
          Expanded(child: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final kcal = meals.fold<num>(0, (a, b) => a + ((b['kcal'] as num?) ?? 0));
    final protein = meals.fold<num>(0, (a, b) => a + ((b['protein'] as num?) ?? 0));
    final vsGoal = widget.adjustedGoal - kcal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('Edit — ${widget.dateLabel}', style: Type.h2)),
          IconBubble(icon: Icon(Icons.close, size: 18, color: T.muted), size: 34, background: T.surface2, onTap: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: Column(children: [
                Text('${kcal.round()}', style: mono(fontSize: 15, fontWeight: FontWeight.w700, color: T.text)),
                Padding(padding: const EdgeInsets.only(top: 2), child: Text('kcal eaten', style: TextStyle(fontSize: 9.5, color: T.muted))),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              // No sign-flipping — a negative (over-budget) number naturally
              // prints its own "-", so what's on screen matches the sign
              // used everywhere else this budget figure shows up.
              child: Column(children: [
                Text('${vsGoal.round()}', style: mono(fontSize: 15, fontWeight: FontWeight.w700, color: vsGoal >= 0 ? T.success : T.danger)),
                Padding(padding: const EdgeInsets.only(top: 2), child: Text('kcal budget', style: TextStyle(fontSize: 9.5, color: T.muted))),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: Column(children: [
                Text('${protein.round()}g', style: mono(fontSize: 15, fontWeight: FontWeight.w700, color: T.text)),
                Padding(padding: const EdgeInsets.only(top: 2), child: Text('protein', style: TextStyle(fontSize: 9.5, color: T.muted))),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        const Eyebrow('Meals', margin: EdgeInsets.zero),
        if (meals.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Nothing logged this day yet — add what you remember below.', style: TextStyle(color: T.muted, fontSize: 13)))
        else
          ...meals.map((m) => Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.surface2))),
                child: Row(children: [
                  Expanded(child: Text(m['name'], style: TextStyle(fontSize: 14, color: T.text))),
                  Text('${m['kcal']} kcal · ${m['protein']}g P', style: mono(fontSize: 12, color: T.muted)),
                  const SizedBox(width: 12),
                  GestureDetector(onTap: () => _remove(m['id']), child: Icon(Icons.close, size: 16, color: T.faint)),
                ]),
              )),
        const SizedBox(height: 8),
        if (!showAdd)
          GestureDetector(
            onTap: () => setState(() => showAdd = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(border: Border.all(color: T.line, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text('＋ Add food', style: TextStyle(color: T.muted, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          )
        else if (addMode == null)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _modeButton('Type to log', "Type a few lines, we'll do the math", Icons.bolt, () => setState(() => addMode = 'quick'))),
              const SizedBox(width: 8),
              Expanded(child: _modeButton('Manual entry', 'One item, exact macros', Icons.edit_note, () => setState(() => addMode = 'custom'))),
            ]),
          )
        else if (addMode == 'custom')
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _backHeader('Manual entry'),
              TextField(controller: cName, style: TextStyle(color: T.text, fontSize: 14), decoration: appFieldDecoration('Food name')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: NumIn(value: cK.text, onChange: (v) => setState(() => cK.text = v), ph: 'e.g. 250', suffix: 'kcal')),
                const SizedBox(width: 8),
                Expanded(child: NumIn(value: cP.text, onChange: (v) => setState(() => cP.text = v), ph: 'e.g. 20', suffix: 'g P')),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: PrimaryButton(padding: const EdgeInsets.all(12), onTap: _add, child: const Text('Add to this day')),
              ),
            ]),
          )
        else
          Builder(builder: (context) {
            final parsedPreview = parseMealLines(logTextCtrl.text);
            final previewKcal = parsedPreview.fold<int>(0, (a, b) => a + b.kcal);
            final previewProtein = parsedPreview.fold<int>(0, (a, b) => a + b.protein);
            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _backHeader('Type to log'),
                TextField(
                  controller: logTextCtrl,
                  onChanged: (_) => setState(() {}),
                  maxLines: 3,
                  style: mono(fontSize: 13, color: T.text),
                  decoration: appFieldDecoration('2 Rotis, 240, 6\nDal tadka, 180, 12'),
                ),
                if (parsedPreview.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(children: [
                      ...parsedPreview.map((it) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Expanded(child: Text(it.name, style: TextStyle(fontSize: 12, color: T.muted))),
                              Text('${it.kcal} · ${it.protein}g', style: mono(fontSize: 12, color: T.muted)),
                            ]),
                          )),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: T.line))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total (${parsedPreview.length} item${parsedPreview.length > 1 ? "s" : ""})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.text)),
                            Text('$previewKcal · ${previewProtein}g', style: mono(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: PrimaryButton(
                    padding: const EdgeInsets.all(12),
                    opacity: parsedPreview.isNotEmpty ? 1 : 0.45,
                    onTap: parsedPreview.isEmpty ? null : () => _logQuick(parsedPreview),
                    child: const Text('Log meal'),
                  ),
                ),
              ]),
            );
          }),
      ],
    );
  }
}
