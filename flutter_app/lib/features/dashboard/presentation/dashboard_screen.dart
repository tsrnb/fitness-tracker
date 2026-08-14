import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/widgets/ai_shimmer_once.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../../plan/data/plan_options.dart';
import '../../training/domain/program.dart';
import '../data/dashboard_stats.dart';
import '../../nutrition/presentation/log_food_sheet.dart';
import '../../insights/domain/insights_engine.dart';
import '../../insights/presentation/insight_actions.dart';
import '../../insights/presentation/widgets/insight_card.dart';
import 'rest_day_screen.dart';
import 'health_sync_banner.dart';

class DashboardScreen extends StatelessWidget {
  final AppState app;
  final AppController controller;
  final void Function(String tab, [String? day]) go;
  final VoidCallback openActivity;
  final VoidCallback openPlan;
  const DashboardScreen({super.key, required this.app, required this.controller, required this.go, required this.openActivity, required this.openPlan});

  @override
  Widget build(BuildContext context) {
    final st = app.data.settings;
    final today = todayStr(st);
    final snap = computeDashboardSnapshot(app);
    final todayDay = snap.todayDay;
    final exercises = snap.exercises;
    bool loggedToday(String name) => isLoggedToday(app.data.history, name, today);

    final kcalToday = snap.kcalToday;
    final protToday = snap.protToday;
    final protGoal = snap.protGoal;
    final adjustedCalGoal = snap.adjustedCalGoal;
    final tdee = snap.tdee;
    final balance = snap.balance;
    final goalType = snap.goalType;

    final cur = snap.currentWeight;
    final tgt = snap.targetWeight;
    final daysLeft = snap.daysLeft;

    final act = snap.activityToday;
    final burnedToday = (act['kcal'] ?? 0) as num;
    final stepGoal = snap.stepGoal;
    final last7 = snap.sessionsLast7Days;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(fmtFull().toUpperCase(), style: mono(fontSize: 11.5, color: T.faint).copyWith(letterSpacing: 1)),
          ),
          // One slot, highest-priority insight only — a wall of AI nags
          // would train people to stop reading this screen at all.
          for (final insight in InsightsEngine.active(app.data, today, limit: 1))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InsightCard(
                insight: insight,
                onAction: insightAction(context, insight, app, controller, goTab: go),
                onDismiss: () {
                  if (controller.current.user == null) return;
                  controller.patchSettings('insightsDismissed', InsightsEngine.withDismissed(app.data, insight.id));
                },
              ),
            ),
          // No HealthKit/Health Connect equivalent exists in a browser —
          // Health Sync is a mobile-only feature, so the banner is simply
          // absent on web rather than showing a permanently-failing state.
          if (!kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HealthSyncBanner(app: app, controller: controller),
            ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildWorkoutHeroCard(
                    todayDay: todayDay,
                    exercises: exercises,
                    loggedToday: loggedToday,
                    sessionsThisWeek: last7,
                    steps: (act['steps'] ?? 0) as num,
                    stepGoal: stepGoal,
                    onTap: todayDay != null ? () => go('train', todayDay) : () => RestDayScreen.push(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HeroCard(
                    tone: HeroTone.lav,
                    onTap: () => go('food'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('NUTRITION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            SizedBox(height: 6),
                            Text('Hit Your Daily Protein Goal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, height: 1.18)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AiShimmerOnce(
                          borderRadius: BorderRadius.circular(T.pill),
                          child: ActionPill(
                            label: 'Log food',
                            icon: const Icon(Icons.add, size: 17, color: Colors.white),
                            onTap: () => showAppSheet(context, LogFoodSheet(app: app, controller: controller)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildStatsCard(
            goalType: goalType,
            balance: balance,
            tdee: tdee,
            burnedToday: burnedToday,
            kcalToday: kcalToday,
            adjustedCalGoal: adjustedCalGoal,
            protToday: protToday,
            protGoal: protGoal,
          ),
          const SizedBox(height: 12),
          PaperCard(
            onTap: () => go('train'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const IconBubble(icon: Icon(Icons.fitness_center, size: 20, color: Colors.white), size: 48, background: T.hero),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(todayDay ?? 'Recovery', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Padding(padding: const EdgeInsets.only(top: 2), child: Text('$last7 of 5 sessions this week', style: const TextStyle(fontSize: 12.5, color: T.paperMuted))),
                  ]),
                ]),
                Ring(value: last7.toDouble(), goal: 5, size: 72, onPaper: true, color: T.hero),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  onTap: () => go('progress'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Body weight'),
                      if (cur != null) ...[
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text('$cur', style: mono(fontSize: 26, fontWeight: FontWeight.w600)),
                          Text(' ${st['units'] ?? 'kg'}', style: mono(fontSize: 13, color: T.muted)),
                        ]),
                        if (tgt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${(cur - tgt).abs().toStringAsFixed(1)} to $tgt${daysLeft != null ? " · ${daysLeft}d left" : ""}',
                              style: TextStyle(fontSize: 12, color: T.muted),
                            ),
                          ),
                      ] else
                        Padding(padding: EdgeInsets.only(top: 8), child: Text('Log a weigh-in', style: TextStyle(color: T.muted, fontSize: 13))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  onTap: openPlan,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Your plan'),
                      Row(children: [
                        const Icon(Icons.auto_awesome, size: 18, color: T.hero),
                        const SizedBox(width: 8),
                        Text(goalLabel(st['goalType'] as String?, fallback: 'Coach'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                      Padding(padding: EdgeInsets.only(top: 6), child: Text('Tap for diet & training', style: TextStyle(fontSize: 12, color: T.muted))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: openActivity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Eyebrow('Today\'s activity', margin: EdgeInsets.zero),
                    Row(children: const [
                      Icon(Icons.add, size: 14, color: T.hero),
                      SizedBox(width: 4),
                      Text('log', style: TextStyle(color: T.hero, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                            const Icon(Icons.directions_walk, size: 16, color: T.hero),
                            const SizedBox(width: 6),
                            Text('${(act['steps'] ?? 0)}', style: mono(fontSize: 22, fontWeight: FontWeight.w600)),
                          ]),
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: (((act['steps'] ?? 0) as num) / stepGoal).clamp(0, 1).toDouble()),
                                duration: const Duration(milliseconds: 750),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, _) => LinearProgressIndicator(
                                  value: v,
                                  minHeight: 5,
                                  backgroundColor: T.surface2,
                                  valueColor: AlwaysStoppedAnimation(((act['steps'] ?? 0) as num) >= stepGoal ? T.success : T.hero),
                                ),
                              ),
                            ),
                          ),
                          Padding(padding: EdgeInsets.only(top: 5), child: Text('steps · goal ${stepGoal.round()}', style: TextStyle(fontSize: 11, color: T.muted))),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 50, color: T.line, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                            const Icon(Icons.local_fire_department, size: 16, color: T.hero),
                            const SizedBox(width: 6),
                            Text('${(act['kcal'] ?? 0)}', style: mono(fontSize: 22, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            Text('kcal', style: mono(fontSize: 12, color: T.muted)),
                          ]),
                          Padding(padding: EdgeInsets.only(top: 14), child: Text('cardio · ${(act['min'] ?? 0)} min', style: TextStyle(fontSize: 11, color: T.muted))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Hit ${protGoal.round()}g protein, keep lifts heavy, sleep 7+ hrs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: T.faint, fontSize: 12, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The ring/stats card just under the hero row — its content depends on
  /// the user's goal, since "calories in a ring + protein in a ring" isn't
  /// actually the number that matters for every goal (fat loss cares about
  /// the deficit; gaining cares about protein + surplus).
  /// The orange "today's workout" card — redesigned around a single
  /// question ("what am I doing now?") instead of a cramped 2-item preview
  /// list. Shows exactly one lift, the first unlogged one, at title size,
  /// with a segment meter as the only reminder a full list exists; the
  /// finished state is a genuinely different layout rather than an empty
  /// checklist. Session-scanning still lives one tap away on the Train
  /// screen, so nothing here is lost, just deferred.
  Widget _buildWorkoutHeroCard({
    required String? todayDay,
    required List<ProgramItem> exercises,
    required bool Function(String) loggedToday,
    required int sessionsThisWeek,
    required num steps,
    required num stepGoal,
    required VoidCallback onTap,
  }) {
    if (todayDay == null) {
      return HeroCard(
        tone: HeroTone.hero,
        onTap: onTap,
        child: SizedBox(
          height: 154,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('REST DAY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's job", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Colors.white.withValues(alpha: 0.75))),
                  const Padding(padding: EdgeInsets.only(top: 5), child: Text('Walk & recover', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 21, height: 1.15))),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text('${steps.round()} / ${stepGoal.round()} steps', style: mono(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final totalSets = exercises.fold<int>(0, (a, e) => a + e.sets);
    final loggedCount = exercises.where((e) => loggedToday(e.name)).length;
    final allDone = exercises.isNotEmpty && loggedCount == exercises.length;
    ProgramItem? nextEx;
    for (final e in exercises) {
      if (!loggedToday(e.name)) {
        nextEx = e;
        break;
      }
    }

    Widget segments() => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: List.generate(exercises.length * 2 - 1, (i) {
              if (i.isOdd) return const SizedBox(width: 3);
              final segIndex = i ~/ 2;
              return Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: segIndex < loggedCount ? Colors.white : Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        );

    return HeroCard(
      tone: HeroTone.hero,
      onTap: onTap,
      child: SizedBox(
        height: 154,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${todayDay.toUpperCase()} DAY', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                if (allDone)
                  const IconBubble(icon: Icon(Icons.check, size: 14, color: T.hero), size: 28, background: Colors.white)
                else
                  Text(
                    loggedCount > 0 ? '$loggedCount/${exercises.length}' : '$totalSets sets',
                    style: mono(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                  ),
              ],
            ),
            if (allDone)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Session done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 21)),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${exercises.length} lifts · $totalSets sets', style: mono(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      sessionsThisWeek == 1 ? '1 session this week' : '$sessionsThisWeek sessions this week',
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.82)),
                    ),
                  ),
                  segments(),
                ],
              )
            else if (nextEx != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loggedCount > 0 ? 'NEXT UP' : 'START WITH', style: mono(fontSize: 10, color: Colors.white.withValues(alpha: 0.75)).copyWith(letterSpacing: 0.6)),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(nextEx.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 21, height: 1.15)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text('${nextEx.sets} × ${nextEx.reps}', style: mono(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                  ),
                  segments(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard({
    required dynamic goalType,
    required int balance,
    required num tdee,
    required num burnedToday,
    required num kcalToday,
    required num adjustedCalGoal,
    required num protToday,
    required num protGoal,
  }) {
    // Two different energy numbers live on this card family: [balance] is
    // the *true* deficit/surplus vs. maintenance (TDEE) — the number that
    // actually predicts weight change, always the bold primary stat below.
    // [budgetLeft] is just "how much of today's calorie goal is left" —
    // useful, but secondary, so it's always the small neutral BudgetChip,
    // never colored as a verdict of its own. Same split on the Diet tab and
    // Progress → Daily log, so "true deficit" means the same thing and
    // looks the same everywhere it shows up.
    final budgetLeft = adjustedCalGoal - kcalToday;
    if (goalType == 'fatLoss') {
      final isDeficit = balance >= 0;
      final amount = balance.abs();
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(isDeficit ? 'True deficit' : 'True surplus'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$amount', style: mono(fontSize: 34, fontWeight: FontWeight.w800, color: isDeficit ? T.success : T.danger)),
                const SizedBox(width: 8),
                Text('kcal', style: Type.h3),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 10),
              child: Text(
                burnedToday > 0
                    ? 'vs ~${tdee.round()} maintenance · ${burnedToday.round()} kcal from activity'
                    : 'vs ~${tdee.round()} maintenance',
                style: Type.caption,
              ),
            ),
            BudgetChip(budgetLeft: budgetLeft),
          ],
        ),
      );
    }
    if (goalType == 'weightGain') {
      final isSurplus = balance <= 0;
      final amount = balance.abs();
      return AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(children: [
              Ring(value: protToday.toDouble(), goal: protGoal.toDouble(), size: 100, unit: 'g', color: T.blue),
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('protein', style: TextStyle(fontSize: 11, color: T.muted))),
            ]),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Eyebrow(isSurplus ? 'True surplus' : 'True deficit', margin: const EdgeInsets.only(bottom: 6)),
                  Text('$amount', style: mono(fontSize: 30, fontWeight: FontWeight.w800, color: isSurplus ? T.success : T.danger)),
                  Padding(padding: const EdgeInsets.only(top: 2, bottom: 8), child: Text('kcal', style: Type.caption)),
                  BudgetChip(budgetLeft: budgetLeft),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // 'maintain' or unset — existing default behavior.
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(children: [
            Ring(value: kcalToday.toDouble(), goal: adjustedCalGoal.toDouble(), size: 100, color: T.hero),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('calories', style: TextStyle(fontSize: 11, color: T.muted))),
          ]),
          Column(children: [
            Ring(value: protToday.toDouble(), goal: protGoal.toDouble(), size: 100, unit: 'g', color: T.blue),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('protein', style: TextStyle(fontSize: 11, color: T.muted))),
          ]),
        ],
      ),
    );
  }

}
