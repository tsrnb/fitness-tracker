// Basic smoke test — `flutter create` regenerates this file with generic
// counter-app boilerplate that doesn't match this project; keep it minimal
// but real instead.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cuttracker/main.dart';

void main() {
  // `flutter test` runs on the Dart VM (not a real device), so sqflite needs
  // an FFI-backed factory instead of its normal platform-channel one.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('app boots without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CutTrackerApp()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
