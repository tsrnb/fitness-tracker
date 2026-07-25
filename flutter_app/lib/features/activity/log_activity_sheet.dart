import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/lib/helpers.dart';
import '../../app/app_state.dart';

class LogActivitySheet extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const LogActivitySheet({super.key, required this.app, required this.controller});

  @override
  State<LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends State<LogActivitySheet> {
  late String steps;
  late String kcal;
  late String min;

  @override
  void initState() {
    super.initState();
    final today = todayStr();
    final cur = Map<String, dynamic>.from(widget.app.data.activity[today] ?? {'steps': 0, 'kcal': 0, 'min': 0});
    steps = '${cur['steps'] ?? 0}';
    kcal = '${cur['kcal'] ?? 0}';
    min = '${cur['min'] ?? 0}';
  }

  void save() {
    final today = todayStr();
    widget.controller.update('activity', (prev) {
      final a = Map<String, dynamic>.from(prev ?? {});
      a[today] = {'steps': int.tryParse(steps) ?? 0, 'kcal': int.tryParse(kcal) ?? 0, 'min': int.tryParse(min) ?? 0};
      return a;
    });
    Navigator.of(context).pop();
  }

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
          child: Text(label, style: mono(fontSize: 13)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final today = todayStr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBubble(icon: Icon(Icons.directions_run, size: 16, color: Colors.white), size: 36, background: T.hero),
            const SizedBox(width: 10),
            Expanded(child: Text('Log activity', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: T.text))),
            IconBubble(icon: Icon(Icons.close, size: 18, color: T.muted), size: 36, background: T.surface2, onTap: () => Navigator.of(context).pop()),
          ],
        ),
        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text(fmtDay(today), style: TextStyle(fontSize: 13, color: T.muted))),
        const SizedBox(height: 8),
        const Eyebrow('Steps walked'),
        Padding(padding: const EdgeInsets.only(bottom: 10), child: NumIn(value: steps, onChange: (v) => setState(() => steps = v), ph: '9000', suffix: 'steps')),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('+1k', () => setState(() => steps = '${(int.tryParse(steps) ?? 0) + 1000}')),
            _chip('+2k', () => setState(() => steps = '${(int.tryParse(steps) ?? 0) + 2000}')),
            _chip('+5k', () => setState(() => steps = '${(int.tryParse(steps) ?? 0) + 5000}')),
            _chip('clear', () => setState(() => steps = '0')),
          ]),
        ),
        const Eyebrow('Cardio calories'),
        Padding(padding: const EdgeInsets.only(bottom: 14), child: NumIn(value: kcal, onChange: (v) => setState(() => kcal = v), ph: '180', suffix: 'kcal')),
        const Eyebrow('Cardio minutes'),
        Padding(padding: const EdgeInsets.only(bottom: 18), child: NumIn(value: min, onChange: (v) => setState(() => min = v), ph: '20', suffix: 'min')),
        PrimaryButton(onTap: save, child: const Text('Save')),
      ],
    );
  }
}
