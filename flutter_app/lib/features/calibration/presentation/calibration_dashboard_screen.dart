import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../../nutrition/domain/ai_food_item.dart' show AiConfigException, AiParseException;
import '../../nutrition/presentation/widgets/ai_gradient.dart' show aiColor1, aiColor2, aiColor3;
import '../data/calibration_insight_service.dart';
import '../domain/calibration_ai.dart';
import '../domain/calibration_digest.dart';
import '../domain/calibration_engine.dart';
import 'calibration_ask_ai_screen.dart';
import 'calibration_mode_screen.dart';
import 'widgets/calibration_chat_sheet.dart';

/// Mockup screens 06 (running) and 07 (results) in one place — which of the
/// two renders depends purely on `calibration['status']`/`endDate`, not on
/// how this screen was reached, so every entry point (Next Kg's card, the
/// Home status card, a fresh push) always lands on the right view.
class CalibrationDashboardScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const CalibrationDashboardScreen({super.key, required this.app, required this.controller});

  @override
  State<CalibrationDashboardScreen> createState() => _CalibrationDashboardScreenState();
}

class _CalibrationDashboardScreenState extends State<CalibrationDashboardScreen> {
  bool _freezing = false;
  bool _swept = false;

  /// `widget.app` is a snapshot frozen at the moment this screen was
  /// *constructed* — for every other pushed screen that's fine (data a few
  /// seconds stale doesn't matter), but this one is routinely built in the
  /// very same frame as the `controller.update('calibration', ...)` that
  /// created the record it depends on (Mode screen's "Begin" does exactly
  /// this via `pushReplacement`). `widget.app` in that case still reflects
  /// the world *before* that write, so `data.calibration` reads back null
  /// and the old "shouldn't normally be reachable" guard below would pop
  /// this screen right back off — landing back on Intro, which is exactly
  /// the bug this getter fixes. `controller.current` (see app_state.dart)
  /// is always the live state, so every read in this file goes through it
  /// instead of `widget.app` directly.
  AppState get _app => widget.controller.current;

  @override
  void initState() {
    super.initState();
    if (_maybeSweepExpired()) return;
    _maybeFreezeResult();
  }

  /// A finished study that's aged past [calibrationRetentionDays] is cleared
  /// the next time it would be opened — so the results screen can't linger
  /// forever, and the entry point falls back to a fresh "start" CTA. Returns
  /// true when it swept (build then just pops).
  bool _maybeSweepExpired() {
    final calibration = _app.data.calibration;
    if (calibration == null) return false;
    if (!calibrationExpired(calibration, todayStr(_app.data.settings))) return false;
    _swept = true;
    widget.controller.update('calibration', (_) => null);
    return true;
  }

  /// The first time this screen is opened on/after `endDate` for a still-
  /// `running` calibration, compute the result once and persist it — so the
  /// numbers shown don't keep drifting as later weigh-ins/food logs come in.
  void _maybeFreezeResult() {
    final calibration = _app.data.calibration;
    if (calibration == null || calibration['status'] != 'running') return;
    final today = todayStr(_app.data.settings);
    if (!isFinished(calibration, today)) return;
    _freezing = true;
    final result = computeResults(_app.data, calibration, today);
    widget.controller.update('calibration', (prev) {
      final next = Map<String, dynamic>.from(prev as Map);
      next['status'] = 'completed';
      next['result'] = result.toMap(today);
      next['terminalOn'] = today; // starts the retention countdown
      return next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final calibration = _app.data.calibration;
    if (_swept || calibration == null) {
      // Shouldn't normally be reachable (every entry point checks first),
      // but pop rather than crash if data changed out from under this push.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return pageScaffold(context: context, title: 'Calibration', onBack: () => Navigator.of(context).pop(), child: const SizedBox());
    }

    final today = todayStr(_app.data.settings);
    final finished = _freezing || calibration['status'] != 'running' || isFinished(calibration, today);

    return pageScaffold(
      context: context,
      title: finished ? 'Calibration complete' : 'Calibration',
      onBack: () => Navigator.of(context).pop(),
      child: finished
          ? _ResultsView(app: _app, controller: widget.controller, calibration: calibration)
          : _RunningView(app: _app, controller: widget.controller, calibration: calibration, onChanged: () => setState(() {})),
    );
  }
}

class _RunningView extends StatelessWidget {
  final AppState app;
  final AppController controller;
  final Map<String, dynamic> calibration;
  // Switch mode / end early both mutate `calibration` via the controller,
  // which (per this screen's own `_app` getter) is picked up on the next
  // build — but nothing triggers that next build on its own, since this is
  // a StatelessWidget with no state of its own to invalidate. This callback
  // is just `setState(() {})` on the parent, so the change actually shows
  // up immediately instead of only after leaving and re-entering the screen.
  final VoidCallback onChanged;
  const _RunningView({required this.app, required this.controller, required this.calibration, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final today = todayStr(app.data.settings);
    final progress = computeProgress(app.data, calibration, today);
    final units = app.data.settings['units'] as String? ?? 'kg';
    final mode = calibration['mode'] as String? ?? 'observe';
    final controlled = mode == 'controlled';
    final locked = isModeLocked(calibration, today);
    final daysLeft = daysUntilModeUnlock(calibration, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
              child: Text('DAY ${progress.day} / ${progress.totalDays}', style: mono(fontSize: 11, fontWeight: FontWeight.w800, color: T.text).copyWith(letterSpacing: 0.6)),
            ),
            Row(
              children: List.generate(progress.totalDays, (i) {
                final on = i < progress.day;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? T.accent : T.line)),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TrendHero(progress: progress, units: units, controlled: controlled),
        const SizedBox(height: 12),
        AppCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 1), child: Text('💡', style: TextStyle(fontSize: 16))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                progress.status == 'within_range'
                    ? "Keep going. We're looking for a trend, not one reading."
                    : progress.status == 'ahead'
                        ? "You're ahead of what the model expected — could be real progress, could be noise. Keep logging and let it settle."
                        : "You're a bit behind what the model expected so far — too early to read much into it. Keep logging and let it settle.",
                style: Type.body,
              ),
            ),
          ]),
        ),
        if (progress.day >= 7 && progress.day < progress.totalDays && calibration['day7Seen'] != true) ...[
          const SizedBox(height: 12),
          _MidpointCheckCard(app: app, controller: controller, calibration: calibration, onChanged: onChanged),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MiniCheck(label: 'Weight logged', done: progress.weightLoggedToday)),
          const SizedBox(width: 8),
          Expanded(child: _MiniCheck(label: 'Food logged', done: progress.foodLoggedToday)),
        ]),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Eyebrow('Mode', margin: EdgeInsets.zero),
            Text(
              locked ? '🔒 ${daysLeft == 1 ? 'unlocks tomorrow' : 'unlocks in ${daysLeft}d'}' : 'tap to switch',
              style: mono(fontSize: 10, color: T.faint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Same sliding-pill control used for the Progress-tab tabs and the
        // Nutrition period picker — its built-in AnimatedPositioned highlight
        // is the "some animation while switching" ask, and it also just
        // shows which mode is active at a glance, which the old plain
        // "Switch mode" text link never did. Locked for `modeLockDays` after
        // it's set (or last switched) — greyed out and non-interactive, with
        // a transparent tap-catcher on top just to explain why via a toast
        // rather than silently doing nothing.
        Stack(
          children: [
            IgnorePointer(
              ignoring: locked,
              child: AnimatedOpacity(
                opacity: locked ? 0.55 : 1,
                duration: const Duration(milliseconds: 150),
                child: PillTabs(
                  options: const [MapEntry('observe', '👀  Observe'), MapEntry('controlled', '🎯  Controlled')],
                  value: mode,
                  onChange: (v) => _switchMode(context, v),
                ),
              ),
            ),
            if (locked)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Locked for $daysLeft more day${daysLeft == 1 ? '' : 's'} — switching mid-window would blur the comparison.')),
                  ),
                ),
              ),
          ],
        ),
        if (controlled) ...[
          const SizedBox(height: 12),
          _ControlledTrackerCard(check: computeControlledDayCheck(app.data, today)),
        ],
        const SizedBox(height: 12),
        _DayLogCard(
          days: computeDayLog(app.data, calibration, today),
          today: today,
          controlled: controlled,
          checkForDate: controlled ? (date) => computeControlledDayCheck(app.data, date) : null,
        ),
        if (progress.day >= 3) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => CalibrationAskAiScreen(app: app, controller: controller)))
                .then((_) => onChanged()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: Border.all(color: T.lav.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(T.rM)),
              alignment: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome, size: 14, color: T.lavAccent),
                const SizedBox(width: 8),
                Text('Ask AI to look at your data so far', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.lavAccent)),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _BaselineDisclosureCard(baseline: Map<String, dynamic>.from(calibration['baseline'] as Map), units: units),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => _endEarly(context),
            child: Text('End early', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.faint)),
          ),
        ),
      ],
    );
  }

  Future<void> _switchMode(BuildContext context, String nextMode) async {
    final today = todayStr(app.data.settings);
    if (nextMode == calibration['mode'] || isModeLocked(calibration, today)) return;
    await controller.update('calibration', (prev) => switchMode(Map<String, dynamic>.from(prev as Map), nextMode, today));
    onChanged();
  }

  void _endEarly(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.surface,
        title: const Text('End calibration early?'),
        content: const Text('You can still see how it compares to the plan so far — but the fewer days logged, the noisier the read.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Keep going')),
          TextButton(
            onPressed: () async {
              final today = todayStr(app.data.settings);
              await controller.update('calibration', (prev) => endCalibrationEarly(Map<String, dynamic>.from(prev as Map), today));
              onChanged();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text('End it', style: TextStyle(color: T.danger)),
          ),
        ],
      ),
    );
  }
}

class _TrendHero extends StatelessWidget {
  final CalibrationProgress progress;
  final String units;
  final bool controlled;
  const _TrendHero({required this.progress, required this.units, required this.controlled});

  // Observe keeps the original cool purple/pink gradient; Controlled shifts
  // to a green/teal one — a quiet but real visual tell for which mode
  // you're in before reading a single word on the card.
  static const _observeColors = [Color(0xFF1C1B3A), Color(0xFF4A3A66), Color(0xFFC4527A)];
  static const _controlledColors = [Color(0xFF12261F), Color(0xFF1B3A3A), Color(0xFF2E6659)];

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (progress.status) {
      'within_range' => 'ON TRACK',
      'ahead' => 'AHEAD',
      _ => 'BEHIND',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(T.rL),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: controlled ? _controlledColors : _observeColors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7-DAY TREND', style: mono(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75)).copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(progress.currentWeight != null ? progress.currentWeight!.toStringAsFixed(1) : '—', style: mono(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(width: 6),
            Text(units, style: mono(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
          ]),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), border: Border.all(color: Colors.white.withValues(alpha: 0.28)), borderRadius: BorderRadius.circular(999)),
            child: Text('${progress.observedKgSoFar.toStringAsFixed(1)} $units since Day 1', style: mono(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _statChip('${progress.observedKgSoFar.toStringAsFixed(1)}$units', 'CURRENT TREND')),
            const SizedBox(width: 7),
            Expanded(child: _statChip('${progress.expectedKgSoFar.toStringAsFixed(1)}$units', 'EXPECTED')),
            const SizedBox(width: 7),
            Expanded(child: _statChip(statusLabel, 'STATUS')),
          ]),
        ],
      ),
    );
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

class _MiniCheck extends StatelessWidget {
  final String label;
  final bool done;
  const _MiniCheck({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? T.success : Colors.transparent, border: done ? null : Border.all(color: T.faint, width: 1.5)),
          alignment: Alignment.center,
          child: done ? const Icon(Icons.check, size: 10, color: Color(0xFF0C0C0D)) : null,
        ),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: T.text)),
      ]),
    );
  }
}

const _amber = Color(0xFFFFC44B);

/// The Controlled-only card comparing today's logged calories/protein/steps
/// against the plan's existing goals — the tracker the mode's whole premise
/// (hold the majors steady) needs to actually mean something, rather than
/// just being a label. Observe never renders this at all.
class _ControlledTrackerCard extends StatelessWidget {
  final ControlledDayCheck check;
  const _ControlledTrackerCard({required this.check});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('🎯  Today vs. your held targets', margin: EdgeInsets.only(bottom: 4)),
          _row('🔥', 'Calories', check.calories, check.calorieTarget, 'kcal', check.caloriesOk),
          _row('🥩', 'Protein', check.protein, check.proteinTarget, 'g', check.proteinOk),
          _row('👣', 'Steps', check.steps, check.stepTarget, '', check.stepsOk, last: true),
        ],
      ),
    );
  }

  Widget _row(String icon, String label, num actual, num target, String unit, bool ok, {bool last = false}) {
    final over = actual > target;
    final flagLabel = ok ? 'ON TARGET' : (over ? 'OVER' : 'UNDER');
    final flagColor = ok ? T.success : (over ? T.danger : _amber);
    final fraction = target <= 0 ? 0.0 : (actual / target).clamp(0.0, 1.4) / 1.4;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: T.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 20, child: Text(icon, style: const TextStyle(fontSize: 15))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: T.text)),
                  Text('${actual.round()} / ${target.round()}${unit.isEmpty ? '' : ' $unit'}', style: mono(fontSize: 10.5, color: T.muted)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: T.surface2, valueColor: AlwaysStoppedAnimation(flagColor)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: flagColor.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
          child: Text(flagLabel, style: mono(fontSize: 8.5, fontWeight: FontWeight.w800, color: flagColor).copyWith(letterSpacing: 0.3)),
        ),
      ]),
    );
  }
}

/// Mockup "Option A" — one cell per day of the window, colored by whether
/// that day's weight *and* food were both logged. The single most
/// consequential thing a 14-day study can show about itself: not the trend
/// (the hero card above already covers that), but whether the logging
/// behind it actually held up day to day. In Controlled mode, a small
/// corner dot adds a second signal — was that day within the held targets —
/// without replacing the logged/partial/missed read underneath it.
class _DayLogCard extends StatelessWidget {
  final List<CalibrationDayLog> days;
  final String today;
  final bool controlled;
  final ControlledDayCheck Function(String date)? checkForDate;
  const _DayLogCard({required this.days, required this.today, required this.controlled, this.checkForDate});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Your calibration log', margin: EdgeInsets.only(bottom: 10)),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: days.map(_dayCell).toList(),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 6, children: [
            _legendItem(T.success.withValues(alpha: 0.35), 'both logged'),
            _legendItem(_amber.withValues(alpha: 0.35), 'partial'),
            _legendItem(T.surface2, 'missed'),
            if (controlled) ...[
              _legendItem(T.success, 'within targets', round: true),
              _legendItem(T.danger, 'off targets', round: true),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _dayCell(CalibrationDayLog d) {
    late final Color bg;
    late final Color border;
    late final Color fg;
    switch (d.status) {
      case CalibrationDayLogStatus.both:
        bg = T.success.withValues(alpha: 0.16);
        border = T.success.withValues(alpha: 0.4);
        fg = T.success;
        break;
      case CalibrationDayLogStatus.partial:
        bg = _amber.withValues(alpha: 0.14);
        border = _amber.withValues(alpha: 0.4);
        fg = _amber;
        break;
      case CalibrationDayLogStatus.missed:
        bg = T.surface2;
        border = T.line;
        fg = T.faint;
        break;
      case CalibrationDayLogStatus.future:
        bg = Colors.transparent;
        border = T.line.withValues(alpha: 0.5);
        fg = T.line;
        break;
    }
    final isToday = d.date == today;
    // Only past/today, logged-enough days get a flag dot — a day nothing
    // was logged on isn't "off target," it's just missing, already said by
    // the cell's own grey.
    final showFlag = controlled && checkForDate != null && d.status != CalibrationDayLogStatus.future && d.status != CalibrationDayLogStatus.missed;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: isToday ? T.accent : border, width: isToday ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Stack(clipBehavior: Clip.none, children: [
        Center(child: Text('${d.dayNumber}', style: mono(fontSize: 10, fontWeight: FontWeight.w700, color: fg))),
        if (showFlag)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, color: checkForDate!(d.date).allOk ? T.success : T.danger, border: Border.all(color: T.bg, width: 1.5)),
            ),
          ),
      ]),
    );
  }

  Widget _legendItem(Color color, String label, {bool round = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(round ? 999 : 3))),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: T.muted)),
    ]);
  }
}

/// Mockup "Option B" — resurfaces `calibration.baseline`, which is
/// otherwise computed once on Day 1 (Mode screen) and never shown again.
/// Collapsed by default: reference material you'd check occasionally, not
/// something worth a permanent chunk of the screen the way the day log is.
class _BaselineDisclosureCard extends StatefulWidget {
  final Map<String, dynamic> baseline;
  final String units;
  const _BaselineDisclosureCard({required this.baseline, required this.units});

  @override
  State<_BaselineDisclosureCard> createState() => _BaselineDisclosureCardState();
}

class _BaselineDisclosureCardState extends State<_BaselineDisclosureCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.baseline;
    return AppCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('What we\'re testing against', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.muted)),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Captured on Day 1 — this doesn't change until the window closes.", style: TextStyle(fontSize: 11.5, color: T.faint, height: 1.5)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 14,
                    childAspectRatio: 2.6,
                    children: [
                      _stat('${(b['intakeKcal'] as num).round()}', 'Est. intake / day'),
                      _stat('${(b['expenditureKcal'] as num).round()}', 'Est. burn / day'),
                      _stat('${(b['deficitKcal'] as num).round()}', 'Est. deficit / day'),
                      _stat('${(b['expectedKgChange'] as num).toStringAsFixed(1)} ${widget.units}', 'Expected in 14d'),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: mono(fontSize: 15, fontWeight: FontWeight.w800, color: T.text)),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: T.faint, letterSpacing: 0.3)),
      ],
    );
  }
}

/// The end-of-window screen. Since the AI's read *is* the screen here, it's
/// generated on open (not behind a button) and laid out as a written
/// finding: an overline, a quiet trace of the fortnight's weigh-ins, the
/// verdict set in serif, one paragraph of reasoning, an honest line on how
/// clean the read is, and a single action that matches the verdict —
/// adjust the plan, or run it again properly. Falls back to a
/// deterministic finding (from `computeResults`) whenever the proxy is
/// unset or the call fails.
class _ResultsView extends StatefulWidget {
  final AppState app;
  final AppController controller;
  final Map<String, dynamic> calibration;
  const _ResultsView({required this.app, required this.controller, required this.calibration});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  final _service = CalibrationInsightService();
  bool _loading = false;
  String? _error;

  /// The plan change this study wrote, once applied — `{tdee, calorieGoal,
  /// on}` — persisted onto `calibration.result.applied` so re-opening the
  /// screen shows "already applied" instead of offering the change again
  /// (and recomputing it against the now-updated plan). Null until applied.
  Map<String, dynamic>? _applied;

  /// The structured AI read — headline verdict + reasoning narrative +
  /// ranked causes + confidence + a tempered TDEE. Hydrated from
  /// `calibration.result.ai` (frozen the first time it's fetched) so it
  /// doesn't re-generate or drift; null until it's generated or if AI is
  /// unavailable.
  CalibrationAiReport? _report;

  @override
  void initState() {
    super.initState();
    final stored = widget.calibration['result'];
    if (stored is Map && stored['ai'] is Map) {
      _report = CalibrationAiReport.fromJson(Map<String, dynamic>.from(stored['ai']));
    }
    if (stored is Map && stored['applied'] is Map) {
      _applied = Map<String, dynamic>.from(stored['applied']);
    }
    // The read is the screen — kick it off on open rather than waiting for
    // a tap. Only when the proxy is actually configured; otherwise the
    // deterministic fallback carries the screen with no error shown.
    if (_report == null && CalibrationInsightService.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate();
      });
    }
  }

  CalibrationResult get _result {
    final today = todayStr(widget.app.data.settings);
    final stored = widget.calibration['result'];
    if (stored is Map && stored['observedKgChange'] != null && stored['gapKg'] != null) {
      final m = Map<String, dynamic>.from(stored);
      final baseline = Map<String, dynamic>.from(widget.calibration['baseline'] as Map);
      return CalibrationResult(
        expectedKgChange: (baseline['expectedKgChange'] as num).toDouble(),
        observedKgChange: (m['observedKgChange'] as num).toDouble(),
        gapKg: (m['gapKg'] as num).toDouble(),
        explanations: List<String>.from(m['explanations'] ?? []),
      );
    }
    return computeResults(widget.app.data, widget.calibration, today);
  }

  /// The window's weigh-ins in date order — the series behind the trace.
  List<double> get _weighInSeries {
    final start = widget.calibration['startDate'] as String;
    final end = widget.calibration['endDate'] as String;
    final pts = <double>[];
    for (final w in widget.app.data.weight) {
      final date = w['date'] as String?;
      if (date == null || date.compareTo(start) < 0 || date.compareTo(end) > 0) continue;
      final v = (w['weight'] as num?)?.toDouble();
      if (v != null) pts.add(v);
    }
    return pts;
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final today = todayStr(widget.app.data.settings);
    final result = _result;
    try {
      final report = await _service.analyzeResult(
        digest: buildCalibrationDigest(widget.app.data, widget.calibration, today),
        expectedKg: result.expectedKgChange,
        observedKg: result.observedKgChange,
      );
      if (!mounted) return;
      // Freeze it into the result so it doesn't re-generate or drift.
      await widget.controller.update('calibration', (prev) {
        final next = Map<String, dynamic>.from(prev as Map);
        final res = Map<String, dynamic>.from((next['result'] as Map?) ?? {});
        res['ai'] = report.toJson();
        next['result'] = res;
        return next;
      });
      if (!mounted) return;
      setState(() => _report = report);
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

  void _openChat() {
    final today = todayStr(widget.app.data.settings);
    CalibrationChatSheet.show(
      context,
      aiContext: buildFullCalibrationContext(widget.app.data, widget.calibration, today),
      suggestions: const [
        'Why did week 2 go differently?',
        'Should I trust this result?',
        'What should my calorie goal actually be?',
      ],
    );
  }

  void _continue() {
    widget.controller.update('calibration', (prev) => extendCalibration(Map<String, dynamic>.from(prev as Map)));
    Navigator.of(context).pop();
  }

  /// "Start a Controlled calibration" / "Re-run the 14 days" — clears the
  /// finished study and drops the user into the Mode screen with the right
  /// mode pre-picked, so they still confirm a fresh baseline before Day 1.
  Future<void> _startFresh(String presetMode) async {
    await widget.controller.update('calibration', (_) => null);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => CalibrationModeScreen(
        app: widget.controller.current,
        controller: widget.controller,
        initialMode: presetMode,
      ),
    ));
  }

  /// Writes the calibration's re-anchored TDEE/calorie-goal back to the
  /// plan — see `computePlanApplyPreview` for how those numbers are derived —
  /// and records what was written onto `calibration.result.applied`, so this
  /// screen shows "already applied" on every later visit instead of
  /// re-offering (and re-deriving) the change.
  Future<void> _applyToPlan(PlanApplyPreview preview, {int? tdeeOverride}) async {
    final newTdee = tdeeOverride ?? preview.newTdee;
    final offset = preview.oldCalorieGoal - preview.oldTdee;
    final newGoal = (newTdee + offset).round();
    await widget.controller.patchSettings('calorieGoal', newGoal);
    await widget.controller.update('plan', (prev) {
      final next = Map<String, dynamic>.from(prev as Map? ?? {});
      next['tdee'] = newTdee;
      return next;
    });
    final record = {'tdee': newTdee, 'calorieGoal': newGoal, 'on': todayStr(widget.app.data.settings)};
    await widget.controller.update('calibration', (prev) {
      final next = Map<String, dynamic>.from(prev as Map);
      final res = Map<String, dynamic>.from((next['result'] as Map?) ?? {});
      res['applied'] = record;
      next['result'] = res;
      return next;
    });
    if (mounted) setState(() => _applied = record);
  }

  String _fallbackHeadline(CalibrationResult r) {
    if (r.gapKg.abs() < 0.2) return 'Your weight tracked your calorie model almost exactly.';
    return r.gapKg > 0
        ? 'Your weight moved slower than your calorie model predicted.'
        : 'Your weight moved faster than your calorie model predicted.';
  }

  String _statLine(CalibrationResult r, String units, String mode, ControlledAdherence adh) {
    final base =
        'predicted ${r.expectedKgChange.toStringAsFixed(1)} $units      actual ${r.observedKgChange.toStringAsFixed(1)} $units';
    if (mode == 'controlled' && adh.elapsedDays > 0) {
      return '$base      ${adh.onTargetDays} / ${adh.elapsedDays} days on target';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final units = widget.app.data.settings['units'] as String? ?? 'kg';
    final mode = widget.calibration['mode'] as String? ?? 'observe';
    final today = todayStr(widget.app.data.settings);
    final adherence = mode == 'controlled'
        ? computeControlledAdherenceDetail(widget.app.data, widget.calibration, today)
        : const ControlledAdherence(onTargetDays: 0, elapsedDays: 0);
    // The AI picks the one decisive move. "rerun" is reserved for a
    // genuinely inconclusive study (confidence < 50) — a conclusive
    // calibration always resolves to a real decision, never "go do it
    // again". Without a report, fall back to the old mode/adherence rule.
    final String action;
    if (_report != null) {
      action = (!_report!.confident || _report!.verdictAction == 'rerun')
          ? 'rerun'
          : (_report!.verdictAction == 'hold' ? 'hold' : 'adjust_plan');
    } else {
      action = (mode == 'controlled' && adherence.fraction >= controlledApplyThreshold) ? 'adjust_plan' : 'hold';
    }

    if (_loading && _report == null) {
      return _GeneratingRead(series: _weighInSeries);
    }

    final series = _weighInSeries;
    final headline = (_report?.headline.isNotEmpty ?? false) ? _report!.headline : _fallbackHeadline(result);
    final reason = (_report?.narrative.isNotEmpty ?? false)
        ? _report!.narrative
        : (result.explanations.isNotEmpty ? result.explanations.first : _fallbackHeadline(result));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '14-DAY CALIBRATION · ${mode == 'controlled' ? 'CONTROLLED' : 'OBSERVE'} · COMPLETE',
          style: mono(fontSize: 9.5, fontWeight: FontWeight.w700, color: T.faint).copyWith(letterSpacing: 1.4),
        ),
        if (series.length >= 2) ...[
          const SizedBox(height: 16),
          _WeighInSparkline(series: series),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 14),
        Text(_statLine(result, units, mode, adherence), style: mono(fontSize: 9.5, color: T.faint)),
        const SizedBox(height: 22),
        Text(headline, style: Type.finding),
        Container(width: 46, height: 1, color: T.line, margin: const EdgeInsets.symmetric(vertical: 17)),
        Text(reason, style: Type.body.copyWith(color: T.muted)),
        if (_report != null) ...[
          const SizedBox(height: 15),
          _ConfidenceLine(confident: _report!.confident, mode: mode, adherence: adherence),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(fontSize: 11.5, color: T.danger)),
        ],
        if (_applied == null && (_report?.nextStep ?? '').isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('DO THIS NEXT', style: mono(fontSize: 8.5, fontWeight: FontWeight.w800, color: T.faint).copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 7),
          Text(_report!.nextStep, style: Type.body.copyWith(fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 22),
        if (_applied != null)
          _AppliedCard(info: _applied!, units: units, onDone: () => _finish(context))
        else if (action == 'adjust_plan')
          _WhatChanges(
            preview: computePlanApplyPreview(widget.app.data, widget.calibration, result),
            units: units,
            report: _report,
            onApply: _applyToPlan,
            onDone: () => _finish(context),
          )
        else if (action == 'hold')
          _BigButton(label: 'Got it — keep my plan', color: T.lav, fg: T.lavInk, onTap: () => _finish(context))
        else
          _VerdictAction(
            onRerun: () => _startFresh('controlled'),
            onContinue: _continue,
            onFinish: () => _finish(context),
          ),
        if (_report != null) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _openChat,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(border: Border.all(color: T.line), borderRadius: BorderRadius.circular(999)),
              alignment: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline, size: 13, color: T.muted),
                const SizedBox(width: 7),
                Text('Ask about this result', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.muted)),
              ]),
            ),
          ),
        ],
        ..._retentionNotice(today),
      ],
    );
  }

  /// The auto-clear warning — this study stays reachable from the Weight
  /// page for [calibrationRetentionDays] after it finished, then it's gone.
  List<Widget> _retentionNotice(String today) {
    final left = daysUntilCalibrationCleared(widget.calibration, today);
    if (left == null) return const [];
    final text = left <= 0
        ? 'This study clears today — apply it now if you want to keep the numbers.'
        : left == 1
            ? 'This study clears tomorrow. Until then you can reopen it from your Weight page.'
            : 'This study clears in $left days. Until then you can reopen it from your Weight page.';
    return [
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.schedule, size: 12, color: T.faint),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: mono(fontSize: 9.5, color: T.faint).copyWith(height: 1.5))),
      ]),
    ];
  }

  /// "Done" / "Keep my plan as is" — just leaves the screen. The study
  /// stays on the Weight page until it auto-clears (see [_retentionNotice]);
  /// nothing is erased here.
  void _finish(BuildContext context) => Navigator.of(context).pop();
}

/// The one honest line about how much to trust the finding — worded, not
/// metered. Green when the logging behind the read was near-complete, amber
/// when it has gaps and the number is really just a direction.
class _ConfidenceLine extends StatelessWidget {
  final bool confident;
  final String mode;
  final ControlledAdherence adherence;
  const _ConfidenceLine({required this.confident, required this.mode, required this.adherence});

  @override
  Widget build(BuildContext context) {
    final color = confident ? T.success : _amber;
    // 14 days of daily weigh-ins and food logs is a real dataset — when the
    // logging held up, the finding is a call, not a guess, and this line
    // says so plainly rather than hedging. It only softens to "re-run" when
    // the data genuinely wasn't there.
    final text = confident
        ? (mode == 'controlled' && adherence.elapsedDays > 0
            ? 'Called from 14 days of logs — ${adherence.onTargetDays}/${adherence.elapsedDays} days on target.'
            : 'Called from 14 days of daily weigh-ins and food logs.')
        : 'Logging this round was too thin for a firm call — re-run to get one.';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(top: 5, right: 8),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      Expanded(child: Text(text, style: mono(fontSize: 9.5, color: T.faint).copyWith(height: 1.5))),
    ]);
  }
}

/// Shown on every visit after the plan change was applied — the frozen
/// numbers from `calibration.result.applied`, not a fresh preview (which
/// would re-derive against the now-updated plan and drift). No action but
/// "Done".
class _AppliedCard extends StatelessWidget {
  final Map<String, dynamic> info;
  final String units;
  final VoidCallback onDone;
  const _AppliedCard({required this.info, required this.units, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final tdee = (info['tdee'] as num?)?.round();
    final goal = (info['calorieGoal'] as num?)?.round();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.check_circle, size: 15, color: T.success),
        const SizedBox(width: 7),
        Text('Applied to your plan', style: Type.body.copyWith(fontWeight: FontWeight.w700, color: T.success)),
      ]),
      const SizedBox(height: 12),
      if (goal != null) _line('Daily calorie target', '$goal kcal'),
      if (tdee != null) _line('Maintenance (TDEE)', '$tdee kcal'),
      const SizedBox(height: 14),
      Center(child: GestureDetector(onTap: onDone, child: Text('Done', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.muted)))),
    ]);
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 12, color: T.muted)),
          Text(value, style: mono(fontSize: 12.5, fontWeight: FontWeight.w800, color: T.text)),
        ]),
      );
}

/// The apply case — a study clean enough to re-anchor the plan. The plan
/// change is the whole point, so it leads; "keep my plan as is" is a link
/// under it. When the AI's moderated TDEE meaningfully differs from the
/// straight-line one, that's the default and the mechanical one is offered
/// as the alternate.
class _WhatChanges extends StatelessWidget {
  final PlanApplyPreview preview;
  final String units;
  final CalibrationAiReport? report;
  final Future<void> Function(PlanApplyPreview, {int? tdeeOverride}) onApply;
  final VoidCallback onDone;
  const _WhatChanges({
    required this.preview,
    required this.units,
    required this.report,
    required this.onApply,
    required this.onDone,
  });

  int? get _tempered {
    final t = report?.temperedTdee;
    if (t == null) return null;
    return (t - preview.newTdee).abs() > 25 ? t : null;
  }

  @override
  Widget build(BuildContext context) {
    final tempered = _tempered;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('WHAT CHANGES', style: mono(fontSize: 8.5, fontWeight: FontWeight.w800, color: T.faint).copyWith(letterSpacing: 1.2)),
      const SizedBox(height: 10),
      _diffRow('Daily calorie target', preview.oldCalorieGoal, preview.newCalorieGoal, 'kcal', last: false),
      _diffRow('Maintenance (TDEE)', preview.oldTdee, tempered ?? preview.newTdee, 'kcal', last: true),
      if (tempered != null && (report?.temperedRationale ?? '').isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(report!.temperedRationale, style: Type.caption),
      ],
      const SizedBox(height: 16),
      _BigButton(
        label: 'Update my plan',
        color: T.accent,
        fg: T.accentInk,
        onTap: () => onApply(preview, tdeeOverride: tempered),
      ),
      if (tempered != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: GestureDetector(
              onTap: () => onApply(preview),
              child: Text('Use the straight-line estimate (${preview.newTdee}) instead',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.muted)),
            ),
          ),
        ),
      const SizedBox(height: 8),
      Center(child: GestureDetector(onTap: onDone, child: Text('Keep my plan as is', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.muted)))),
    ]);
  }

  Widget _diffRow(String label, num oldV, num newV, String unit, {required bool last}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: T.line))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: T.muted)),
        Row(children: [
          Text('${oldV.round()}', style: mono(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.faint).copyWith(decoration: TextDecoration.lineThrough)),
          const SizedBox(width: 7),
          Text('${newV.round()} $unit', style: mono(fontSize: 12.5, fontWeight: FontWeight.w800, color: T.accent)),
        ]),
      ]),
    );
  }
}

/// The inconclusive case only — the AI's confidence came back below 50
/// because the logging was genuinely too thin to call. A conclusive study
/// never lands here; it resolves to `adjust_plan` or `hold`. Continue /
/// Done stay as links below.
class _VerdictAction extends StatelessWidget {
  final VoidCallback onRerun;
  final VoidCallback onContinue;
  final VoidCallback onFinish;
  const _VerdictAction({required this.onRerun, required this.onContinue, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _BigButton(label: 'Re-run the 14 days', color: T.lav, fg: T.lavInk, onTap: onRerun),
      const SizedBox(height: 12),
      Center(
        child: GestureDetector(
          onTap: onContinue,
          child: Text('Continue calibrating (+$calibrationExtensionDays days)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.muted)),
        ),
      ),
      const SizedBox(height: 10),
      Center(child: GestureDetector(onTap: onFinish, child: Text('Done', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.muted)))),
    ]);
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color fg;
  final VoidCallback onTap;
  const _BigButton({required this.label, required this.color, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: fg)),
      ),
    );
  }
}

/// The weigh-in trace under the overline — a bare line that draws itself in
/// left-to-right once, with the last point marked in accent. Deliberately
/// axis-less and label-less: it's a texture that says "here's the fortnight
/// the finding is built on," not a chart to read values off.
class _WeighInSparkline extends StatefulWidget {
  final List<double> series;
  const _WeighInSparkline({required this.series});

  @override
  State<_WeighInSparkline> createState() => _WeighInSparklineState();
}

class _WeighInSparklineState extends State<_WeighInSparkline> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _SparkPainter(series: widget.series, progress: Curves.easeOut.transform(_c.value)),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> series;
  final double progress;
  final bool skeleton;
  _SparkPainter({required this.series, required this.progress, this.skeleton = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;
    final lo = series.reduce((a, b) => a < b ? a : b);
    final hi = series.reduce((a, b) => a > b ? a : b);
    final rng = (hi - lo).abs() < 1e-9 ? 1.0 : (hi - lo);
    final dx = size.width / (series.length - 1);
    Offset at(int i) => Offset(i * dx, size.height - ((series[i] - lo) / rng) * (size.height - 8) - 4);

    final full = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < series.length; i++) {
      full.lineTo(at(i).dx, at(i).dy);
    }

    if (!skeleton && progress > 0.995) {
      final area = Path.from(full)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [T.muted.withValues(alpha: 0.14), T.muted.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }

    final metric = full.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = skeleton ? T.line : T.muted,
    );

    if (!skeleton && progress > 0.995) {
      canvas.drawCircle(at(series.length - 1), 3.2, Paint()..color = T.accent);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.progress != progress || old.series != series || old.skeleton != skeleton;
}

/// The generating state: a skeleton of the finding — overline, trace,
/// headline, reasoning — under a slow diagonal wash of the AI palette, with
/// a pulsing pip beside "reading your 14 days". Subtle on purpose; it reads
/// as the screen composing itself, not a spinner blocking it.
class _GeneratingRead extends StatefulWidget {
  final List<double> series;
  const _GeneratingRead({required this.series});

  @override
  State<_GeneratingRead> createState() => _GeneratingReadState();
}

class _GeneratingReadState extends State<_GeneratingRead> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2100));

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double? w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    final skeleton = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(120, 9),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: CustomPaint(painter: _SparkPainter(series: widget.series, progress: 1, skeleton: true)),
        ),
        const SizedBox(height: 10),
        _bar(190, 8),
        const SizedBox(height: 24),
        FractionallySizedBox(widthFactor: 0.96, child: _bar(null, 18)),
        const SizedBox(height: 9),
        FractionallySizedBox(widthFactor: 0.86, child: _bar(null, 18)),
        const SizedBox(height: 9),
        FractionallySizedBox(widthFactor: 0.52, child: _bar(null, 18)),
        const SizedBox(height: 18),
        _bar(46, 1),
        const SizedBox(height: 18),
        FractionallySizedBox(widthFactor: 0.97, child: _bar(null, 10)),
        const SizedBox(height: 8),
        FractionallySizedBox(widthFactor: 0.92, child: _bar(null, 10)),
        const SizedBox(height: 8),
        FractionallySizedBox(widthFactor: 0.68, child: _bar(null, 10)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRect(
          child: Stack(children: [
            skeleton,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => LayoutBuilder(builder: (context, cns) {
                    final w = cns.maxWidth;
                    final band = w * 0.55;
                    final x = -band + _c.value * (w + band);
                    return Stack(children: [
                      Positioned(
                        left: x,
                        top: 0,
                        bottom: 0,
                        width: band,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                aiColor1.withValues(alpha: 0),
                                aiColor2.withValues(alpha: 0.13),
                                aiColor3.withValues(alpha: 0.10),
                                aiColor1.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.45, 0.62, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              final p = v < 0.5 ? v * 2 : (1 - v) * 2; // 0→1→0 triangle
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: T.lav.withValues(alpha: 0.25 + 0.6 * p),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text('reading your 14 days of logs & weigh-ins', style: mono(fontSize: 10, color: T.faint)),
        ]),
      ],
    );
  }
}

/// Shown once, on/after day 7 of a running window — an AI read of days 1-7
/// against the baseline week, catching a window that's drifted into
/// measuring a stricter-than-normal routine before the second half is
/// wasted. Marks `calibration.day7Seen` once resolved so it never re-nags.
class _MidpointCheckCard extends StatefulWidget {
  final AppState app;
  final AppController controller;
  final Map<String, dynamic> calibration;
  final VoidCallback onChanged;
  const _MidpointCheckCard({required this.app, required this.controller, required this.calibration, required this.onChanged});

  @override
  State<_MidpointCheckCard> createState() => _MidpointCheckCardState();
}

class _MidpointCheckCardState extends State<_MidpointCheckCard> {
  final _service = CalibrationInsightService();
  bool _loading = true;
  CalibrationMidpoint? _read;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final cached = widget.calibration['day7Read'];
    if (cached is Map) {
      setState(() {
        _read = CalibrationMidpoint.fromCache(Map<String, dynamic>.from(cached));
        _loading = false;
      });
      return;
    }
    if (!CalibrationInsightService.isConfigured) {
      setState(() => _loading = false);
      return;
    }
    try {
      final today = todayStr(widget.app.data.settings);
      final read = await _service.midpoint(buildCalibrationDigest(widget.app.data, widget.calibration, today));
      if (!mounted) return;
      await widget.controller.update('calibration', (prev) {
        final next = Map<String, dynamic>.from(prev as Map);
        next['day7Read'] = read.toJson();
        return next;
      });
      setState(() {
        _read = read;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss() async {
    await widget.controller.update('calibration', (prev) {
      final next = Map<String, dynamic>.from(prev as Map);
      next['day7Seen'] = true;
      return next;
    });
    widget.onChanged();
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.surface,
        title: const Text('Restart the calibration?'),
        content: const Text('This clears the current window. Start a fresh one whenever you\'re ready to be observed as normal.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Restart', style: TextStyle(color: T.danger))),
        ],
      ),
    );
    if (ok != true) return;
    // Clears the window entirely so the next thing the user sees is a fresh
    // "start a calibration" CTA — a true restart, not a salvaged early end.
    await widget.controller.update('calibration', (_) => null);
    if (mounted) Navigator.of(context).pop();
    widget.onChanged();
  }

  Future<void> _switchControlled() async {
    final today = todayStr(widget.app.data.settings);
    // Bypasses the usual 7-day mode lock on purpose — acting on the
    // midpoint check's own recommendation, not a free mid-window switch.
    await widget.controller.update('calibration', (prev) {
      final next = Map<String, dynamic>.from(prev as Map);
      next['mode'] = 'controlled';
      next['modeSince'] = today;
      next['day7Seen'] = true;
      return next;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _read == null) return const SizedBox.shrink();
    final r = _read!;
    final onTrack = r.status == MidpointStatus.onTrack;
    final amber = const Color(0xFFFFC44B);
    final tint = onTrack ? T.success : amber;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(T.rL),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.auto_awesome, size: 12, color: tint),
            const SizedBox(width: 6),
            Text('MIDPOINT CHECK', style: mono(fontSize: 9, fontWeight: FontWeight.w800, color: tint).copyWith(letterSpacing: 0.6)),
          ]),
          Text('shown once', style: mono(fontSize: 8.5, color: T.faint)),
        ]),
        const SizedBox(height: 9),
        Text(r.message, style: Type.body),
        const SizedBox(height: 11),
        Row(children: [
          if (r.status == MidpointStatus.restart) ...[
            Expanded(child: _btn('Restart', T.surface2, T.text, _restart)),
            const SizedBox(width: 8),
            Expanded(child: _btn('Keep going', tint, T.bg, _dismiss)),
          ] else if (r.status == MidpointStatus.switchMode) ...[
            Expanded(child: _btn('Switch to Controlled', tint, T.bg, _switchControlled)),
            const SizedBox(width: 8),
            Expanded(child: _btn('Keep going', T.surface2, T.text, _dismiss)),
          ] else
            Expanded(child: _btn('Got it', tint, T.bg, _dismiss)),
        ]),
      ]),
    );
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }
}
