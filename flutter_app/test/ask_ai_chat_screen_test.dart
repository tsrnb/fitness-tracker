// Widget tests for the Ask AI chat's broadened scope — locking in the two
// things that actually changed behavior: an advice-only reply (empty
// items) must render as a plain answer, not a broken "0 items, Add to
// log does nothing" result card; and conversation history must actually
// carry a prior exchange into the next call, so a follow-up has something
// to follow up on. Network is faked entirely — nothing here talks to the
// real Cloudflare proxy/OpenAI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cuttracker/app/app_state.dart';
import 'package:cuttracker/features/nutrition/data/ask_ai_controller.dart';
import 'package:cuttracker/features/nutrition/data/openai_food_service.dart';
import 'package:cuttracker/features/nutrition/domain/ai_food_item.dart';
import 'package:cuttracker/features/nutrition/presentation/ask_ai_chat_screen.dart';

/// Overrides the network call entirely — records what it was asked
/// (message/history/profileContext) and returns the next canned result
/// off the queue, one per call.
class FakeOpenAiFoodService extends OpenAiFoodService {
  final List<AiFoodParseResult> queue;
  final List<({String message, List<Map<String, String>> history, String? profileContext})> calls = [];
  var _i = 0;
  FakeOpenAiFoodService(this.queue);

  @override
  Future<bool> ping() async => true;

  @override
  Future<AiFoodParseResult> chat(
    String message, {
    List<Map<String, String>> history = const [],
    Map<String, dynamic> knownFacts = const {},
    String? profileContext,
  }) async {
    calls.add((message: message, history: List.of(history), profileContext: profileContext));
    final result = queue[_i < queue.length ? _i : queue.length - 1];
    _i++;
    return result;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // No glyph in these tests depends on the real typeface — skip the
    // network fetch entirely rather than racing it.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  AppState buildState() => AppState(
        ready: true,
        view: AppView.app,
        users: const [],
        user: const SimpleUser(1, 'Alex'),
        foods: const [],
        tab: 'food',
        data: const AppData(settings: {'calorieGoal': 2200, 'proteinGoal': 160, 'goalType': 'fatLoss', 'dietPref': 'veg'}),
      );

  Widget buildScreen(AppState app, AskAiController ai) => MaterialApp(
        home: AskAiChatScreen(app: app, controller: AppController(), aiController: ai),
      );

  testWidgets('an advice-only reply (empty items) renders as a plain answer, not a broken result card', (tester) async {
    final fake = FakeOpenAiFoodService([
      const AiFoodParseResult(
        items: [],
        rawContent: '{"reply":"Protein around workouts matters less than your daily total — aim for 20-40g within a couple hours either side.","items":[],"remember":[]}',
        reply: 'Protein around workouts matters less than your daily total — aim for 20-40g within a couple hours either side.',
      ),
    ]);
    final ai = AskAiController(fake);

    await tester.pumpWidget(buildScreen(buildState(), ai));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Should I eat before or after my workout?');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump(); // shows the typing indicator
    await tester.pump(); // resolves the fake's Future

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Protein around workouts'), findsOneWidget);
    // The broken state this guards against: an empty-items result still
    // rendering its item-breakdown card with a live "Add to today's log"
    // button wired to nothing useful.
    expect(find.text("Add to today's log"), findsNothing);
    expect(find.text('Total'), findsNothing);
  });

  testWidgets('a food-logging reply still renders the item card with a working Add-to-log button', (tester) async {
    final fake = FakeOpenAiFoodService([
      const AiFoodParseResult(
        items: [AiFoodItem(name: 'Paneer bhurji', emoji: '🍳', kcal: 320, protein: 22, carb: 8, fat: 22, fiber: 2)],
        rawContent: '{"reply":"Here'
            's the breakdown:","items":[{"name":"Paneer bhurji","emoji":"🍳","kcal":320,"protein":22,"carb":8,"fat":22,"fiber":2}],"remember":[]}',
        reply: "Here's the breakdown:",
      ),
    ]);
    final ai = AskAiController(fake);

    await tester.pumpWidget(buildScreen(buildState(), ai));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'paneer bhurji for breakfast');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Paneer bhurji'), findsOneWidget);
    // The button existing (rather than the tap flowing all the way through
    // to a persisted log entry, which needs a real signed-in controller —
    // exercised by the app's other logging-path tests, not this one) is
    // what proves the item card rendered correctly for a non-empty result.
    expect(find.text("Add to today's log"), findsOneWidget);
  });

  testWidgets('a follow-up message carries the prior exchange as history, and profile context is attached', (tester) async {
    final fake = FakeOpenAiFoodService([
      const AiFoodParseResult(items: [], rawContent: '{"reply":"Aim for roughly 130-150g protein a day given your goal.","items":[],"remember":[]}', reply: 'Aim for roughly 130-150g protein a day given your goal.'),
      const AiFoodParseResult(items: [], rawContent: '{"reply":"Good vegetarian sources: paneer, lentils, Greek yogurt, tofu.","items":[],"remember":[]}', reply: 'Good vegetarian sources: paneer, lentils, Greek yogurt, tofu.'),
    ]);
    final ai = AskAiController(fake);

    await tester.pumpWidget(buildScreen(buildState(), ai));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'How much protein do I need?');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'What are good vegetarian sources?');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(fake.calls.length, 2);
    // The first call has no history to replay yet.
    expect(fake.calls[0].history, isEmpty);
    // The second call replays the first exchange, so "good vegetarian
    // sources" resolves as a follow-up to the protein question rather than
    // an unrelated one.
    expect(fake.calls[1].history, isNotEmpty);
    expect(fake.calls[1].history.any((m) => m['content'] == 'How much protein do I need?'), isTrue);
    // Profile context (goal/diet/remaining-today) is attached to every call.
    expect(fake.calls[0].profileContext, contains('losing fat'));
    expect(fake.calls[0].profileContext, contains('vegetarian'));
  });
}
