/// Barrel export for the app's small reusable UI building blocks — split
/// across `atoms/` by kind (cards, pills, rings, buttons, inputs, layout
/// chrome) since this one file had grown to ~20 unrelated widgets. Existing
/// `import '.../atoms.dart'` call sites keep working unchanged.
export 'atoms/cards.dart';
export 'atoms/pills.dart';
export 'atoms/rings.dart';
export 'atoms/buttons.dart';
export 'atoms/inputs.dart';
export 'atoms/layout.dart';
