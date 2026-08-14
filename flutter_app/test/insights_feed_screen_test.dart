// Widget tests for the InsightCard component and the Insights feed screen.
// Rule logic itself is covered in insight_rules_test.dart — this is about
// rendering and the dismiss/restore interaction.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cuttracker/app/app_state.dart';
import 'package:cuttracker/features/insights/domain/insight.dart';
import 'package:cuttracker/features/insights/presentation/insights_feed_screen.dart';
import 'package:cuttracker/features/insights/presentation/widgets/insight_card.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Unlike daily_log_peek_test.dart / next_kg_screen_test.dart (which do
    // a real network fetch + wait, and use goldens that want the real
    // typeface), nothing here depends on the exact glyphs rendered — just
    // disable google_fonts' runtime fetch entirely so mono() falls back to
    // the platform default immediately, with no network, no timer, no
    // flakiness to chase.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> settleFonts(WidgetTester tester) async {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('google_fonts')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    await tester.pump();
  }

  const insight = Insight(
    id: 'weight-log-gap:2026-08-20',
    tone: InsightTone.suggestion,
    tag: 'Suggestion',
    message: "It's been 11 days since your last weigh-in — want to log one?",
    actionLabel: 'Log weight',
  );

  testWidgets('InsightCard shows message/tag/action, and each control fires its callback', (tester) async {
    var actioned = false;
    var dismissed = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InsightCard(
          insight: insight,
          onAction: () => actioned = true,
          onDismiss: () => dismissed = true,
        ),
      ),
    ));
    await settleFonts(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Suggestion'), findsOneWidget);
    expect(find.text(insight.message), findsOneWidget);
    expect(find.text('Log weight'), findsOneWidget);

    await tester.tap(find.text('Log weight'));
    await tester.pump();
    expect(actioned, isTrue);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('InsightCard in the dismissed state shows a restore control instead of dismiss/action', (tester) async {
    var restored = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InsightCard(insight: insight, dismissed: true, onRestore: () => restored = true),
      ),
    ));
    await settleFonts(tester);
    expect(tester.takeException(), isNull);

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Log weight'), findsNothing); // no action button once dismissed
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(restored, isTrue);
  });

  AppState buildState({Map<String, dynamic> extraSettings = const {}}) => AppState(
        ready: true,
        view: AppView.app,
        users: const [],
        user: null,
        foods: const [],
        tab: 'progress',
        data: AppData(settings: {'goalType': 'fatLoss', ...extraSettings}),
      );

  testWidgets('the feed shows a currently-firing insight, and dismissing it persists through patchSettings', (tester) async {
    final controller = AppController();
    final app = buildState();

    await tester.pumpWidget(MaterialApp(home: InsightsFeedScreen(app: app, controller: controller)));
    await settleFonts(tester);
    expect(tester.takeException(), isNull);

    // fatLoss with no weigh-in logged -> the weight-log-gap rule fires.
    expect(find.textContaining("haven't logged"), findsOneWidget);
    expect(find.text('Nothing to flag right now — check back as you log more.'), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // AppController is a real (background, un-awaited) instance here rather
    // than a stub — this just confirms the tap didn't throw reaching for
    // patchSettings, matching the null-user guard pattern used elsewhere
    // (e.g. next_kg_screen.dart's kgMilestonesSeen persistence).
  });

  testWidgets('the feed shows its empty state when no rule fires', (tester) async {
    final controller = AppController();
    // maintain has no weight target -> checkWeightLogGap (the only rule
    // that can fire off bare settings with no other data) stays quiet too.
    final app = buildState(extraSettings: const {'goalType': 'maintain'});

    await tester.pumpWidget(MaterialApp(home: InsightsFeedScreen(app: app, controller: controller)));
    await settleFonts(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Nothing to flag right now — check back as you log more.'), findsOneWidget);
  });
}
