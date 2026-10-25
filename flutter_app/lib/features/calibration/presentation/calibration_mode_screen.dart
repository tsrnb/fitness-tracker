import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../data/calibration_insight_service.dart';
import '../domain/calibration_ai.dart';
import '../domain/calibration_digest.dart';
import '../domain/calibration_engine.dart';
import 'calibration_dashboard_screen.dart';
import '../../../shared/responsive.dart';

/// Mockup screen 05 — Observe vs. Controlled, plus a live preview of the
/// baseline that gets frozen into `calibration.baseline` the moment
/// "Begin" is tapped.
class CalibrationModeScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;

  /// Pre-selects a mode and marks it as a deliberate choice (so pre-flight
  /// won't override it) — set when the results screen sends the user
  /// straight into a fresh run, e.g. "Start a Controlled calibration" after
  /// an Observe study, or "Re-run the 14 days".
  final String? initialMode;
  const CalibrationModeScreen({super.key, required this.app, required this.controller, this.initialMode});

  @override
  State<CalibrationModeScreen> createState() => _CalibrationModeScreenState();
}

class _CalibrationModeScreenState extends State<CalibrationModeScreen> {
  late String mode = widget.initialMode ?? 'observe';
  bool _starting = false;

  final _service = CalibrationInsightService();
  bool _preflightLoading = true;
  CalibrationPreflight? _preflight;
  PreflightReadiness? _readiness;
  late bool _modeTouched = widget.initialMode != null;

  String? get _recommendedMode => _preflight?.recommendedMode ?? _readiness?.suggestedMode;

  @override
  void initState() {
    super.initState();
    _runPreflight();
  }

  Future<void> _runPreflight() async {
    final today = todayStr(widget.app.data.settings);
    _readiness = computePreflightReadiness(widget.app.data, today);
    // Deterministic default even before/without AI: recommend a mode.
    if (!_modeTouched) mode = _readiness!.suggestedMode;

    if (!CalibrationInsightService.isConfigured) {
      setState(() => _preflightLoading = false);
      return;
    }
    try {
      final p = await _service.preflight(buildPreflightDigest(widget.app.data, today));
      if (!mounted) return;
      setState(() {
        _preflight = p;
        if (!_modeTouched) mode = p.recommendedMode;
        _preflightLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _preflightLoading = false);
    }
  }

  Future<void> _begin() async {
    if (_starting) return;
    setState(() => _starting = true);
    final today = todayStr(widget.app.data.settings);
    final record = startCalibration(widget.app.data, today, mode);
    await widget.controller.update('calibration', (_) => record);
    if (!mounted) return;
    // `widget.controller.current`, not `widget.app` — the latter is a
    // snapshot frozen before the write just above, so its `data.calibration`
    // would still read back null on Dashboard's very first build (see the
    // long comment on `_CalibrationDashboardScreenState._app`).
    Navigator.of(context).pushReplacement(AppRoute(builder: (_) => CalibrationDashboardScreen(app: widget.controller.current, controller: widget.controller)));
  }

  @override
  Widget build(BuildContext context) {
    final today = todayStr(widget.app.data.settings);
    final baseline = computeBaseline(widget.app.data, today);
    final units = widget.app.data.settings['units'] as String? ?? 'kg';

    return pageScaffold(
      context: context,
      title: '',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How do you want to run this?', style: Type.h1),
          const SizedBox(height: 8),
          Text('Either way, we\'re just watching closely for 14 days — not judging.', style: Type.body),
          const SizedBox(height: 16),
          if (_preflightLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: T.faint)),
                const SizedBox(width: 9),
                Text('Checking your recent logging…', style: Type.caption),
              ]),
            )
          else if (_readiness != null) ...[
            _PreflightCard(readiness: _readiness!, preflight: _preflight),
            const SizedBox(height: 16),
          ],
          _ModeOption(
            icon: '👀',
            title: 'Observe my normal routine',
            sub: 'Eat and train like you normally would. Cheat meals included — we need to see the real pattern, not a cleaned-up one.',
            active: mode == 'observe',
            recommended: _recommendedMode == 'observe',
            onTap: () => setState(() {
              mode = 'observe';
              _modeTouched = true;
            }),
          ),
          const SizedBox(height: 10),
          _ModeOption(
            icon: '🎯',
            title: 'Run a controlled experiment',
            sub: 'Hold calories, protein, steps and training steady so there\'s less noise to sort through.',
            active: mode == 'controlled',
            recommended: _recommendedMode == 'controlled',
            onTap: () => setState(() {
              mode = 'controlled';
              _modeTouched = true;
            }),
          ),
          const SizedBox(height: 20),
          Eyebrow('Your starting model'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Captured now, compared against reality in 14 days.', style: Type.caption),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 14,
                  childAspectRatio: 2.6,
                  children: [
                    _baselineStat('${(baseline['intakeKcal'] as num).round()}', 'Est. intake / day'),
                    _baselineStat('${(baseline['expenditureKcal'] as num).round()}', 'Est. burn / day'),
                    _baselineStat('${(baseline['deficitKcal'] as num).round()}', 'Est. deficit / day'),
                    _baselineStat('${(baseline['expectedKgChange'] as num).toStringAsFixed(1)} $units', 'Expected in 14d'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(onTap: _begin, opacity: _starting ? 0.6 : 1, child: const Text('Begin — Day 1 of 14')),
        ],
      ),
    );
  }

  Widget _baselineStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: mono(fontSize: 15, fontWeight: FontWeight.w800, color: T.text)),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: T.faint, letterSpacing: 0.3)),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String icon;
  final String title;
  final String sub;
  final bool active;
  final bool recommended;
  final VoidCallback onTap;
  const _ModeOption({required this.icon, required this.title, required this.sub, required this.active, required this.onTap, this.recommended = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? T.accentDim : T.surface,
          border: Border.all(color: active ? T.accent : T.line),
          borderRadius: BorderRadius.circular(T.pill),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: active ? T.accent : T.surface2),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: T.text))),
                    if (recommended)
                      Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: T.lav.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                          child: Text('SUGGESTED', style: mono(fontSize: 7.5, fontWeight: FontWeight.w800, color: T.lavAccent).copyWith(letterSpacing: 0.5)),
                        ),
                      ),
                  ]),
                  Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub, style: TextStyle(fontSize: 11.5, color: T.muted, height: 1.45))),
                ],
              ),
            ),
            if (active)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The pre-flight read shown above the mode choice — a plain verdict on
/// whether the recent logging is solid enough to calibrate, with the raw
/// readiness counts as the always-present deterministic floor and the AI
/// summary layered on when available.
class _PreflightCard extends StatelessWidget {
  final PreflightReadiness readiness;
  final CalibrationPreflight? preflight;
  const _PreflightCard({required this.readiness, this.preflight});

  @override
  Widget build(BuildContext context) {
    final v = preflight?.verdict;
    final ok = v == null ? readiness.readyToCalibrate : v == PreflightVerdict.go;
    final tint = ok ? T.success : const Color(0xFFFFC44B);
    final foodPct = (readiness.foodRate * 100).round();

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
            Text('PRE-FLIGHT', style: mono(fontSize: 9, fontWeight: FontWeight.w800, color: tint).copyWith(letterSpacing: 0.6)),
          ]),
          Text('last ${readiness.windowDays} days', style: mono(fontSize: 8.5, color: T.faint)),
        ]),
        const SizedBox(height: 9),
        Text(
          preflight?.summary.isNotEmpty == true
              ? preflight!.summary
              : (ok
                  ? 'Your logging over the last ${readiness.windowDays} days ($foodPct% of days) is solid enough to calibrate.'
                  : 'Only $foodPct% of the last ${readiness.windowDays} days were logged — a week of tighter logging first would make the result mean more.'),
          style: Type.body,
        ),
        const SizedBox(height: 10),
        Row(children: [
          _stat('Food', '${readiness.foodLoggedDays}/${readiness.windowDays}'),
          _stat('Weigh-ins', '${readiness.weighInDays}/${readiness.windowDays}'),
          _stat('Weekends', '${readiness.weekendLoggedDays}/${readiness.weekendDays}'),
        ]),
        if ((preflight?.modeReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(preflight!.modeReason, style: Type.caption),
        ],
      ]),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: mono(fontSize: 13, fontWeight: FontWeight.w800, color: T.text)),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: T.faint, letterSpacing: 0.3)),
      ]),
    );
  }
}
