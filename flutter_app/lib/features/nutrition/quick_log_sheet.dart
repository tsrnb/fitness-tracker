import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../app/app_state.dart';
import 'parse_meal_lines.dart';
import 'meal_log.dart';

/// The home screen's "Log food" action opens this instead of jumping to the
/// full Diet tab — same quick-log text box as the Nutrition screen (one item
/// per line: name, kcal, protein, carb, fat), just in a focused sheet.
class QuickLogSheet extends StatefulWidget {
  final AppController controller;
  const QuickLogSheet({super.key, required this.controller});

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  final logTextCtrl = TextEditingController();
  bool showFormat = false;

  @override
  void dispose() {
    logTextCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    final parsedPreview = parseMealLines(logTextCtrl.text);
    final previewTotals = parsedPreview.fold<Map<String, int>>({'kcal': 0, 'protein': 0}, (a, b) => {'kcal': a['kcal']! + b.kcal, 'protein': a['protein']! + b.protein});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBubble(icon: const Icon(Icons.restaurant, size: 16, color: Colors.white), size: 36, background: T.hero),
            const SizedBox(width: 10),
            Expanded(child: Text('Log food', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: T.text))),
            IconBubble(icon: Icon(Icons.close, size: 18, color: T.muted), size: 36, background: T.surface2, onTap: () => Navigator.of(context).pop()),
          ],
        ),
        const SizedBox(height: 16),
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
                    TextSpan(text: 'name, kcal, protein, carb, fat', style: mono(fontSize: 12, color: T.text)),
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
                        Text('Paneer bhurji, 220, 14, 6, 16', style: mono(fontSize: 12, color: T.muted)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Only kcal is required — protein, carb, fat are each optional, so ', style: TextStyle(fontSize: 12, color: T.muted)),
                      TextSpan(text: 'name, kcal', style: mono(fontSize: 12, color: T.text)),
                      TextSpan(text: ' also works.', style: TextStyle(fontSize: 12, color: T.muted)),
                    ])),
                  ),
                ],
              ),
            ),
          ),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: logTextCtrl,
                onChanged: (_) => setState(() {}),
                autofocus: true,
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
                    addMealEntries(widget.controller, parsedPreview);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Log meal'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
