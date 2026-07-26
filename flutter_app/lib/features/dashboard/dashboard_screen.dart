import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/lib/helpers.dart';
import '../../app/app_state.dart';
import '../training/program.dart';
import '../training/splits.dart';
import '../nutrition/quick_log_sheet.dart';
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
    final today = todayStr();
    final jsDow = DateTime.now().weekday % 7; // JS getDay(): 0=Sun..6=Sat
    final split = activeSplit(st);
    final todayDay = scheduleFromSettings(st, split)[jsDow];
    final exercises = todayDay != null ? split.program[todayDay]!.items : <ProgramItem>[];
    bool loggedToday(String name) {
      final h = List<dynamic>.from(app.data.history[name] ?? []);
      return h.isNotEmpty && h.last['date'] == today;
    }

    final meals = List<Map<String, dynamic>>.from(app.data.diet[today] ?? []);
    final kcalToday = meals.fold<num>(0, (a, b) => a + (b['kcal'] ?? 0));
    final protToday = meals.fold<num>(0, (a, b) => a + (b['protein'] ?? 0));
    final calGoal = (st['calorieGoal'] ?? 2000) as num;
    final protGoal = (st['proteinGoal'] ?? 150) as num;
    final actToday = Map<String, dynamic>.from(app.data.activity[today] ?? {});
    final burnedToday = (actToday['kcal'] ?? 0) as num;
    final adjustedCalGoal = calGoal + burnedToday;
    final tdee = (app.data.plan?['tdee'] ?? calGoal) as num;
    // Positive = under maintenance (deficit), negative = over maintenance (surplus).
    final balance = (tdee - (kcalToday - burnedToday)).round();
    final goalType = st['goalType'];

    final weightList = app.data.weight;
    final lastWeight = weightList.isNotEmpty ? weightList.last['weight'] : null;
    final cur = st['currentWeight'] ?? lastWeight;
    final tgt = st['targetWeight'];
    final daysLeft = st['targetDate'] != null ? daysBetween(today, st['targetDate']).clamp(0, 1 << 30) : null;

    final act = actToday.isNotEmpty ? actToday : {'steps': 0, 'kcal': 0, 'min': 0};
    final stepGoal = (st['stepGoal'] ?? 10000) as num;
    final last7 = app.data.sessions.keys.where((d) {
      final df = daysBetween(d, today);
      return df >= 0 && df < 7;
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(fmtFull().toUpperCase(), style: mono(fontSize: 11.5, color: T.faint).copyWith(letterSpacing: 1)),
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
                  child: HeroCard(
                    tone: HeroTone.hero,
                    onTap: todayDay != null ? () => go('train', todayDay) : () => RestDayScreen.push(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${todayDay ?? "Rest"}\nDay', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19, height: 1.15)),
                            const IconBubble(icon: Icon(Icons.fitness_center, size: 16, color: Colors.white), size: 34, background: Color(0x33FFFFFF)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: todayDay != null
                              ? exercises.take(2).map((ex) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: ChecklistPill(label: ex.name, sub: '${ex.sets} × ${ex.reps}', done: loggedToday(ex.name)),
                                  )).toList()
                              : [ChecklistPill(label: 'Walk & recover', sub: 'Active rest', done: app.data.activity[today] != null)],
                        ),
                      ],
                    ),
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
                        ActionPill(label: 'Log food', icon: const Icon(Icons.add, size: 17, color: Colors.white), onTap: () => showAppSheet(context, QuickLogSheet(controller: controller))),
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
                              '${((cur as num) - (tgt as num)).abs().toStringAsFixed(1)} to $tgt${daysLeft != null ? " · ${daysLeft}d left" : ""}',
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
                        Text(_goalLabel(st['goalType']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
    if (goalType == 'fatLoss') {
      final isDeficit = balance >= 0;
      final amount = balance.abs();
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow("Today's energy balance"),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$amount', style: mono(fontSize: 34, fontWeight: FontWeight.w800, color: isDeficit ? T.success : T.danger)),
                const SizedBox(width: 8),
                Text(isDeficit ? 'kcal deficit' : 'kcal surplus', style: Type.h3),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              burnedToday > 0
                  ? 'vs ~${tdee.round()} maintenance · ${burnedToday.round()} kcal from activity'
                  : 'vs ~${tdee.round()} maintenance',
              style: Type.caption,
            ),
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
                  const Eyebrow('Energy surplus', margin: EdgeInsets.only(bottom: 6)),
                  Text('$amount', style: mono(fontSize: 30, fontWeight: FontWeight.w800, color: isSurplus ? T.success : T.danger)),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(isSurplus ? 'kcal surplus' : 'kcal deficit', style: Type.caption),
                  ),
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

  String _goalLabel(dynamic goalType) {
    switch (goalType) {
      case 'fatLoss':
        return 'Fat loss';
      case 'weightGain':
        return 'Muscle gain';
      case 'maintain':
        return 'Maintain';
      default:
        return 'Coach';
    }
  }
}
