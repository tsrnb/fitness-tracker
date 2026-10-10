import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart' show showAppSheet;
import '../../../../shared/lib/helpers.dart';
import '../../../../app/app_state.dart';
import '../../../nutrition/presentation/widgets/ai_gradient.dart' show aiColor1;
import '../../../progress/presentation/widgets/weigh_in_sheet.dart';
import '../../domain/calibration_engine.dart';
import '../calibration_dashboard_screen.dart';

/// Takes over the Home dashboard's one insight slot while a calibration is
/// running (mockup "variant B") — special-cased at the `DashboardScreen`
/// call site rather than folded into `allInsightRules`, since `Insight` has
/// no visual slot for a sparkline and `InsightsEngine` has no forced-
/// priority mechanism to make this always outrank the other five rules.
class CalibrationStatusCard extends StatelessWidget {
  final AppState app;
  final AppController controller;
  const CalibrationStatusCard({super.key, required this.app, required this.controller});

  @override
  Widget build(BuildContext context) {
    final data = app.data;
    final calibration = Map<String, dynamic>.from(data.calibration!);
    final today = todayStr(data.settings);
    final progress = computeProgress(data, calibration, today);
    // The calibration's whole premise is a daily weigh-in — the generic
    // `checkWeightLogGap` insight rule only fires after a 10-day silence
    // (see insight_rules.dart), which defeats the point here. While this
    // card is showing, an unlogged today takes over its own headline
    // instead of waiting a week and a half to say anything.
    final needsWeighIn = !progress.weightLoggedToday;
    final statusLabel = needsWeighIn
        ? 'Log today\'s weigh-in to keep the trend going'
        : switch (progress.status) {
            'within_range' => 'Trend\'s tracking close to plan',
            'ahead' => 'Trend\'s ahead of plan',
            _ => 'Trend\'s behind plan — no need to react yet',
          };

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalibrationDashboardScreen(app: app, controller: controller))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rL),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [T.accentDim, aiColor1.withValues(alpha: 0.08)]),
            border: Border.all(color: T.accentSoft),
            borderRadius: BorderRadius.circular(T.rL),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [T.accent, aiColor1]))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 13, 12, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
                              alignment: Alignment.center,
                              child: Text(needsWeighIn ? '⚖️' : '🧪', style: const TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CALIBRATION · DAY ${progress.day}/${progress.totalDays}', style: mono(fontSize: 9, fontWeight: FontWeight.w700, color: T.accent).copyWith(letterSpacing: 0.5)),
                                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(statusLabel, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (needsWeighIn)
                          Padding(
                            padding: const EdgeInsets.only(top: 10, left: 36),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => showAppSheet(context, WeighInSheet(app: app, controller: controller)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(999)),
                                child: Text('Log weight', style: mono(fontSize: 11, fontWeight: FontWeight.w700, color: T.accent)),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 10, left: 36),
                            child: Row(
                              children: [
                                Text('${progress.observedKgSoFar.toStringAsFixed(1)}kg', style: mono(fontSize: 10.5, fontWeight: FontWeight.w700, color: T.success)),
                                Text(' / ${progress.expectedKgSoFar.toStringAsFixed(1)}kg expected', style: mono(fontSize: 10.5, color: T.muted)),
                                const Spacer(),
                                Text('View →', style: mono(fontSize: 10.5, fontWeight: FontWeight.w700, color: T.faint)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
