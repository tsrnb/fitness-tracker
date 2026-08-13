import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../shared/lib/muscle_map.dart';
import '../../../app/app_state.dart';
import '../../exercises/data/exercise_library_data.dart';
import '../../exercises/presentation/exercise_detail_sheet.dart';
import '../domain/program.dart';
import '../domain/training_split.dart';
import '../data/training_splits_data.dart';
import '../data/training_history_repository.dart';
import '../data/exercise_swaps.dart';
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

/// A small bordered, icon+label button — used wherever an action (swap,
/// tutorial, add set) needs to read as a real, labelled control rather than
/// a bare icon competing for space in an already-busy row.
class _OutlinedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlinedAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = T.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: T.line)),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }
}

/// The "swap with" list shown inline in place of the set editor once the
/// ⇄ button is tapped — same-muscle-group alternatives, one tap to swap in
/// (matching the rest of the app's "quick" one-tap-and-done convention),
/// long-press for the full exercise detail sheet first.
class _SwapPanel extends StatelessWidget {
  final String exerciseName;
  final ProgramItem slotItem;
  final bool isSwapped;
  final List<String> exclude;
  final VoidCallback onCancel;
  final ValueChanged<String> onCommit;
  final VoidCallback? onUndo;
  final ValueChanged<String> onPreview;

  const _SwapPanel({
    required this.exerciseName,
    required this.slotItem,
    required this.isSwapped,
    required this.exclude,
    required this.onCancel,
    required this.onCommit,
    required this.onUndo,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final group = lib[exerciseName]?.group;
    final alternatives = sameGroupAlternatives(exerciseName, exclude: exclude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.chevron_left, size: 18, color: T.faint),
            ),
          ),
          Expanded(
            child: Text('Swap with${group != null ? ' · $group' : ''}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: T.text)),
          ),
          if (isSwapped)
            GestureDetector(
              onTap: onUndo,
              child: const Text('Undo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.accent)),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Text('tap to swap · hold to preview', style: mono(fontSize: 10, color: T.faint)),
        ),
        if (alternatives.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No other $group exercises in the library yet.', style: TextStyle(fontSize: 12.5, color: T.muted)),
          )
        else
          ...alternatives.map((name) {
            final info = lib[name]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onCommit(name),
                onLongPress: () => onPreview(name),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rM)),
                  child: Row(children: [
                    SizedBox(width: 30, height: 30, child: Center(child: MuscleMap(view: info.view, primary: info.primary, secondary: info.secondary, size: 26))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.text)),
                        Text(info.target, style: mono(fontSize: 10.5, color: T.muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _TrainScreenState extends State<TrainScreen> {
  late TrainingSplit split;
  late String day;
  Map<String, List<_SetWork>> work = {};
  String? open;
  String? flash;

  /// Name of the exercise whose "swap with" panel is currently expanded —
  /// at most one at a time, same as [open].
  String? swapOpen;

  /// Optimistic local copy of this day's swaps, applied on top of whatever
  /// [widget.app.data.settings] currently has persisted — [setExerciseSwap]
  /// round-trips through the controller, and this keeps the card showing the
  /// new exercise immediately instead of flickering back for a frame or two
  /// while that persists. Reset whenever the day/split changes.
  Map<String, String> swapOverrides = {};

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
    swapOverrides = {};
    final swaps = swapsForDay(widget.app.data.settings, split.id, day);
    final items = applySwaps(split.program[day]!.items, swaps);
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

  /// Appends one more set, copying the last row's weight/reps as a starting
  /// point (closer to what's actually next than a blank 0×0 would be).
  void _addSet(String ex) {
    setState(() {
      final rows = work[ex]!;
      final last = rows.isNotEmpty ? rows.last : _SetWork(0, 0);
      rows.add(_SetWork(last.weight, last.reps));
    });
  }

  /// Drops one set — the "scheduled for 4, only did 3" case. Always leaves
  /// at least one row so there's something to log.
  void _removeSet(String ex, int i) {
    setState(() {
      final rows = work[ex]!;
      if (rows.length <= 1) return;
      rows.removeAt(i);
    });
  }

  /// Swaps [slotItem] (the split's originally-scheduled exercise for this
  /// slot) for [newName] — persists it keyed by day-type, so it shows up on
  /// every future occurrence of [day], not just today, and updates locally
  /// right away rather than waiting on the round-trip.
  void _commitSwap(ProgramItem slotItem, String currentName, String newName) {
    setState(() {
      swapOverrides[slotItem.name] = newName;
      final carried = work.remove(currentName);
      work[newName] = carried ??
          initialWorkingSets(widget.app.data.history, newName, targetSets: slotItem.sets, repRange: slotItem.reps)
              .map((r) => _SetWork(r['weight']!.toDouble(), r['reps']!.toInt()))
              .toList();
      swapOpen = null;
      open = newName;
    });
    setExerciseSwap(widget.controller, split.id, day, slotItem.name, newName);
  }

  /// Reverts [slotItem] back to what the split originally prescribed.
  void _undoSwap(ProgramItem slotItem, String currentName) {
    setState(() {
      swapOverrides.remove(slotItem.name);
      final carried = work.remove(currentName);
      work[slotItem.name] = carried ??
          initialWorkingSets(widget.app.data.history, slotItem.name, targetSets: slotItem.sets, repRange: slotItem.reps)
              .map((r) => _SetWork(r['weight']!.toDouble(), r['reps']!.toInt()))
              .toList();
      open = slotItem.name;
    });
    clearExerciseSwap(widget.controller, split.id, day, slotItem.name);
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
    final originalItems = split.program[day]!.items;
    final swaps = {...swapsForDay(widget.app.data.settings, split.id, day), ...swapOverrides};
    final items = applySwaps(originalItems, swaps);
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
            ...items.asMap().entries.map((entry) {
              final slotIndex = entry.key;
              final it = entry.value;
              final slotItem = originalItems[slotIndex];
              final isSwapped = it.name != slotItem.name;
              final info = lib[it.name];
              final view = info?.view ?? 'front';
              final primary = info?.primary ?? const <String>[];
              final secondary = info?.secondary ?? const <String>[];
              final hist = List<dynamic>.from(widget.app.data.history[it.name] ?? []);
              final prev = hist.isNotEmpty ? hist.last : null;
              final rows = work[it.name] ?? [];
              final isOpen = open == it.name;
              final isSwapOpen = swapOpen == it.name;
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
                                    Text('${rows.isNotEmpty ? rows.length : it.sets} × ${it.reps}', style: mono(fontSize: 12, color: T.muted)),
                                    if (allTop) ...[
                                      const SizedBox(width: 8),
                                      const Row(children: [
                                        Icon(Icons.arrow_upward, size: 11, color: T.accent),
                                        Text(' add weight', style: TextStyle(fontSize: 11, color: T.accent, fontWeight: FontWeight.w600)),
                                      ]),
                                    ],
                                  ]),
                                  if (isSwapped)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: T.accentDim, borderRadius: BorderRadius.circular(T.pill)),
                                        child: Text('swapped in for ${slotItem.name}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: T.accent)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (flash == it.name || saved)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.check, size: 14, color: T.success),
                                  const SizedBox(width: 4),
                                ]),
                              ),
                            if (flash == it.name || saved)
                              Text(flash == it.name ? 'Saved' : 'Logged', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.success)),
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
                        child: isSwapOpen
                            ? _SwapPanel(
                                exerciseName: it.name,
                                slotItem: slotItem,
                                isSwapped: isSwapped,
                                exclude: items.map((x) => x.name).toList(),
                                onCancel: () => setState(() => swapOpen = null),
                                onCommit: (newName) => _commitSwap(slotItem, it.name, newName),
                                onUndo: isSwapped ? () => _undoSwap(slotItem, it.name) : null,
                                onPreview: (candidate) => showAppSheet(
                                  context,
                                  ExerciseDetailSheet(name: candidate, onUseInstead: () {
                                    Navigator.of(context).pop();
                                    _commitSwap(slotItem, it.name, candidate);
                                  }),
                                ),
                              )
                            : Column(
                          children: [
                            prev != null
                                ? Text.rich(TextSpan(children: [
                                    TextSpan(text: 'Last: ', style: TextStyle(fontSize: 12, color: T.muted)),
                                    TextSpan(
                                        text: List<Map<String, dynamic>>.from(prev['sets']).map((x) => '${x['weight']}×${x['reps']}').join('  '),
                                        style: mono(fontSize: 12, color: T.text)),
                                  ]))
                                : Text('No history yet', style: TextStyle(fontSize: 12, color: T.muted)),
                            const SizedBox(height: 10),
                            // Contained, labelled actions instead of bare icons — both what
                            // this exercise is and what you can do with it read at a glance.
                            Row(children: [
                              Expanded(
                                child: _OutlinedAction(
                                  icon: Icons.swap_horiz,
                                  label: 'Swap exercise',
                                  onTap: () => setState(() {
                                    swapOpen = it.name;
                                    open = it.name;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _OutlinedAction(
                                  icon: Icons.play_arrow,
                                  label: 'Tutorial',
                                  onTap: () => widget.openExercise(it.name),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            ...List.generate(rows.length, (i) {
                              final s = rows[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: i > 0 ? BoxDecoration(border: Border(top: BorderSide(color: T.surface2))) : null,
                                child: Row(
                                  children: [
                                    SizedBox(width: 14, child: Text('${i + 1}', style: mono(fontSize: 13, color: T.faint))),
                                    const SizedBox(width: 6),
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
                                    // Quiet until you reach for it, and it disappears once only one
                                    // set is left so a working set can't be removed entirely.
                                    if (rows.length > 1)
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          splashRadius: 15,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _removeSet(it.name, i),
                                          icon: Icon(Icons.delete_outline, size: 16, color: T.faint),
                                          tooltip: 'Remove set ${i + 1}',
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 30),
                                  ],
                                ),
                              );
                            }),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _OutlinedAction(icon: Icons.add, label: 'Add set', onTap: () => _addSet(it.name)),
                            ),
                            const SizedBox(height: 8),
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
