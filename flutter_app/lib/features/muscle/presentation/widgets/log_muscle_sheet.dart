import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/lib/helpers.dart';
import '../../../../app/app_state.dart';
import '../../../progress/domain/weight_log.dart';
import '../../data/muscle_store.dart';
import '../../domain/muscle_models.dart';
import 'muscle_bits.dart';

/// Weigh-in plus the weekly tape check in one sheet. Weight and tape are
/// both optional so either can be logged alone; tape rows stay empty until
/// touched, so nothing is ever recorded that the person did not enter.
class LogMuscleSheet extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const LogMuscleSheet({super.key, required this.app, required this.controller});

  static Future<void> show(BuildContext context, AppState app, AppController controller) =>
      showAppSheet(context, LogMuscleSheet(app: app, controller: controller));

  @override
  State<LogMuscleSheet> createState() => _LogMuscleSheetState();
}

class _LogMuscleSheetState extends State<LogMuscleSheet> {
  String _weight = '';
  final Map<String, double> _cm = {};
  bool _saving = false;

  List<TapeEntry> get _tape => muscleProfileOf(widget.app.data)?.tape ?? const [];

  Map<String, double> get _last => _tape.isEmpty ? const {} : _tape.last.cm;

  void _step(String site, double d) => setState(() {
        final base = _cm[site] ?? _last[site] ?? tapeDefaults[site]!;
        _cm[site] = _cm.containsKey(site) ? (base + d).clamp(10.0, 250.0) : base;
      });

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final w = double.tryParse(_weight);
    final settings = widget.app.data.settings;
    if (w != null && w > 0) await logWeightEntry(widget.controller, settings, w);
    if (_cm.isNotEmpty) await addTapeEntry(widget.controller, _cm);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = todayStr(widget.app.data.settings);
    final stage = tapeStage(_tape);
    final due = tapeDue(_tape, today);
    final (chipText, chipColor) = stage == TapeStage.none ? ('First entry', T.lavAccent) : (due ? ('Due now', T.accent) : ('Not due yet', T.success));
    final canSave = _weight.isNotEmpty || _cm.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(child: Text('Log weigh-in', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: T.text))),
          IconBubble(icon: Icon(Icons.close, size: 18, color: T.muted), size: 36, background: T.surface2, onTap: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: 14),
        const Eyebrow('Weight (kg)'),
        NumIn(value: _weight, onChange: (v) => setState(() => _weight = v), ph: 'e.g. 74.1', suffix: 'kg'),
        const SizedBox(height: 18),
        Row(children: [
          const Expanded(child: Eyebrow('Measurements · weekly', margin: EdgeInsets.zero)),
          MuscleChip(chipText, chipColor),
        ]),
        const SizedBox(height: 6),
        for (final s in tapeSites)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: T.surface2))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.text)),
                  Text(_last[s.$1] != null ? 'last ${_last[s.$1]!.toStringAsFixed(1)} cm' : s.$3, style: TextStyle(fontSize: 11.5, color: T.muted)),
                ]),
              ),
              _roundBtn(Icons.remove, () => _step(s.$1, -0.5), 'Less ${s.$2}'),
              SizedBox(
                width: 78,
                child: Text(
                  _cm[s.$1] == null ? '— cm' : '${_cm[s.$1]!.toStringAsFixed(1)} cm',
                  textAlign: TextAlign.center,
                  style: mono(fontSize: 14, fontWeight: FontWeight.w600, color: _cm[s.$1] == null ? T.faint : T.text),
                ),
              ),
              _roundBtn(Icons.add, () => _step(s.$1, 0.5), 'More ${s.$2}'),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text('Leave a row empty to skip it. Same spot each time, relaxed, in the morning.', style: TextStyle(fontSize: 11.5, color: T.muted)),
        ),
        PrimaryButton(onTap: canSave && !_saving ? _save : null, opacity: canSave && !_saving ? 1 : 0.5, child: const Text('Save')),
      ],
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, String label) => Semantics(
        button: true,
        label: label,
        child: PressableScale(
          onTap: onTap,
          downScale: 0.88,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: T.line), color: T.surface2),
            child: Icon(icon, size: 16, color: T.text),
          ),
        ),
      );
}
