/// `sqflite` (used for native persistence) has no web implementation, so the
/// actual `Backend`/`UserRow`/`FoodRow` types live in two platform-specific
/// files with an identical public API — this file just picks the right one
/// at compile time so every caller can keep importing `storage.dart` without
/// caring which backend is active.
export 'storage_io.dart' if (dart.library.html) 'storage_web.dart';
