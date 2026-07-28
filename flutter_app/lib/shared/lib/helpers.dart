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
