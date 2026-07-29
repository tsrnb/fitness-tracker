import 'package:flutter/material.dart';
import '../../shared/theme.dart';

/// Full-screen, one-shot moment shown while switching between profiles —
/// `AppController.switchUser` reloads the *entire* AppData (diet, history,
/// plan, everything) for another user with no loading state of its own, so
/// snapping instantly to new data read as a glitch more than a switch.
///
/// Deliberately quiet: after trying a fist-bump handoff and a heavily
/// art-directed "Aurora" version, both got rejected in favor of something
/// simpler — the incoming profile's avatar fades in once, a thin ring spins
/// around it while the real data loads, then the ring fades out and the
/// text resolves to "Ready". No second avatar, no particles, no flash.
class SwitchProfileScreen extends StatefulWidget {
  final String toName;
  final Future<void> Function() onSwitch;
  const SwitchProfileScreen({super.key, required this.toName, required this.onSwitch});

  @override
  State<SwitchProfileScreen> createState() => _SwitchProfileScreenState();
}

class _SwitchProfileScreenState extends State<SwitchProfileScreen> with SingleTickerProviderStateMixin {
  late final bool _reduceMotion;
  late final AnimationController _entrance;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _entrance = AnimationController(vsync: this, duration: Duration(milliseconds: _reduceMotion ? 1 : 320))..forward();
    _run();
  }

  Future<void> _run() async {
    final started = DateTime.now();
    await widget.onSwitch();
    if (!mounted) return;
    // A load that resolves instantly would otherwise flash the ring and
    // vanish — a small minimum hold keeps it legible without making a fast
    // switch feel artificially slow.
    final elapsed = DateTime.now().difference(started);
    final minDisplay = Duration(milliseconds: _reduceMotion ? 0 : 500);
    if (elapsed < minDisplay) await Future.delayed(minDisplay - elapsed);
    if (!mounted) return;
    setState(() => _settled = true);
    await Future.delayed(Duration(milliseconds: _reduceMotion ? 150 : 450));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.toName.isNotEmpty ? widget.toName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: _settled ? () => Navigator.of(context).maybePop() : null,
      child: Scaffold(
        backgroundColor: T.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(alignment: Alignment.center, children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _settled ? 0 : 1,
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: T.accent, backgroundColor: T.surface2),
                    ),
                  ),
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
                    child: FadeTransition(
                      opacity: _entrance,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
                        alignment: Alignment.center,
                        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 30)),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 26),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _settled ? widget.toName : 'Switching to ${widget.toName}…',
                  key: ValueKey(_settled),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.text),
                ),
              ),
              const SizedBox(height: 5),
              Text(_settled ? 'Ready' : 'Loading their plan, diet log, and progress…', style: TextStyle(fontSize: 12.5, color: T.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
