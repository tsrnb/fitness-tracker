// Widget tests for the Next Kg screen (the math itself is covered
// exhaustively in kg_progress_test.dart) — this just proves the screen
// actually renders both its empty and populated states without throwing,
// that a logged day in the strip opens its detail sheet, and that the
// Weight tab's teaser card navigates into it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cuttracker/app/app_state.dart';
import 'package:cuttracker/features/progress/presentation/next_kg_screen.dart';
import 'package:cuttracker/features/progress/presentation/progress_screen.dart';

void main() {
  setUpAll(() {
    // AppController's constructor kicks off a real Backend.init() in the
    // background (never awaited here, same as daily_log_peek_test.dart) —
    // it still needs a real databaseFactory wired up or that init throws
    // synchronously before the async gap.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // This screen renders text through mono()/Type (GoogleFonts), which
    // needs the test binding's fake-every-request HttpOverrides turned off
    // to resolve at all.
    HttpOverrides.global = null;
  });

  String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// A diet log built so every rendered state has something to show:
  /// several very-old, deep-deficit days (guarantees at least one kg
  /// already reached, well outside the display window), then a trailing
  /// 14-day window mixing a deficit day, a surplus day, and a skipped
  /// (un-logged) day — the three bar colors the day-strip can draw.
  AppState buildPopulatedState() {
    final today = DateTime.now();
    final diet = <String, dynamic>{};
    final activity = <String, dynamic>{};

    for (var i = 40; i <= 43; i++) {
      diet[dateKey(today.subtract(Duration(days: i)))] = [
        {'kcal': 0, 'protein': 0},
      ];
    }
    diet[dateKey(today.subtract(const Duration(days: 3)))] = [
      {'kcal': 1500, 'protein': 120},
    ];
    // day - 2 deliberately left unlogged (no key at all) — the skip bar.
    diet[dateKey(today.subtract(const Duration(days: 1)))] = [
      {'kcal': 3200, 'protein': 90}, // surplus day
    ];
    diet[dateKey(today)] = [
      {'kcal': 1600, 'protein': 130},
    ];

    return AppState(
      ready: true,
      view: AppView.app,
      users: const [],
      user: null,
      foods: const [],
      tab: 'progress',
      data: AppData(
        settings: {'calorieGoal': 2200, 'proteinGoal': 160, 'dayStartMinutes': 0},
        plan: {'tdee': 2500},
        diet: diet,
        activity: activity,
      ),
    );
  }

  AppState buildEmptyState() => AppState(
        ready: true,
        view: AppView.app,
        users: const [],
        user: null,
        foods: const [],
        tab: 'progress',
        data: const AppData(settings: {'calorieGoal': 2200, 'proteinGoal': 160}),
      );

  /// A populated state plus two weigh-ins spaced far enough apart, with a
  /// food log in between that implies a much bigger loss than the scale
  /// actually shows — enough to clear computeLatestGap's default 1kg
  /// threshold and surface the gap-insight card.
  AppState buildStateWithGap() {
    final base = buildPopulatedState();
    final today = DateTime.now();
    final weight = [
      {'date': dateKey(today.subtract(const Duration(days: 10))), 'weight': 80.0},
      {'date': dateKey(today.subtract(const Duration(days: 3))), 'weight': 80.2}, // barely moved...
    ];
    // ...despite six deep-deficit days (2300 kcal/day at this fixture's
    // 2500 tdee -> ~1.8kg implied) logged between the two weigh-ins.
    final diet = Map<String, dynamic>.from(base.data.diet);
    for (var i = 4; i <= 9; i++) {
      diet[dateKey(today.subtract(Duration(days: i)))] = [
        {'kcal': 200, 'protein': 100},
      ];
    }
    return AppState(
      ready: base.ready,
      view: base.view,
      users: base.users,
      user: base.user,
      foods: base.foods,
      tab: base.tab,
      data: base.data.copyWith(weight: weight, diet: diet),
    );
  }

  Future<void> settleFonts(WidgetTester tester) async {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('google_fonts')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();
  }

  testWidgets('renders the empty state, then the populated state, and a day tap opens its detail sheet', (tester) async {
    // Not disposed — same reasoning as daily_log_peek_test.dart: its
    // background backend init is never awaited or relied on here.
    final controller = AppController();

    await tester.pumpWidget(MaterialApp(home: NextKgScreen(app: buildEmptyState(), controller: controller)));
    await settleFonts(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Log food'), findsOneWidget);
    expect(find.text('KILOGRAMS SO FAR'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: NextKgScreen(app: buildPopulatedState(), controller: controller)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700)); // ring/bar entrance tweens
    expect(tester.takeException(), isNull);

    // Hero + milestones list rendered, at least one kg actually reached.
    expect(find.text('Nothing yet'), findsNothing);
    // Eyebrow() renders its label upper-cased.
    expect(find.text('KILOGRAMS SO FAR'), findsOneWidget);
    expect(find.text('Kg 1'), findsOneWidget);
    expect(find.textContaining('Reached '), findsOneWidget);
    expect(find.textContaining('in progress'), findsOneWidget);

    // Tap today's (logged) day bar, found by the same key
    // `_DayStripCard` gives it, and confirm its detail sheet opens with the
    // expected breakdown.
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayBar = find.byKey(ValueKey('kg-day-$todayKey'));
    expect(todayBar, findsOneWidget);
    await tester.ensureVisible(todayBar);
    await tester.tap(todayBar);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Counted toward kg'), findsOneWidget);
    expect(find.text('You ate'), findsOneWidget);
    expect(find.text('Your maintenance'), findsOneWidget);
  });

  testWidgets('the Weight tab teaser card opens the Next Kg screen', (tester) async {
    final controller = AppController();
    final app = buildPopulatedState();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProgressScreen(app: app, controller: controller, openActivity: () {})),
    ));
    await settleFonts(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Weight loss progress'), findsOneWidget);
    await tester.tap(find.text('Weight loss progress'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Landed on the full screen — its back button + disclosure card are
    // proof it's the pushed NextKgScreen, not still the tab.
    expect(find.byType(NextKgScreen), findsOneWidget);
    expect(find.text('How this works'), findsOneWidget);
  });

  testWidgets('a real gap between weigh-ins and the food log surfaces the AI insight card', (tester) async {
    final controller = AppController();

    await tester.pumpWidget(MaterialApp(home: NextKgScreen(app: buildStateWithGap(), controller: controller)));
    await settleFonts(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('A gap between your log and your scale'), findsOneWidget);
    expect(find.textContaining('your food log had predicted'), findsOneWidget);

    // AI_PROXY_URL/AI_PROXY_CLIENT_KEY aren't passed via --dart-define in
    // this test run, so WeightInsightService.isConfigured is false — tapping
    // "Ask AI why" deterministically exercises the config-missing path
    // rather than needing a real (or mocked) network call.
    expect(find.text('Ask AI why'), findsOneWidget);
    await tester.ensureVisible(find.text('Ask AI why'));
    await tester.tap(find.text('Ask AI why'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining("isn't set up for this build"), findsOneWidget);
  });
}
