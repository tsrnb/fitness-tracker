import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../../shared/lib/helpers.dart';
import '../../../../app/app_state.dart';
import '../../data/muscle_store.dart';
import '../../domain/muscle_models.dart';
import '../../domain/muscle_stats.dart';
import '../know_why_screen.dart';
import '../muscle_screen.dart';
import 'know_why_button.dart';
import 'log_muscle_sheet.dart';
import 'muscle_bits.dart';

/// The Dashboard's Muscle entry. Shown to anyone whose goal is weight gain
/// and to anyone who has already set Muscle up (so a fat-loss user who is
/// curious is not nagged, but keeps their card once they opt in).
bool showMuscleCard(AppData data) => data.settings['goalType'] == 'weightGain' || data.muscle != null;

/// Compact status card. Before setup it is an invitation; after, the pace
/// chip, kg gained, progress to the goal, and lifts that progressed.
class MuscleDashboardCard extends StatelessWidget {
  final AppState app;
  final AppController controller;
  const MuscleDashboardCard({super.key, required this.app, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = muscleProfileOf(app.data);
    final today = todayStr(app.data.settings);
    if (p == null) {
      return AppCard(
        onTap: () => openMuscle(context, app, controller),
        child: Row(children: [
          const IconBubble(icon: Icon(Icons.fitness_center, size: 18, color: Colors.white), size: 40, background: T.hero),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Track your lean gain', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: T.text)),
              const SizedBox(height: 2),
              Text('Two-minute setup, then pace, lifts and a muscle-or-fat check.', style: TextStyle(fontSize: 12, color: T.muted, height: 1.35)),
            ]),
          ),
          const MuscleChip('Set up', T.accent),
        ]),
      );
    }
    final g = computeGain(app.data, p, today);
    final lifts = summarizeLifts(app.data.history, p.tracked);
    final up = lifts.where((l) => l.progressed(today)).length;
    final prs = lifts.where((l) => l.isPr && daysBetween(l.last.date, today) <= 10).length;
    final (chip, chipColor) = paceChip(g?.state);
    return AppCard(
      onTap: () => openMuscle(context, app, controller),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Eyebrow(g == null ? 'Muscle' : 'Muscle · week ${g.weekNumber}', margin: EdgeInsets.zero)),
          if (g != null) MuscleChip(chip, chipColor),
          const SizedBox(width: 8),
          KnowWhyButton(compact: true, onTap: () => KnowWhyScreen.open(context)),
        ]),
        const SizedBox(height: 12),
        if (g == null)
          Text('Log a weigh-in to start tracking your pace.', style: Type.caption)
        else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(signed(g.gained), style: mono(fontSize: 30, fontWeight: FontWeight.w600, color: T.text)),
                Text(' kg', style: mono(fontSize: 13, color: T.muted)),
              ]),
            ),
            if (lifts.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$up of ${lifts.length} lifts up', style: mono(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.text)),
                if (prs > 0) Text('$prs new ${prs == 1 ? 'PR' : 'PRs'}', style: TextStyle(fontSize: 11.5, color: T.muted)),
              ]),
          ]),
          const SizedBox(height: 12),
          MuscleBar(g.fraction, T.accent),
          const SizedBox(height: 6),
          Text('${(g.fraction * 100).round()}% to ${g.goalWeight.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11.5, color: T.muted)),
        ],
      ]),
    );
  }
}

/// Top-of-Dashboard banner: the weekly tape check is due. Only appears once
/// a baseline exists (someone who skipped tape is never nagged for it) and
/// opens the weigh-in sheet directly.
class TapeDueNudge extends StatelessWidget {
  final AppState app;
  final AppController controller;
  const TapeDueNudge({super.key, required this.app, required this.controller});

  static bool shouldShow(AppData data) {
    final p = muscleProfileOf(data);
    if (p == null || p.tape.isEmpty) return false;
    return tapeDue(p.tape, todayStr(data.settings));
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: T.accentSoft,
      onTap: () => LogMuscleSheet.show(context, app, controller),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: T.accentDim, borderRadius: BorderRadius.circular(12)),
          child: Text('cm', style: mono(fontSize: 12, fontWeight: FontWeight.w700, color: T.accent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Weekly tape check is due', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: T.text)),
            const SizedBox(height: 2),
            Text('Arm, chest, waist. Takes about a minute.', style: TextStyle(fontSize: 12, color: T.muted)),
          ]),
        ),
        Icon(Icons.chevron_right, size: 20, color: T.accent),
      ]),
    );
  }
}
