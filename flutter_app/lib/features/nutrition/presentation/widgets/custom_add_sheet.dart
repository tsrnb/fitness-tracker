import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import 'field_decoration.dart';

class CustomAddSheet extends StatefulWidget {
  final Widget backHeader;
  final TextEditingController cName;
  final TextEditingController cK;
  final TextEditingController cP;
  final TextEditingController cC;
  final TextEditingController cF;
  final TextEditingController cFi;
  final VoidCallback onSubmit;
  const CustomAddSheet({
    super.key,
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
  State<CustomAddSheet> createState() => _CustomAddSheetState();
}

class _CustomAddSheetState extends State<CustomAddSheet> {
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
            TextField(controller: widget.cName, onChanged: (_) => setState(() {}), autofocus: true, style: TextStyle(color: T.text, fontSize: 14), decoration: appFieldDecoration('Food name')),
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
