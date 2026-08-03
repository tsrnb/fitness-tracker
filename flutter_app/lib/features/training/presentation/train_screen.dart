import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../shared/lib/muscle_map.dart';
import '../../../app/app_state.dart';
import '../../exercises/data/exercise_library_data.dart';
import '../domain/training_split.dart';
import '../data/training_splits_data.dart';
import '../data/training_history_repository.dart';
import 'rest_timer_screen.dart';

class TrainScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  final String? initialDay;
  final ValueChanged<String> openExercise;
  const TrainScreen({super.key, required this.app, required this.controller, this.initialDay, required this.openExercise});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _SetWork {
  double weight;
  int reps;
  _SetWork(this.weight, this.reps);
}

class _TrainScreenState extends State<TrainScreen> {
  late TrainingSplit split;
  late String day;
  Map<String, List<_SetWork>> work = {};
  String? open;
  String? flash;

  @override
  void initState() {
    super.initState();
    split = activeSplit(widget.app.data.settings);
    final jsDow = DateTime.now().weekday % 7;
    day = widget.initialDay ?? scheduleFromSettings(widget.app.data.settings, split)[jsDow] ?? split.dayOrder.first;
    _initWork();
  }

  @override
  void didUpdateWidget(covariant TrainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSplit = activeSplit(widget.app.data.settings);
    if (newSplit.id != split.id) {
      setState(() {
        split = newSplit;
        final jsDow = DateTime.now().weekday % 7;
        day = scheduleFromSettings(widget.app.data.settings, split)[jsDow] ?? split.dayOrder.first;
        _initWork();
      });
      return;
    }
    if (widget.initialDay != null && widget.initialDay != oldWidget.initialDay) {
      setState(() {
        day = widget.initialDay!;
        _initWork();
      });
    }
  }

  void _initWork() {
    final items = split.program[day]!.items;
    final init = <String, List<_SetWork>>{};
    for (final it in items) {
      final rows = initialWorkingSets(widget.app.data.history, it.name, targetSets: it.sets, repRange: it.reps);
      init[it.name] = rows.map((r) => _SetWork(r['weight']!.toDouble(), r['reps']!.toInt())).toList();
    }
    work = init;
    open = items.isNotEmpty ? items.first.name : null;
  }

  void _changeDay(String d) {
    setState(() {
      day = d;
      _initWork();
    });
  }

  void _setSet(String ex, int i, {double? weight, int? reps}) {
    setState(() {
      final row = work[ex]![i];
      if (weight != null) row.weight = weight;
      if (reps != null) row.reps = reps;
    });
  }

  bool _savedToday(String name) => isLoggedToday(widget.app.data.history, name, todayStr(widget.app.data.settings));

  void _saveExercise(String name) {
    final rows = work[name] ?? [];
    final sets = rows.where((x) => x.reps > 0).map((x) => {'weight': x.weight, 'reps': x.reps}).toList();
    if (sets.isEmpty) return;
    final today = todayStr(widget.app.data.settings);
    logTrainingSession(widget.controller, exerciseName: name, dayType: day, today: today, sets: sets);
    setState(() => flash = name);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && flash == name) setState(() => flash = null);
    });
    RestTimerScreen.push(context, seconds: 90, exerciseName: name);
  }

  @override
  Widget build(BuildContext context) {
    final items = split.program[day]!.items;
    final loggedCount = items.where((it) => _savedToday(it.name)).length;
    return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            SizedBox(height: 8),
            Builder(builder: (_) => Padding(padding: EdgeInsets.only(bottom: 0), child: Text(split.program[day]!.focus, style: TextStyle(fontSize: 13, color: T.muted)))),
            const SizedBox(height: 4),
            PillTabs(options: split.dayOrder.map((d) => MapEntry(d, d)).toList(), value: day, onChange: _changeDay, scroll: true),
            PaperCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const IconBubble(icon: Icon(Icons.fitness_center, size: 20, color: Colors.white), size: 48, background: T.hero),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$day day', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Padding(padding: const EdgeInsets.only(top: 2), child: Text('$loggedCount of ${items.length} exercises logged today', style: const TextStyle(fontSize: 12.5, color: T.paperMuted))),
                    ]),
                  ]),
                  Ring(value: loggedCount.toDouble(), goal: items.length.toDouble(), size: 72, onPaper: true, color: T.hero),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...items.map((it) {
              final info = lib[it.name];
              final view = info?.view ?? 'front';
              final primary = info?.primary ?? const <String>[];
              final secondary = info?.secondary ?? const <String>[];
              final hist = List<dynamic>.from(widget.app.data.history[it.name] ?? []);
              final prev = hist.isNotEmpty ? hist.last : null;
              final rows = work[it.name] ?? [];
              final isOpen = open == it.name;
              final saved = _savedToday(it.name);
              final allTop = prev != null &&
                  prev['date'] != todayStr(widget.app.data.settings) &&
                  List.from(prev['sets']).length >= it.sets &&
                  List<Map<String, dynamic>>.from(prev['sets']).every((x) => (x['reps'] as num) >= topReps(it.reps));
              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: T.surface,
                  border: Border.all(color: saved ? const Color(0x807FCB86) : T.line),
                  borderRadius: BorderRadius.circular(T.rL),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => open = isOpen ? null : it.name),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(width: 40, height: 56, child: Center(child: MuscleMap(view: view, primary: primary, secondary: secondary, size: 38))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: T.text)),
                                  Row(children: [
                                    Text('${it.sets} × ${it.reps}', style: mono(fontSize: 12, color: T.muted)),
                                    if (allTop) ...[
                                      const SizedBox(width: 8),
                                      const Row(children: [
                                        Icon(Icons.arrow_upward, size: 11, color: T.accent),
                                        Text(' add weight', style: TextStyle(fontSize: 11, color: T.accent, fontWeight: FontWeight.w600)),
                                      ]),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                            if (flash == it.name || saved)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.check, size: 14, color: T.success),
                                  SizedBox(width: 4),
                                ]),
                              ),
                            if (flash == it.name || saved)
                              Text(flash == it.name ? 'Saved' : 'Logged', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.success)),
                            AnimatedRotation(
                              turns: isOpen ? 0 : -0.25,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(Icons.keyboard_arrow_down, size: 18, color: T.faint),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: isOpen ? 220 : 120),
                        opacity: isOpen ? 1 : 0,
                        child: !isOpen
                            ? const SizedBox(width: double.infinity, height: 0)
                            : Container(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: T.line))),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: prev != null
                                      ? Text.rich(TextSpan(children: [
                                          TextSpan(text: 'Last: ', style: TextStyle(fontSize: 12, color: T.muted)),
                                          TextSpan(
                                              text: List<Map<String, dynamic>>.from(prev['sets']).map((x) => '${x['weight']}×${x['reps']}').join('  '),
                                              style: mono(fontSize: 12, color: T.text)),
                                        ]))
                                      : Text('No history yet', style: TextStyle(fontSize: 12, color: T.muted)),
                                ),
                                GestureDetector(
                                  onTap: () => widget.openExercise(it.name),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.play_arrow, size: 12, color: T.accent),
                                    SizedBox(width: 4),
                                    Text('tutorial', style: TextStyle(fontSize: 12, color: T.accent)),
                                  ]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...List.generate(rows.length, (i) {
                              final s = rows[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: i > 0 ? BoxDecoration(border: Border(top: BorderSide(color: T.surface2))) : null,
                                child: Row(
                                  children: [
                                    SizedBox(width: 18, child: Text('${i + 1}', style: mono(fontSize: 13, color: T.faint))),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('WEIGHT', style: mono(fontSize: 10, color: T.faint)),
                                        Stepper2(value: s.weight, step: 2.5, onChange: (v) => _setSet(it.name, i, weight: v.toDouble()), suffix: 'kg'),
                                      ]),
                                    ),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('REPS', style: mono(fontSize: 10, color: T.faint)),
                                        Stepper2(value: s.reps, step: 1, onChange: (v) => _setSet(it.name, i, reps: v.toInt())),
                                      ]),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                            PrimaryButton(
                              padding: const EdgeInsets.all(12),
                              onTap: () => _saveExercise(it.name),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.save, size: 16),
                                const SizedBox(width: 6),
                                Text(saved ? 'Update exercise' : 'Save exercise'),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
              );
            }),
      ],
    );
  }
}
