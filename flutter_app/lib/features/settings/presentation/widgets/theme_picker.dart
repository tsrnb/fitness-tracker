import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';

/// Fixed swatch colors for the two previews — deliberately *not* [T.bg] /
/// [T.surface] / etc., which track whichever mode is live right now. A
/// picker that's supposed to show "what light looks like" while the app is
/// currently in dark mode needs its own literal copy of both palettes,
/// independent of [AppTheme.mode].
class _Swatch {
  final Color bg, surface, line, text, muted;
  const _Swatch({required this.bg, required this.surface, required this.line, required this.text, required this.muted});
}

const _darkSwatch = _Swatch(
  bg: Color(0xFF0C0C0D),
  surface: Color(0xFF161618),
  line: Color(0xFF2A2A2E),
  text: Color(0xFFEDEAE3),
  muted: Color(0xFF8B8B92),
);
const _lightSwatch = _Swatch(
  bg: Color(0xFFFAFAF8),
  surface: Color(0xFFFFFFFF),
  line: Color(0xFFE2E0DA),
  text: Color(0xFF1A1A1D),
  muted: Color(0xFF6B6B70),
);

/// Two tappable preview cards — each a tiny skeletonized rendition of the
/// app's own chrome (a header bar + a card with a couple of text lines) in
/// that mode's real colors, not just a "Dark"/"Light" label. Picking a
/// theme should look like picking a theme, the way iOS/macOS/Slack's own
/// appearance pickers do it — a plain pill toggle answers "which word is
/// selected" but not "what will this actually look like".
class ThemePicker extends StatelessWidget {
  final String value; // 'dark' | 'light'
  final ValueChanged<String> onChange;
  const ThemePicker({super.key, required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _ThemeOption(mode: 'dark', label: 'Dark', swatch: _darkSwatch, selected: value == 'dark', onTap: () => onChange('dark'))),
      const SizedBox(width: 12),
      Expanded(child: _ThemeOption(mode: 'light', label: 'Light', swatch: _lightSwatch, selected: value == 'light', onTap: () => onChange('light'))),
    ]);
  }
}

class _ThemeOption extends StatelessWidget {
  final String mode;
  final String label;
  final _Swatch swatch;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.mode, required this.label, required this.swatch, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? T.hero : T.line, width: selected ? 2 : 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(children: [
                _SkeletonPreview(swatch: swatch),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  top: 8,
                  right: selected ? 8 : -20,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: T.hero),
                      child: const Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 9),
          Row(children: [
            Icon(mode == 'dark' ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 15, color: selected ? T.text : T.muted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? T.text : T.muted)),
          ]),
        ],
      ),
    );
  }
}

/// The tiny "app screenshot" itself — a header bar and one card with a
/// couple of skeleton text lines and two status dots, all drawn from
/// [swatch] so it reads unmistakably as "this is what the app looks like",
/// not an abstract color chip.
class _SkeletonPreview extends StatelessWidget {
  final _Swatch swatch;
  const _SkeletonPreview({required this.swatch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      color: swatch.bg,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 6, decoration: BoxDecoration(color: swatch.text, borderRadius: BorderRadius.circular(3))),
          const Spacer(),
          Container(width: 12, height: 12, decoration: const BoxDecoration(color: T.hero, shape: BoxShape.circle)),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: swatch.surface, border: Border.all(color: swatch.line), borderRadius: BorderRadius.circular(9)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 44, height: 5, decoration: BoxDecoration(color: swatch.text, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 6),
              Container(width: 64, height: 4, decoration: BoxDecoration(color: swatch.muted, borderRadius: BorderRadius.circular(3))),
              const Spacer(),
              Row(children: [
                Container(width: 5, height: 5, decoration: const BoxDecoration(color: T.hero, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Container(width: 5, height: 5, decoration: BoxDecoration(color: swatch.muted, shape: BoxShape.circle)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
