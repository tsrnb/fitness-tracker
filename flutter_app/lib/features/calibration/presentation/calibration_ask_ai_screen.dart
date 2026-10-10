import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../../nutrition/domain/ai_food_item.dart' show AiConfigException, AiParseException;
import '../data/calibration_insight_service.dart';
import '../domain/calibration_ai.dart';
import '../domain/calibration_digest.dart';
import '../domain/calibration_engine.dart';
import 'widgets/calibration_chat_sheet.dart';

/// User-triggered "look at everything so far" — the deep dive. Reached from
/// a button on the running dashboard. Hands the model the full raw record
/// for the window ([buildFullCalibrationContext]) and renders the
/// evidence-cited observations it returns, then opens a chat over the same
/// context.
///
/// The result is cached per day on `calibration.askAi[<date>]` with a
/// fingerprint of how much data existed when it ran — reopening the same
/// day is free, a new log invalidates it.
class CalibrationAskAiScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const CalibrationAskAiScreen({super.key, required this.app, required this.controller});

  @override
  State<CalibrationAskAiScreen> createState() => _CalibrationAskAiScreenState();
}

class _CalibrationAskAiScreenState extends State<CalibrationAskAiScreen> {
  final _service = CalibrationInsightService();
  bool _loading = true;
  String? _error;
  CalibrationDeepDive? _dive;

  AppState get _app => widget.controller.current;
  Map<String, dynamic> get _calibration => Map<String, dynamic>.from(_app.data.calibration!);
  String get _today => todayStr(_app.data.settings);

  /// Cheap "has the data changed" key — logged meal-days + weigh-ins in the
  /// window. A new food log or weigh-in bumps it, invalidating the cache.
  int _fingerprint() {
    final ctx = buildFullCalibrationContext(_app.data, _calibration, _today);
    final days = (ctx['days'] as List).where((d) => (d as Map)['logged'] == true).length;
    final weighins = (ctx['weighins'] as List).length;
    return days * 100 + weighins;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final cache = (_calibration['askAi'] as Map?)?[_today];
    if (!force && cache is Map && cache['fp'] == _fingerprint()) {
      setState(() {
        _dive = CalibrationDeepDive.fromCache(Map<String, dynamic>.from(cache));
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = buildFullCalibrationContext(_app.data, _calibration, _today);
      final dive = await _service.deepDive(ctx);
      if (!mounted) return;
      await widget.controller.update('calibration', (prev) {
        final next = Map<String, dynamic>.from(prev as Map);
        final store = Map<String, dynamic>.from((next['askAi'] as Map?) ?? {});
        store[_today] = {...dive.toJson(), 'fp': _fingerprint()};
        next['askAi'] = store;
        return next;
      });
      if (!mounted) return;
      setState(() {
        _dive = dive;
        _loading = false;
      });
    } on AiConfigException {
      if (!mounted) return;
      setState(() {
        _error = "Ask AI isn't set up for this build — see secrets.example.json.";
        _loading = false;
      });
    } on AiParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _openChat() {
    CalibrationChatSheet.show(
      context,
      aiContext: buildFullCalibrationContext(_app.data, _calibration, _today),
      suggestions: const [
        'If I keep this up, what will Day 14 say?',
        'Why is my weight bouncing around?',
        'Is my logging accurate enough?',
        'Should I switch to Controlled?',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = dayNumber(_calibration, _today);
    return pageScaffold(
      context: context,
      title: 'Ask AI · Day $day',
      onBack: () => Navigator.of(context).pop(),
      trailing: _loading
          ? null
          : IconButton(
              icon: Icon(Icons.refresh, size: 18, color: T.faint),
              onPressed: () => _load(force: true),
              tooltip: 'Re-run',
            ),
      child: _loading
          ? Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(children: [
                CircularProgressIndicator(color: T.lavAccent),
                const SizedBox(height: 16),
                Text('Reading every day of your window…', style: Type.caption),
              ]),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_error!, style: TextStyle(color: T.danger, fontSize: 13)),
                    const SizedBox(height: 14),
                    PrimaryButton(onTap: () => _load(force: true), child: const Text('Try again')),
                  ]),
                )
              : _content(),
    );
  }

  Widget _content() {
    final dive = _dive!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: T.lav.withValues(alpha: 0.12),
            border: Border.all(color: T.lav.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(T.rL),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome, size: 13, color: T.lavAccent),
              const SizedBox(width: 6),
              Text('READ OF DAYS 1–${dayNumber(_calibration, _today)}',
                  style: mono(fontSize: 9.5, fontWeight: FontWeight.w800, color: T.lavAccent).copyWith(letterSpacing: 0.5)),
            ]),
            if (dive.summary.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(dive.summary, style: Type.body),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        if (dive.observations.isEmpty)
          AppCard(child: Text('Not enough logged yet to call out anything specific. Check back in a few days.', style: Type.caption))
        else ...[
          const Eyebrow('What stands out'),
          for (final o in dive.observations) _ObservationCard(o: o),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          onTap: _openChat,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.chat_bubble_outline, size: 15),
            SizedBox(width: 7),
            Text('Ask a follow-up'),
          ]),
        ),
      ],
    );
  }
}

class _ObservationCard extends StatelessWidget {
  final CalibrationObservation o;
  const _ObservationCard({required this.o});

  ({Color color, String label}) get _meta => switch (o.kind) {
        ObservationKind.pattern => (color: T.accent, label: 'PATTERN'),
        ObservationKind.noise => (color: T.blue, label: 'LIKELY NOISE'),
        ObservationKind.watch => (color: const Color(0xFFFFC44B), label: 'WATCH'),
        ObservationKind.working => (color: T.success, label: 'WORKING'),
        ObservationKind.unknown => (color: T.lavAccent, label: 'NOTED'),
      };

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border(left: BorderSide(color: m.color, width: 2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.label, style: mono(fontSize: 8.5, fontWeight: FontWeight.w800, color: T.faint).copyWith(letterSpacing: 1)),
        const SizedBox(height: 5),
        if (o.headline.isNotEmpty)
          Text(o.headline, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.35)),
        if (o.body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(o.body, style: TextStyle(fontSize: 11.5, height: 1.5, color: T.muted)),
        ],
        if (o.evidence.isNotEmpty) ...[
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(7)),
            child: Text(o.evidence, style: mono(fontSize: 10, color: T.faint)),
          ),
        ],
      ]),
    );
  }
}
