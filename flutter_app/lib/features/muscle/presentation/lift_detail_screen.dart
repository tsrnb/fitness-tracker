import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../domain/muscle_models.dart';
import 'know_why_screen.dart';
import 'widgets/know_why_button.dart';
import 'widgets/muscle_bits.dart';

/// One lift: its last eight sessions as estimated 1RM, what changed, and a
/// concrete target for the next session.
class LiftDetailScreen extends StatelessWidget {
  final AppState app;
  final AppController controller;
  final String name;
  const LiftDetailScreen({super.key, required this.app, required this.controller, required this.name});

  @override
  Widget build(BuildContext context) {
    final lift = LiftSummary(name, liftSeries(app.data.history, name));
    return pageScaffold(
      context: context,
      title: name,
      onBack: () => Navigator.of(context).pop(),
      trailing: KnowWhyButton(compact: true, onTap: () => KnowWhyScreen.open(context, focusLift: name)),
      child: lift.hasData ? _body(context, lift) : AppCard(child: Text('No logged sets yet for this lift.', style: Type.caption)),
    );
  }

  Widget _body(BuildContext context, LiftSummary lift) {
    final today = todayStr(app.data.settings);
    final pts = lift.points.length > 8 ? lift.points.sublist(lift.points.length - 8) : lift.points;
    final mn = pts.map((p) => p.e1rm).reduce((a, b) => a < b ? a : b) - 4;
    final mx = pts.map((p) => p.e1rm).reduce((a, b) => a > b ? a : b) + 2;
    final d = lift.delta;
    final dColor = d > 0 ? T.success : (d < 0 ? T.danger : T.muted);
    final (nw, nr) = lift.nextTarget;
    final (aw, ar) = lift.nextAltTarget;
    final vc = lift.volumeChangePct;
    String w(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Eyebrow('Estimated 1RM', margin: EdgeInsets.zero)),
            if (lift.isPr && daysBetween(lift.last.date, today) <= 10) MuscleChip('New PR', T.accent),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('${lift.e1rm}', style: Type.display),
                Text(' kg', style: mono(fontSize: 14, color: T.muted)),
              ]),
            ),
            if (lift.points.length > 1) MuscleChip('${signed(d, digits: 0)} kg', dColor),
          ]),
          if (lift.points.length > 1) Padding(padding: const EdgeInsets.only(top: 4), child: Text('vs previous session', style: Type.caption)),
          const SizedBox(height: 18),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < pts.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Flexible(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: (pts[i].e1rm - mn) / (mx - mn)),
                            duration: Duration(milliseconds: 450 + i * 40),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => FractionallySizedBox(
                              heightFactor: v.clamp(0.04, 1.0),
                              child: Container(decoration: BoxDecoration(color: i == pts.length - 1 ? T.accent : T.surface2, borderRadius: BorderRadius.circular(6))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(fmtDay(pts[i].date).replaceFirst(' ', ' '), maxLines: 1, overflow: TextOverflow.clip, style: mono(fontSize: 8, color: T.faint)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Next session target'),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${w(nw)} kg × $nr', style: mono(fontSize: 22, fontWeight: FontWeight.w600, color: T.text)),
            const MuscleChip('+2.5 kg', Color(0xFF3F9E55)),
          ]),
          const SizedBox(height: 4),
          Text('Last top set: ${w(lift.last.topWeight)} kg × ${lift.last.topReps}', style: Type.caption),
          const SizedBox(height: 10),
          Text('Or keep ${w(aw)} kg and aim for $ar reps. Both count as overload.', style: Type.caption),
        ]),
      ),
      if (vc != null) ...[
        const SizedBox(height: 12),
        AppCard(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Session volume load', margin: EdgeInsets.only(bottom: 4)),
                Text('weight × reps, vs previous session', style: Type.caption),
              ]),
            ),
            Text('${signed(vc, digits: 0)}%', style: mono(fontSize: 18, fontWeight: FontWeight.w600, color: vc > 0 ? T.success : (vc < 0 ? T.danger : T.muted))),
          ]),
        ),
      ],
    ]);
  }
}
