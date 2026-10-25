/// "Continue with Google". On web Google requires its own rendered button to
/// hand back an ID token; everywhere else we draw our own pill. Both call
/// [onToken] with the Google ID token the backend verifies.
export 'google_button_io.dart' if (dart.library.html) 'google_button_web.dart';
