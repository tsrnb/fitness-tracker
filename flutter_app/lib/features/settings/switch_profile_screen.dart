import 'dart:ui';
import 'package:flutter/material.dart';
import '../../shared/theme.dart';

const _outC1 = Color(0xFF7C86D9);
const _outC2 = Color(0xFF9AA3EA);
const _outC3 = Color(0xFF565FB0);
const _accent3 = Color(0xFFFFB16A);

/// Full-screen, one-shot moment shown while switching between profiles —
/// `AppController.switchUser` reloads the *entire* AppData (diet, history,
/// plan, everything) for another user with no loading state of its own, so
/// snapping instantly to new data read as a glitch more than a switch.
///
/// The outgoing avatar (violet) and incoming avatar (accent) close the
/// distance and meet at center with a warm flare, expanding rings, and a
/// scatter of drifting embers; the outgoing one recedes and fades while the
/// incoming one settles into the centered resting position — matched by a
/// color-tinted ambient glow breathing behind each. Runs for its full
/// duration (or until the real data load finishes, whichever is longer) so
/// it never dismisses mid-fetch.
class SwitchProfileScreen extends StatefulWidget {
  final String fromName;
  final String toName;
  final Future<void> Function() onSwitch;
  const SwitchProfileScreen({super.key, required this.fromName, required this.toName, required this.onSwitch});

  @override
  State<SwitchProfileScreen> createState() => _SwitchProfileScreenState();
}

class _SwitchProfileScreenState extends State<SwitchProfileScreen> with SingleTickerProviderStateMixin {
  late final bool _reduceMotion;
  late final AnimationController _c;
  bool _settled = false;

  // Keyframe stops/values transcribed 1:1 from the confirmed mockup
  // (switch-profile-v5 "Aurora"), just re-centered: the mockup's own idle
  // state sat off-center because it was parked at the animation's start
  // coordinate — here both avatars are anchored at the same center point
  // and animate as an offset *from* it, so idle/settled are always centered.
  static const _stops5 = [0.0, .44, .52, .62, 1.0];
  static const _outX = [0.0, -32.0, -38.0, -30.0, -74.0];
  static const _outScale = [1.0, 1.04, 0.9, 0.97, 0.62];
  static const _outOpStops = [0.0, .62, 1.0];
  static const _outOp = [1.0, 1.0, 0.0];

  static const _incX = [112.0, 32.0, 38.0, 30.0, 0.0];
  static const _incScale = [0.8, 1.04, 1.18, 1.04, 1.0];
  static const _incOpStops = [0.0, .26, 1.0];
  static const _incOp = [0.0, 1.0, 1.0];

  @override
  void initState() {
    super.initState();
    _reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: _reduceMotion ? 1 : 2100));
    _run();
  }

  Future<void> _run() async {
    final animFuture = _c.forward();
    await Future.wait([animFuture, widget.onSwitch()]);
    if (!mounted) return;
    setState(() => _settled = true);
    await Future.delayed(Duration(milliseconds: _reduceMotion ? 150 : 500));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _kf(double t, List<double> stops, List<double> values) {
    for (var i = 0; i < stops.length - 1; i++) {
      if (t <= stops[i + 1]) {
        final span = stops[i + 1] - stops[i];
        final localT = span == 0 ? 1.0 : ((t - stops[i]) / span).clamp(0.0, 1.0);
        return values[i] + (values[i + 1] - values[i]) * localT;
      }
    }
    return values.last;
  }

  Widget _avatarShell({required String initial, required List<Color> ring, required List<Color> fill}) {
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: ring)),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: fill)),
          child: Stack(alignment: Alignment.center, children: [
            Positioned(
              top: -8,
              left: -4,
              child: Container(
                width: 62,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0)]),
                ),
              ),
            ),
            Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 34)),
          ]),
        ),
      ),
    );
  }

  Widget _ring(double start, double end, Color color) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (t < start) return const SizedBox.shrink();
        final p = Curves.easeOut.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
        final opacity = (1 - p) * 0.95;
        if (opacity <= 0.01) return const SizedBox.shrink();
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.4 + p * 3.2,
            child: Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.5))),
          ),
        );
      },
    );
  }

  Widget _flare(double start, double end) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (t < start) return const SizedBox.shrink();
        final localT = ((t - start) / (end - start)).clamp(0.0, 1.0);
        double opacity, scale;
        if (localT <= 0.35) {
          final p = localT / 0.35;
          opacity = p;
          scale = 0.2 + p * 1.1;
        } else {
          final p = (localT - 0.35) / 0.65;
          opacity = 1 - p;
          scale = 1.3 + p * 0.9;
        }
        if (opacity <= 0.01) return const SizedBox.shrink();
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white, Color(0xB3FFD6AA), Colors.transparent], stops: [0, .35, .7]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mote(double start, Offset dir) {
    const span = 0.62;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (t < start) return const SizedBox.shrink();
        final localT = ((t - start) / span).clamp(0.0, 1.0);
        final opacity = localT <= 0.2 ? localT / 0.2 : 1 - ((localT - 0.2) / 0.8);
        if (opacity <= 0.01) return const SizedBox.shrink();
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dir.dx * localT, dir.dy * localT),
            child: Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: _accent3)),
          ),
        );
      },
    );
  }

  Offset _shake(double t) {
    const start = 0.424, end = 0.529;
    if (t < start || t > end) return Offset.zero;
    final localT = (t - start) / (end - start);
    if (localT < 0.3) return Offset.lerp(Offset.zero, const Offset(-1.5, 1), localT / 0.3)!;
    if (localT < 0.6) return Offset.lerp(const Offset(-1.5, 1), const Offset(1.5, -1), (localT - 0.3) / 0.3)!;
    return Offset.lerp(const Offset(1.5, -1), Offset.zero, (localT - 0.6) / 0.4)!;
  }

  @override
  Widget build(BuildContext context) {
    final fromInitial = widget.fromName.isNotEmpty ? widget.fromName[0].toUpperCase() : '?';
    final toInitial = widget.toName.isNotEmpty ? widget.toName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: _settled ? () => Navigator.of(context).maybePop() : null,
      child: Scaffold(
        backgroundColor: T.bg,
        body: Stack(
          children: [
            // Ambient color-matched glow, crossfading from the outgoing
            // profile's tone to the incoming one's over the whole switch.
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(children: [
                Positioned(
                  left: -110,
                  top: 140,
                  child: Opacity(
                    opacity: _reduceMotion ? 0 : (1 - _c.value) * 0.5,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: Container(width: 320, height: 320, decoration: const BoxDecoration(shape: BoxShape.circle, color: _outC1)),
                    ),
                  ),
                ),
                Positioned(
                  right: -120,
                  top: 210,
                  child: Opacity(
                    opacity: _reduceMotion ? 0.5 : _c.value * 0.5,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: Container(width: 340, height: 340, decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent)),
                    ),
                  ),
                ),
              ]),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(radius: 0.9, colors: [Colors.transparent, Color(0x8C000000)], stops: [0.4, 1]),
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SWITCHING PROFILE',
                    style: mono(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)).copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 34),
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final t = _reduceMotion ? 1.0 : _c.value;
                      final outX = _kf(t, _stops5, _outX);
                      final outScale = _kf(t, _stops5, _outScale);
                      final outOp = _kf(t, _outOpStops, _outOp);
                      final incX = _kf(t, _stops5, _incX);
                      final incScale = _kf(t, _stops5, _incScale);
                      final incOp = _kf(t, _incOpStops, _incOp);
                      final shake = _reduceMotion ? Offset.zero : _shake(t);

                      return Transform.translate(
                        offset: shake,
                        child: SizedBox(
                          width: 220,
                          height: 110,
                          child: Stack(alignment: Alignment.center, children: [
                            if (!_reduceMotion) ...[
                              _ring(.43, .787, Colors.white),
                              _ring(.457, .909, _accent3.withValues(alpha: 0.7)),
                              _flare(.43, .668),
                              _mote(.452, const Offset(-34, -30)),
                              _mote(.471, const Offset(30, -36)),
                              _mote(.490, const Offset(-20, 22)),
                              _mote(.510, const Offset(26, 20)),
                              _mote(.476, const Offset(4, -40)),
                            ],
                            Opacity(
                              opacity: outOp,
                              child: Transform.translate(
                                offset: Offset(outX, 0),
                                child: Transform.scale(
                                  scale: outScale,
                                  child: _avatarShell(initial: fromInitial, ring: const [_outC1, _outC2, _outC1], fill: const [_outC1, _outC3]),
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: incOp,
                              child: Transform.translate(
                                offset: Offset(incX, 0),
                                child: Transform.scale(
                                  scale: incScale,
                                  child: _avatarShell(initial: toInitial, ring: const [T.accent, _accent3, Color(0xFFFF7A52), T.accent], fill: const [_accent3, T.accent]),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _settled ? widget.toName : 'Switching to ${widget.toName}…',
                      key: ValueKey(_settled),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(_settled ? 'Ready' : 'Loading their plan, diet log, and progress…', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
