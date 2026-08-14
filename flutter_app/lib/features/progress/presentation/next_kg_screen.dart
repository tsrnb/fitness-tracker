import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../domain/kg_progress.dart';
import 'widgets/kg_day_detail_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    final progress = computeKgProgress(diet: widget.app.data.diet, activity: widget.app.data.activity, tdee: _tdee);
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
    final progress = computeKgProgress(diet: widget.app.data.diet, activity: widget.app.data.activity, tdee: _tdee);
    final remaining = kcalPerKg - progress.currentKcal;
    final window = computeKgWindow(
      diet: widget.app.data.diet,
      activity: widget.app.data.activity,
      tdee: _tdee,
      today: today,
      remainingKcal: remaining,
    );
    final hasAnyLog = widget.app.data.diet.values.any((v) => v is List && v.isNotEmpty);

    return pageScaffold(
      context: context,
      title: 'Weight loss progress',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('From your food log, not the scale', style: Type.caption),
          ),
          if (_justReached) Padding(padding: const EdgeInsets.only(bottom: 12), child: _MilestoneBanner(number: progress.reached.length)),
          if (!hasAnyLog)
            _EmptyState(onLogFood: () => Navigator.of(context).pop())
          else ...[
            _HeroCard(progress: progress, window: window),
            const SizedBox(height: 12),
            _DayStripCard(window: window, milestoneNumber: progress.currentNumber, onTapDay: (bar) => _openDay(bar, progress.currentNumber)),
            const SizedBox(height: 12),
            _MilestonesCard(progress: progress),
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

class _HeroCard extends StatelessWidget {
  final KgProgress progress;
  final KgWindow window;
  const _HeroCard({required this.progress, required this.window});

  @override
  Widget build(BuildContext context) {
    final remaining = kcalPerKg - progress.currentKcal;
    return AppCard(
      borderColor: T.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _KgRing(fraction: progress.currentFraction, centerLabel: 'there'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(progress.currentKcal.clamp(0, kcalPerKg) / kcalPerKg).toStringAsFixed(2)} kg toward your next',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: T.text),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3, bottom: 6),
                      child: Text(
                        '${progress.currentKcal.clamp(0, kcalPerKg).round()} / $kcalPerKg calories',
                        style: mono(fontSize: 11.5, color: T.muted),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        '${progress.reached.length} kg lost so far',
                        style: mono(fontSize: 10.5, color: T.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.currentFraction),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => LinearProgressIndicator(
                  value: t,
                  minHeight: 8,
                  backgroundColor: T.surface2,
                  valueColor: const AlwaysStoppedAnimation(T.hero),
                ),
              ),
            ),
          ),
          Row(children: [
            Expanded(child: _statChip('${window.daysLogged}/${window.days.length}', 'days logged')),
            const SizedBox(width: 7),
            Expanded(child: _statChip(window.avgDeficitPerLoggedDay > 0 ? '${window.avgDeficitPerLoggedDay.round()}' : '—', 'avg cal/day')),
            const SizedBox(width: 7),
            Expanded(child: _statChip(_etaLabel(window.etaDays, remaining), 'to next kg')),
          ]),
        ],
      ),
    );
  }

  String _etaLabel(int? etaDays, num remaining) {
    if (remaining <= 0) return 'any day';
    if (etaDays == null) return '—';
    if (etaDays == 0) return 'any day';
    return '~$etaDays days';
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value, style: mono(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text)),
        Padding(padding: const EdgeInsets.only(top: 2), child: Text(label, style: TextStyle(fontSize: 8.5, color: T.muted))),
      ]),
    );
  }
}

class _DayStripCard extends StatelessWidget {
  final KgWindow window;
  final int milestoneNumber;
  final void Function(KgDayBar) onTapDay;
  const _DayStripCard({required this.window, required this.milestoneNumber, required this.onTapDay});

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
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: window.days.map((d) {
                final heightFrac = d.logged ? (d.deficit.abs() / maxAbs).clamp(0.12, 1.0) : 0.0;
                final color = !d.logged ? T.line : (d.deficit >= 0 ? T.success : T.danger);
                return Expanded(
                  child: GestureDetector(
                    key: ValueKey('kg-day-${d.date}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: d.logged ? () => onTapDay(d) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Stack(alignment: Alignment.bottomCenter, children: [
                        Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 1, color: T.line)),
                        FractionallySizedBox(
                          heightFactor: d.logged ? heightFrac : 0.04,
                          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                        ),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  final KgProgress progress;
  const _MilestonesCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final ordered = progress.reached.reversed.toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Kilograms so far', margin: EdgeInsets.only(bottom: 4)),
          _row(
            leading: _KgRing(fraction: progress.currentFraction, size: 30, stroke: 3),
            title: 'Kg ${progress.currentNumber} — in progress',
            sub: '${(progress.currentFraction * 100).round()}% there',
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
              title: 'Kg ${ordered[i].number}',
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
