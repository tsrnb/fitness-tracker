import 'package:flutter/material.dart';

/// Wraps a child with tactile scale-down-on-press feedback, used everywhere
/// something is tappable (cards, buttons, pills, icon bubbles).
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double downScale;

  const PressableScale({super.key, required this.child, this.onTap, this.downScale = 0.96});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.downScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
