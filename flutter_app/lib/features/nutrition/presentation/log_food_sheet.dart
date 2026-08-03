import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../app/app_state.dart';
import '../domain/parsed_meal_item.dart';
import '../data/meal_repository.dart';
import 'ask_ai_chat_screen.dart';
import 'widgets/ai_gradient.dart';
import 'widgets/field_decoration.dart';
import 'widgets/confirm_save_sheet.dart';
import 'widgets/quick_add_sheet.dart';
import 'widgets/custom_add_sheet.dart';
import 'widgets/browse_foods_sheet.dart';

/// The single entry point for logging food (today), meant to be opened from
/// anywhere the app offers a "log food" action — the Nutrition screen's own
/// button, the dashboard's quick action, etc. — instead of each place having
/// its own bespoke sheet. Fully self-contained: only needs `app`/`controller`,
/// no page-level state to wire up (the old "save to your library?" step used
/// to live on the calling page; it's now part of the Custom entry flow
/// itself). Every path confirms success in place — the button that was just
/// tapped morphs into a green "Saved" state — and the sheet auto-dismisses
/// shortly after, rather than a toast on the page underneath.
///
/// Three paths, given names that describe what each actually does rather
/// than a repeated "quick X/Y" that was easy to mix up:
///  - Type to log: paste/type several lines, parsed automatically.
///  - Manual entry: one item, every macro field.
///  - Browse foods: tap a suggested or saved item, opens its own sheet.
class LogFoodSheet extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const LogFoodSheet({super.key, required this.app, required this.controller});

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

  Future<void> _confirmCustom(bool saveForFuture) async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mode == null) ...[
          Text('Log food', style: Type.h2),
          const SizedBox(height: 4),
          Text('Fastest: just describe it.', style: Type.caption),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => AskAiChatScreen(app: widget.app, controller: widget.controller)));
            },
            child: AiGradient(
              builder: (context, gradient) => Container(
                padding: const EdgeInsets.all(1.6),
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20)),
                child: AiGradientWash(
                  base: const Color(0xFF17161D),
                  borderRadius: BorderRadius.circular(18.5),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
                          alignment: Alignment.center,
                          child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ShaderMask(
                              shaderCallback: (rect) => gradient.createShader(rect),
                              child: const Text('Ask AI', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                            Text('Describe your meal in plain words', style: TextStyle(fontSize: 10.5, color: T.muted)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          '"2 rotis, dal, and a small bowl of curd" → 490 kcal · 22g protein',
                          style: TextStyle(fontSize: 11.5, color: T.text, height: 1.5, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Text('Fits it straight into today\'s log', style: TextStyle(fontSize: 11, color: T.faint))),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(Icons.arrow_forward, size: 13, color: Colors.white),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Divider(color: T.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('OR LOG IT YOURSELF', style: mono(fontSize: 9.5, color: T.faint).copyWith(letterSpacing: 0.8)),
            ),
            Expanded(child: Divider(color: T.line)),
          ]),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _modeButton('Type to log', "Type a few lines, we'll do the math", Icons.bolt, () => setState(() => mode = 'quick'))),
              const SizedBox(width: 8),
              Expanded(child: _modeButton('Manual entry', 'One item, exact macros', Icons.edit_note, () => setState(() => mode = 'custom'))),
            ]),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showAppSheet(context, BrowseFoodsSheet(app: widget.app, controller: widget.controller)),
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
          QuickAddSheet(
            backHeader: _backHeader('Type to log'),
            dec: appFieldDecoration,
            logTextCtrl: logTextCtrl,
            showFormat: showFormat,
            onToggleFormat: () => setState(() => showFormat = !showFormat),
            onSubmit: _logQuick,
          )
        else if (mode == 'custom')
          CustomAddSheet(backHeader: _backHeader('Manual entry'), cName: cName, cK: cK, cP: cP, cC: cC, cF: cF, cFi: cFi, onSubmit: _submitCustom)
        else
          ConfirmSaveSheet(pending: pendingCustom!, onConfirm: _confirmCustom),
      ],
    );
  }
}
