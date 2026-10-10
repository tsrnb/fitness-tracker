import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../app/app_state.dart';
import 'calibration_mode_screen.dart';

/// Explains the calibration loop before asking for anything — mockup
/// screen 04. Pure copy/explanation; the actual mode choice and baseline
/// snapshot live one screen further in ([CalibrationModeScreen]).
class CalibrationIntroScreen extends StatelessWidget {
  final AppState app;
  final AppController controller;
  const CalibrationIntroScreen({super.key, required this.app, required this.controller});

  static const _tracked = [
    ('⚖️', 'Morning weight', 'every day'),
    ('🍽', 'Food log', 'meals + drinks'),
    ('👣', 'Steps & workouts', 'auto-synced'),
    ('😴', 'Sleep', 'context only'),
  ];

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      context: context,
      title: '',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Let\'s calibrate your plan', style: Type.h1),
          const SizedBox(height: 10),
          Text(
            'Calorie and weight-loss numbers are estimates — yours included. Your real-world response is better evidence than any formula.',
            style: Type.body,
          ),
          const SizedBox(height: 16),
          Text(
            'Over the next 14 days we\'ll compare what your current plan predicts against what actually happens — then use whatever gap shows up to sharpen your numbers.',
            style: Type.body,
          ),
          const SizedBox(height: 20),
          Eyebrow('What we\'ll track'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [
              for (final t in _tracked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Text(t.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.text)),
                          Text(t.$3, style: TextStyle(fontSize: 9.5, color: T.faint)),
                        ],
                      ),
                    ),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalibrationModeScreen(app: app, controller: controller))),
            child: const Text('Start Calibration'),
          ),
        ],
      ),
    );
  }
}
