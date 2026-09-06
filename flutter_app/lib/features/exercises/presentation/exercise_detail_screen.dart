import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/app_state.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../shared/lib/muscle_map.dart';
import '../../training/data/training_splits_data.dart';
import '../../training/data/training_history_repository.dart';
import '../../training/data/exercise_swaps.dart';
import '../../training/presentation/rest_timer_screen.dart';
import '../data/exercise_cues_service.dart';
import '../data/exercise_library_data.dart';
import '../data/exercise_media_repository.dart';
import 'exercise_animation_widget.dart';

/// Everything the detail screen needs to log a working set and swap the
/// exercise — passed only when the screen is opened from the Train tab.
class ExerciseTrainingArgs {
  final AppState app;
  final AppController controller;
  final String dayType;

  /// The exercise the split originally prescribes for this slot (differs from
  /// the screen's [name] when a swap is already in effect).
  final String slotName;
  final int targetSets;
  final String repRange;

  const ExerciseTrainingArgs({
    required this.app,
    required this.controller,
    required this.dayType,
    required this.slotName,
    required this.targetSets,
    required this.repRange,
  });
}

/// Full-screen exercise detail. The whole screen scrolls as one column:
/// animation hero → exercise info (group, name, targets, prescribed) →
/// Watch tutorial / Swap row → form cues → set/rep editor (from Train) →
/// description. Only the back button is pinned.
class ExerciseDetailScreen extends StatefulWidget {
  final String name;
  final VoidCallback? onUseInstead;
  final ExerciseTrainingArgs? training;

  const ExerciseDetailScreen({
    super.key,
    required this.name,
    this.onUseInstead,
    this.training,
  });

  static Future<R?> push<R>(
    BuildContext context,
    String name, {
    VoidCallback? onUseInstead,
    ExerciseTrainingArgs? training,
  }) {
    return Navigator.of(context).push<R>(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          name: name,
          onUseInstead: onUseInstead,
          training: training,
        ),
      ),
    );
  }

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _Set {
  double weight;
  int reps;
  _Set(this.weight, this.reps);
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  List<_Set> _sets = [];
  bool _saved = false;

  /// Form cues — the AI's, once they arrive; the library's hand-written ones
  /// until then (and if the AI can't be reached).
  List<String> _cues = const [];
  bool _cuesFromAi = false;

  bool get _isTraining => widget.training != null;
  bool get _isSwapped =>
      _isTraining && widget.name != widget.training!.slotName;

  @override
  void initState() {
    super.initState();
    final info = lib[widget.name];
    _cues = info?.cues ?? const [];
    if (info != null) {
      ExerciseCuesService.cuesFor(
        widget.name,
        target: info.target,
        fallback: info.cues,
      ).then((r) {
        if (mounted) {
          setState(() {
            _cues = r.cues;
            _cuesFromAi = r.ai;
          });
        }
      });
    }
    final t = widget.training;
    if (t != null) {
      _saved = isLoggedToday(
        t.app.data.history,
        widget.name,
        todayStr(t.app.data.settings),
      );
      final rows = initialWorkingSets(
        t.app.data.history,
        widget.name,
        targetSets: t.targetSets,
        repRange: t.repRange,
      );
      _sets = rows
          .map((r) => _Set(r['weight']!.toDouble(), r['reps']!.toInt()))
          .toList();
    }
  }

  Map<String, dynamic>? get _prevSession {
    final t = widget.training;
    if (t == null) return null;
    final hist = List<dynamic>.from(t.app.data.history[widget.name] ?? []);
    if (hist.isEmpty) return null;
    final last = hist.last as Map<String, dynamic>;
    return last['date'] == todayStr(t.app.data.settings) ? null : last;
  }

  bool get _addWeightHint {
    final t = widget.training;
    final prev = _prevSession;
    if (t == null || prev == null) return false;
    final sets = List<Map<String, dynamic>>.from(prev['sets']);
    if (sets.length < t.targetSets) return false;
    final top = topReps(t.repRange);
    return sets.every((s) => (s['reps'] as num) >= top);
  }

  String _prevSummary() {
    final prev = _prevSession;
    if (prev == null) return '';
    return List<Map<String, dynamic>>.from(
      prev['sets'],
    ).map((s) => '${s['weight']}×${s['reps']}').join('  ');
  }

  void _addSet() => setState(() {
    final last = _sets.isNotEmpty ? _sets.last : _Set(0, 0);
    _sets.add(_Set(last.weight, last.reps));
  });

  void _removeSet(int i) => setState(() {
    if (_sets.length > 1) _sets.removeAt(i);
  });

  Future<void> _save() async {
    final t = widget.training!;
    final sets = _sets
        .where((s) => s.reps > 0)
        .map((s) => {'weight': s.weight, 'reps': s.reps})
        .toList();
    if (sets.isEmpty) return;
    await logTrainingSession(
      t.controller,
      exerciseName: widget.name,
      dayType: t.dayType,
      today: todayStr(t.app.data.settings),
      sets: sets,
    );
    if (!mounted) return;
    setState(() => _saved = true);
    RestTimerScreen.push(context, seconds: 90, exerciseName: widget.name);
  }

  void _openSwap() {
    final t = widget.training!;
    showAppSheet(
      context,
      _SwapSheet(
        group: lib[widget.name]?.group,
        alternatives: sameGroupAlternatives(
          widget.name,
          exclude: [widget.name],
        ),
        onPick: (newName) async {
          Navigator.of(context).pop();
          await setExerciseSwap(
            t.controller,
            activeSplit(t.app.data.settings).id,
            t.dayType,
            t.slotName,
            newName,
          );
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _undoSwap() async {
    final t = widget.training!;
    await clearExerciseSwap(
      t.controller,
      activeSplit(t.app.data.settings).id,
      t.dayType,
      t.slotName,
    );
    if (mounted) Navigator.of(context).pop();
  }

  bool get _isSkipped {
    final t = widget.training;
    if (t == null) return false;
    final all = Map<String, dynamic>.from(
      t.app.data.settings['workoutSkips'] ?? {},
    );
    final today = List<String>.from(
      all[todayStr(t.app.data.settings)] ?? const [],
    );
    return today.contains(widget.name);
  }

  /// Mark (or un-mark) this exercise as skipped for today — it then counts as
  /// done on the Train list without a set being logged. Keyed by the app's
  /// "today", so it's back tomorrow.
  Future<void> _toggleSkip() async {
    final t = widget.training!;
    final today = todayStr(t.app.data.settings);
    final all = Map<String, dynamic>.from(
      t.app.data.settings['workoutSkips'] ?? {},
    );
    final list = List<String>.from(all[today] ?? const []);
    list.contains(widget.name)
        ? list.remove(widget.name)
        : list.add(widget.name);
    if (list.isEmpty) {
      all.remove(today);
    } else {
      all[today] = list;
    }
    await t.controller.patchSettings('workoutSkips', all);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final info = lib[widget.name];
    if (info == null) {
      return Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(backgroundColor: T.bg, elevation: 0),
        body: Center(
          child: Text('Unknown exercise', style: TextStyle(color: T.muted)),
        ),
      );
    }
    final prescribed = findAnyPrescription(widget.name);
    final hasAnim = hasExerciseAnimation(widget.name);
    final heroH = (MediaQuery.of(context).size.height * 0.36).clamp(
      240.0,
      340.0,
    );

    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.bg,
        surfaceTintColor: T.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: T.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_isTraining)
            TextButton(
              onPressed: _toggleSkip,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSkipped ? Icons.check : Icons.skip_next,
                    size: 16,
                    color: _isSkipped ? T.success : T.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isSkipped ? 'Skipped' : 'Skip',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isSkipped ? T.success : T.muted,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          // ── Hero: the clip, full-bleed (only when there is one) ──
          if (hasAnim)
            SizedBox(
              height: heroH,
              child: ExerciseAnimationWidget(exerciseName: widget.name),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.group.toUpperCase(),
                  style: mono(fontSize: 10, color: T.faint),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: T.text,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (_saved)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 15, color: T.success),
                            const SizedBox(width: 3),
                            Text(
                              'Logged',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: T.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (_isSwapped)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: T.accentDim,
                          borderRadius: BorderRadius.circular(T.pill),
                        ),
                        child: Text(
                          'swapped in for ${widget.training!.slotName}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: T.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconBubble(
                      icon: MuscleMap(
                        view: info.view,
                        primary: info.primary,
                        secondary: info.secondary,
                        size: 68,
                      ),
                      size: 84,
                      background: T.surface2,
                      border: Border.all(color: T.line),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('Targets'),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              info.target,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: T.text,
                              ),
                            ),
                          ),
                          if (prescribed != null) ...[
                            const Eyebrow('Prescribed'),
                            Text(
                              '${prescribed.sets} × ${prescribed.reps}',
                              style: mono(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: T.hero,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Watch tutorial + Swap ──
                if (widget.onUseInstead != null)
                  PrimaryButton(
                    onTap: widget.onUseInstead,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_horiz, size: 18),
                        const SizedBox(width: 8),
                        Text('Use ${widget.name} instead'),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _Outlined(
                          icon: Icons.play_arrow,
                          label: 'Watch tutorial',
                          onTap: () => launchUrl(
                            ytUri(widget.name),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ),
                      if (_isTraining) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Outlined(
                            icon: _isSwapped ? Icons.undo : Icons.swap_horiz,
                            label: _isSwapped ? 'Undo swap' : 'Swap exercise',
                            onTap: _isSwapped ? _undoSwap : _openSwap,
                          ),
                        ),
                      ],
                    ],
                  ),

                // ── Form cues (AI-written) ──
                if (_cues.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: 'Form cues',
                    ai: _cuesFromAi,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(_cues.length, (i) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _cues.length - 1 ? 0 : 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (i + 1).toString().padLeft(2, '0'),
                                style: mono(fontSize: 12, color: T.accent),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _cues[i],
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    color: T.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                if (_isTraining) ...[
                  _SetEditor(
                    sets: _sets,
                    addWeightHint: _addWeightHint,
                    prevSummary: _prevSummary(),
                    onWeight: (i, v) => setState(() => _sets[i].weight = v),
                    onReps: (i, v) => setState(() => _sets[i].reps = v),
                    onRemove: _removeSet,
                    onAdd: _addSet,
                    onSave: _save,
                    saved: _saved,
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  info.desc,
                  style: TextStyle(fontSize: 14, color: T.muted, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled section on the shared card background — same treatment as the
/// set editor, so cues, sets and any future section read as one family.
/// [ai] tags the header with the app's "the assistant did this" mark.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool ai;
  const _SectionCard({
    required this.title,
    required this.child,
    this.ai = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.rL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ai
                ? Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: T.lavAccent),
                      const SizedBox(width: 6),
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: T.lavAccent,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'AI-generated',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: T.lavAccent,
                        ),
                      ),
                    ],
                  )
                : Eyebrow(title),
          ),
          child,
        ],
      ),
    );
  }
}

/// Working-set editor + save — the Train-tab logging surface, now here.
class _SetEditor extends StatelessWidget {
  final List<_Set> sets;
  final bool addWeightHint;
  final String prevSummary;
  final void Function(int, double) onWeight;
  final void Function(int, int) onReps;
  final void Function(int) onRemove;
  final VoidCallback onAdd;
  final VoidCallback onSave;
  final bool saved;

  const _SetEditor({
    required this.sets,
    required this.addWeightHint,
    required this.prevSummary,
    required this.onWeight,
    required this.onReps,
    required this.onRemove,
    required this.onAdd,
    required this.onSave,
    required this.saved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.rL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                prevSummary.isEmpty ? 'No history yet' : 'Last',
                style: TextStyle(fontSize: 12, color: T.muted),
              ),
              if (prevSummary.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    prevSummary,
                    style: mono(fontSize: 12, color: T.text),
                  ),
                ),
              ] else
                const Spacer(),
              if (addWeightHint)
                const Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 11, color: T.accent),
                    Text(
                      ' add weight',
                      style: TextStyle(
                        fontSize: 11,
                        color: T.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(sets.length, (i) {
            final s = sets[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    child: Text(
                      '${i + 1}',
                      style: mono(fontSize: 13, color: T.faint),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WEIGHT',
                          style: mono(fontSize: 10, color: T.faint),
                        ),
                        Stepper2(
                          value: s.weight,
                          step: 2.5,
                          suffix: 'kg',
                          onChange: (v) => onWeight(i, v.toDouble()),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REPS', style: mono(fontSize: 10, color: T.faint)),
                        Stepper2(
                          value: s.reps,
                          step: 1,
                          onChange: (v) => onReps(i, v.toInt()),
                        ),
                      ],
                    ),
                  ),
                  if (sets.length > 1)
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onRemove(i),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: T.faint,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 30),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          _Outlined(icon: Icons.add, label: 'Add set', onTap: onAdd),
          const SizedBox(height: 10),
          PrimaryButton(
            padding: const EdgeInsets.all(12),
            onTap: onSave,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.save, size: 16),
                const SizedBox(width: 6),
                Text(saved ? 'Update exercise' : 'Save exercise'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Outlined extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Outlined({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: T.line),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: T.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: T.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapSheet extends StatelessWidget {
  final String? group;
  final List<String> alternatives;
  final ValueChanged<String> onPick;
  const _SwapSheet({
    required this.group,
    required this.alternatives,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: T.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Text(
          'Swap with${group != null ? ' · $group' : ''}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: T.text,
          ),
        ),
        const SizedBox(height: 12),
        if (alternatives.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'No other $group exercises in the library yet.',
              style: TextStyle(fontSize: 13, color: T.muted),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: alternatives.length,
              itemBuilder: (context, idx) {
                final n = alternatives[idx];
                final i = lib[n]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPick(n),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: T.surface,
                        border: Border.all(color: T.line),
                        borderRadius: BorderRadius.circular(T.rM),
                      ),
                      child: Row(
                        children: [
                          MuscleMap(
                            view: i.view,
                            primary: i.primary,
                            secondary: i.secondary,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: T.text,
                                  ),
                                ),
                                Text(
                                  i.target,
                                  style: mono(fontSize: 10.5, color: T.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
