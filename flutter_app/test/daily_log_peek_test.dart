// Regression test for the daily-log ring strip's long-press peek: the
// enlarged ring used to be a Transform.scale'd child of the horizontally
// scrolling ring row, which clips vertically to be scrollable at all — so
// the grown ring got cropped. It's now a separate floating card tracked via
// a LayerLink/CompositedTransformFollower into the app's Overlay, outside
// that clip. This asserts the peek (and its legend) show on hold, nothing
// throws (no RenderFlex overflow etc.), and it's gone on release — plus a
// golden capture of the held state to eyeball for cropping/overlap.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';

import 'package:cuttracker/app/app_state.dart';
import 'package:cuttracker/features/progress/presentation/daily_log_section.dart';
import 'package:cuttracker/features/progress/presentation/widgets/day_ring_column.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // TestWidgetsFlutterBinding installs an HttpOverrides that fakes every
    // HttpClient request as a 400 (to keep tests from hitting the real
    // network by accident) — that's what breaks mono()/Type's GoogleFonts
    // calls here, not an actual lack of connectivity. This test does want
    // the real fonts rendered, so drop that override back to normal.
    HttpOverrides.global = null;
  });

  AppState buildState() {
    final today = DateTime.now();
    final diet = <String, dynamic>{};
    final activity = <String, dynamic>{};
    for (var i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      diet[key] = [
        {'id': '1', 'name': 'Chicken bowl', 'kcal': 850 + i * 40, 'protein': 60 + i * 5},
        {'id': '2', 'name': 'Protein shake', 'kcal': 250, 'protein': 40},
      ];
      activity[key] = {'steps': 6000, 'kcal': 220, 'min': 30};
    }
    return AppState(
      ready: true,
      view: AppView.app,
      users: const [],
      user: null,
      foods: const [],
      tab: 'progress',
      data: AppData(
        settings: {'calorieGoal': 2200, 'proteinGoal': 160, 'dayStartMinutes': 0},
        diet: diet,
        activity: activity,
      ),
    );
  }

  testWidgets('long-pressing a ring shows an uncropped peek + legend, release dismisses it', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // mono()/Type route through GoogleFonts, which — now that the real
    // network fetch above is allowed through — can still occasionally
    // report a transient fetch error via FlutterError instead of quietly
    // falling back. Filtered out for the duration of this test only; a real
    // failure in the assertions below still fails the test normally.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('google_fonts')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    // Not disposed: AppController's own async backend init keeps running
    // in the background regardless (this test never awaits or depends on
    // it — DailyLogSection is driven entirely off the `app` passed below),
    // and racing a dispose against it is a source of unrelated test flake.
    final controller = AppController();
    final app = buildState();

    // Mirrors the real Progress screen (a ListView with 16px horizontal
    // padding around DailyLogSection), not just a bare SingleChildScrollView
    // — that matters here since it's exactly what constrains the ring
    // strip's available width.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [DailyLogSection(app: app, controller: controller)],
        ),
      ),
    ));
    // Let the post-frame scroll-to-today run, then the rings' load-in sweep
    // + per-column stagger finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    // mono()/Type now do a *real* network fetch (see the HttpOverrides note
    // above) — that's wall-clock async I/O, not fake test time, so give it
    // a real moment to land before capturing anything.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();

    // Legend isn't shown at rest.
    expect(find.text('Calories (outer)'), findsNothing);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/daily_log_rest.png'));

    final todayRing = find.byType(DayRingColumn).last;
    final center = tester.getCenter(todayRing);
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600)); // past kLongPressTimeout
    await tester.pump(const Duration(milliseconds: 260)); // let the peek card's pop-in settle

    // Peek + legend both present, and nothing threw laying them out (the
    // regression this guards was a silent visual crop, not an overflow
    // exception, but a real RenderFlex overflow elsewhere would also
    // surface here).
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Calories (outer)'), findsOneWidget);
    expect(find.text('Protein (inner)'), findsOneWidget);

    // The actual regression: the peek card must size to its own content
    // (~104×130), not stretch to fill the Overlay (400×900) — which is
    // exactly what happened before wrapping the CompositedTransformFollower
    // in an Align, since the Overlay hands its non-Positioned children
    // tight full-screen constraints that would otherwise propagate straight
    // through the Follower to the card.
    final peekCardSize = tester.getSize(find.byKey(const Key('peekCardBox')));
    expect(peekCardSize.width, lessThan(150));
    expect(peekCardSize.height, lessThan(200));

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/daily_log_peek_held.png'));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Calories (outer)'), findsNothing);
  });
}
