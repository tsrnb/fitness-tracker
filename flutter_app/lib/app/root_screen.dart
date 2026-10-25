import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/theme.dart';
import '../shared/responsive.dart';
import '../shared/widgets/atoms.dart';
import '../shared/widgets/animated_indexed_stack.dart';
import '../shared/widgets/pressable_scale.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_picker_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/training/presentation/train_screen.dart';
import '../features/exercises/presentation/library_screen.dart';
import '../features/exercises/presentation/exercise_detail_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/nutrition/presentation/nutrition_screen.dart';
import '../features/plan/presentation/plan_screen.dart';
import '../features/activity/presentation/log_activity_sheet.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/account/presentation/auth_screens.dart';
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
  // Tabs are built the first time they're opened and then kept alive, so the
  // app doesn't build (and rebuild on every change) all five up front.
  final _visited = <int>{0};

  late final AppController _controller = ref.read(appControllerProvider.notifier);

  void _showNotice() {
    final msg = _controller.notice.value;
    if (msg == null || !mounted) return;
    _controller.notice.value = null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  void initState() {
    super.initState();
    _controller.notice.addListener(_showNotice);
  }

  @override
  void dispose() {
    _controller.notice.removeListener(_showNotice);
    super.dispose();
  }

  void _go(String tab, [String? day]) {
    if (day != null) setState(() => trainDay = day);
    ref.read(appControllerProvider.notifier).setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    if (!app.ready) {
      return const _Loading(msg: 'Opening your account…');
    }
    switch (app.view) {
      case AppView.gate:
        return AuthGateScreen(
          mode: app.auth.gateMode,
          localUsers: app.auth.localUsers,
          email: app.auth.email,
          offline: app.auth.offline,
          error: app.auth.error,
          onToken: controller.signInWithGoogleToken,
          onError: controller.gateError,
          onRetry: controller.retry,
        );
      case AppView.migrating:
        return MigrationScreen(
          email: app.auth.email,
          users: app.auth.localUsers,
          doneIds: app.auth.migratedIds,
          finished: app.auth.migrationDone,
          error: app.auth.error,
          onContinue: controller.finishMigration,
          onRetry: controller.retryMigration,
        );
      case AppView.conflict:
        return ConflictScreen(
          email: app.auth.email,
          cloudCount: app.auth.cloudCount,
          localUsers: app.auth.localUsers,
          onChoose: (add) => controller.resolveConflict(add: add),
        );
      case AppView.restoring:
        return RestoreScreen(email: app.auth.email);
      default:
        break;
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
              'trainingSplitId': profile['trainingSplitId'],
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
      body: LayoutBuilder(builder: (context, constraints) {
        final screen = Responsive.of(constraints.maxWidth);
        final desktop = screen == ScreenClass.desktop;
        final activeIndex = _tabs.indexWhere((t) => t.$1 == app.tab).clamp(0, _tabs.length - 1);
        void openSettings() => Navigator.of(context).push(AppRoute(builder: (_) => SettingsScreen(app: app, controller: controller)));

        // Every tab lays itself out in two columns once its content is wide enough.
        double widthFor(int i) => switch (screen) {
              ScreenClass.phone => double.infinity,
              ScreenClass.tablet => 800,
              ScreenClass.desktop => 1180,
            };

        _visited.add(activeIndex);
        final tabBodies = <Widget>[
          DashboardScreen(
            app: app,
            controller: controller,
            go: _go,
            openActivity: () => showAppSheet(context, LogActivitySheet(app: app, controller: controller)),
            openPlan: () => Navigator.of(context).push(AppRoute(builder: (_) => PlanScreen(app: app, controller: controller))),
          ),
          TrainScreen(app: app, controller: controller, initialDay: trainDay),
          LibraryScreen(openExercise: (name) => ExerciseDetailScreen.push(context, name)),
          ProgressScreen(
            app: app,
            controller: controller,
            openActivity: () => showAppSheet(context, LogActivitySheet(app: app, controller: controller)),
          ),
          NutritionScreen(app: app, controller: controller),
        ];

        final content = Column(
          children: [
            if (desktop)
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widthFor(0)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hello there!', style: TextStyle(fontSize: 13, color: T.muted)),
                              Text(app.user!.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 30, letterSpacing: -0.7, color: T.text)),
                            ],
                          ),
                        ),
                        Text(_tabs[activeIndex].$2.toUpperCase(), style: mono(fontSize: 12, color: T.faint).copyWith(letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ContentColumn(
                maxWidth: widthFor(0),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(screen == ScreenClass.tablet ? 28 : 16, 16, screen == ScreenClass.tablet ? 28 : 16, 4),
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
                        onTap: openSettings,
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: desktop ? 0 : 90 + MediaQuery.of(context).padding.bottom),
                child: AnimatedIndexedStack(
                  index: activeIndex,
                  children: [
                    for (var i = 0; i < tabBodies.length; i++)
                      _visited.contains(i) ? ContentColumn(maxWidth: widthFor(i), child: tabBodies[i]) : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ],
        );

        if (desktop) {
          return Row(
            children: [
              RepaintBoundary(child: _Sidebar(
                activeIndex: activeIndex,
                userName: app.user!.name,
                onSelect: (id) => _go(id),
                onSettings: openSettings,
              )),
              Expanded(child: content),
            ],
          );
        }

        return SafeArea(
          bottom: false,
          child: Stack(
            children: [
              content,
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: RepaintBoundary(child: _PillNav(activeTab: app.tab, onSelect: _go)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// The floating bottom pill used on phone and tablet widths.
class _PillNav extends StatelessWidget {
  final String activeTab;
  final void Function(String tab) onSelect;
  const _PillNav({required this.activeTab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: T.surface2.withValues(alpha: 0.92),
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.pill),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final activeIndex = _tabs.indexWhere((t) => t.$1 == activeTab).clamp(0, _tabs.length - 1);
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
                  final active = activeTab == t.$1;
                  return Expanded(
                    child: PressableScale(
                      onTap: () => onSelect(t.$1),
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
    );
  }
}

/// Desktop navigation: the five tabs plus the profile/settings entry, in place
/// of the floating pill.
class _Sidebar extends StatelessWidget {
  final int activeIndex;
  final String userName;
  final void Function(String tab) onSelect;
  final VoidCallback onSettings;
  const _Sidebar({required this.activeIndex, required this.userName, required this.onSelect, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final initial = (userName.trim().isNotEmpty ? userName.trim()[0] : '?').toUpperCase();
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 18),
      decoration: BoxDecoration(color: T.surface, border: Border(right: BorderSide(color: T.line))),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 26),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: T.hero, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.fitness_center, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text('CutTracker', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: T.text)),
              ]),
            ),
            for (var i = 0; i < _tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: PressableScale(
                  onTap: () => onSelect(_tabs[i].$1),
                  downScale: 0.97,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: i == activeIndex ? T.accentDim : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Icon(_tabs[i].$3, size: 20, color: i == activeIndex ? T.accent : T.muted),
                      const SizedBox(width: 12),
                      Text(
                        _tabs[i].$2,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: i == activeIndex ? T.accent : T.muted),
                      ),
                    ]),
                  ),
                ),
              ),
            const Spacer(),
            Divider(height: 1, color: T.line),
            const SizedBox(height: 12),
            PressableScale(
              onTap: onSettings,
              downScale: 0.97,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: T.hero, shape: BoxShape.circle),
                    child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: T.text)),
                        Text('Settings', style: TextStyle(fontSize: 11.5, color: T.muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.settings, size: 18, color: T.muted),
                ]),
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
