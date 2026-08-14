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
    final remaining = kcalPerKg - progress.currentKcal;
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
            _HeroCard(progress: progress, window: window),
            const SizedBox(height: 12),
            _DayStripCard(window: window, milestoneNumber: progress.currentNumber, onTapDay: (bar) => _openDay(bar, progress.currentNumber)),
            const SizedBox(height: 12),
            _MilestonesCard(progress: progress),
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

class _HeroCard extends StatelessWidget {
  final KgProgress progress;
  final KgWindow window;
  const _HeroCard({required this.progress, required this.window});

  @override
  Widget build(BuildContext context) {
    final remaining = kcalPerKg - progress.currentKcal;
    final calibrated = progress.currentWeight;
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
                        calibrated != null ? '≈${_fmtKg(calibrated)} kg now · ${progress.reached.length} kg lost so far' : '${progress.reached.length} kg lost so far',
                        style: mono(fontSize: 10.5, color: T.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
            title: progress.currentWeight != null ? '≈${_fmtKg(progress.currentWeight!)} kg — in progress' : 'Kg ${progress.currentNumber} — in progress',
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
