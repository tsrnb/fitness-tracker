import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/root_screen.dart';
import 'shared/theme.dart';

void main() {
  runApp(const ProviderScope(child: CutTrackerApp()));
}

class CutTrackerApp extends StatelessWidget {
  const CutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Brightness>(
      valueListenable: AppTheme.mode,
      builder: (context, _, __) => MaterialApp(
        title: 'CutTracker',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const RootScreen(),
      ),
    );
  }
}
