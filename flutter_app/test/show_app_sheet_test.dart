import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/shared/widgets/atoms.dart';

void main() {
  testWidgets('a tall sheet never overlaps the top safe area (status bar / notch)', (tester) async {
    const topInset = 47.0; // e.g. iPhone notch/Dynamic Island height
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: topInset);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAppSheet(
                  context,
                  // Deliberately much taller than the viewport, like the
                  // real Settings sheet (many fields + profile list).
                  Column(children: List.generate(60, (i) => SizedBox(height: 40, child: Text('field $i')))),
                ),
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey('app-sheet-content')));
    expect(
      rect.top,
      greaterThanOrEqualTo(topInset),
      reason: 'sheet top edge must stay below the status bar / notch, however tall its content is',
    );
  });
}
