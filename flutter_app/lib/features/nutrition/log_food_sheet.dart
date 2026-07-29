import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../app/app_state.dart';
import 'food_db.dart';
import 'parse_meal_lines.dart';
import 'meal_log.dart';

/// The single entry point for logging food (today), meant to be opened from
/// anywhere the app offers a "log food" action — the Nutrition screen's own
/// button, the dashboard's quick action, etc. — instead of each place having
/// its own bespoke sheet. Fully self-contained: only needs `app`/`controller`
/// and a callback for confirming a successful add, no page-level state to
/// wire up (the old "save to your library?" step used to live on the calling
/// page; it's now part of the Custom entry flow itself).
///
/// Three paths, given names that describe what each actually does rather
/// than a repeated "quick X/Y" that was easy to mix up:
///  - Type to log: paste/type several lines, parsed automatically.
///  - Manual entry: one item, every macro field.
///  - Browse foods: tap a suggested or saved item, opens its own sheet.
class LogFoodSheet extends StatefulWidget {
  final AppState app;
  final AppController controller;
  final void Function(String foodName) onFoodAdded;
  const LogFoodSheet({super.key, required this.app, required this.controller, required this.onFoodAdded});

  @override
  State<LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<LogFoodSheet> {
  // null = the picker (both buttons + Browse foods); 'quick'/'custom' once
  // chosen; 'confirmSave' is the "save to library?" step after Manual entry.
  String? mode;
  Map<String, dynamic>? pendingCustom;
  bool showFormat = false;
  final logTextCtrl = TextEditingController();
  final cName = TextEditingController();
  final cK = TextEditingController();
  final cP = TextEditingController();
  final cC = TextEditingController();
  final cF = TextEditingController();
  final cFi = TextEditingController();

  @override
  void dispose() {
    logTextCtrl.dispose();
    cName.dispose();
    cK.dispose();
    cP.dispose();
    cC.dispose();
    cF.dispose();
    cFi.dispose();
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

  Widget _modeButton(String label, String sub, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 19, color: T.accent),
            const SizedBox(height: 7),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.text)),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: TextStyle(fontSize: 10.5, color: T.muted), textAlign: TextAlign.center)),
          ]),
        ),
      );

  Widget _backHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          GestureDetector(onTap: () => setState(() => mode = null), child: Icon(Icons.chevron_left, size: 20, color: T.muted)),
          Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.text))),
        ]),
      );

  void _logQuick(List<ParsedMealItem> items) {
    if (items.isEmpty) return;
    addMealEntries(widget.controller, items);
    logTextCtrl.clear();
    Navigator.of(context).pop();
    widget.onFoodAdded(items.length == 1 ? items.first.name : '${items.length} items');
  }

  void _submitCustom() {
    final name = cName.text.trim();
    final k = double.tryParse(cK.text);
    final p = double.tryParse(cP.text);
    if (name.isEmpty || k == null || k < 0 || p == null || p < 0) return;
    final c = double.tryParse(cC.text) ?? 0;
    final f = double.tryParse(cF.text) ?? 0;
    final fi = double.tryParse(cFi.text) ?? 0;
    setState(() {
      pendingCustom = {'name': name, 'kcal': k, 'protein': p, 'carb': c, 'fat': f, 'fiber': fi};
      mode = 'confirmSave';
    });
  }

  void _confirmCustom(bool saveForFuture) async {
    final p = pendingCustom!;
    addMealEntry(widget.controller, p['name'], p['kcal'], p['protein'], p['carb'], p['fat'], p['fiber']);
    if (saveForFuture) {
      await widget.controller.addFood(
        p['name'],
        (p['kcal'] as num).toDouble(),
        (p['protein'] as num).toDouble(),
        (p['carb'] as num).toDouble(),
        (p['fat'] as num).toDouble(),
        (p['fiber'] as num).toDouble(),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onFoodAdded(p['name'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mode == null) ...[
          Text('Log food', style: Type.h2),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _modeButton('Type to log', "Type a few lines, we'll do the math", Icons.bolt, () => setState(() => mode = 'quick'))),
              const SizedBox(width: 8),
              Expanded(child: _modeButton('Manual entry', 'One item, exact macros', Icons.edit_note, () => setState(() => mode = 'custom'))),
            ]),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showAppSheet(context, _BrowseFoodsSheet(app: widget.app, controller: widget.controller, onFoodAdded: widget.onFoodAdded)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.grid_view_rounded, size: 18, color: T.accent),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Browse foods', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.text)),
                      Text('Tap a suggested or saved food to add it instantly', style: TextStyle(fontSize: 11, color: T.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: T.faint),
              ]),
            ),
          ),
        ] else if (mode == 'quick')
          _QuickAddBody(
            backHeader: _backHeader('Type to log'),
            dec: _dec,
            logTextCtrl: logTextCtrl,
            showFormat: showFormat,
            onToggleFormat: () => setState(() => showFormat = !showFormat),
            onSubmit: _logQuick,
          )
        else if (mode == 'custom')
          _CustomAddBody(backHeader: _backHeader('Manual entry'), cName: cName, cK: cK, cP: cP, cC: cC, cF: cF, cFi: cFi, onSubmit: _submitCustom)
        else
          _ConfirmSaveBody(pending: pendingCustom!, onConfirm: _confirmCustom),
      ],
    );
  }
}

class _ConfirmSaveBody extends StatelessWidget {
  final Map<String, dynamic> pending;
  final void Function(bool saveForFuture) onConfirm;
  const _ConfirmSaveBody({required this.pending, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Save for next time?', style: Type.h2),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text.rich(TextSpan(style: TextStyle(color: T.muted, fontSize: 14), children: [
            const TextSpan(text: 'Add '),
            TextSpan(text: '${pending['name']}', style: TextStyle(color: T.text, fontWeight: FontWeight.bold)),
            TextSpan(text: ' (${pending['kcal']} kcal · ${pending['protein']}g) to your food library so it\'s one tap in future?'),
          ])),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PrimaryButton(
            onTap: () => onConfirm(true),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.save, size: 17),
              SizedBox(width: 8),
              Text('Save & add to today'),
            ]),
          ),
        ),
        GestureDetector(
          onTap: () => onConfirm(false),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
            alignment: Alignment.center,
            child: Text('Just add for today', style: TextStyle(color: T.text, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _QuickAddBody extends StatefulWidget {
  final Widget backHeader;
  final InputDecoration Function(String) dec;
  final TextEditingController logTextCtrl;
  final bool showFormat;
  final VoidCallback onToggleFormat;
  final void Function(List<ParsedMealItem>) onSubmit;
  const _QuickAddBody({
    required this.backHeader,
    required this.dec,
    required this.logTextCtrl,
    required this.showFormat,
    required this.onToggleFormat,
    required this.onSubmit,
  });

  @override
  State<_QuickAddBody> createState() => _QuickAddBodyState();
}

class _QuickAddBodyState extends State<_QuickAddBody> {
  @override
  Widget build(BuildContext context) {
    final parsedPreview = parseMealLines(widget.logTextCtrl.text);
    final totalKcal = parsedPreview.fold<int>(0, (a, b) => a + b.kcal);
    final totalProtein = parsedPreview.fold<int>(0, (a, b) => a + b.protein);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.backHeader,
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(onTap: widget.onToggleFormat, child: Text(widget.showFormat ? 'hide format' : 'format?', style: const TextStyle(fontSize: 12, color: T.accent))),
          ),
        ),
        if (widget.showFormat)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
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
                    child: Text('Only kcal is required — the rest are optional trailing numbers.', style: TextStyle(fontSize: 12, color: T.muted)),
                  ),
                ],
              ),
            ),
          ),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
              controller: widget.logTextCtrl,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              autofocus: true,
              style: mono(fontSize: 13, color: T.text),
              decoration: widget.dec('2 Rotis, 240, 6\nDal tadka, 180, 12'),
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
                        Text('$totalKcal · ${totalProtein}g', style: mono(fontSize: 13, fontWeight: FontWeight.w600)),
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
                onTap: parsedPreview.isEmpty ? null : () => widget.onSubmit(parsedPreview),
                child: const Text('Log meal'),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _CustomAddBody extends StatefulWidget {
  final Widget backHeader;
  final TextEditingController cName;
  final TextEditingController cK;
  final TextEditingController cP;
  final TextEditingController cC;
  final TextEditingController cF;
  final TextEditingController cFi;
  final VoidCallback onSubmit;
  const _CustomAddBody({
    required this.backHeader,
    required this.cName,
    required this.cK,
    required this.cP,
    required this.cC,
    required this.cF,
    required this.cFi,
    required this.onSubmit,
  });

  @override
  State<_CustomAddBody> createState() => _CustomAddBodyState();
}

class _CustomAddBodyState extends State<_CustomAddBody> {
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

  @override
  Widget build(BuildContext context) {
    final ready = widget.cName.text.trim().isNotEmpty && widget.cK.text.isNotEmpty && widget.cP.text.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.backHeader,
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(controller: widget.cName, onChanged: (_) => setState(() {}), autofocus: true, style: TextStyle(color: T.text, fontSize: 14), decoration: _dec('Food name')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: NumIn(value: widget.cK.text, onChange: (v) => setState(() => widget.cK.text = v), ph: 'e.g. 250', suffix: 'kcal')),
              const SizedBox(width: 8),
              Expanded(child: NumIn(value: widget.cP.text, onChange: (v) => setState(() => widget.cP.text = v), ph: 'e.g. 20', suffix: 'g P')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: NumIn(value: widget.cC.text, onChange: (v) => setState(() => widget.cC.text = v), ph: 'e.g. 30', suffix: 'g C')),
              const SizedBox(width: 8),
              Expanded(child: NumIn(value: widget.cF.text, onChange: (v) => setState(() => widget.cF.text = v), ph: 'e.g. 8', suffix: 'g F')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: NumIn(value: widget.cFi.text, onChange: (v) => setState(() => widget.cFi.text = v), ph: 'e.g. 5', suffix: 'g Fib')),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PrimaryButton(padding: const EdgeInsets.all(12), opacity: ready ? 1 : 0.45, onTap: widget.onSubmit, child: const Text('Add to today')),
            ),
          ]),
        ),
      ],
    );
  }
}

/// Nested sheet opened from "Browse foods" — the grid of suggested + saved
/// foods that used to sit permanently on the Nutrition page. Tapping a card
/// adds it immediately and returns all the way to the page it was opened
/// from (closing this sheet and the picker beneath it), with a toast
/// confirming what was added — "quick" means one tap and done, not staying
/// in a sheet to add several.
class _BrowseFoodsSheet extends StatelessWidget {
  final AppState app;
  final AppController controller;
  final void Function(String foodName) onFoodAdded;
  const _BrowseFoodsSheet({required this.app, required this.controller, required this.onFoodAdded});

  @override
  Widget build(BuildContext context) {
    final st = app.data.settings;
    final quick = <(FoodItem, int?)>[
      ...foodsForPref(st['dietPref'] ?? 'veg').map((f) => (f, null)),
      ...app.foods.map((f) => (FoodItem(f.name, f.kcal.round(), f.protein.round(), f.carb.round(), f.fat.round(), f.fiber.round()), f.id)),
    ];

    void addAndReturn(FoodItem f) {
      addMealEntry(controller, f.name, f.kcal, f.protein, f.carb, f.fat, f.fiber);
      final nav = Navigator.of(context);
      nav.pop(); // this sheet
      nav.pop(); // the Log food picker underneath it
      onFoodAdded(f.name);
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
          children: quick.map((entry) {
            final f = entry.$1;
            final savedId = entry.$2;
            return Stack(
              children: [
                GestureDetector(
                  onTap: () => addAndReturn(f),
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
                    onTap: () => showAppSheet(context, _EditFoodSheet(controller: controller, id: savedId, food: f)),
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
