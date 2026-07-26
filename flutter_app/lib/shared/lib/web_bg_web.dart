import 'package:web/web.dart' as web;

/// Keeps the actual HTML page (`<html>`/`<body>`) background in sync with
/// the app's current theme — without this, anything not covered by the
/// Flutter canvas (safe-area insets, the moment before first paint) shows
/// the browser's own default background instead of the app's.
void setWebPageBackground(String hexColor) {
  (web.document.documentElement as web.HTMLElement?)?.style.backgroundColor = hexColor;
  web.document.body?.style.backgroundColor = hexColor;
}
