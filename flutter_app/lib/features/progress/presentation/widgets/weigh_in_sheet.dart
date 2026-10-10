import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../../shared/lib/helpers.dart';
import '../../../../app/app_state.dart';
import '../../../calibration/domain/calibration_engine.dart';
import '../../domain/weight_log.dart';

/// A short pre-flight before the actual weigh-in field, opened via
/// `showAppSheet` from the Home weight-log nudge (and reachable from
/// calibration screens too) — same conditions the 14-Day Calibration spec
/// asks for regardless of whether one happens to be running: empty
/// stomach, before eating/drinking, same scale/spot, same time. The
/// conditions themselves are informational context, not a checklist to
/// tick off.
class WeighInSheet extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const WeighInSheet({super.key, required this.app, required this.controller});

  @override
  State<WeighInSheet> createState() => _WeighInSheetState();
}

class _WeighInSheetState extends State<WeighInSheet> {
  String value = '';
  bool _saving = false;

  Future<void> _log() async {
    final v = double.tryParse(value);
    if (v == null || _saving) return;
    setState(() => _saving = true);
    await logWeightEntry(widget.controller, widget.app.data.settings, v);
    if (mounted) Navigator.of(context).pop();
  }

  static const _conditions = [
    ('🚻', 'Right after you use the bathroom'),
    ('🍽', 'Before eating or drinking anything'),
    ('👕', 'Same scale, same spot, minimal clothing'),
    ('⏰', 'Around the same time each morning'),
  ];

  @override
  Widget build(BuildContext context) {
    final data = widget.app.data;
    final calibration = data.calibration;
    final today = todayStr(data.settings);
    final calibrationRunning = calibration != null && calibration['status'] == 'running';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBubble(icon: Icon(Icons.monitor_weight_outlined, size: 16, color: Colors.white), size: 36, background: T.hero),
            const SizedBox(width: 10),
            Expanded(child: Text('Before you weigh in', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: T.text))),
            IconBubble(icon: Icon(Icons.close, size: 18, color: T.muted), size: 36, background: T.surface2, onTap: () => Navigator.of(context).pop()),
          ],
        ),
        if (calibrationRunning)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: T.accentDim, border: Border.all(color: T.accentSoft), borderRadius: BorderRadius.circular(T.pill)),
              child: Text('🧪 Day ${dayNumber(calibration, today)} of your calibration', style: mono(fontSize: 10.5, fontWeight: FontWeight.w700, color: T.accent)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text('A few conditions keep readings comparable day to day.', style: TextStyle(fontSize: 12.5, color: T.muted)),
        ),
        for (final c in _conditions)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.surface2))),
            child: Row(children: [
              SizedBox(width: 26, child: Text(c.$1, style: const TextStyle(fontSize: 16))),
              const SizedBox(width: 10),
              Expanded(child: Text(c.$2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.text))),
            ]),
          ),
        const SizedBox(height: 18),
        NumIn(value: value, onChange: (v) => setState(() => value = v), ph: 'e.g. 78.4', suffix: data.settings['units'] as String? ?? 'kg'),
        const SizedBox(height: 14),
        PrimaryButton(
          onTap: value.isEmpty || _saving ? null : _log,
          opacity: value.isEmpty || _saving ? 0.5 : 1,
          child: const Text('Log weight'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Center(
            child: GestureDetector(
              onTap: value.isEmpty || _saving ? null : _log,
              child: Text('Not under these conditions — log anyway', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.faint)),
            ),
          ),
        ),
      ],
    );
  }
}
