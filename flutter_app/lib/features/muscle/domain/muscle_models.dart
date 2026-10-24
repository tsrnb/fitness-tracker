import '../../../shared/lib/helpers.dart';

/// Training-experience bands. The weekly lean-gain corridor is a guidance
/// band (secondary-source figures, they vary), not a promise — see the
/// copy on the Gain tab.
class MuscleLevel {
  final String key;
  final String label;
  final String years;
  final String blurb;
  final double lo; // kg per week
  final double hi;
  const MuscleLevel(this.key, this.label, this.years, this.blurb, this.lo, this.hi);

  String get range => '${_trim(lo)}–${_trim(hi)}';
  double get mid => (lo + hi) / 2;

  static String _trim(double v) => v.toStringAsFixed(v < 0.1 ? 2 : (v * 10 == (v * 10).roundToDouble() ? 1 : 2));
}

const muscleLevels = [
  MuscleLevel('beginner', 'Beginner', 'Under 1 year', 'New to lifting, or coming back after a long break. Gains come fastest here.', 0.25, 0.6),
  MuscleLevel('intermediate', 'Intermediate', '1 to 3 years', 'Training steadily. Progress is slower and needs a plan.', 0.1, 0.3),
  MuscleLevel('advanced', 'Advanced', '3+ years', 'Close to your genetic ceiling. Gains are small and slow.', 0.04, 0.15),
];

MuscleLevel muscleLevelOf(String? key) => muscleLevels.firstWhere((l) => l.key == key, orElse: () => muscleLevels[1]);

/// Days between tape checks.
const tapeIntervalDays = 7;

const tapeSites = [
  ('arm', 'Arm', 'Flexed or relaxed, mid-bicep'),
  ('chest', 'Chest', 'Around the nipple line'),
  ('waist', 'Waist', 'At the navel, relaxed'),
  ('thigh', 'Thigh', 'Mid-thigh, standing'),
];

/// Starting values the stepper jumps to the first time a site is touched.
const tapeDefaults = {'arm': 35.0, 'chest': 98.0, 'waist': 81.0, 'thigh': 57.0};

class TapeEntry {
  final String date;
  final Map<String, double> cm; // site -> centimetres (only sites measured)
  const TapeEntry(this.date, this.cm);

  factory TapeEntry.fromJson(Map<String, dynamic> j) => TapeEntry(
        j['date'] as String,
        {for (final s in tapeSites) if (j[s.$1] is num) s.$1: (j[s.$1] as num).toDouble()},
      );

  Map<String, dynamic> toJson() => {'date': date, ...cm};
}

/// Everything the Muscle feature persists for one user (AppData key
/// `muscle`). `null` in AppData means the first-run setup hasn't happened.
class MuscleProfile {
  final String level;
  final List<String> tracked;
  final String setupDate;
  final double goalGainKg;
  final List<TapeEntry> tape;
  final List<Map<String, dynamic>> chats;

  const MuscleProfile({
    required this.level,
    required this.tracked,
    required this.setupDate,
    required this.goalGainKg,
    this.tape = const [],
    this.chats = const [],
  });

  MuscleLevel get levelInfo => muscleLevelOf(level);

  factory MuscleProfile.fromJson(Map<String, dynamic> j) => MuscleProfile(
        level: j['level'] as String? ?? 'intermediate',
        tracked: List<String>.from(j['tracked'] ?? const []),
        setupDate: j['setupDate'] as String? ?? '',
        goalGainKg: (j['goalGainKg'] as num?)?.toDouble() ?? 2.0,
        tape: [for (final t in (j['tape'] as List? ?? const [])) TapeEntry.fromJson(Map<String, dynamic>.from(t))],
        chats: [for (final c in (j['chats'] as List? ?? const [])) Map<String, dynamic>.from(c)],
      );

  Map<String, dynamic> toJson() => {
        'level': level,
        'tracked': tracked,
        'setupDate': setupDate,
        'goalGainKg': goalGainKg,
        'tape': tape.map((t) => t.toJson()).toList(),
        'chats': chats,
      };

  MuscleProfile copyWith({String? level, List<String>? tracked, double? goalGainKg, List<TapeEntry>? tape, List<Map<String, dynamic>>? chats}) =>
      MuscleProfile(
        level: level ?? this.level,
        tracked: tracked ?? this.tracked,
        setupDate: setupDate,
        goalGainKg: goalGainKg ?? this.goalGainKg,
        tape: tape ?? this.tape,
        chats: chats ?? this.chats,
      );
}

// ---------------------------------------------------------------------------
// Weight pace
// ---------------------------------------------------------------------------

/// Least-squares slope of weight against date over the last [windowDays],
/// in kg per week. Averages same-day readings first so a day with three
/// weigh-ins doesn't outvote the others. Null when there isn't enough to
/// say anything (under 3 distinct days, or under a week of spread).
double? weightPaceKgPerWeek(List<Map<String, dynamic>> weight, String today, {int windowDays = 28}) {
  final byDay = <int, List<double>>{};
  for (final w in weight) {
    final age = daysBetween(w['date'] as String, today);
    if (age < 0 || age >= windowDays) continue;
    (byDay[-age] ??= []).add((w['weight'] as num).toDouble());
  }
  if (byDay.length < 3) return null;
  final xs = byDay.keys.toList()..sort();
  if (xs.last - xs.first < 7) return null;
  final ys = [for (final x in xs) byDay[x]!.reduce((a, b) => a + b) / byDay[x]!.length];
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var sxy = 0.0, den = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  if (den == 0) return null;
  return sxy / den * 7;
}

enum PaceState { tooSlow, onPace, fast }

PaceState paceState(double kgPerWeek, MuscleLevel l) => kgPerWeek < l.lo ? PaceState.tooSlow : (kgPerWeek > l.hi ? PaceState.fast : PaceState.onPace);

/// Weight on or just before [date]; falls back to the first reading.
double? weightOnOrBefore(List<Map<String, dynamic>> weight, String date) {
  if (weight.isEmpty) return null;
  Map<String, dynamic>? best;
  for (final w in weight) {
    if ((w['date'] as String).compareTo(date) <= 0) best = w;
  }
  return ((best ?? weight.first)['weight'] as num).toDouble();
}

// ---------------------------------------------------------------------------
// Tape
// ---------------------------------------------------------------------------

class TapeVerdict {
  final String label; // Mostly lean | Mixed | Mostly fat | Within tape error
  final String detail;
  final String tone; // ok | warn | bad | neutral
  final Map<String, double> deltas;
  final int days;
  const TapeVerdict(this.label, this.detail, this.tone, this.deltas, this.days);
}

enum TapeStage { none, baselineOnly, enough }

TapeStage tapeStage(List<TapeEntry> tape) => tape.isEmpty ? TapeStage.none : (tape.length < 2 ? TapeStage.baselineOnly : TapeStage.enough);

/// Days since the newest entry; null when there is none.
int? daysSinceTape(List<TapeEntry> tape, String today) => tape.isEmpty ? null : daysBetween(tape.last.date, today);

bool tapeDue(List<TapeEntry> tape, String today) {
  final d = daysSinceTape(tape, today);
  return d != null && d >= tapeIntervalDays;
}

/// Newest entry compared with the first. Null when the two don't share a
/// waist plus an arm or chest reading.
TapeVerdict? tapeVerdict(List<TapeEntry> tape) {
  if (tape.length < 2) return null;
  final a = tape.first, b = tape.last;
  final d = <String, double>{
    for (final s in tapeSites)
      if (a.cm[s.$1] != null && b.cm[s.$1] != null) s.$1: b.cm[s.$1]! - a.cm[s.$1]!,
  };
  final up = [d['arm'], d['chest']].whereType<double>().toList();
  final w = d['waist'];
  if (up.isEmpty || w == null) return null;
  final u = up.reduce((x, y) => x + y) / up.length;
  final days = daysBetween(a.date, b.date);
  if (u.abs() < 0.5 && w.abs() < 0.5) {
    return TapeVerdict('Within tape error', 'Changes are under 0.5 cm. Keep going and check again.', 'neutral', d, days);
  }
  if (u >= 0.5 && u >= 2 * (w < 0.1 ? 0.1 : w)) {
    return TapeVerdict('Mostly lean', 'Arms and chest are growing at least 2× faster than the waist.', 'ok', d, days);
  }
  if (w >= u) {
    return TapeVerdict('Mostly fat', 'Your waist is growing as fast as your arms and chest. Consider a smaller surplus.', 'bad', d, days);
  }
  return TapeVerdict('Mixed', 'Some of the gain is muscle and some is fat. A smaller surplus would tilt it.', 'warn', d, days);
}

// ---------------------------------------------------------------------------
// Lifts
// ---------------------------------------------------------------------------

class LiftPoint {
  final String date;
  final int e1rm;
  final double topWeight;
  final int topReps;
  final double volume; // sum of weight × reps across the session
  const LiftPoint(this.date, this.e1rm, this.topWeight, this.topReps, this.volume);
}

/// One point per logged session of [name], oldest first. Sessions with no
/// valid set are dropped.
List<LiftPoint> liftSeries(Map<String, dynamic> history, String name) {
  final out = <LiftPoint>[];
  for (final e in List<dynamic>.from(history[name] ?? const [])) {
    var best = 0;
    double bw = 0;
    var br = 0;
    double vol = 0;
    for (final s in List<dynamic>.from(e['sets'] ?? const [])) {
      final w = (s['weight'] as num).toDouble();
      final r = (s['reps'] as num).toInt();
      if (w <= 0 || r <= 0) continue;
      vol += w * r;
      final est = epley(w, r);
      if (est > best) {
        best = est;
        bw = w;
        br = r;
      }
    }
    if (best > 0) out.add(LiftPoint(e['date'] as String, best, bw, br, vol));
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

class LiftSummary {
  final String name;
  final List<LiftPoint> points;
  const LiftSummary(this.name, this.points);

  bool get hasData => points.isNotEmpty;
  LiftPoint get last => points.last;
  int get e1rm => last.e1rm;

  /// Change in estimated 1RM from the previous session (0 with a single one).
  int get delta => points.length < 2 ? 0 : last.e1rm - points[points.length - 2].e1rm;

  /// Moved up since the previous session, and that session is recent enough
  /// to still count as "this week" (10 days of slack for a weekly lifter).
  bool progressed(String today) => delta > 0 && daysBetween(last.date, today) <= 10;

  /// New all-time high on the latest session.
  bool get isPr => points.length >= 2 && last.e1rm > points.sublist(0, points.length - 1).map((p) => p.e1rm).reduce((a, b) => a > b ? a : b);

  double? get volumeChangePct {
    if (points.length < 2) return null;
    final prev = points[points.length - 2].volume;
    return prev == 0 ? null : (last.volume - prev) / prev * 100;
  }

  /// Next session: same reps at +2.5 kg, or the same weight for one more rep.
  (double weight, int reps) get nextTarget => (last.topWeight + 2.5, last.topReps);
  (double weight, int reps) get nextAltTarget => (last.topWeight, last.topReps + 1);

  List<int> recentE1rm([int n = 8]) {
    final p = points.length > n ? points.sublist(points.length - n) : points;
    return [for (final x in p) x.e1rm];
  }
}

List<LiftSummary> summarizeLifts(Map<String, dynamic> history, List<String> names) =>
    [for (final n in names) LiftSummary(n, liftSeries(history, n))].where((l) => l.hasData).toList();

/// Logged exercises, most-trained first, for the setup picker and as the
/// default tracked set.
List<String> exercisesByUse(Map<String, dynamic> history) {
  final counts = <String, int>{
    for (final e in history.entries)
      if (liftSeries(history, e.key).isNotEmpty) e.key: liftSeries(history, e.key).length,
  };
  final names = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return names;
}

/// Total weight × reps over [days] ending [today], and over the [days]
/// before that — for the "volume load" headline.
(double current, double previous) volumeLoadWindows(Map<String, dynamic> history, List<String> names, String today, {int days = 7}) {
  double cur = 0, prev = 0;
  for (final n in names) {
    for (final p in liftSeries(history, n)) {
      final age = daysBetween(p.date, today);
      if (age < 0) continue;
      if (age < days) {
        cur += p.volume;
      } else if (age < days * 2) {
        prev += p.volume;
      }
    }
  }
  return (cur, prev);
}
