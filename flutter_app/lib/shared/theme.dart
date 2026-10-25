import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lib/web_bg.dart';

/// Holds the current light/dark mode as a global, observable flag. `T.*`
/// colors below read this at build time; toggling it and rebuilding the
/// tree (see `main.dart`) is enough to re-theme every screen.
class AppTheme {
  static final mode = ValueNotifier<Brightness>(Brightness.dark);
  static bool get isDark => mode.value == Brightness.dark;

  static void set(Brightness b) {
    mode.value = b;
    // On web, the actual HTML page background (outside/behind the Flutter
    // canvas) is a separate thing from anything Flutter itself paints —
    // keep it in sync so it's never a mismatched or default-white sliver.
    setWebPageBackground(b == Brightness.dark ? '#0C0C0D' : '#FAFAF8');
  }
}

/// Design tokens ported 1:1 from the React app's shared/theme.js, now
/// mode-aware: each color is a getter that swaps between a dark and light
/// value based on [AppTheme.isDark].
class T {
  static Color get bg => AppTheme.isDark ? const Color(0xFF0C0C0D) : const Color(0xFFFAFAF8);
  static Color get surface => AppTheme.isDark ? const Color(0xFF161618) : const Color(0xFFFFFFFF);
  static Color get surface2 => AppTheme.isDark ? const Color(0xFF1E1E21) : const Color(0xFFF1F0EC);
  static Color get line => AppTheme.isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE2E0DA);
  static Color get text => AppTheme.isDark ? const Color(0xFFEDEAE3) : const Color(0xFF1A1A1D);
  static Color get muted => AppTheme.isDark ? const Color(0xFF8B8B92) : const Color(0xFF6B6B70);
  static Color get faint => AppTheme.isDark ? const Color(0xFF5A5A60) : const Color(0xFF9B9B9F);

  static const accent = Color(0xFFFF5B33);
  static const accentSoft = Color(0x6BFF5B33); // 0.42 alpha
  static const accentDim = Color(0x24FF5B33); // 0.14 alpha
  static const accentInk = Color(0xFF2B0D02);

  static const hero = Color(0xFFFF5B33);
  static const heroSoft = Color(0x29FF5B33); // 0.16 alpha

  // Fixed, NOT mode-aware — [lav] is always the same pale pastel because it's
  // always paired with [lavInk] (a fixed dark ink) as a matched fill/text
  // pair for "lav-toned" filled surfaces (HeroCard's lav tone, the
  // export/import badge circle in DataIllustration). Deepening [lav] for
  // light mode would leave dark ink sitting on a now-darker fill — the
  // opposite of what those surfaces need. Anywhere lav is used *without*
  // lavInk — as a plain foreground accent on the app's own background, e.g.
  // a macro-bar fill or a badge icon on a translucent tint — use
  // [lavAccent] instead, which is exactly that: mode-aware.
  static const lav = Color(0xFFAEB8F2);
  static const lavInk = Color(0xFF1C1E3A);

  /// The foreground/accent version of [lav] — same pale value in dark mode
  /// (nothing changes there), but a deeper indigo in light mode so it reads
  /// as text/icon color against a light background instead of nearly
  /// disappearing. See the comment on [lav] for why these are two tokens.
  static Color get lavAccent => AppTheme.isDark ? const Color(0xFFAEB8F2) : const Color(0xFF5A62C4);

  static const paper = Color(0xFFF4F1EC);
  static const paperInk = Color(0xFF15151A);
  static const paperMuted = Color(0xFF77757A);

  // success/danger/blue have no fixed-surface pairing like lav does — they're
  // only ever used as a foreground accent (text, icon, bar/ring fill, chip
  // color) directly on T.bg/T.surface. Tuned soft and desaturated for
  // legibility floating on near-black; that same value on white read as
  // washed-out and low-contrast (the daily-log deficit chip and protein
  // status text were the clearest cases), so each gets a deeper, more
  // saturated light-mode value instead of just inheriting the dark one.
  static Color get success => AppTheme.isDark ? const Color(0xFF7FCB86) : const Color(0xFF3F9E55);
  static Color get danger => AppTheme.isDark ? const Color(0xFFE06C5A) : const Color(0xFFC1503E);
  static Color get muscleBase => AppTheme.isDark ? const Color(0xFF34343B) : const Color(0xFFDCDBD6);
  static Color get blue => AppTheme.isDark ? const Color(0xFF6FA8DC) : const Color(0xFF3A74A8);

  static const rM = 16.0;
  static const rL = 22.0;
  static const rXL = 30.0;
  static const pill = 999.0;
}

const monoFont = 'JetBrains Mono';

// GoogleFonts.*() does a font lookup on every call, and mono()/Type.* are
// called hundreds of times per frame, so each distinct style is built once.
final _styleCache = <Object, TextStyle>{};

TextStyle mono({double fontSize = 14, FontWeight? fontWeight, Color? color}) {
  return _styleCache.putIfAbsent(
    ('mono', fontSize, fontWeight, color),
    () => GoogleFonts.jetBrainsMono(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    ),
  );
}

TextStyle _manrope(String key, double size, FontWeight weight, double letterSpacing, double height, Color color) {
  return _styleCache.putIfAbsent(
    (key, color),
    () => GoogleFonts.manrope(fontSize: size, fontWeight: weight, letterSpacing: letterSpacing, height: height, color: color),
  );
}

/// Deliberate type scale (Manrope), so headings/body/captions read as one
/// considered system instead of ad-hoc `fontSize:`/`fontWeight:` pairs
/// scattered per screen. Every size step also carries a matched
/// letter-spacing and line-height — tighter tracking as size goes up, looser
/// leading as size goes down — which is most of what separates "designed"
/// type from "default" type at the same sizes.
class Type {
  /// Big hero numbers (e.g. onboarding summary calorie figure).
  static TextStyle get display => _manrope('display', 34, FontWeight.w800, -0.6, 1.05, T.text);

  /// Screen/section titles (onboarding step titles, Settings page titles).
  static TextStyle get h1 => _manrope('h1', 25, FontWeight.w700, -0.4, 1.15, T.text);

  /// Card/subsection headers.
  static TextStyle get h2 => _manrope('h2', 19, FontWeight.w700, -0.2, 1.2, T.text);

  /// In-card emphasis (row titles, list item names).
  static TextStyle get h3 => _manrope('h3', 15, FontWeight.w700, -0.1, 1.3, T.text);

  /// Default paragraph/body copy.
  static TextStyle get body => _manrope('body', 14, FontWeight.w500, 0, 1.45, T.text);

  /// Secondary/supporting copy under a title.
  static TextStyle get caption => _manrope('caption', 12.5, FontWeight.w500, 0, 1.4, T.muted);

  /// A serif display voice, used deliberately in one place — the 14-Day
  /// Calibration's end-of-window finding, where the AI's read *is* the
  /// screen and should carry the weight of a written conclusion rather than
  /// another card heading. The app is otherwise Manrope + JetBrains Mono;
  /// this is the one considered exception.
  static TextStyle get finding => GoogleFonts.newsreader(fontSize: 25, fontWeight: FontWeight.w500, height: 1.24, letterSpacing: 0, color: T.text);
}

ThemeData buildAppTheme() {
  final dark = AppTheme.isDark;
  final brightness = dark ? Brightness.dark : Brightness.light;
  final textTheme = GoogleFonts.manropeTextTheme().apply(bodyColor: T.text, displayColor: T.text);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: T.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: T.accent,
      brightness: brightness,
      surface: T.bg,
    ),
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}

/// Cycling color-per-weekday palette used to distinguish day tiles in both
/// the weekly Plan calendar and the Training Plan chooser's day rows. Each
/// entry is used as a plain foreground accent (chip text/dot on a
/// `color.withValues(alpha: ...)` tint of itself) — [T.lavAccent], not
/// [T.lav], for the same legibility reason as everywhere else that pairs a
/// semantic color with its own translucent tint.
List<Color> get dayPalette => [T.hero, T.blue, T.success, T.lavAccent, T.danger, const Color(0xFFCBA858)];
