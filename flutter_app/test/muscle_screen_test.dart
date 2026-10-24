// Widget tests for the Muscle feature's screens: they prove each state
// renders without throwing and that the key interactions (setup prompt,
// tab switch, lift detail, Know why chat + saved history, Dashboard card
// and nudge) do what the design says. The math lives in
// muscle_models_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cuttracker/app/app_state.dart';
import 'package:cuttracker/features/muscle/data/muscle_store.dart';
import 'package:cuttracker/features/muscle/presentation/know_why_screen.dart';
import 'package:cuttracker/features/muscle/presentation/lift_detail_screen.dart';
import 'package:cuttracker/features/muscle/presentation/muscle_screen.dart';
import 'package:cuttracker/features/muscle/presentation/muscle_setup_screen.dart';
import 'package:cuttracker/features/muscle/presentation/widgets/log_muscle_sheet.dart';
import 'package:cuttracker/features/muscle/presentation/widgets/muscle_dashboard_cards.dart';

/// Keeps everything in memory: the real controller writes to sqlite and
/// needs a signed-in user, neither of which these tests care about.
class _FakeController extends AppController {
  _FakeController(AppState initial) {
    state = initial;
  }

  @override
  Future<void> update(String key, dynamic Function(dynamic prev) fn) async {
    final next = fn(state.data[key]);
    if (key == 'muscle') {
      state = state.copyWith(data: state.data.copyWith(muscle: next == null ? null : Map<String, dynamic>.from(next)));
    }
  }
}

String _d(int daysAgo) => DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: daysAgo)));

Map<String, dynamic> _sets(double w, int reps) => {
      'sets': [
        {'weight': w, 'reps': reps}
      ]
    };

AppData _data({bool profile = true, int tapeDaysAgo = 14, String goalType = 'weightGain'}) {
  final weight = [
    for (var i = 28; i >= 0; i -= 4) {'date': _d(i), 'weight': 72.4 + (28 - i) * 0.04},
  ];
  final history = {
    'Barbell Bench Press': [
      {'date': _d(14), ..._sets(70, 8)},
      {'date': _d(7), ..._sets(72.5, 8)},
      {'date': _d(1), ..._sets(75, 8)},
    ],
    'Back Squat': [
      {'date': _d(9), ..._sets(100, 8)},
      {'date': _d(2), ..._sets(95, 8)},
    ],
  };
  return AppData(
    settings: {'goalType': goalType, 'calorieGoal': 2900, 'dayStartMinutes': 0},
    plan: {'tdee': 2600},
    weight: weight,
    history: history,
    diet: {
      for (var i = 0; i < 5; i++)
        _d(i): [
          {'kcal': 2900, 'protein': 140}
        ]
    },
    muscle: profile
        ? {
            'level': 'intermediate',
            'tracked': ['Barbell Bench Press', 'Back Squat'],
            'setupDate': _d(28),
            'goalGainKg': 2.0,
            'tape': [
              {'date': _d(tapeDaysAgo + 14), 'arm': 35.0, 'chest': 98.0, 'waist': 81.0},
              {'date': _d(tapeDaysAgo), 'arm': 36.1, 'chest': 99.6, 'waist': 81.4},
            ],
            'chats': [],
          }
        : null,
  );
}

AppState _state(AppData d) => AppState(ready: true, view: AppView.app, users: const [], user: null, foods: const [], tab: 'progress', data: d);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    HttpOverrides.global = null;
  });

  Future<void> settle(WidgetTester tester) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('google_fonts')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(milliseconds: 900));
  }

  Widget host(Widget child, {AppController? controller}) => ProviderScope(
        overrides: [if (controller != null) appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
      );

  testWidgets('before setup the tab offers to set Muscle up', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = _FakeController(_state(_data(profile: false)));
    await tester.pumpWidget(host(MuscleTab(app: c.current, controller: c)));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Set up Muscle'), findsOneWidget);
  });

  testWidgets('Gain tab shows pace, tape verdict and fuel check; Lifts tab lists lifts; a lift opens its detail', (tester) async {
    tester.view.physicalSize = const Size(1000, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = _FakeController(_state(_data()));
    await tester.pumpWidget(host(MuscleTab(app: c.current, controller: c)));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.textContaining('LEAN-GAIN PHASE'), findsOneWidget);
    expect(find.text('Know why'), findsOneWidget);
    expect(find.text('Mostly lean'), findsOneWidget);
    expect(find.text('FUEL CHECK'), findsOneWidget);
    expect(find.textContaining('Next whole kg'), findsOneWidget);

    await tester.tap(find.text('Lifts'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('OVERLOAD THIS WEEK'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget);
    expect(find.text('1 of 2'), findsNothing); // rendered as separate "1" and " of 2" spans
    expect(find.text('PR'), findsOneWidget); // bench only: squat dipped

    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(find.byType(LiftDetailScreen), findsOneWidget);
    expect(find.text('NEXT SESSION TARGET'), findsOneWidget);
    expect(find.text('77.5 kg × 8'), findsOneWidget); // 75 kg + 2.5
  });

  testWidgets('Dashboard: card shows for gain goals and set-up users, nudge only when a baseline is due', (tester) async {
    expect(showMuscleCard(_data(profile: false, goalType: 'weightGain')), isTrue);
    expect(showMuscleCard(_data(profile: false, goalType: 'fatLoss')), isFalse);
    expect(showMuscleCard(_data(profile: true, goalType: 'fatLoss')), isTrue);

    expect(TapeDueNudge.shouldShow(_data(tapeDaysAgo: 8)), isTrue);
    expect(TapeDueNudge.shouldShow(_data(tapeDaysAgo: 3)), isFalse);
    expect(TapeDueNudge.shouldShow(_data(profile: false)), isFalse);

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = _FakeController(_state(_data()));
    await tester.pumpWidget(host(Column(children: [
      MuscleDashboardCard(app: c.current, controller: c),
      TapeDueNudge(app: c.current, controller: c),
    ])));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('MUSCLE · WEEK'), findsOneWidget);
    expect(find.text('Weekly tape check is due'), findsOneWidget);

    final fresh = _FakeController(_state(_data(profile: false)));
    await tester.pumpWidget(host(MuscleDashboardCard(app: fresh.current, controller: fresh)));
    await settle(tester);
    expect(find.text('Track your lean gain'), findsOneWidget);
    expect(find.text('Set up'), findsOneWidget);
  });

  testWidgets('Know why: opens with context chips and starters, saves the chat, and lists it in History', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = _FakeController(_state(_data()));
    await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
      child: const MaterialApp(home: KnowWhyScreen()),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Know why'), findsOneWidget);
    expect(find.textContaining('Weight · 8 weigh-ins'), findsOneWidget);
    expect(find.textContaining('Lifts · 2 tracked'), findsOneWidget);
    expect(find.text('Am I gaining at the right speed?'), findsOneWidget);

    await tester.tap(find.text('Am I gaining at the right speed?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    // No AI proxy in tests: the unconfigured message is shown inline, and the
    // user's question was still saved as a chat.
    expect(find.text("Ask AI isn't set up for this build."), findsOneWidget);
    expect(muscleProfileOf(c.current.data)!.chats, hasLength(1));

    await tester.tap(find.textContaining('History'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Saved chats'), findsOneWidget);
    expect(find.text('Am I gaining at the right speed?'), findsOneWidget);
  });

  // A large-phone width (iPhone Pro Max, 430pt). Widget tests fall back to the
  // Ahem font when Google Fonts can't load, whose glyphs are far wider than
  // Manrope's, so a layout that fits here has headroom on a 375-390pt device.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430 * 3, 932 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('at phone width the Gain and Lifts tabs and a lift detail do not overflow', (tester) async {
    phone(tester);
    final c = _FakeController(_state(_data()));
    await tester.pumpWidget(host(MuscleTab(app: c.current, controller: c), controller: c));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lifts'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Back Squat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('setup flow walks all four steps, gates Continue on experience, and saves a profile', (tester) async {
    phone(tester);
    final c = _FakeController(_state(_data(profile: false)));
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: MuscleSetupScreen(app: c.current, controller: c)),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('How long have you been lifting?'), findsOneWidget);

    // Continue is disabled until an experience level is picked.
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('How long have you been lifting?'), findsOneWidget);

    await tester.tap(find.text('Beginner'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Which lifts should we track?'), findsOneWidget);
    expect(find.text('✓ Barbell Bench Press'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Starting measurements'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add).at(2)); // arm, chest, waist, thigh
    await tester.pump();
    expect(find.text('81.0 cm'), findsOneWidget);
    expect(find.text('Save and continue'), findsOneWidget);

    await tester.tap(find.text('Save and continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Here is your plan'), findsOneWidget);
    expect(find.text('0.25–0.6 kg/wk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the weigh-in sheet renders at phone width and only enables Save once something is entered', (tester) async {
    phone(tester);
    final c = _FakeController(_state(_data()));
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(onPressed: () => LogMuscleSheet.show(ctx, c.current, c), child: const Text('open'))))),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Log weigh-in'), findsOneWidget);
    expect(find.text('Due now'), findsOneWidget); // fixture's last tape entry is 14 days old
    expect(find.text('last 36.1 cm'), findsOneWidget);
  });
}
