import 'package:flutter/material.dart';

/// Like [IndexedStack] (all children stay mounted, so tab state survives
/// switching) but cross-fades + gently scales the incoming child instead of
/// snapping instantly.
class AnimatedIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const AnimatedIndexedStack({super.key, required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < children.length; i++)
          Positioned.fill(
            child: IgnorePointer(
              // Only ever block taps on tabs that are NOT the active one.
              ignoring: i != index,
              // The opacity/scale transition itself must keep ticking even
              // while inactive so it can finish fading OUT — only the tab's
              // own inner content (Rings, timers, etc.) gets its tickers
              // paused, and only once it's actually offscreen.
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: AnimatedScale(
                  scale: i == index ? 1 : 0.98,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: TickerMode(enabled: i == index, child: children[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
