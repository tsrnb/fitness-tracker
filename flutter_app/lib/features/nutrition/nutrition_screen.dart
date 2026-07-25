import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/lib/helpers.dart';
import '../../app/app_state.dart';
import 'food_db.dart';
import 'parse_meal_lines.dart';
import 'meal_log.dart';

class NutritionScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const NutritionScreen({super.key, required this.app, required this.controller});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

// Fiber isn't represented in the shared theme's color set — a distinct
// amber/brown tone keeps it visually separate from kcal/protein/carb/fat.
const _fiberColor = Color(0xFFC28A45);

class _NutritionScreenState extends State<NutritionScreen> {
  final cName = TextEditingController();
  final cK = TextEditingController();
  final cP = TextEditingController();
  final cC = TextEditingController();
  final cF = TextEditingController();
  final cFi = TextEditingController();
  final logTextCtrl = TextEditingController();
  Map<String, dynamic>? pending;
  bool showFormat = false;

  @override
  void dispose() {
    cName.dispose();
    cK.dispose();
    cP.dispose();
    cC.dispose();
    cF.dispose();
    cFi.dispose();
    logTextCtrl.dispose();
    super.dispose();
  }

  void addMeal(String name, num k, num p, [num c = 0, num f = 0, num fi = 0]) => addMealEntry(widget.controller, name, k, p, c, f, fi);

  void addMeals(List<ParsedMealItem> items) => addMealEntries(widget.controller, items);

  void removeMeal(dynamic id) {
    final today = todayStr();
    widget.controller.update('diet', (prev) {
      final d = Map<String, dynamic>.from(prev ?? {});
      final list = List<Map<String, dynamic>>.from(d[today] ?? []).where((m) => m['id'] != id).toList();
      d[today] = list;
      return d;
    });
  }

  void setWater(int n) {
    final today = todayStr();
    widget.controller.update('water', (prev) {
      final w = Map<String, dynamic>.from(prev ?? {});
      w[today] = n < 0 ? 0 : n;
      return w;
    });
  }

  void submitCustom() {
    final name = cName.text.trim();
    final k = double.tryParse(cK.text);
    final p = double.tryParse(cP.text);
    final c = double.tryParse(cC.text) ?? 0;
    final f = double.tryParse(cF.text) ?? 0;
    final fi = double.tryParse(cFi.text) ?? 0;
    if (name.isEmpty || k == null || k < 0 || p == null || p < 0) return;
    setState(() => pending = {'name': name, 'kcal': k, 'protein': p, 'carb': c, 'fat': f, 'fiber': fi});
  }

  void confirmPending(bool saveForFuture) async {
    final p = pending!;
    addMeal(p['name'], p['kcal'], p['protein'], p['carb'] ?? 0, p['fat'] ?? 0, p['fiber'] ?? 0);
    if (saveForFuture) {
      await widget.controller.addFood(
        p['name'],
        (p['kcal'] as num).toDouble(),
        (p['protein'] as num).toDouble(),
        (p['carb'] as num? ?? 0).toDouble(),
        (p['fat'] as num? ?? 0).toDouble(),
        (p['fiber'] as num? ?? 0).toDouble(),
      );
    }
    setState(() {
      pending = null;
      cName.clear();
      cK.clear();
      cP.clear();
      cC.clear();
      cF.clear();
      cFi.clear();
    });
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: T.faint),
        filled: true,
        fillColor: T.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: T.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: T.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: T.accent)),
      );

  Widget _macroBar({required String label, required num value, required num goal, required Color color, String unit = 'g'}) {
    final pct = goal > 0 ? (value / goal).clamp(0, 1).toDouble() : 0.0;
    final done = goal > 0 && value >= goal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.text)),
              Text('${value.round()} / ${goal.round()}$unit', style: mono(fontSize: 12, color: T.muted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 9,
                backgroundColor: T.surface2,
                valueColor: AlwaysStoppedAnimation(done ? T.success : color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mealSummary(Map<String, dynamic> m) {
    final parts = <String>['${m['kcal']} · ${m['protein']}g P'];
    final c = (m['carb'] ?? 0) as num;
    final f = (m['fat'] ?? 0) as num;
    final fi = (m['fiber'] ?? 0) as num;
    if (c > 0) parts.add('${c}g C');
    if (f > 0) parts.add('${f}g F');
    if (fi > 0) parts.add('${fi}g Fib');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.app.data.settings;
    final today = todayStr();
    final meals = List<Map<String, dynamic>>.from(widget.app.data.diet[today] ?? []);
    final kcal = meals.fold<num>(0, (a, b) => a + (b['kcal'] ?? 0));
    final prot = meals.fold<num>(0, (a, b) => a + (b['protein'] ?? 0));
    final carb = meals.fold<num>(0, (a, b) => a + (b['carb'] ?? 0));
    final fat = meals.fold<num>(0, (a, b) => a + (b['fat'] ?? 0));
    final fiber = meals.fold<num>(0, (a, b) => a + (b['fiber'] ?? 0));
    final calGoal = (st['calorieGoal'] ?? 2000) as num;
    final protGoal = (st['proteinGoal'] ?? 150) as num;
    final carbGoal = (st['carbGoal'] ?? 250) as num;
    final fatGoal = (st['fatGoal'] ?? 65) as num;
    final fiberGoal = (st['fiberGoal'] ?? 30) as num;
    final water = (widget.app.data.water[today] ?? 0) as num;
    final burned = ((widget.app.data.activity[today] ?? {})['kcal'] ?? 0) as num;
    final adjustedGoal = calGoal + burned;
    final tdee = (widget.app.data.plan != null ? widget.app.data.plan!['tdee'] : null) ?? calGoal;
    final deficit = ((tdee as num) - (kcal - burned)).round();

    final quick = <(FoodItem, int?)>[
      ...foodsForPref(st['dietPref'] ?? 'veg').map((f) => (f, null)),
      ...widget.app.foods.map((f) => (FoodItem(f.name, f.kcal.round(), f.protein.round(), f.carb.round(), f.fat.round(), f.fiber.round()), f.id)),
    ];
    final parsedPreview = parseMealLines(logTextCtrl.text);
    final previewTotals = parsedPreview.fold<Map<String, int>>({'kcal': 0, 'protein': 0}, (a, b) => {'kcal': a['kcal']! + b.kcal, 'protein': a['protein']! + b.protein});

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      Ring(value: kcal.toDouble(), goal: adjustedGoal.toDouble(), size: 100, color: T.hero),
                      Padding(padding: const EdgeInsets.only(top: 6), child: Text('Calories', style: TextStyle(fontSize: 11, color: T.muted))),
                    ]),
                    Column(children: [
                      Ring(value: prot.toDouble(), goal: protGoal.toDouble(), size: 100, unit: 'g', color: T.blue),
                      Padding(padding: const EdgeInsets.only(top: 6), child: Text('Protein', style: TextStyle(fontSize: 11, color: T.muted))),
                    ]),
                  ],
                ),
              ),
            ),
            // Carbs/fat/fiber as a plain bar list rather than more rings —
            // rings stop reading well past 2 at a glance (everything starts
            // competing for the same circular real estate), while stacked
            // bars scale to any number of nutrients without crowding, and
            // this screen already treats "Quick add"/"Add custom item" as
            // bare sections with no card wrapper, so this matches that
            // existing lower-emphasis pattern instead of inventing a new one.
            const Eyebrow('Macros'),
            _macroBar(label: 'Carbs', value: carb, goal: carbGoal, color: T.success),
            _macroBar(label: 'Fat', value: fat, goal: fatGoal, color: T.lav),
            _macroBar(label: 'Fiber', value: fiber, goal: fiberGoal, color: _fiberColor),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Center(
                child: Text(
                  '${deficit.abs()} kcal ${deficit >= 0 ? 'deficit' : 'surplus'} · vs ~${tdee.round()} maintenance${burned > 0 ? ' (+${burned.round()} from activity)' : ''}',
                  style: TextStyle(fontSize: 12, color: T.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      IconBubble(icon: const Icon(Icons.water_drop, size: 16, color: Colors.white), size: 34, background: water * 0.25 >= 3 ? T.success : T.hero),
                      const SizedBox(width: 10),
                      const Eyebrow('Water', margin: EdgeInsets.zero),
                    ]),
                    Row(children: [
                      IconBubble(icon: Icon(Icons.remove, size: 16, color: T.muted), size: 30, background: T.surface2, onTap: () => setWater(water.toInt() - 1)),
                      const SizedBox(width: 10),
                      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Text((water * 0.25).toStringAsFixed(2), style: mono(fontSize: 18)),
                        Text(' / 3.5L', style: mono(fontSize: 12, color: T.muted)),
                      ]),
                      const SizedBox(width: 10),
                      IconBubble(icon: const Icon(Icons.add, size: 16, color: Colors.white), size: 30, background: T.hero, onTap: () => setWater(water.toInt() + 1)),
                    ]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Eyebrow('Quick log a meal', margin: EdgeInsets.zero),
                  GestureDetector(onTap: () => setState(() => showFormat = !showFormat), child: Text(showFormat ? 'hide format' : 'format?', style: const TextStyle(fontSize: 12, color: T.accent))),
                ],
              ),
            ),
            if (showFormat)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: 'One item per line: ', style: TextStyle(fontSize: 12, color: T.muted, height: 1.6)),
                        TextSpan(text: 'name, kcal, protein, carb, fat, fiber', style: mono(fontSize: 12, color: T.text)),
                      ])),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: T.bg, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('2 Rotis, 240, 6', style: mono(fontSize: 12, color: T.muted)),
                            Text('Dal tadka, 180, 12', style: mono(fontSize: 12, color: T.muted)),
                            Text('Paneer bhurji, 220, 14, 6, 16, 5', style: mono(fontSize: 12, color: T.muted)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: 'Only kcal is required — ', style: TextStyle(fontSize: 12, color: T.muted)),
                          TextSpan(text: 'protein', style: mono(fontSize: 12, color: T.text)),
                          TextSpan(text: ', then ', style: TextStyle(fontSize: 12, color: T.muted)),
                          TextSpan(text: 'carb', style: mono(fontSize: 12, color: T.text)),
                          TextSpan(text: ', then ', style: TextStyle(fontSize: 12, color: T.muted)),
                          TextSpan(text: 'fat', style: mono(fontSize: 12, color: T.text)),
                          TextSpan(text: ', then ', style: TextStyle(fontSize: 12, color: T.muted)),
                          TextSpan(text: 'fiber', style: mono(fontSize: 12, color: T.text)),
                          TextSpan(text: ' are each optional trailing numbers, so ', style: TextStyle(fontSize: 12, color: T.muted)),
                          TextSpan(text: 'name, kcal', style: mono(fontSize: 12, color: T.text)),
                          TextSpan(text: ' also works.', style: TextStyle(fontSize: 12, color: T.muted)),
                        ])),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: logTextCtrl,
                      onChanged: (_) => setState(() {}),
                      maxLines: 3,
                      style: mono(fontSize: 13, color: T.text),
                      decoration: _dec('2 Rotis, 240, 6\nDal tadka, 180, 12'),
                    ),
                    if (parsedPreview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
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
                                  Text('${previewTotals['kcal']} · ${previewTotals['protein']}g', style: mono(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: PrimaryButton(
                        padding: const EdgeInsets.all(12),
                        opacity: parsedPreview.isNotEmpty ? 1 : 0.45,
                        onTap: () {
                          if (parsedPreview.isEmpty) return;
                          addMeals(parsedPreview);
                          logTextCtrl.clear();
                          setState(() {});
                        },
                        child: const Text('Log meal'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Eyebrow('Quick add'),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
                children: quick.map((entry) {
                  final f = entry.$1;
                  final savedId = entry.$2;
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => addMeal(f.name, f.kcal, f.protein, f.carb, f.fat, f.fiber),
                        child: Container(
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
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => showAppSheet(context, _EditFoodSheet(controller: widget.controller, id: savedId, food: f)),
                          child: Icon(Icons.edit, size: 15, color: T.muted),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const Eyebrow('Add single custom item'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(controller: cName, onChanged: (_) => setState(() {}), style: TextStyle(color: T.text, fontSize: 14), decoration: _dec('Food name')),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: NumIn(value: cK.text, onChange: (v) => setState(() => cK.text = v), ph: 'e.g. 250', suffix: 'kcal')),
                      const SizedBox(width: 8),
                      Expanded(child: NumIn(value: cP.text, onChange: (v) => setState(() => cP.text = v), ph: 'e.g. 20', suffix: 'g P')),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: NumIn(value: cC.text, onChange: (v) => setState(() => cC.text = v), ph: 'e.g. 30', suffix: 'g C')),
                      const SizedBox(width: 8),
                      Expanded(child: NumIn(value: cF.text, onChange: (v) => setState(() => cF.text = v), ph: 'e.g. 8', suffix: 'g F')),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: NumIn(value: cFi.text, onChange: (v) => setState(() => cFi.text = v), ph: 'e.g. 5', suffix: 'g Fib')),
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox()),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: PrimaryButton(
                        padding: const EdgeInsets.all(12),
                        opacity: cName.text.trim().isNotEmpty && cK.text.isNotEmpty && cP.text.isNotEmpty ? 1 : 0.45,
                        onTap: submitCustom,
                        child: const Text('Add to today'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Eyebrow("Today's meals"),
            if (meals.isEmpty)
              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nothing logged yet.', style: TextStyle(color: T.muted, fontSize: 13)))
            else
              ...meals.map((m) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.surface2))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(m['name'], style: TextStyle(fontSize: 14, color: T.text))),
                        Row(children: [
                          Text(_mealSummary(m), style: mono(fontSize: 12, color: T.muted)),
                          const SizedBox(width: 12),
                          GestureDetector(onTap: () => removeMeal(m['id']), child: Icon(Icons.close, size: 16, color: T.faint)),
                        ]),
                      ],
                    ),
                  )),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: pending == null,
            child: GestureDetector(
              onTap: () => setState(() => pending = null),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: pending == null ? 0 : 1,
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: () {},
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      offset: pending == null ? const Offset(0, 1) : Offset.zero,
                      child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(color: T.bg, border: Border(top: BorderSide(color: T.line)), borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXL))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Save for next time?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: T.text)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text.rich(TextSpan(style: TextStyle(color: T.muted, fontSize: 14), children: [
                            const TextSpan(text: 'Add '),
                            TextSpan(text: '${pending?['name'] ?? ''}', style: TextStyle(color: T.text, fontWeight: FontWeight.bold)),
                            TextSpan(text: ' (${pending?['kcal'] ?? 0} kcal · ${pending?['protein'] ?? 0}g) to your food library so it\'s one tap in future?'),
                          ])),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PrimaryButton(
                            onTap: () => confirmPending(true),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.save, size: 17),
                              SizedBox(width: 8),
                              Text('Save & add to today'),
                            ]),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => confirmPending(false),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
                            alignment: Alignment.center,
                            child: Text('Just add for today', style: TextStyle(color: T.text, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditFoodSheet extends StatefulWidget {
  final AppController controller;
  final int? id;
  final FoodItem food;
  const _EditFoodSheet({required this.controller, required this.id, required this.food});

  @override
  State<_EditFoodSheet> createState() => _EditFoodSheetState();
}

class _EditFoodSheetState extends State<_EditFoodSheet> {
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

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: T.faint),
        filled: true,
        fillColor: T.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: T.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: T.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: T.accent)),
      );

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
        TextField(controller: cName, style: TextStyle(color: T.text, fontSize: 14), decoration: _dec('Food name')),
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
