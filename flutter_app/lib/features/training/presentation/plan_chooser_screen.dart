import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../app/app_state.dart';
import '../../plan/domain/plan.dart';
import '../../plan/data/plan_generator.dart';
import '../../plan/data/plan_options.dart';
import '../domain/training_split.dart';
import '../data/training_splits_data.dart';
import '../data/split_effectiveness.dart';

/// Full-page "Training plan" chooser (Settings → Training plan). Splits are
/// ranked by an effectiveness score for whichever goal is selected up top —
/// most effective first — and picking one immediately swaps the app's active
/// training split: Train tab exercises, and the Plan tab's weekly calendar,
/// both read `settings['trainingSplitId']` via [activeSplit] and update the
/// moment this screen's `controller.update('settings', ...)` call lands.
class TrainingPlanChooserScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const TrainingPlanChooserScreen({super.key, required this.app, required this.controller});

  @override
  State<TrainingPlanChooserScreen> createState() => _TrainingPlanChooserScreenState();
}

class _TrainingPlanChooserScreenState extends State<TrainingPlanChooserScreen> {
  late String goal;
  late String selectedId;
  String? expandedId;

  /// `widget.app` is a snapshot taken once when this screen was pushed — it
  /// never refreshes mid-session, only `controller.update` calls do. Without
  /// a local mirror, a second switch within the same visit to this screen
  /// re-reads that stale snapshot as "current", so a goal change is only
  /// ever detected once per visit (e.g. switching fatLoss -> weightGain
  /// works, but immediately switching back to fatLoss afterward silently no-ops
  /// because the stale snapshot still says "fatLoss" was already current).
  late Map<String, dynamic> _settings;
  late String currentGoal;

  @override
  void initState() {
    super.initState();
    _settings = Map<String, dynamic>.from(widget.app.data.settings);
    currentGoal = (_settings['goalType'] as String?) ?? 'fatLoss';
    if (!goalOptions.any((o) => o.key == currentGoal)) currentGoal = 'fatLoss';
    goal = currentGoal;
    selectedId = activeSplit(_settings).id;
  }

  List<TrainingSplit> get _ranked => rankedSplits(goal);

  Future<bool?> _confirmGoalSwitch(String currentGoal, String newGoal) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.surface,
        title: Text('Switch your goal too?', style: TextStyle(color: T.text)),
        content: Text(
          'This plan is ranked for "${goalLabel(newGoal)}", but your goal is set to "${goalLabel(currentGoal)}". '
          'Continuing will also switch your goal to "${goalLabel(newGoal)}" — your calories, macros, and nutrition plan will be recalculated.',
          style: TextStyle(color: T.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: TextStyle(color: T.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Switch goal', style: TextStyle(color: T.accent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Plan _recalculatePlan(Map<String, dynamic> settings, String goalType) => buildPlanFromSettings(settings, goalType: goalType);

  Future<void> _select(TrainingSplit s) async {
    final switchingGoal = goal != currentGoal;

    if (switchingGoal) {
      final confirmed = await _confirmGoalSwitch(currentGoal, goal);
      if (confirmed != true || !mounted) return;
    }

    final wasSelected = selectedId == s.id;

    final merged = Map<String, dynamic>.from(_settings);
    merged['trainingSplitId'] = s.id;
    merged.remove('schedule'); // old day names don't map onto the new split

    Map<String, dynamic>? planJson;
    if (switchingGoal) {
      merged['goalType'] = goal;
      final plan = _recalculatePlan(merged, goal);
      merged['calorieGoal'] = plan.calorieGoal;
      merged['stepGoal'] = plan.stepGoal;
      merged['proteinGoal'] = plan.proteinGoal;
      merged['carbGoal'] = plan.carbGoal;
      merged['fatGoal'] = plan.fatGoal;
      merged['fiberGoal'] = plan.fiberGoal;
      planJson = plan.toJson();
    }

    widget.controller.update('settings', (_) => merged);
    if (planJson != null) widget.controller.update('plan', (_) => planJson);

    setState(() {
      _settings = merged;
      selectedId = s.id;
      if (switchingGoal) currentGoal = goal;
    });

    if (!mounted) return;

    if (switchingGoal) {
      // A goal change touches calories, macros, training, and the weekly
      // plan all at once — a full-screen beat gives that the weight a
      // snackbar can't, instead of burying it in a one-line toast.
      await Navigator.of(context).push(PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => _GoalSwitchTransitionScreen(
          goalLabel: goalLabel(goal),
          splitName: s.name,
          splitShortTag: s.shortTag,
          splitIcon: s.icon,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ));
      return;
    }

    if (!wasSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${s.name} — your Train tab and weekly plan are updated.')),
      );
    }
  }

  Color _tierColor(int pct) {
    if (pct >= 90) return T.success;
    if (pct >= 80) return T.hero;
    if (pct >= 70) return T.blue;
    return T.danger;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked;
    return pageScaffold(
      context: context,
      title: 'Training plan',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ranked for your goal, most effective first — scored from real weekly volume and frequency, not a lab measurement.',
            style: Type.body.copyWith(color: T.muted),
          ),
          const SizedBox(height: 16),
          const Eyebrow('Optimize for'),
          PillTabs(options: goalOptions, value: goal, onChange: (v) => setState(() => goal = v)),
          ...List.generate(
            ranked.length,
            (i) => StaggerIn(
              key: ValueKey('$goal-${ranked[i].id}'),
              index: i,
              child: _splitCard(ranked[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitCard(TrainingSplit s, int rank) {
    final pct = splitEffectiveness(s)[goal] ?? 0;
    final isActive = selectedId == s.id;
    final isExpanded = expandedId == s.id;
    final tier = _tierColor(pct);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        borderColor: isActive ? T.hero : T.line,
        onTap: () => setState(() => expandedId = isExpanded ? null : s.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rankBadge(rank),
                const SizedBox(width: 10),
                IconBubble(icon: Icon(s.icon, size: 17, color: Colors.white), size: 38, background: isActive ? T.hero : T.faint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(s.name, style: Type.h3, overflow: TextOverflow.ellipsis)),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: T.accentDim, borderRadius: BorderRadius.circular(T.pill)),
                            child: Text('ACTIVE', style: mono(fontSize: 9.5, color: T.hero, fontWeight: FontWeight.w700).copyWith(letterSpacing: 0.6)),
                          ),
                        ],
                      ]),
                      Padding(padding: const EdgeInsets.only(top: 2), child: Text(s.tagline, style: Type.caption)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$pct%', style: mono(fontSize: 20, fontWeight: FontWeight.w700, color: tier)),
                    Text(s.shortTag, style: mono(fontSize: 10, color: T.faint)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: List.generate(s.dayOrder.length, (i) => _dayChip(s, s.dayOrder[i], i))),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !isExpanded
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 1, color: T.line, margin: const EdgeInsets.only(bottom: 12)),
                          Text(s.description, style: Type.body.copyWith(height: 1.5)),
                          const SizedBox(height: 12),
                          ...s.dayOrder.map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 84,
                                      child: Text(d, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text)),
                                    ),
                                    Expanded(child: Text(s.program[d]!.focus, style: Type.caption)),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: isActive
                                ? Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.pill), border: Border.all(color: T.line)),
                                    alignment: Alignment.center,
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.check_circle, size: 16, color: T.success),
                                      const SizedBox(width: 8),
                                      Text('Currently active', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: T.text)),
                                    ]),
                                  )
                                : PrimaryButton(
                                    onTap: () => _select(s),
                                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.swap_horiz, size: 17),
                                      SizedBox(width: 8),
                                      Text('Use this plan'),
                                    ]),
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankBadge(int rank) {
    if (rank == 0) {
      return Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: T.hero, shape: BoxShape.circle),
        child: const Icon(Icons.emoji_events, size: 14, color: Colors.white),
      );
    }
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: T.surface2, shape: BoxShape.circle, border: Border.all(color: T.line)),
      child: Text('${rank + 1}', style: mono(fontSize: 12, fontWeight: FontWeight.w700, color: T.muted)),
    );
  }

  Widget _dayChip(TrainingSplit s, String dayType, int index) {
    final color = dayPalette[index % dayPalette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(T.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(dayType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

/// Full-screen ceremony shown while a goal switch lands — it touches
/// calories, macros, the Train tab, and the weekly plan all at once, which
/// felt too consequential for a one-line snackbar. Purely presentational:
/// the actual `controller.update` calls already landed before this pushes,
/// this just gives the moment some weight, then pops itself.
class _GoalSwitchTransitionScreen extends StatefulWidget {
  final String goalLabel;
  final String splitName;
  final String splitShortTag;
  final IconData splitIcon;
  const _GoalSwitchTransitionScreen({
    required this.goalLabel,
    required this.splitName,
    required this.splitShortTag,
    required this.splitIcon,
  });

  @override
  State<_GoalSwitchTransitionScreen> createState() => _GoalSwitchTransitionScreenState();
}

class _GoalSwitchTransitionScreenState extends State<_GoalSwitchTransitionScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() => _done = true);
      _pulse.stop();
    });
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _done
                    ? const AlwaysStoppedAnimation(1.0)
                    : Tween<double>(begin: 0.92, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                child: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: T.hero, shape: BoxShape.circle),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                    child: _done
                        ? const Icon(Icons.check, key: ValueKey('check'), size: 44, color: Colors.white)
                        : Icon(widget.splitIcon, key: const ValueKey('icon'), size: 40, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _done ? 'All set' : 'Switching to ${widget.goalLabel}',
                  key: ValueKey(_done),
                  style: Type.h2,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text('${widget.splitName} · ${widget.splitShortTag}', style: Type.caption, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _done
                      ? 'Calories, macros, Train tab, and weekly plan are all updated.'
                      : 'Recalculating calories, macros, Train tab, and weekly plan…',
                  key: ValueKey('${_done}_sub'),
                  style: Type.caption,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
