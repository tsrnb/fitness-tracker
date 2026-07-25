import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/shared/widgets/animated_indexed_stack.dart';

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: [
          Row(
            children: List.generate(
              3,
              (i) => ElevatedButton(
                key: ValueKey('tab-$i'),
                onPressed: () => setState(() => index = i),
                child: Text('tab $i'),
              ),
            ),
          ),
          Expanded(
            child: AnimatedIndexedStack(
              index: index,
              children: [
                Container(key: const ValueKey('page-0'), color: Colors.red),
                Container(key: const ValueKey('page-1'), color: Colors.green),
                Container(key: const ValueKey('page-2'), color: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('switching tabs settles with exactly one page visible/tappable', (tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    final stackFinder = find.byType(AnimatedIndexedStack);
    // AnimatedOpacity.opacity is the *target*, not what's actually painted —
    // reading it can't tell "settled at 0" apart from "frozen mid-fade by a
    // disabled ticker". FadeTransition.opacity.value is the real, currently
    // rendered value, which is what actually exposes the bug.
    List<double> opacities() => tester
        .widgetList<FadeTransition>(find.descendant(of: stackFinder, matching: find.byType(FadeTransition)))
        .map((w) => w.opacity.value)
        .toList();
    List<bool> ignoring() =>
        tester.widgetList<IgnorePointer>(find.descendant(of: stackFinder, matching: find.byType(IgnorePointer))).map((w) => w.ignoring).toList();

    // Initial state: only page 0 visible + tappable.
    expect(opacities(), [1, 0, 0]);
    expect(ignoring(), [false, true, true]);

    // Switch to tab 1, then let the (previously buggy) TickerMode-frozen
    // fade-out actually finish.
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    expect(opacities(), [0, 1, 0], reason: 'page 0 must fully fade out, not freeze visible');
    expect(ignoring(), [true, false, true]);

    // Switch again — page 1 (now inactive) must also fully settle to 0,
    // not get stuck the way the TickerMode bug caused.
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pumpAndSettle();
    expect(opacities(), [0, 0, 1]);
    expect(ignoring(), [true, true, false]);

    // Back to tab 0 for good measure — every previously-active tab must
    // still be able to fade out correctly, not just the first switch.
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await tester.pumpAndSettle();
    expect(opacities(), [1, 0, 0]);
    expect(ignoring(), [false, true, true]);
  });
}
