import 'package:intl/intl.dart';

// `settings['dayStartMinutes']` (0-1439, minutes since midnight) lets a day
// roll over at a time other than midnight — e.g. 6am, so a late-night
// session before then still counts toward the previous day. Defaults to 0
// (midnight) when unset.
String todayStr([Map<String, dynamic>? settings]) {
  final minutes = (settings?['dayStartMinutes'] as num?)?.toInt() ?? 0;
  final t = DateTime.now().subtract(Duration(minutes: minutes));
  return DateFormat('yyyy-MM-dd').format(t);
}

String fmtDay(String iso) {
  final d = DateTime.parse('${iso}T00:00:00');
  return DateFormat('MMM d').format(d);
}

String fmtFull() => DateFormat('EEEE, MMMM d').format(DateTime.now());

int epley(num w, num r) => (w * (1 + r / 30)).round();

int topReps(String range) => int.parse(range.split('-').last);
int lowReps(String range) => int.parse(range.split('-').first);

int round5(num n) => (n / 5).round() * 5;
int round10(num n) => (n / 10).round() * 10;

int daysBetween(String a, String b) {
  final da = DateTime.parse('${a}T00:00:00');
  final db = DateTime.parse('${b}T00:00:00');
  return db.difference(da).inDays;
}

num clamp(num n, num lo, num hi) => n < lo ? lo : (n > hi ? hi : n);

/// True if `history[name]`'s most recent entry is dated today — the same
/// "already logged today" check needed by both the Train screen (per
/// exercise) and the Dashboard (per today's scheduled exercise).
bool isLoggedToday(Map<String, dynamic> history, String name, String today) {
  final h = List<dynamic>.from(history[name] ?? []);
  return h.isNotEmpty && h.last['date'] == today;
}

/// Entries from a date-keyed map (`'yyyy-MM-dd' -> value`) falling within
/// the last [n] days up to and including [today].
List<MapEntry<String, dynamic>> lastNDaysEntries(Map<String, dynamic> map, String today, int n) {
  return map.entries.where((e) {
    final df = daysBetween(e.key, today);
    return df >= 0 && df < n;
  }).toList();
}
