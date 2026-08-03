import 'package:flutter/material.dart';

/// The app's AI-brand palette — deliberately distinct from the single
/// accent-orange used everywhere else, so anything wrapped in this gradient
/// reads as "the assistant did this."
const aiColor1 = Color(0xFF7C6FFF);
const aiColor2 = Color(0xFF4FA8FF);
const aiColor3 = Color(0xFFFF6FD8);
const aiColor4 = Color(0xFFFFB156);
const _aiColors = [aiColor1, aiColor2, aiColor3, aiColor4, aiColor1];

class _SlidingGradientTransform extends GradientTransform {
  final double slide;
  const _SlidingGradientTransform(this.slide);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * slide, 0, 0);
}

/// Rebuilds [builder] every frame with a slowly sliding copy of the AI
/// gradient (mirrors the CSS `background-position` shimmer used in the
/// design mockups) — pass the same [Gradient] to a border, an icon fill,
/// and a `ShaderMask` text so they all move in sync.
class AiGradient extends StatefulWidget {
  final Widget Function(BuildContext context, Gradient gradient) builder;
  const AiGradient({super.key, required this.builder});

  @override
  State<AiGradient> createState() => _AiGradientState();
}

class _AiGradientState extends State<AiGradient> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(
        context,
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _aiColors,
          tileMode: TileMode.mirror,
          transform: _SlidingGradientTransform(_c.value),
        ),
      ),
    );
  }
}

/// A slow, low-alpha sliding wash of the AI palette over [base] — for card
/// and header *backgrounds*, where the accent should feel ambient rather
/// than loud. Runs on its own (slower) clock than [AiGradient], since a
/// background reads as "alive" at a much gentler pace than a border.
class AiGradientWash extends StatefulWidget {
  final Color base;
  final double alpha;
  final BorderRadius? borderRadius;
  final Widget child;
  const AiGradientWash({
    super.key,
    required this.base,
    required this.child,
    this.alpha = 0.16,
    this.borderRadius,
  });

  @override
  State<AiGradientWash> createState() => _AiGradientWashState();
}

class _AiGradientWashState extends State<AiGradientWash> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.base,
              Color.alphaBlend(aiColor1.withValues(alpha: widget.alpha), widget.base),
              Color.alphaBlend(aiColor3.withValues(alpha: widget.alpha * 0.8), widget.base),
              widget.base,
            ],
            stops: const [0.0, 0.38, 0.62, 1.0],
            tileMode: TileMode.mirror,
            transform: _SlidingGradientTransform(_c.value),
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
