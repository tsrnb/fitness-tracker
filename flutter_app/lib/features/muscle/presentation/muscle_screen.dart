import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../data/muscle_store.dart';
import '../domain/muscle_models.dart';
import '../domain/muscle_stats.dart';
import 'know_why_screen.dart';
import 'lift_detail_screen.dart';
import 'muscle_setup_screen.dart';
import 'widgets/gain_chart.dart';
import 'widgets/know_why_button.dart';
import 'widgets/log_muscle_sheet.dart';
import 'widgets/muscle_bits.dart';
import '../../../shared/responsive.dart';

/// Opens the Muscle screen from anywhere (the Dashboard card). Someone who
/// has never set it up goes straight into the setup flow first.
Future<void> openMuscle(BuildContext context, AppState app, AppController controller) async {
  if (muscleProfileOf(app.data) == null) {
    final done = await MuscleSetupScreen.open(context, app, controller);
    if (!done || !context.mounted) return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(AppRoute(builder: (_) => const MuscleScreen()));
}

/// Full-page wrapper around [MuscleTab], watching live state because a
/// pushed route would otherwise keep the `AppState` it was opened with.
class MuscleScreen extends ConsumerWidget {
  const MuscleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    return pageScaffold(
      context: context,
      title: 'Muscle',
      onBack: () => Navigator.of(context).pop(),
      child: MuscleTab(app: app, controller: controller),
    );
  }
}

/// The Muscle screen body: a Gain tab (pace, trend, tape check, fuel) and a
/// Lifts tab (overload board). Embedded in Progress and in [MuscleScreen].
class MuscleTab extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const MuscleTab({super.key, required this.app, required this.controller});

  @override
  State<MuscleTab> createState() => _MuscleTabState();
}

class _MuscleTabState extends State<MuscleTab> {
  String _tab = 'gain';
  int _weeks = 8;

  AppData get _data => widget.app.data;
  String get _today => todayStr(_data.settings);

  void _logSheet() => LogMuscleSheet.show(context, widget.app, widget.controller);

  Future<void> _setup() => MuscleSetupScreen.open(context, widget.app, widget.controller);

  @override
  Widget build(BuildContext context) {
    final p = muscleProfileOf(_data);
    if (p == null) return _intro();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: PillTabs(
              options: const [MapEntry('gain', 'Gain'), MapEntry('lifts', 'Lifts')],
              value: _tab,
              onChange: (v) => setState(() => _tab = v),
            ),
          ),
          const SizedBox(width: 10),
          Padding(padding: const EdgeInsets.only(bottom: 16), child: KnowWhyButton(onTap: () => KnowWhyScreen.open(context))),
        ]),
        if (_tab == 'gain') ..._gain(p) else ..._lifts(p),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // First run
  // -------------------------------------------------------------------------

  Widget _intro() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Muscle'),
          Text('Track lean gain, not just weight', style: Type.finding),
          const SizedBox(height: 10),
          Text(
            'A short setup tells the app how fast gains should come for you. Then you get your pace against a healthy range, your lifts climbing, and a check on whether the weight you gain is muscle.',
            style: Type.caption,
          ),
          const SizedBox(height: 16),
          PrimaryButton(onTap: _setup, child: const Text('Set up Muscle')),
        ]),
      );

  // -------------------------------------------------------------------------
  // Gain tab
  // -------------------------------------------------------------------------

  List<Widget> _gain(MuscleProfile p) {
    final g = computeGain(_data, p, _today);
    final l = p.levelInfo;
    return [
      _settingsRow(l),
      if (g == null) _noWeighIn() else ...[_hero(g, l), const SizedBox(height: 12), _trend(l, g), const SizedBox(height: 12), _paceCard(g, l)],
      const SizedBox(height: 12),
      _tapeCard(p),
      if (g?.fuel != null) ...[const SizedBox(height: 12), _fuelCard(g!.fuel!)],
      const SizedBox(height: 8),
      Text(
        'Pace bands are guidance based on training experience and vary between sources. They are a range to aim for, not a promise.',
        style: TextStyle(fontSize: 11, color: T.faint, height: 1.4),
      ),
    ];
  }

  Widget _settingsRow(MuscleLevel l) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _setup,
              behavior: HitTestBehavior.opaque,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${l.label} · ', style: TextStyle(color: T.muted, fontSize: 12.5)),
                TextSpan(text: '${l.range} kg/wk', style: mono(fontSize: 12, color: T.muted)),
                const TextSpan(text: ' · Edit', style: TextStyle(color: T.accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ])),
            ),
          ),
          GestureDetector(
            onTap: _logSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
              child: Text('+ Log weigh-in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.text)),
            ),
          ),
        ]),
      );

  Widget _noWeighIn() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Lean-gain phase'),
          Text('Log your first weigh-in to start tracking your pace.', style: Type.caption),
          const SizedBox(height: 14),
          PrimaryButton(onTap: _logSheet, child: const Text('Log weigh-in')),
        ]),
      );

  Widget _hero(GainSnapshot g, MuscleLevel l) {
    final (chip, chipColor) = paceChip(g.state);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(T.rXL),
        border: Border.all(color: T.line),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [T.accent.withValues(alpha: 0.14), T.surface], stops: const [0, 0.6]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('LEAN-GAIN PHASE · WEEK ${g.weekNumber}', overflow: TextOverflow.ellipsis, style: mono(fontSize: 10.5, color: T.faint).copyWith(letterSpacing: 1.2))),
          const SizedBox(width: 8),
          MuscleChip(chip, chipColor),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(signed(g.gained), style: Type.display.copyWith(fontSize: 46)),
                Text(' kg', style: mono(fontSize: 16, color: T.muted)),
              ]),
              const SizedBox(height: 6),
              Text('${g.startWeight.toStringAsFixed(1)} → ${g.currentWeight.toStringAsFixed(1)} kg · goal ${g.goalWeight.toStringAsFixed(1)}', style: Type.caption),
            ]),
          ),
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(alignment: Alignment.center, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: g.fraction),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(value: v, strokeWidth: 8, strokeCap: StrokeCap.round, backgroundColor: T.surface2, valueColor: const AlwaysStoppedAnimation(T.accent)),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(g.fraction * 100).round()}%', style: mono(fontSize: 17, fontWeight: FontWeight.w600, color: T.text)),
                Text('to goal', style: TextStyle(fontSize: 9.5, color: T.muted)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Next whole kg: ', style: TextStyle(color: T.muted, fontSize: 12.5)),
          TextSpan(text: g.nextWholeKg.toStringAsFixed(1), style: TextStyle(color: T.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
          TextSpan(
            text: ' · ${(g.nextWholeKg - g.currentWeight).toStringAsFixed(1)} kg away${g.weeksToNext != null ? ', about ${g.weeksToNext!.ceil()} ${g.weeksToNext!.ceil() == 1 ? 'week' : 'weeks'} at this pace' : ''}',
            style: TextStyle(color: T.muted, fontSize: 12.5),
          ),
        ])),
      ]),
    );
  }

  Widget _trend(MuscleLevel l, GainSnapshot g) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Eyebrow('Weight vs target corridor', margin: EdgeInsets.zero)),
            _rangeToggle(),
          ]),
          const SizedBox(height: 12),
          GainChart(weight: _data.weight, today: _today, weeks: _weeks, level: l, startDate: g.startDate, baseline: g.startWeight),
          const SizedBox(height: 8),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: T.success.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Expanded(child: Text('${l.label} target: ${l.range} kg per week', style: TextStyle(fontSize: 11.5, color: T.muted))),
          ]),
        ]),
      );

  Widget _rangeToggle() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(T.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final w in const [4, 8])
            GestureDetector(
              onTap: () => setState(() => _weeks = w),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(color: _weeks == w ? T.text : Colors.transparent, borderRadius: BorderRadius.circular(T.pill)),
                child: Text('${w}w', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _weeks == w ? T.bg : T.muted)),
              ),
            ),
        ]),
      );

  Widget _paceCard(GainSnapshot g, MuscleLevel l) {
    final pace = g.pace;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Expanded(child: Eyebrow('Pace since goal start', margin: EdgeInsets.zero)),
          if (pace != null) Text('${signed(pace, digits: 2)} kg/wk', style: mono(fontSize: 13, fontWeight: FontWeight.w600, color: T.text)),
        ]),
        const SizedBox(height: 14),
        if (pace == null)
          Text('Weigh in on at least three different days across a week to see your pace.', style: Type.caption)
        else ...[
          _gauge(pace, l),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Too slow', style: TextStyle(fontSize: 11, color: T.muted)),
            Text('Lean zone', style: TextStyle(fontSize: 11, color: T.success, fontWeight: FontWeight.w700)),
            Text('Mostly fat', style: TextStyle(fontSize: 11, color: T.muted)),
          ]),
        ],
      ]),
    );
  }

  Widget _gauge(double pace, MuscleLevel l) {
    final max = l.hi * 1.8;
    final loF = l.lo / max, hiF = l.hi / max;
    final pos = (pace / max).clamp(0.02, 0.98);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 18,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Row(children: [
                Expanded(flex: (loF * 1000).round(), child: ColoredBox(color: T.surface2)),
                Expanded(flex: ((hiF - loF) * 1000).round(), child: ColoredBox(color: T.success.withValues(alpha: 0.45))),
                Expanded(flex: ((1 - hiF) * 1000).round(), child: ColoredBox(color: T.danger.withValues(alpha: 0.3))),
              ]),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            left: pos * w - 2,
            top: 0,
            child: Container(width: 4, height: 18, decoration: BoxDecoration(color: T.text, borderRadius: BorderRadius.circular(3))),
          ),
        ]),
      );
    });
  }

  Widget _tapeCard(MuscleProfile p) {
    final stage = tapeStage(p.tape);
    final due = tapeDue(p.tape, _today);
    final v = tapeVerdict(p.tape);
    final since = daysSinceTape(p.tape, _today);
    Widget action(String t) => GestureDetector(
          onTap: _logSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
            child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.text)),
          ),
        );
    Widget head() => Row(children: [
          const Expanded(child: Eyebrow('Is it muscle? Tape vs waist', margin: EdgeInsets.zero)),
          if (v != null) MuscleChip(v.label, toneColor(v.tone)),
        ]);

    final Widget body;
    if (stage == TapeStage.none) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add arm, chest and waist once. After a week we can tell if the weight you gain is muscle or fat.', style: Type.caption),
        const SizedBox(height: 12),
        action('Add measurements'),
      ]);
    } else if (stage == TapeStage.baselineOnly || v == null) {
      final base = p.tape.last;
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (final s in tapeSites)
            if (base.cm[s.$1] != null)
              Expanded(child: _tapeNumber(s.$2, base.cm[s.$1]!.toStringAsFixed(1), T.text)),
        ]),
        const SizedBox(height: 12),
        Text(
          stage == TapeStage.enough
              ? 'Need waist plus arm or chest in both entries to compare.'
              : due
                  ? 'A new check is due. Measure again to see the change.'
                  : 'Baseline saved ${since == 0 ? 'today' : '$since days ago'}. Next check in ${tapeIntervalDays - (since ?? 0)} days.',
          style: Type.caption,
        ),
        if (due || stage == TapeStage.enough) ...[const SizedBox(height: 12), action('Log measurements')],
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (final s in tapeSites)
            Expanded(
              child: _tapeNumber(
                s.$2,
                v.deltas[s.$1] == null ? '—' : signed(v.deltas[s.$1]!),
                v.deltas[s.$1] == null
                    ? T.faint
                    : (s.$1 == 'waist' ? (v.deltas[s.$1]! > 0.5 ? T.danger : T.muted) : (v.deltas[s.$1]! > 0.5 ? T.success : T.muted)),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        Text.rich(TextSpan(children: [
          TextSpan(text: '${v.detail} ', style: TextStyle(fontSize: 12.5, color: T.muted, height: 1.4)),
          TextSpan(text: 'cm over ${v.days} days', style: TextStyle(fontSize: 12.5, color: T.faint)),
        ])),
        const SizedBox(height: 12),
        action(due ? 'Log again · due' : 'Log again'),
      ]);
    }
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head(), const SizedBox(height: 12), body]));
  }

  Widget _tapeNumber(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: T.muted)),
        const SizedBox(height: 2),
        Text(value, style: mono(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      ]);

  Widget _fuelCard(FuelCheck f) {
    final surplusOk = f.surplusKcal >= 200 && f.surplusKcal <= 500;
    final protOk = f.proteinPerKg >= 1.6;
    Widget col(String label, String value, double frac, bool ok, String goal) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: T.muted)),
            const SizedBox(height: 2),
            Text(value, style: mono(fontSize: 15, fontWeight: FontWeight.w600, color: T.text)),
            const SizedBox(height: 8),
            MuscleBar(frac, ok ? T.success : T.lavAccent),
            const SizedBox(height: 4),
            Text(goal, style: TextStyle(fontSize: 11, color: T.faint)),
          ]),
        );
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Fuel check'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          col('Surplus vs maintenance', '${signed(f.surplusKcal, digits: 0)} kcal', (f.surplusKcal / 500).clamp(0.0, 1.0), surplusOk, 'goal +200 to +500'),
          const SizedBox(width: 16),
          col('Protein', '${f.proteinPerKg.toStringAsFixed(1)} g/kg', (f.proteinPerKg / 2.2).clamp(0.0, 1.0), protOk, 'goal 1.6 to 2.2'),
        ]),
        const SizedBox(height: 10),
        Text('Average of the last ${f.days} days with food logged.', style: TextStyle(fontSize: 11, color: T.faint)),
      ]),
    );
  }

  // -------------------------------------------------------------------------
  // Lifts tab
  // -------------------------------------------------------------------------

  List<Widget> _lifts(MuscleProfile p) {
    final lifts = summarizeLifts(_data.history, p.tracked);
    if (lifts.isEmpty) {
      return [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('Lifts'),
            Text(p.tracked.isEmpty ? 'No lifts selected yet. Pick the lifts to track in Edit.' : 'No logged sets for your tracked lifts yet. Log a session on the Train tab.', style: Type.caption),
            const SizedBox(height: 14),
            PrimaryButton(onTap: _setup, child: const Text('Choose lifts')),
          ]),
        ),
      ];
    }
    final up = lifts.where((l) => l.progressed(_today)).length;
    final prs = lifts.where((l) => l.isPr && daysBetween(l.last.date, _today) <= 10).length;
    final (vc, vp) = volumeLoadWindows(_data.history, p.tracked, _today);
    final volPct = vp > 0 ? (vc - vp) / vp * 100 : null;
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(T.rXL),
          border: Border.all(color: T.line),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [T.accent.withValues(alpha: 0.14), T.surface], stops: const [0, 0.6]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('OVERLOAD THIS WEEK', style: mono(fontSize: 10.5, color: T.faint).copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$up', style: Type.display.copyWith(fontSize: 46)),
                Text(' of ${lifts.length}', style: Type.h2.copyWith(color: T.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (prs > 0) MuscleChip('$prs new ${prs == 1 ? 'PR' : 'PRs'}', T.accent),
              if (volPct != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('volume load ${signed(volPct)}%', style: TextStyle(fontSize: 12, color: T.muted))),
            ]),
          ]),
          const SizedBox(height: 8),
          Text('lifts progressed since the previous session. Estimated 1RM from your logged sets.', style: Type.caption),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          for (var i = 0; i < lifts.length; i++) _liftRow(lifts[i], first: i == 0),
        ]),
      ),
    ];
  }

  Widget _liftRow(LiftSummary l, {required bool first}) {
    final d = l.delta;
    final c = d > 0 ? T.success : (d < 0 ? T.danger : T.muted);
    final pr = l.isPr && daysBetween(l.last.date, _today) <= 10;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(AppRoute(builder: (_) => LiftDetailScreen(app: widget.app, controller: widget.controller, name: l.name))),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: T.surface2))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(l.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.text))),
                if (pr) ...[const SizedBox(width: 6), const MuscleChip('PR', T.accent)],
              ]),
              const SizedBox(height: 2),
              Text('${l.e1rm} kg e1RM', style: mono(fontSize: 12, color: T.muted)),
            ]),
          ),
          Sparkline(l.recentE1rm(), color: c),
          SizedBox(width: 44, child: Text(l.points.length < 2 ? '—' : (d == 0 ? '=' : signed(d, digits: 0)), textAlign: TextAlign.right, style: mono(fontSize: 13, fontWeight: FontWeight.w600, color: c))),
        ]),
      ),
    );
  }
}
