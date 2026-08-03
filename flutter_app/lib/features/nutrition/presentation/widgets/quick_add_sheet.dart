import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../domain/parsed_meal_item.dart';
import '../../data/meal_line_parser.dart';
import 'save_morph_button.dart';

class QuickAddSheet extends StatefulWidget {
  final Widget backHeader;
  final InputDecoration Function(String) dec;
  final TextEditingController logTextCtrl;
  final bool showFormat;
  final VoidCallback onToggleFormat;
  final void Function(List<ParsedMealItem>) onSubmit;
  const QuickAddSheet({
    super.key,
    required this.backHeader,
    required this.dec,
    required this.logTextCtrl,
    required this.showFormat,
    required this.onToggleFormat,
    required this.onSubmit,
  });

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
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
              child: SaveMorphButton(
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
