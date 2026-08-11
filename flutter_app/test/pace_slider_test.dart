// Regression test for the pace slider not rendering (a Positioned widget
// one level removed from its Stack via a LayoutBuilder, which trips
// Flutter's parent-data check and silently fails to paint). Pumps every
// shape the widget can take — no ceiling, ceiling near either edge, ceiling
// mid-track — and asserts no exception and a visible Slider/thumb.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuttracker/features/settings/presentation/widgets/pace_slider.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required double value, double? ceiling}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: PaceSlider(min: 100, max: 1000, value: value, ceiling: ceiling, onChanged: (_) {}),
        ),
      ),
    ));
  }

  testWidgets('renders with no ceiling (muscle-gain case)', (tester) async {
    await pump(tester, value: 300, ceiling: null);
    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('renders with a mid-track ceiling (typical fat-loss case)', (tester) async {
    await pump(tester, value: 550, ceiling: 590);
    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('renders with the ceiling at the very start of the range', (tester) async {
    await pump(tester, value: 500, ceiling: 100);
    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('renders with the ceiling at (or past) the very end of the range', (tester) async {
    await pump(tester, value: 500, ceiling: 1000);
    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('renders with a negative ceiling (e.g. an incomplete profile)', (tester) async {
    await pump(tester, value: 500, ceiling: -1495);
    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsOneWidget);
  });
}
