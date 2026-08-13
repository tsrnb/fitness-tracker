import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../../../shared/theme.dart';

/// The deficit/surplus slider for Settings → Goals — a plain [Slider] laid
/// over a custom-drawn track so the full Gentle→Aggressive gradient (green
/// to danger-red) is always visible, with the "below your safety minimum"
/// zone past [ceiling] shown as a translucent scrim *over* that same
/// gradient — never a flat color replacing it — plus a marker line at the
/// boundary. Dragging into that zone is never blocked: the marker is a
/// warning, not a limit, and the requested pace always applies exactly as
/// chosen. The native track is made fully transparent; only the thumb and
/// drag/keyboard behavior are kept.
///
/// The marker/scrim use flex ratios (`Expanded`) and `Positioned.fill`
/// inside a small inner `Stack` scoped to the track's own box — no
/// `LayoutBuilder`-computed pixel offsets, deliberately: an earlier version
/// used one to place the marker, which is what caused it not to render at
/// all for fat loss (a `Positioned` one widget removed from its `Stack`,
/// tripping Flutter's parent-data check). This avoids that whole class of bug.
class PaceSlider extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  /// The value past which the calorie goal drops below the safety floor —
  /// the segment from here to [max] gets a translucent scrim over the
  /// gradient plus a marker line. Null (or >= max) means there's nothing to
  /// warn about on this range (e.g. muscle-gain surplus, which has no floor
  /// concept) — no scrim, just the plain gradient.
  final double? ceiling;
  final ValueChanged<double> onChanged;

  const PaceSlider({super.key, required this.min, required this.max, required this.value, required this.ceiling, required this.onChanged});

  @override
  State<PaceSlider> createState() => _PaceSliderState();
}

class _PaceSliderState extends State<PaceSlider> {
  // Tracks which side of the safety-floor marker the thumb was on last, so
  // a buzz only fires the instant it crosses — not on every pixel dragged
  // while already past it.
  late bool _pastCeiling = widget.ceiling != null && widget.value > widget.ceiling!;

  void _handleChanged(double v) {
    final pastCeiling = widget.ceiling != null && v > widget.ceiling!;
    if (pastCeiling != _pastCeiling) {
      // Heavier buzz crossing *into* the unsafe zone (a warning) than
      // coming back out of it (just an acknowledgement).
      HapticFeedback.mediumImpact();
      _pastCeiling = pastCeiling;
    }
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.min, max = widget.max, value = widget.value, ceiling = widget.ceiling;
    const inset = 14.0; // approx. default thumb touch radius, so the drawn track lines up with where the thumb actually travels
    final ceilingFrac = (ceiling == null || ceiling >= max) ? null : ((ceiling - min) / (max - min)).clamp(0.0, 1.0);

    // Full green→accent→danger gradient across the whole track, always —
    // that's the Gentle/Moderate/Aggressive read and it should stay visible
    // everywhere, ceiling or not. Past the safety-floor ceiling gets a
    // translucent scrim over that same gradient (not a flat grey replacing
    // it), so the color never disappears — just fades under a warning tint.
    // Marker + scrim are Positioned.fill inside their own inner Stack,
    // matched 1:1 to the gradient's box, so everything shares one geometry
    // instead of separate absolutely-positioned siblings.
    final leftFlex = ceilingFrac == null ? null : (ceilingFrac * 1000).round().clamp(1, 998);
    final rightFlex = leftFlex == null ? null : (1000 - leftFlex).clamp(1, 998);

    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: inset,
            right: inset,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [T.success, T.accent, T.danger]))),
                    ),
                    if (leftFlex != null && rightFlex != null)
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(flex: leftFlex, child: const SizedBox()),
                            Container(width: 2, color: T.text),
                            Expanded(flex: rightFlex, child: DecoratedBox(decoration: BoxDecoration(color: T.surface.withValues(alpha: 0.6)))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              // T.text (not a fixed white) so the thumb has real contrast in
              // both themes — a plain white thumb was nearly invisible
              // sitting on the near-white card surface in light mode.
              thumbColor: T.text,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 3),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(min: min, max: max, value: value.clamp(min, max), onChanged: _handleChanged),
          ),
        ],
      ),
    );
  }
}
