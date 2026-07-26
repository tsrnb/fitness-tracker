import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import 'pressable_scale.dart';

const _fast = Duration(milliseconds: 180);
const _med = Duration(milliseconds: 260);
const _curve = Curves.easeOutCubic;

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
    _controller = AnimationController(vsync: this, duration: _med);
    _fade = CurvedAnimation(parent: _controller, curve: _curve);
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

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.background,
    this.borderColor,
    this.radius = T.rL,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: _fast,
      curve: _curve,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? T.surface,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.98, child: content);
  }
}

/// Card == Surface with the default surface look (used everywhere as `Card` in the React app).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Surface(
      padding: padding,
      background: T.surface,
      borderColor: borderColor ?? T.line,
      onTap: onTap,
      child: child,
    );
  }
}

enum HeroTone { hero, lav, paper }

class HeroCard extends StatelessWidget {
  final Widget child;
  final HeroTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const HeroCard({super.key, required this.child, this.tone = HeroTone.hero, this.padding = const EdgeInsets.all(18), this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = tone == HeroTone.lav ? T.lav : (tone == HeroTone.paper ? T.paper : T.hero);
    final ink = tone == HeroTone.lav ? T.lavInk : (tone == HeroTone.paper ? T.paperInk : Colors.white);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(T.rXL)),
      child: DefaultTextStyle(style: TextStyle(color: ink), child: IconTheme(data: IconThemeData(color: ink), child: child)),
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.97, child: content);
  }
}

class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const PaperCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(color: T.paper, borderRadius: BorderRadius.circular(T.rXL)),
      child: DefaultTextStyle(style: const TextStyle(color: T.paperInk), child: child),
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.97, child: content);
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
      duration: _fast,
      curve: _curve,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: border),
      child: AnimatedSwitcher(
        duration: _fast,
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: KeyedSubtree(key: ValueKey(_iconIdentity(icon)), child: icon),
      ),
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.9, child: content);
  }
}

class ChecklistPill extends StatelessWidget {
  final String label;
  final String? sub;
  final bool done;
  final VoidCallback? onTap;
  final HeroTone tone;
  const ChecklistPill({super.key, required this.label, this.sub, required this.done, this.onTap, this.tone = HeroTone.hero});

  @override
  Widget build(BuildContext context) {
    final bg = tone == HeroTone.lav ? const Color(0x1A1C1E3A) : const Color(0x29FFFFFF);
    final ink = tone == HeroTone.lav ? T.lavInk : Colors.white;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(T.pill)),
      child: Row(
        children: [
          AnimatedContainer(
            duration: _fast,
            curve: _curve,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? ink : Colors.transparent,
              border: done ? null : Border.all(color: ink.withValues(alpha: 0.7), width: 2),
            ),
            child: AnimatedSwitcher(
              duration: _fast,
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: done
                  ? Icon(Icons.check, size: 13, color: tone == HeroTone.lav ? T.lav : T.hero, key: const ValueKey('on'))
                  : const SizedBox.shrink(key: ValueKey('off')),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 14, height: 1.2), overflow: TextOverflow.ellipsis),
                if (sub != null) Text(sub!, style: TextStyle(color: ink.withValues(alpha: 0.8), fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return PressableScale(onTap: onTap, downScale: 0.96, child: content);
  }
}

class ActionPill extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;
  const ActionPill({super.key, required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: T.paperInk, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFF141416), shape: BoxShape.circle),
            child: icon ?? const Icon(Icons.chevron_right, size: 17, color: Colors.white),
          ),
        ],
      ),
    );
    return PressableScale(onTap: onTap, downScale: 0.95, child: content);
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

class PageHeader extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String? sub;
  const PageHeader({super.key, this.icon, required this.title, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (icon != null) ...[IconBubble(icon: icon!, size: 40, background: T.hero), const SizedBox(width: 12)],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: T.text)),
              if (sub != null) Padding(padding: EdgeInsets.only(top: 2), child: Text(sub!, style: TextStyle(fontSize: 13, color: T.muted))),
            ],
          ),
        ],
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

/// Rounded-full segmented control with a sliding highlight pill (equal-width
/// items only — the `scroll` variant has variable-width items so it instead
/// cross-fades each item's own background color).
class PillTabs extends StatelessWidget {
  final List<MapEntry<String, String>> options;
  final String value;
  final ValueChanged<String> onChange;
  final bool scroll;
  const PillTabs({super.key, required this.options, required this.value, required this.onChange, this.scroll = false});

  @override
  Widget build(BuildContext context) {
    if (scroll) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((o) {
              final active = value == o.key;
              return GestureDetector(
                onTap: () => onChange(o.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: _fast,
                  curve: _curve,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: active ? T.hero : Colors.transparent, borderRadius: BorderRadius.circular(T.pill)),
                  child: AnimatedDefaultTextStyle(
                    duration: _fast,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : T.muted),
                    child: Text(o.value, textAlign: TextAlign.center),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
    final index = options.indexWhere((o) => o.key == value).clamp(0, options.length - 1);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth - 8) / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: _med,
                curve: _curve,
                left: index * w,
                width: w,
                top: 0,
                bottom: 0,
                child: DecoratedBox(decoration: BoxDecoration(color: T.hero, borderRadius: BorderRadius.circular(T.pill))),
              ),
              Row(
                children: options.map((o) {
                  final active = value == o.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChange(o.key),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: AnimatedDefaultTextStyle(
                          duration: _fast,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : T.muted),
                          child: Text(o.value, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Progress ring that animates its sweep + the number counting up whenever
/// [value]/[goal] change, and fills in from zero on first mount.
class Ring extends StatefulWidget {
  final double value;
  final double goal;
  final double size;
  final String? label;
  final String unit;
  final Color? color;
  final bool onPaper;
  const Ring({super.key, required this.value, required this.goal, this.size = 132, this.label, this.unit = '', this.color, this.onPaper = false});

  @override
  State<Ring> createState() => _RingState();
}

class _RingState extends State<Ring> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _valueAnim;
  late Animation<double> _pctAnim;

  double get _pct => widget.goal > 0 ? (widget.value / widget.goal).clamp(0.0, 1.0) : 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _valueAnim = Tween<double>(begin: 0, end: widget.value).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _pctAnim = Tween<double>(begin: 0, end: _pct).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant Ring old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.goal != widget.goal) {
      final fromValue = _valueAnim.value;
      final fromPct = _pctAnim.value;
      _valueAnim = Tween<double>(begin: fromValue, end: widget.value).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _pctAnim = Tween<double>(begin: fromPct, end: _pct).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final track = widget.onPaper ? const Color(0x1A15151A) : T.surface2;
    final ink = widget.onPaper ? T.paperInk : T.text;
    final sub = widget.onPaper ? T.paperMuted : T.muted;
    final compact = size < 80;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pct = _pctAnim.value;
          final displayValue = _valueAnim.value.round();
          final done = widget.goal > 0 && widget.value / widget.goal >= 1;
          final stroke = done ? T.success : (widget.color ?? T.accent);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: Size(size, size), painter: _RingPainter(pct: pct, track: track, stroke: stroke)),
              Padding(
                padding: EdgeInsets.all(size * 0.16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: compact
                      ? Text('$displayValue/${widget.goal.round()}${widget.unit}', style: mono(fontSize: 15, fontWeight: FontWeight.w600, color: done ? T.success : ink))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$displayValue', style: mono(fontSize: size > 110 ? 26 : 22, fontWeight: FontWeight.w600, color: done ? T.success : ink)),
                            Text('/ ${widget.goal.round()}${widget.unit}', style: mono(fontSize: 11, color: sub)),
                            if (widget.label != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.label!, style: TextStyle(fontSize: 10, color: sub))),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color track;
  final Color stroke;
  _RingPainter({required this.pct, required this.track, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, r, trackPaint);
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * pct;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, sweep, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct || old.stroke != stroke || old.track != track;
}

class Stepper2 extends StatelessWidget {
  final num value;
  final ValueChanged<num> onChange;
  final num step;
  final num min;
  final String? suffix;
  const Stepper2({super.key, required this.value, required this.onChange, this.step = 1, this.min = 0, this.suffix});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback onTap) => PressableScale(
          onTap: onTap,
          downScale: 0.88,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: T.line), color: T.surface2),
            child: Icon(icon, size: 18, color: T.text),
          ),
        );
    final displayValue = value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(2);
    return Row(
      children: [
        btn(Icons.remove, () {
          final v = value - step;
          onChange(double.parse((v < min ? min : v).toStringAsFixed(2)));
        }),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: _fast,
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(displayValue, key: ValueKey(displayValue), style: mono(fontSize: 20, fontWeight: FontWeight.w600)),
              ),
              if (suffix != null) Text(suffix!, style: mono(fontSize: 11, color: T.muted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        btn(Icons.add, () => onChange(double.parse((value + step).toStringAsFixed(2)))),
      ],
    );
  }
}

const primaryBtnDecoration = BoxDecoration(color: T.accent, borderRadius: BorderRadius.all(Radius.circular(T.pill)));

class PrimaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double opacity;
  final EdgeInsetsGeometry padding;
  const PrimaryButton({super.key, required this.child, this.onTap, this.opacity = 1, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: _fast,
      curve: _curve,
      child: PressableScale(
        onTap: opacity < 1 ? null : onTap,
        downScale: 0.97,
        child: Container(
          padding: padding,
          decoration: primaryBtnDecoration,
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            child: IconTheme(data: const IconThemeData(color: Colors.white), child: child),
          ),
        ),
      ),
    );
  }
}

class OptBtn extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final Widget? icon;
  final String label;
  final String? sub;
  const OptBtn({super.key, required this.active, required this.onTap, this.icon, required this.label, this.sub});

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: _fast,
      curve: _curve,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: active ? T.accentDim : T.surface,
        border: Border.all(color: active ? T.hero : T.line),
        borderRadius: BorderRadius.circular(T.pill),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            IconBubble(icon: icon!, size: 38, background: active ? T.hero : T.surface2),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: T.text)),
                if (sub != null) Padding(padding: EdgeInsets.only(top: 2), child: Text(sub!, style: TextStyle(fontSize: 12, color: T.muted))),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: _fast,
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: active
                ? const IconBubble(key: ValueKey('active'), icon: Icon(Icons.check, size: 14, color: Colors.white, key: ValueKey('check')), size: 26, background: T.hero)
                : const SizedBox.shrink(key: ValueKey('inactive')),
          ),
        ],
      ),
    );
    return PressableScale(onTap: onTap, downScale: 0.98, child: content);
  }
}

class NumIn extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  final String? ph;
  final String? suffix;
  const NumIn({super.key, required this.value, required this.onChange, this.ph, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController.fromValue(TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length))),
              onChanged: onChange,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: mono(fontSize: 18, color: T.text),
              decoration: InputDecoration(hintText: ph, hintStyle: TextStyle(color: T.faint), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 13)),
            ),
          ),
          if (suffix != null) MonoText(suffix!, fontSize: 14, color: T.muted),
        ],
      ),
    );
  }
}

Future<R?> showAppSheet<R>(BuildContext context, Widget child) {
  return showModalBottomSheet<R>(
    context: context,
    backgroundColor: T.bg,
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
