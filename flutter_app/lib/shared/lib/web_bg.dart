/// Syncs the actual HTML page background to the app's theme on web; a no-op
/// everywhere else. See `web_bg_web.dart`/`web_bg_stub.dart`.
export 'web_bg_stub.dart' if (dart.library.html) 'web_bg_web.dart';
