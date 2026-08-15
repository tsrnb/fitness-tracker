import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../data/weight_insight_service.dart';
import '../domain/kg_progress.dart';
import '../../nutrition/domain/ai_food_item.dart' show AiConfigException, AiParseException;
import 'widgets/kg_day_detail_sheet.dart';

/// "76.4" without a pointless trailing ".0" when the weight happens to
/// round to a whole number.
String _fmtKg(double kg) {
  final rounded = (kg * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.toStringAsFixed(0) : rounded.toStringAsFixed(1);
}

/// A gap under 0.1kg reads as "0.0" at one decimal, which looks like a
/// rounding bug right when it matters most (the "so close" moment) — two
/// decimals only kick in there.
String _fmtGapKg(double gap) => gap < 0.1 ? gap.toStringAsFixed(2) : gap.toStringAsFixed(1);

/// Full-screen home for the food-log-driven weight-loss tracker — opened
/// from the compact teaser card on Progress → Weight (see [nextKgTeaserCard]
/// in `progress_screen.dart`). Everything here reads from [KgProgress]/
/// [KgWindow] (`domain/kg_progress.dart`); this file is purely presentation.
class NextKgScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const NextKgScreen({super.key, required this.app, required this.controller});

  @override
  State<NextKgScreen> createState() => _NextKgScreenState();
}

class _NextKgScreenState extends State<NextKgScreen> {
  late final bool _justReached;

  num get _tdee => (widget.app.data.plan?['tdee'] as num?) ?? (widget.app.data.settings['calorieGoal'] as num?) ?? 2000;
  double? get _fallbackBaseline => (widget.app.data.settings['currentWeight'] as num?)?.toDouble();

  KgProgress _computeProgress() => computeKgProgress(
        diet: widget.app.data.diet,
        activity: widget.app.data.activity,
        tdee: _tdee,
        weightLog: widget.app.data.weight,
        fallbackBaseline: _fallbackBaseline,
        today: todayStr(widget.app.data.settings),
      );

  @override
  void initState() {
    super.initState();
    final progress = _computeProgress();
    final lastSeen = (widget.app.data.settings['kgMilestonesSeen'] as num?)?.toInt() ?? 0;
    // Captured once at open — the banner (built from this) stays put for the
    // rest of this visit even though the "seen" count below updates
    // immediately, so it doesn't vanish mid-read if something else on the
    // screen triggers a rebuild.
    _justReached = progress.reached.length > lastSeen;
    // Guarded on a loaded active user — `controller`'s own state can
    // briefly disagree with the `app` snapshot this screen was pushed with
    // (mid profile-switch), and patchSettings reaches for `state.user!.id`.
    // Skipping the persist in that edge case just means the banner might
    // show once more than strictly necessary, which is harmless.
    if (progress.reached.length != lastSeen && widget.controller.current.user != null) {
      widget.controller.patchSettings('kgMilestonesSeen', progress.reached.length);
    }
  }

  void _openDay(KgDayBar bar, int milestoneNumber) {
    final detail = computeKgDayDetail(widget.app.data.diet, widget.app.data.activity, bar.date, _tdee);
    showAppSheet(context, KgDayDetailSheet(detail: detail, milestoneNumber: milestoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    final today = todayStr(widget.app.data.settings);
    final progress = _computeProgress();
    // The gap to the next *round* number on the scale — what the hero
    // actually leads with now — rather than the food-log milestone's own
    // fractional remainder, which has no reason to land on a whole number.
    final nextWhole = computeNextWholeKg(progress.currentWeight);
    final remaining = nextWhole != null ? nextWhole.gap * kcalPerKg : kcalPerKg - progress.currentKcal;
    final window = computeKgWindow(
      diet: widget.app.data.diet,
      activity: widget.app.data.activity,
      tdee: _tdee,
      today: today,
      remainingKcal: remaining,
    );
    final hasAnyLog = widget.app.data.diet.values.any((v) => v is List && v.isNotEmpty);
    final gap = computeLatestGap(
      weightLog: widget.app.data.weight,
      diet: widget.app.data.diet,
      activity: widget.app.data.activity,
      tdee: _tdee,
    );

    return pageScaffold(
      context: context,
      title: 'Weight loss progress',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('From your food log, calibrated against your weigh-ins', style: Type.caption),
          ),
          if (_justReached) Padding(padding: const EdgeInsets.only(bottom: 12), child: _MilestoneBanner(number: progress.reached.length)),
          if (!hasAnyLog)
            _EmptyState(onLogFood: () => Navigator.of(context).pop())
          else ...[
            _HeroCard(progress: progress, window: window, nextWhole: nextWhole),
            const SizedBox(height: 12),
            _DayStripCard(window: window, onTapDay: (bar) => _openDay(bar, progress.currentNumber)),
            const SizedBox(height: 12),
            _MilestonesCard(progress: progress, nextWhole: nextWhole),
            if (gap != null) ...[const SizedBox(height: 12), _GapInsightCard(gap: gap)],
            const SizedBox(height: 12),
            const _DisclosureCard(),
          ],
        ],
      ),
    );
  }
}

/// A compact ring — just a percentage and a short label in the center, no
/// raw value/goal pair — reused for both the hero and the small in-progress
/// indicator on the current-leg milestone row.
class _KgRing extends StatelessWidget {
  final double fraction; // 0-1
  final double size;
  final double stroke;
  final String? centerLabel;
  const _KgRing({required this.fraction, this.size = 96, this.stroke = 9, this.centerLabel});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size(size, size), painter: _RingPainter(t, stroke)),
          if (centerLabel != null)
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${(t * 100).round()}%', style: mono(fontSize: size > 60 ? 19 : 10, fontWeight: FontWeight.w800, color: T.text)),
              Text(centerLabel!, style: TextStyle(fontSize: size > 60 ? 8 : 6.5, fontWeight: FontWeight.w700, color: T.muted)),
            ]),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final double stroke;
  _RingPainter(this.fraction, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..color = T.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);
    if (fraction <= 0) return;
    final fill = Paint()
      ..color = T.hero
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708, 6.28319 * fraction, false, fill);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction || old.stroke != stroke;
}

/// The hero — a fixed atmospheric gradient (not theme-swapped, same call
/// the app already makes for the Ask AI chat's gradient and the
/// profile-switch ceremony) carrying the one thing worth checking back for:
/// the real, whole-number gap to the next kg. Back to a rounded card like
/// every other section on this screen (not full-bleed) — sits in the same
/// scrolling column as the day strip and milestones below it, so it can go
/// straight through `pageScaffold` instead of needing its own Scaffold/
/// collapsing sliver header.
///
/// Animated on arrival: the card itself fades/slides up once on mount, the
/// headline weight and the gap pill count up to their real values, and the
/// descent rail's marker eases down into position rather than snapping
/// there — all one-shot, tied to [_HeroCardState]'s own entrance
/// controller rather than looping, so the card settles and goes still. The
/// "so close" gradient is the one exception: a slow ambient breathe, only
/// running while [close] is true, so the excited state is the one that
/// keeps feeling alive.
class _HeroCard extends StatefulWidget {
  final KgProgress progress;
  final KgWindow window;
  final NextWholeKg? nextWhole;
  const _HeroCard({required this.progress, required this.window, required this.nextWhole});

  // Roughly a strong single day's deficit — close enough that "today could
  // be the day" is actually true, not just close-ish.
  static const _closeThresholdKg = 0.15;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calibrated = widget.progress.currentWeight;
    final gap = widget.nextWhole;
    final window = widget.window;
    final close = gap != null && gap.gap < _HeroCard._closeThresholdKg;
    final fractionDown = gap != null ? (1 - gap.gap).clamp(0.0, 1.0) : 0.0;

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_entrance.value);
        return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child));
      },
      child: _AmbientGradientCard(
        close: close,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (close) const Padding(padding: EdgeInsets.only(right: 6), child: _PulseDot()),
              Text(
                close ? 'SO CLOSE' : 'YOUR DESCENT',
                style: mono(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8)).copyWith(letterSpacing: 1.2),
              ),
            ]),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  // Counts *down* into place — from the whole kg just above
                  // (the one already left behind) to the real calibrated
                  // reading — rather than up from below it, so the motion
                  // itself reads as the descent, not just a reveal.
                  tween: Tween(begin: gap != null ? gap.target + 1 : (calibrated ?? 0), end: calibrated ?? 0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    calibrated != null ? _fmtKg(v) : '—',
                    style: mono(fontSize: 50, fontWeight: FontWeight.w800, color: Colors.white).copyWith(height: 0.9),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5, bottom: 7),
                  child: Text('kg', style: mono(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.72))),
                ),
                const Spacer(),
                if (gap != null)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fractionDown),
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => _DescentRail(topWhole: gap.target + 1, bottomWhole: gap.target, fractionDown: v, close: close),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (gap != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: close ? 0.2 : 0.13),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: gap.gap),
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text('${_fmtGapKg(v)} kg', style: mono(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 5),
                  Text('to ${_fmtKg(gap.target)} kg', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
                ]),
              )
            else
              Text("Log a weigh-in to see how close you are.", style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.75))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _statChip('${window.daysLogged}/${window.days.length}', 'LOGGED')),
              const SizedBox(width: 7),
              Expanded(child: _statChip(window.avgDeficitPerLoggedDay > 0 ? '${window.avgDeficitPerLoggedDay.round()}' : '—', 'AVG CAL/DAY')),
              const SizedBox(width: 7),
              Expanded(child: _statChip(close ? 'TODAY' : _etaLabel(window.etaDays), close ? 'COULD BE IT' : 'TO NEXT')),
            ]),
          ],
        ),
      ),
    );
  }

  String _etaLabel(int? etaDays) {
    if (etaDays == null) return '—';
    if (etaDays == 0) return 'any day';
    return '~$etaDays days';
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), border: Border.all(color: Colors.white.withValues(alpha: 0.16)), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value, style: mono(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
        Padding(padding: const EdgeInsets.only(top: 2), child: Text(label, style: TextStyle(fontSize: 7.5, color: Colors.white.withValues(alpha: 0.7)))),
      ]),
    );
  }
}

/// The card's gradient background — always drifting, never a static
/// paint, but at two different paces: a slow, barely-there sky drift for
/// the normal "descent" state, and a faster, warmer breathe once [close]
/// flips true, so the one moment worth getting excited about is
/// noticeably more alive than the rest.
///
/// On mount, the color also *blooms* in — the card starts flat (nothing
/// but [_dusk]) and the mid/end stops fade up to their real colors over
/// the first beat, rather than the gradient just snapping to a random
/// point mid-cycle the instant the screen appears. One-shot, via
/// [_reveal]; the looping breathe in [_c] runs underneath it the whole
/// time, so the bloom is really just this card's own arrival settling on
/// top of motion that was already going.
class _AmbientGradientCard extends StatefulWidget {
  final bool close;
  final Widget child;
  const _AmbientGradientCard({required this.close, required this.child});

  @override
  State<_AmbientGradientCard> createState() => _AmbientGradientCardState();
}

class _AmbientGradientCardState extends State<_AmbientGradientCard> with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _reveal;

  static const _dusk = Color(0xFF1C1B3A);
  static const _twilightA = Color(0xFF6E4E8E);
  static const _emberA = Color(0xFFFF7A45);
  static const _twilightB = Color(0xFF553F73);
  static const _emberB = Color(0xFFFF9A61);
  static const _closeMidA = Color(0xFFC4527A);
  static const _closeEndA = Color(0xFFFFC24B);
  static const _closeMidB = Color(0xFFD9628C);
  static const _closeEndB = Color(0xFFFFD976);

  static const _slowDuration = Duration(milliseconds: 7000);
  static const _closeDuration = Duration(milliseconds: 3400);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.close ? _closeDuration : _slowDuration)..repeat(reverse: true);
    _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void didUpdateWidget(covariant _AmbientGradientCard old) {
    super.didUpdateWidget(old);
    if (widget.close != old.close) {
      _c.duration = widget.close ? _closeDuration : _slowDuration;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_c, _reveal]),
      builder: (context, child) {
        final ambientMid = Color.lerp(widget.close ? _closeMidA : _twilightA, widget.close ? _closeMidB : _twilightB, _c.value)!;
        final ambientEnd = Color.lerp(widget.close ? _closeEndA : _emberA, widget.close ? _closeEndB : _emberB, _c.value)!;
        final bloom = Curves.easeOut.transform(_reveal.value);
        final mid = Color.lerp(_dusk, ambientMid, bloom)!;
        final end = Color.lerp(_dusk, ambientEnd, bloom)!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.rL),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_dusk, mid, end]),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A vertical gauge instead of a ring — [topWhole] and [bottomWhole] are
/// the two round numbers the current weight sits between, [fractionDown]
/// is how far from the top one toward the bottom one (0 = at [topWhole],
/// 1 = at [bottomWhole]). Ties the visual directly to numbers that count
/// *down*, which a ring doesn't communicate on its own.
class _DescentRail extends StatelessWidget {
  final double topWhole;
  final double bottomWhole;
  final double fractionDown;
  final bool close;
  const _DescentRail({required this.topWhole, required this.bottomWhole, required this.fractionDown, required this.close});

  static const _trackHeight = 84.0;
  static const _markerBox = 22.0;

  @override
  Widget build(BuildContext context) {
    final fillHeight = _trackHeight * fractionDown;
    return Column(
      children: [
        Text(_fmtKg(topWhole), style: mono(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.5))),
        SizedBox(
          width: _markerBox,
          height: _trackHeight,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            Center(
              child: Container(width: 5, height: _trackHeight, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
              top: 0,
              child: Container(
                width: 5,
                height: fillHeight.clamp(0.0, _trackHeight),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Positioned(
              top: (fillHeight - _markerBox / 2).clamp(-_markerBox / 2, _trackHeight - _markerBox / 2),
              child: close ? const _PulseMarker() : const _StaticMarker(),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(_fmtKg(bottomWhole), style: mono(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}

class _StaticMarker extends StatelessWidget {
  const _StaticMarker();
  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22))),
      Container(width: 13, height: 13, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
    ]);
  }
}

/// The "so close" state's marker — a slow glow instead of sitting still,
/// so the card looks more alive exactly when it genuinely is closer, with
/// nothing counting down and nothing that can "break".
class _PulseMarker extends StatefulWidget {
  const _PulseMarker();
  @override
  State<_PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<_PulseMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
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
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: const Color(0xFFFFC24B).withValues(alpha: 0.3 + 0.35 * t), blurRadius: 10 + 8 * t, spreadRadius: 2 + 3 * t)],
          ),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
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
      builder: (context, _) => Opacity(
        opacity: 0.5 + 0.5 * _c.value,
        child: Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFC24B))),
      ),
    );
  }
}

/// Bars again (not the ridge-line alternative) — the fix for "cramped" is
/// giving each day real width and letting the strip scroll horizontally
/// instead of squeezing 14 of them into one fixed-width card.
class _DayStripCard extends StatelessWidget {
  final KgWindow window;
  final void Function(KgDayBar) onTapDay;
  const _DayStripCard({required this.window, required this.onTapDay});

  @override
  Widget build(BuildContext context) {
    final maxAbs = window.days.fold<num>(1, (m, d) => d.logged && d.deficit.abs() > m ? d.deficit.abs() : m);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Eyebrow('Last ${window.days.length} days', margin: EdgeInsets.zero),
              Text('tap a day', style: mono(fontSize: 9.5, color: T.faint)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // opens scrolled to today, the end of the strip
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: window.days.map((d) {
                final isToday = identical(d, window.days.last);
                final heightFrac = d.logged ? (d.deficit.abs() / maxAbs).clamp(0.1, 1.0) : 0.0;
                final color = !d.logged ? T.line : (d.deficit >= 0 ? T.success : T.danger);
                final dayLabel = d.date.length >= 10 ? int.parse(d.date.substring(8, 10)).toString() : '';
                return Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: GestureDetector(
                    key: ValueKey('kg-day-${d.date}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: d.logged ? () => onTapDay(d) : null,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 82,
                          child: Stack(alignment: Alignment.bottomCenter, children: [
                            Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 1, color: T.line)),
                            FractionallySizedBox(
                              heightFactor: d.logged ? heightFrac : 0.05,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                  border: isToday ? Border.all(color: T.hero, width: 2) : null,
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        Text(dayLabel, style: mono(fontSize: 8.5, fontWeight: isToday ? FontWeight.w800 : FontWeight.w500, color: isToday ? T.hero : T.faint)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('← scroll for earlier days', style: TextStyle(fontSize: 9.5, color: T.faint)),
          ),
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  final KgProgress progress;
  final NextWholeKg? nextWhole;
  const _MilestonesCard({required this.progress, required this.nextWhole});

  @override
  Widget build(BuildContext context) {
    final ordered = progress.reached.reversed.toList();
    final gap = nextWhole;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Kilograms so far', margin: EdgeInsets.only(bottom: 4)),
          _row(
            leading: _KgRing(fraction: gap != null ? (1 - gap.gap).clamp(0.0, 1.0) : progress.currentFraction, size: 30, stroke: 3),
            title: gap != null
                ? '${_fmtGapKg(gap.gap)} kg to ${_fmtKg(gap.target)} kg'
                : (progress.currentWeight != null ? '≈${_fmtKg(progress.currentWeight!)} kg — in progress' : 'Kg ${progress.currentNumber} — in progress'),
            sub: gap != null ? 'in progress' : '${(progress.currentFraction * 100).round()}% there',
            last: ordered.isEmpty,
          ),
          for (var i = 0; i < ordered.length; i++)
            _row(
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, color: T.success.withValues(alpha: 0.16)),
                alignment: Alignment.center,
                child: Icon(Icons.check, size: 15, color: T.success),
              ),
              // Real, scale-grounded weight when there's a weigh-in to anchor
              // to (see estimatedWeightOnDate); falls back to the abstract
              // "Kg N" count for someone who hasn't logged a weight yet.
              title: ordered[i].weight != null ? '${_fmtKg(ordered[i].weight!)} kg' : 'Kg ${ordered[i].number}',
              sub: 'Reached ${fmtDay(ordered[i].date)}',
              last: i == ordered.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _row({required Widget leading, required String title, required String sub, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: T.line))),
      child: Row(children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text)),
              Text(sub, style: mono(fontSize: 10.5, color: T.muted)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _DisclosureCard extends StatefulWidget {
  const _DisclosureCard();
  @override
  State<_DisclosureCard> createState() => _DisclosureCardState();
}

class _DisclosureCardState extends State<_DisclosureCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('How this works', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.muted)),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.keyboard_arrow_down, size: 18, color: T.faint),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Eating about $kcalPerKg calories under your goal, in total, adds up to roughly 1 kg. '
                "We only count days you actually logged food — skipped days don't count for or against you. "
                "This comes from your food log, not your scale, so the two numbers won't always match.",
                style: TextStyle(fontSize: 11.5, color: T.muted, height: 1.55),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Shown only when [computeLatestGap] finds a real mismatch between the two
/// most recent weigh-ins and what the food log alone predicted for the
/// latest one — the explanation itself is opt-in (a button, not an
/// automatic call) so this never spends AI credits without the user asking.
class _GapInsightCard extends StatefulWidget {
  final KgGapInsight gap;
  const _GapInsightCard({required this.gap});

  @override
  State<_GapInsightCard> createState() => _GapInsightCardState();
}

class _GapInsightCardState extends State<_GapInsightCard> {
  final _service = WeightInsightService();
  bool _loading = false;
  String? _reply;
  String? _error;

  Future<void> _ask() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reply = await _service.explainGap(widget.gap);
      if (!mounted) return;
      setState(() => _reply = reply);
    } on AiConfigException {
      if (!mounted) return;
      setState(() => _error = "Ask AI isn't set up for this build — see secrets.example.json.");
    } on AiParseException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.gap;
    final over = gap.gapKg > 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.query_stats, size: 16, color: T.blue),
            const SizedBox(width: 8),
            Expanded(child: Text('A gap between your log and your scale', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text))),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              'At your ${fmtDay(gap.latestDate)} weigh-in (${_fmtKg(gap.actualWeight)} kg), your food log had predicted about ${_fmtKg(gap.predictedWeight)} kg — '
              '${_fmtKg(gap.gapKg.abs())} kg ${over ? 'more' : 'less'} than expected since ${fmtDay(gap.previousDate)}.',
              style: TextStyle(fontSize: 12, color: T.muted, height: 1.5),
            ),
          ),
          if (_reply != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: T.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.auto_awesome, size: 15, color: T.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(_reply!, style: TextStyle(fontSize: 12, color: T.text, height: 1.5))),
              ]),
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(fontSize: 11.5, color: T.danger)),
              ),
            GestureDetector(
              onTap: _loading ? null : _ask,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(999)),
                alignment: Alignment.center,
                child: _loading
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: T.muted))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome, size: 14, color: T.blue),
                        const SizedBox(width: 7),
                        Text('Ask AI why', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.blue)),
                      ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneBanner extends StatelessWidget {
  final int number;
  const _MilestoneBanner({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.hero.withValues(alpha: 0.08),
        border: Border.all(color: T.hero),
        borderRadius: BorderRadius.circular(T.rL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: T.hero),
              alignment: Alignment.center,
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('That\'s kg $number done 🎉', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: T.text))),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "You're already on your way to kg ${number + 1} below.",
              style: TextStyle(fontSize: 11, color: T.muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onLogFood;
  const _EmptyState({required this.onLogFood});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Opacity(opacity: 0.5, child: _KgRing(fraction: 0, centerLabel: 'there')),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Nothing yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.muted)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: Text(
              'This fills up as you log meals that come in under your calorie goal. Log your first meal to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: T.muted, height: 1.5),
            ),
          ),
          PrimaryButton(
            onTap: onLogFood,
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('Log food'),
            ]),
          ),
        ],
      ),
    );
  }
}
