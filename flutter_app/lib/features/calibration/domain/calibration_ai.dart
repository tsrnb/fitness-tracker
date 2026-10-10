// Typed shapes for the calibration AI surfaces, plus tolerant parsers from
// the model's JSON. Every parser fills sensible defaults rather than
// throwing on a missing field — a slightly thin response should still
// render, and the calling screens keep their deterministic fallback for a
// response that can't be parsed at all.

double _d(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int _i(dynamic v, [int fallback = 0]) => _d(v, fallback.toDouble()).round();

String _s(dynamic v, [String fallback = '']) => v is String ? v.trim() : fallback;

// ---------------------------------------------------------------------------
// End-of-window analysis
// ---------------------------------------------------------------------------

class CalibrationCause {
  final String name;
  final double kg; // absolute kg attributed to this cause
  final double share; // 0..1 of the total gap
  final String note;
  const CalibrationCause({required this.name, required this.kg, required this.share, required this.note});

  factory CalibrationCause.fromJson(Map<String, dynamic> m) => CalibrationCause(
        name: _s(m['name'], 'Factor'),
        kg: _d(m['kg']).abs(),
        share: _d(m['share']).clamp(0, 1).toDouble(),
        note: _s(m['note']),
      );

  Map<String, dynamic> toJson() => {'name': name, 'kg': kg, 'share': share, 'note': note};
}

class CalibrationAiReport {
  /// One-sentence verdict — the screen's headline. Names the biggest driver
  /// in plain language ("Your body burns about 240 more calories a day than
  /// your plan assumed"). Empty for older frozen reports and the
  /// deterministic fallback, which derive a headline from the gap instead.
  final String headline;
  final String narrative;

  /// The one decisive move — `'adjust_plan'` (the plan's numbers should
  /// change), `'hold'` (the plan is right, the fix is behavioural — no
  /// number change), or `'rerun'` (only when [confident] is false). Drives
  /// which action card the results screen shows.
  final String verdictAction;

  /// One imperative sentence — the single thing to do on closing the screen.
  final String nextStep;
  final List<CalibrationCause> causes; // ranked, most-likely first
  final int confidence; // 0..100
  final int? temperedTdee; // AI's moderated TDEE, may differ from the mechanical one
  final String temperedRationale;

  const CalibrationAiReport({
    this.headline = '',
    required this.narrative,
    this.verdictAction = '',
    this.nextStep = '',
    required this.causes,
    required this.confidence,
    this.temperedTdee,
    this.temperedRationale = '',
  });

  bool get confident => confidence >= 50;

  factory CalibrationAiReport.fromJson(Map<String, dynamic> m) {
    final rawCauses = (m['causes'] as List?) ?? const [];
    return CalibrationAiReport(
      headline: _s(m['headline'] ?? m['verdict']),
      narrative: _s(m['narrative'] ?? m['reply']),
      verdictAction: _s(m['verdictAction'] ?? m['action']).toLowerCase().replaceAll('-', '_'),
      nextStep: _s(m['nextStep'] ?? m['next_step']),
      causes: rawCauses
          .whereType<Map>()
          .map((c) => CalibrationCause.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      confidence: _i(m['confidence']).clamp(0, 100),
      temperedTdee: m['temperedTdee'] == null ? null : _i(m['temperedTdee']),
      temperedRationale: _s(m['temperedRationale']),
    );
  }

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'narrative': narrative,
        'verdictAction': verdictAction,
        'nextStep': nextStep,
        'causes': causes.map((c) => c.toJson()).toList(),
        'confidence': confidence,
        if (temperedTdee != null) 'temperedTdee': temperedTdee,
        'temperedRationale': temperedRationale,
      };
}

// ---------------------------------------------------------------------------
// Mid-calibration "Ask AI" deep dive
// ---------------------------------------------------------------------------

/// Drives the insight card's left-border colour and eyebrow.
enum ObservationKind { pattern, noise, watch, working, unknown }

ObservationKind _kindFrom(String raw) {
  switch (raw.toLowerCase().trim()) {
    case 'pattern':
      return ObservationKind.pattern;
    case 'noise':
      return ObservationKind.noise;
    case 'watch':
      return ObservationKind.watch;
    case 'working':
    case 'positive':
      return ObservationKind.working;
    default:
      return ObservationKind.unknown;
  }
}

class CalibrationObservation {
  final ObservationKind kind;
  final String headline;
  final String body;
  final String evidence; // short data citation, may be empty

  const CalibrationObservation({
    required this.kind,
    required this.headline,
    required this.body,
    this.evidence = '',
  });

  factory CalibrationObservation.fromJson(Map<String, dynamic> m) {
    final ev = m['evidence'];
    return CalibrationObservation(
      kind: _kindFrom(_s(m['type'] ?? m['kind'], 'pattern')),
      headline: _s(m['headline'] ?? m['title']),
      body: _s(m['body'] ?? m['detail']),
      evidence: ev is List ? ev.map((e) => _s(e)).where((e) => e.isNotEmpty).join(' · ') : _s(ev),
    );
  }
}

/// Whole deep-dive response: a one-line lede plus the ranked observations.
class CalibrationDeepDive {
  final String summary;
  final List<CalibrationObservation> observations;
  const CalibrationDeepDive({required this.summary, required this.observations});

  factory CalibrationDeepDive.fromJson(Map<String, dynamic> m) {
    final raw = (m['observations'] as List?) ?? (m['insights'] as List?) ?? const [];
    return CalibrationDeepDive(
      summary: _s(m['summary'] ?? m['reply']),
      observations: raw
          .whereType<Map>()
          .map((o) => CalibrationObservation.fromJson(Map<String, dynamic>.from(o)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'observations': observations
            .map((o) => {
                  'type': o.kind.name,
                  'headline': o.headline,
                  'body': o.body,
                  'evidence': o.evidence,
                })
            .toList(),
      };

  factory CalibrationDeepDive.fromCache(Map<String, dynamic> m) => CalibrationDeepDive.fromJson(m);
}

// ---------------------------------------------------------------------------
// Pre-flight
// ---------------------------------------------------------------------------

enum PreflightVerdict { go, tighten, window, unknown }

PreflightVerdict _verdictFrom(String raw) {
  switch (raw.toLowerCase().trim()) {
    case 'go':
      return PreflightVerdict.go;
    case 'tighten':
    case 'tighten_logging':
      return PreflightVerdict.tighten;
    case 'window':
    case 'pick_window':
      return PreflightVerdict.window;
    default:
      return PreflightVerdict.unknown;
  }
}

class CalibrationPreflight {
  final PreflightVerdict verdict;
  final String summary;
  final String recommendedMode; // 'observe' | 'controlled'
  final String modeReason;

  const CalibrationPreflight({
    required this.verdict,
    required this.summary,
    required this.recommendedMode,
    required this.modeReason,
  });

  factory CalibrationPreflight.fromJson(Map<String, dynamic> m) {
    final mode = _s(m['recommendedMode'] ?? m['mode'], 'observe').toLowerCase();
    return CalibrationPreflight(
      verdict: _verdictFrom(_s(m['verdict'], 'go')),
      summary: _s(m['summary'] ?? m['reply']),
      recommendedMode: mode == 'controlled' ? 'controlled' : 'observe',
      modeReason: _s(m['modeReason']),
    );
  }
}

// ---------------------------------------------------------------------------
// Mid-window (day 7) check
// ---------------------------------------------------------------------------

enum MidpointStatus { onTrack, restart, switchMode, unknown }

MidpointStatus _midFrom(String raw) {
  switch (raw.toLowerCase().trim()) {
    case 'on_track':
    case 'ontrack':
    case 'keep_going':
      return MidpointStatus.onTrack;
    case 'restart':
      return MidpointStatus.restart;
    case 'switch':
    case 'switch_mode':
    case 'controlled':
      return MidpointStatus.switchMode;
    default:
      return MidpointStatus.unknown;
  }
}

class CalibrationMidpoint {
  final MidpointStatus status;
  final String message;
  const CalibrationMidpoint({required this.status, required this.message});

  factory CalibrationMidpoint.fromJson(Map<String, dynamic> m) => CalibrationMidpoint(
        status: _midFrom(_s(m['status'], 'on_track')),
        message: _s(m['message'] ?? m['reply']),
      );

  Map<String, dynamic> toJson() => {'status': status.name, 'message': message};
  factory CalibrationMidpoint.fromCache(Map<String, dynamic> m) => CalibrationMidpoint(
        status: _midFrom(_s(m['status'], 'on_track')),
        message: _s(m['message']),
      );
}
