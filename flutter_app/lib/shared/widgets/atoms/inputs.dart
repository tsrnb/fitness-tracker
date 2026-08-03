import 'package:flutter/material.dart';
import '../../theme.dart';
import '../pressable_scale.dart';
import 'layout.dart';
import 'motion.dart';

class Stepper2 extends StatelessWidget {
  final num value;
  final ValueChanged<num> onChange;
  final num step;
  final num min;
  final String? suffix;
  const Stepper2({super.key, required this.value, required this.onChange, this.step = 1, this.min = 0, this.suffix});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback onTap) => PressableScale(
          onTap: onTap,
          downScale: 0.88,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: T.line), color: T.surface2),
            child: Icon(icon, size: 18, color: T.text),
          ),
        );
    final displayValue = value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(2);
    return Row(
      children: [
        btn(Icons.remove, () {
          final v = value - step;
          onChange(double.parse((v < min ? min : v).toStringAsFixed(2)));
        }),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: fastAnim,
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(displayValue, key: ValueKey(displayValue), style: mono(fontSize: 20, fontWeight: FontWeight.w600)),
              ),
              if (suffix != null) Text(suffix!, style: mono(fontSize: 11, color: T.muted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        btn(Icons.add, () => onChange(double.parse((value + step).toStringAsFixed(2)))),
      ],
    );
  }
}

class NumIn extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  final String? ph;
  final String? suffix;
  const NumIn({super.key, required this.value, required this.onChange, this.ph, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController.fromValue(TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length))),
              onChanged: onChange,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: mono(fontSize: 18, color: T.text),
              decoration: InputDecoration(hintText: ph, hintStyle: TextStyle(color: T.faint), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 13)),
            ),
          ),
          if (suffix != null) MonoText(suffix!, fontSize: 14, color: T.muted),
        ],
      ),
    );
  }
}
