import 'package:flutter/material.dart';
import '../../theme.dart';
import '../pressable_scale.dart';
import 'motion.dart';

/// Fades + slides one list item in, delayed by [index] steps — wrap each
/// item of a list with this (passing its position) for a lightweight
/// staggered-entrance feel with no external animation package. Give it a
/// `key` that changes when the list's order/contents change (e.g. a filter
/// switch) if the entrance should replay; an unkeyed/stably-keyed instance
/// only plays once, on first mount.
class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggerIn({super.key, required this.index, required this.child});

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: medAnim);
    _fade = CurvedAnimation(parent: _controller, curve: easeCurve);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(_fade);
    // Capped so long lists don't take forever to finish revealing.
    final delay = Duration(milliseconds: 32 * widget.index.clamp(0, 12));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
  }
}

/// A stable identity for the common icon-bearing widgets, so [IconBubble]'s
/// cross-fade only fires when the icon *content* actually changes, not
/// merely because the caller rebuilt a new (non-const) `Icon(...)` instance
/// with the same glyph — the default `Object.hashCode` used before this is
/// identity-based, so it changed on every rebuild and re-triggered the
/// fade/scale transition on any unrelated state change, reading as a flicker.
Object _iconIdentity(Widget icon) {
  if (icon is Icon) return Object.hash(icon.icon?.codePoint, icon.color, icon.size);
  if (icon is ImageIcon) return Object.hash(icon.image, icon.color, icon.size);
  return icon.key ?? icon.runtimeType;
}

class IconBubble extends StatelessWidget {
  final Widget icon;
  final double size;
  final Color background;
  final VoidCallback? onTap;
  final BoxBorder? border;
  const IconBubble({super.key, required this.icon, this.size = 44, this.background = T.accentDim, this.onTap, this.border});

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: fastAnim,
      curve: easeCurve,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: border),
      child: AnimatedSwitcher(
        duration: fastAnim,
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: KeyedSubtree(key: ValueKey(_iconIdentity(icon)), child: icon),
      ),
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.9, child: content);
  }
}

class MonoText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  const MonoText(this.text, {super.key, this.fontSize = 14, this.fontWeight, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: mono(fontSize: fontSize, fontWeight: fontWeight, color: color));
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry margin;
  const Eyebrow(this.text, {super.key, this.margin = const EdgeInsets.only(bottom: 8)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Text(
        text.toUpperCase(),
        style: mono(fontSize: 11, color: T.faint).copyWith(letterSpacing: 1.5),
      ),
    );
  }
}

/// Shared header + scroll body chrome for any full-page screen (Settings and
/// its sub-pages, Your Plan, ...) so they all read as one consistent part of
/// the app rather than a collection of ad-hoc screens.
Widget pageScaffold({
  required BuildContext context,
  required String title,
  required VoidCallback onBack,
  required Widget child,
  Widget? trailing,
}) {
  return Scaffold(
    backgroundColor: T.bg,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                IconBubble(icon: Icon(Icons.arrow_back, size: 18, color: T.muted), size: 36, background: T.surface, border: Border.all(color: T.line), onTap: onBack),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: Type.h1)),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<R?> showAppSheet<R>(BuildContext context, Widget child) {
  return showModalBottomSheet<R>(
    context: context,
    backgroundColor: T.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXL))),
    builder: (ctx) {
      // Read live from `ctx` (the sheet's own context) instead of a value
      // captured once from the caller's context before the sheet opened.
      // On Flutter web + iOS Safari, opening the on-screen keyboard shrinks
      // the browser viewport itself (MediaQuery.size) rather than growing
      // viewInsets.bottom — a stale maxHeight computed before that resize
      // no longer fits the actual (now shorter) viewport, so the sheet
      // overflows upward past the top of the screen with its buttons
      // pushed out of reach. Reading it here rebuilds it on every resize.
      final mq = MediaQuery.of(ctx);
      final maxHeight = mq.size.height - mq.padding.top - 24;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          key: const ValueKey('app-sheet-content'),
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );
    },
  );
}
