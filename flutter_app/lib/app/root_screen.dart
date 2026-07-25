import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/theme.dart';
import '../shared/widgets/atoms.dart';
import '../shared/widgets/animated_indexed_stack.dart';
import '../shared/widgets/pressable_scale.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_picker_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/training/train_screen.dart';
import '../features/exercises/library_screen.dart';
import '../features/exercises/exercise_detail_sheet.dart';
import '../features/progress/progress_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/activity/log_activity_sheet.dart';
import '../features/settings/settings_screen.dart';
import 'app_state.dart';

const _tabs = [
  ('home', 'Home', Icons.home_rounded),
  ('train', 'Train', Icons.fitness_center),
  ('library', 'Library', Icons.menu_book),
  ('progress', 'Progress', Icons.trending_up),
  ('food', 'Diet', Icons.restaurant),
];

class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  String? trainDay;

  void _go(String tab, [String? day]) {
    if (day != null) setState(() => trainDay = day);
    ref.read(appControllerProvider.notifier).setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    if (!app.ready) {
      return const _Loading(msg: 'Opening your database…');
    }
    if (app.view == AppView.onboarding) {
      return OnboardingScreen(
        onComplete: (profile, plan) {
          controller.onboardingComplete(
            {
              'name': profile['name'],
              'sex': profile['sex'],
              'age': profile['age'],
              'height': profile['height'],
              'units': profile['units'],
              'goalType': profile['goalType'],
              'dietPref': profile['dietPref'],
              'currentWeight': profile['currentWeight'],
              'targetWeight': profile['targetWeight'],
              'targetDate': profile['targetDate'],
              'activity': profile['activity'],
              'calorieGoal': plan.calorieGoal,
              'proteinGoal': plan.proteinGoal,
              'stepGoal': plan.stepGoal,
            },
            plan.toJson(),
            profile['name'],
            (profile['currentWeight'] as num).toDouble(),
            DateTime.now().toIso8601String().substring(0, 10),
          );
        },
        onCancel: app.users.isNotEmpty ? () => controller.showPicker() : null,
      );
    }
    if (app.view == AppView.picker) {
      return ProfilePickerScreen(
        users: app.users,
        onPick: (id) => controller.switchUser(id),
        onCreate: () => controller.beginCreate(),
      );
    }
    if (app.user == null) {
      return const _Loading(msg: null);
    }

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: T.hero, shape: BoxShape.circle),
                          child: Text(
                            (app.user!.name.trim().isNotEmpty ? app.user!.name.trim()[0] : '?').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello there! 👋', style: TextStyle(fontSize: 12.5, color: T.muted)),
                            Padding(padding: EdgeInsets.only(top: 1), child: Text(app.user!.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.2, color: T.text))),
                          ],
                        ),
                      ]),
                      IconBubble(
                        icon: Icon(Icons.settings, size: 19, color: T.muted),
                        size: 42,
                        background: T.surface,
                        border: Border.all(color: T.line),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(app: app, controller: controller))),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 90 + MediaQuery.of(context).padding.bottom),
                    child: AnimatedIndexedStack(
                      index: _tabs.indexWhere((t) => t.$1 == app.tab).clamp(0, _tabs.length - 1),
                      children: [
                        DashboardScreen(
                          app: app,
                          controller: controller,
                          go: _go,
                          openActivity: () => showAppSheet(context, LogActivitySheet(app: app, controller: controller)),
                          openPlan: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlanScreen(app: app, controller: controller))),
                        ),
                        TrainScreen(
                          app: app,
                          controller: controller,
                          initialDay: trainDay,
                          openExercise: (name) => showAppSheet(context, ExerciseDetailSheet(name: name)),
                        ),
                        LibraryScreen(openExercise: (name) => showAppSheet(context, ExerciseDetailSheet(name: name))),
                        ProgressScreen(
                          app: app,
                          controller: controller,
                          openActivity: () => showAppSheet(context, LogActivitySheet(app: app, controller: controller)),
                        ),
                        NutritionScreen(app: app, controller: controller),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: T.surface2.withValues(alpha: 0.92),
                    border: Border.all(color: T.line),
                    borderRadius: BorderRadius.circular(T.pill),
                    boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final activeIndex = _tabs.indexWhere((t) => t.$1 == app.tab).clamp(0, _tabs.length - 1);
                      final itemW = constraints.maxWidth / _tabs.length;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            left: activeIndex * itemW,
                            width: itemW,
                            top: 0,
                            bottom: 0,
                            child: DecoratedBox(decoration: BoxDecoration(color: T.hero, borderRadius: BorderRadius.circular(T.pill))),
                          ),
                          Row(
                            children: _tabs.map((t) {
                              final active = app.tab == t.$1;
                              return Expanded(
                                child: PressableScale(
                                  onTap: () => _go(t.$1),
                                  downScale: 0.9,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedScale(
                                          duration: const Duration(milliseconds: 320),
                                          curve: Curves.easeOutBack,
                                          scale: active ? 1.08 : 1.0,
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: TextStyle(color: active ? Colors.white : T.faint),
                                            child: Icon(t.$3, size: 19, color: active ? Colors.white : T.faint),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 220),
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: active ? Colors.white : T.faint),
                                          child: Text(t.$2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  final String? msg;
  const _Loading({this.msg});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: T.hero, borderRadius: BorderRadius.circular(T.rM)),
              child: const Icon(Icons.fitness_center, size: 24, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(msg ?? 'Loading…', style: mono(fontSize: 13, color: T.muted)),
          ],
        ),
      ),
    );
  }
}
