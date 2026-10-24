import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../data/muscle_store.dart';
import '../domain/muscle_models.dart';

/// First-run setup for the Muscle feature (and "Edit" afterwards). Collects
/// only what the app cannot know: training experience. Lifts come from the
/// logged history, tape is optional, and the plan is derived. Pops `true`
/// once a profile has been saved.
class MuscleSetupScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const MuscleSetupScreen({super.key, required this.app, required this.controller});

  static Future<bool> open(BuildContext context, AppState app, AppController controller) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => MuscleSetupScreen(app: app, controller: controller)));
    return ok == true;
  }

  @override
  State<MuscleSetupScreen> createState() => _MuscleSetupScreenState();
}

enum _Step { level, lifts, tape, plan }

class _MuscleSetupScreenState extends State<MuscleSetupScreen> {
  late final MuscleProfile? _existing = muscleProfileOf(widget.app.data);
  late final bool _edit = _existing != null;
  late final List<_Step> _steps = _edit ? [_Step.level, _Step.lifts, _Step.plan] : _Step.values;
  int _i = 0;
  String? _level;
  late Set<String> _tracked;
  late double _goalKg;
  final Map<String, double> _tape = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.app.data;
    _level = _existing?.level;
    _tracked = (_existing?.tracked ?? exercisesByUse(data.history).take(6).toList()).toSet();
    _goalKg = _existing?.goalGainKg ?? _defaultGoal();
  }

  /// A gain goal the person already has (target weight above current) wins
  /// over the generic +2 kg.
  double _defaultGoal() {
    final st = widget.app.data.settings;
    final tgt = (st['targetWeight'] as num?)?.toDouble();
    final cur = widget.app.data.weight.isEmpty ? null : (widget.app.data.weight.last['weight'] as num).toDouble();
    if (tgt != null && cur != null && tgt > cur + 0.4 && tgt - cur <= 10) return double.parse((tgt - cur).toStringAsFixed(1));
    return 2.0;
  }

  _Step get _step => _steps[_i];
  bool get _last => _i == _steps.length - 1;
  bool get _canContinue => _step != _Step.level || _level != null;

  Future<void> _finish({bool skipped = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final data = widget.app.data;
    final today = todayStr(data.settings);
    final base = _existing ?? defaultMuscleProfile(data, today);
    var p = base.copyWith(
      level: skipped ? (_level ?? 'intermediate') : (_level ?? base.level),
      tracked: _tracked.toList(),
      goalGainKg: _goalKg,
    );
    if (!_edit && _tape.isNotEmpty) p = p.copyWith(tape: [TapeEntry(today, Map.of(_tape))]);
    await saveMuscleProfile(widget.controller, p);
    if (mounted) Navigator.of(context).pop(true);
  }

  void _next() => _last ? _finish() : setState(() => _i++);

  @override
  Widget build(BuildContext context) {
    final label = switch (_step) {
      _Step.tape => _tape.isEmpty ? 'Skip for now' : 'Save and continue',
      _Step.plan => _edit ? 'Save' : 'Start tracking',
      _ => 'Continue',
    };
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconBubble(
                  icon: Icon(_i == 0 ? Icons.close : Icons.arrow_back, size: 18, color: T.muted),
                  size: 36,
                  background: T.surface,
                  border: Border.all(color: T.line),
                  onTap: () => _i == 0 ? Navigator.of(context).pop(false) : setState(() => _i--),
                ),
                const Spacer(),
                if (!_edit)
                  GestureDetector(
                    onTap: () => _finish(skipped: true),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(padding: const EdgeInsets.all(8), child: Text('Skip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.muted))),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                for (var k = 0; k < _steps.length; k++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      margin: EdgeInsets.only(right: k == _steps.length - 1 ? 0 : 6),
                      decoration: BoxDecoration(color: k <= _i ? T.accent : T.line, borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
              ]),
              const SizedBox(height: 22),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: SingleChildScrollView(key: ValueKey(_step), child: _body()),
                ),
              ),
              PrimaryButton(onTap: _canContinue && !_saving ? _next : null, opacity: _canContinue && !_saving ? 1 : 0.5, child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _head(String t, String d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Eyebrow('Muscle setup · ${_i + 1} of ${_steps.length}'),
        Text(t, style: Type.finding),
        const SizedBox(height: 8),
        Text(d, style: Type.caption),
        const SizedBox(height: 20),
      ]);

  Widget _body() => switch (_step) {
        _Step.level => _levelStep(),
        _Step.lifts => _liftsStep(),
        _Step.tape => _tapeStep(),
        _Step.plan => _planStep(),
      };

  Widget _levelStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _head('How long have you been lifting?', 'This sets how fast gains should realistically come, so the app can tell you if you are on pace.'),
        for (final l in muscleLevels)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => setState(() => _level = l.key),
              borderColor: _level == l.key ? T.accent : T.line,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(child: Text(l.label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.text))),
                  const SizedBox(width: 8),
                  Text(l.years, style: mono(fontSize: 12, color: T.muted)),
                ]),
                const SizedBox(height: 6),
                Text(l.blurb, style: TextStyle(fontSize: 12.5, color: T.muted, height: 1.4)),
                const SizedBox(height: 8),
                Text('${l.range} kg per week', style: mono(fontSize: 12, color: T.accent)),
              ]),
            ),
          ),
        Text('Not sure? Pick the lower one. You can change this later.', style: Type.caption),
      ]);

  Widget _liftsStep() {
    final names = exercisesByUse(widget.app.data.history);
    final enough = names.where((n) => liftSeries(widget.app.data.history, n).length >= 3).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _head('Which lifts should we track?', 'Pick the main lifts you want to see climbing. We estimate your 1RM from your logged sets, so there is nothing extra to enter.'),
      if (names.isEmpty)
        AppCard(child: Text('No workouts logged yet. Log a session on the Train tab and your lifts will show up here.', style: Type.caption))
      else ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in names)
            PressableScale(
              onTap: () => setState(() => _tracked.contains(n) ? _tracked.remove(n) : _tracked.add(n)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _tracked.contains(n) ? T.accentDim : T.surface,
                  border: Border.all(color: _tracked.contains(n) ? T.accent : T.line),
                  borderRadius: BorderRadius.circular(T.pill),
                ),
                child: Text('${_tracked.contains(n) ? '✓ ' : ''}$n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _tracked.contains(n) ? T.accent : T.text)),
              ),
            ),
        ]),
        const SizedBox(height: 18),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('Found in your history'),
            Text('$enough ${enough == 1 ? 'lift has' : 'lifts have'} 3 or more logged sessions, so ${enough == 1 ? 'its chart' : 'their charts'} will start filled in.', style: Type.caption),
          ]),
        ),
      ],
    ]);
  }

  Widget _tapeStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _head('Starting measurements', 'Muscle and fat both show up on the scale. A tape at the start lets us tell them apart later. Takes a minute, and you can skip it.'),
        AppCard(
          child: Column(children: [
            for (var k = 0; k < tapeSites.length; k++) _tapeRow(tapeSites[k], first: k == 0),
          ]),
        ),
        const SizedBox(height: 10),
        Text('Use the same spot each time. Waist plus arm or chest is enough for the muscle check.', style: Type.caption),
      ]);

  Widget _tapeRow((String, String, String) s, {required bool first}) {
    final v = _tape[s.$1];
    void bump(double d) => setState(() => _tape[s.$1] = v == null ? tapeDefaults[s.$1]! : (v + d).clamp(10.0, 250.0));
    Widget btn(IconData i, double d, String l) => Semantics(
          button: true,
          label: l,
          child: PressableScale(
            onTap: () => bump(d),
            downScale: 0.88,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: T.line), color: T.surface2),
              child: Icon(i, size: 16, color: T.text),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: T.surface2))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.text)),
            Text(s.$3, style: TextStyle(fontSize: 11.5, color: T.muted)),
          ]),
        ),
        btn(Icons.remove, -0.5, 'Less ${s.$2}'),
        SizedBox(width: 74, child: Text(v == null ? '— cm' : '${v.toStringAsFixed(1)} cm', textAlign: TextAlign.center, style: mono(fontSize: 14, fontWeight: FontWeight.w600, color: v == null ? T.faint : T.text))),
        btn(Icons.add, 0.5, 'More ${s.$2}'),
      ]),
    );
  }

  Widget _planStep() {
    final l = muscleLevelOf(_level ?? _existing?.level);
    final w = widget.app.data.weight;
    final cur = w.isEmpty ? null : (w.last['weight'] as num).toDouble();
    final weeks = (_goalKg / l.mid).round();
    Widget row(String a, String b, {bool first = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: T.surface2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(a.toUpperCase(), style: mono(fontSize: 10.5, color: T.faint).copyWith(letterSpacing: 1.2)),
            Text(b, style: mono(fontSize: 13, fontWeight: FontWeight.w600, color: T.text)),
          ]),
        );
    final protLo = cur == null ? null : (cur * 1.6).round(), protHi = cur == null ? null : (cur * 2.2).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _head('Here is your plan', cur == null ? 'Based on your answers.' : 'Based on your answers and your latest weigh-in of ${cur.toStringAsFixed(1)} kg.'),
      AppCard(
        child: Column(children: [
          row('Target pace', '${l.range} kg/wk', first: true),
          row('Calorie surplus', '+200 to +400 kcal'),
          row('Protein', protLo == null ? '1.6 to 2.2 g/kg' : '$protLo to $protHi g'),
          row('Tracking', '${_tracked.length} ${_tracked.length == 1 ? 'lift' : 'lifts'}'),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Goal gain'),
          Row(children: [
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('+${_goalKg.toStringAsFixed(1)}', style: Type.display),
                Text(' kg', style: mono(fontSize: 14, color: T.muted)),
              ]),
            ),
            Stepper2(value: _goalKg, onChange: (v) => setState(() => _goalKg = v.toDouble().clamp(0.5, 10.0)), step: 0.5, min: 0.5, suffix: 'kg'),
          ]),
          const SizedBox(height: 8),
          Text(cur == null ? 'About $weeks weeks at this pace.' : 'Goal weight ${(cur + _goalKg).toStringAsFixed(1)} kg, about $weeks weeks at this pace. We will review it at week 8.', style: Type.caption),
        ]),
      ),
    ]);
  }
}
