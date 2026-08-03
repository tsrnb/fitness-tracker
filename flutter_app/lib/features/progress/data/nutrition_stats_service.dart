import '../../../shared/lib/helpers.dart';
import '../../../shared/lib/macro_totals.dart';

/// Per-date kcal/protein/carb/fat/fiber totals across a `diet` map.
Map<String, Map<String, int>> nutritionTotalsByDate(Map<String, dynamic> diet) {
  final Map<String, Map<String, int>> perDate = {};
  diet.forEach((date, meals) {
    final list = List<Map<String, dynamic>>.from(meals as List);
    perDate[date] = sumMacros(list).toIntMap();
  });
  return perDate;
}

class NutritionSeries {
  final List<String> labels;
  final List<double> values;
  const NutritionSeries(this.labels, this.values);
}

/// Buckets [perDate] (keyed by every date in [sortedDates]) by day/week/month
/// for [metric] — day is a direct series, week/month average within each
/// bucket. [period] is one of 'day' | 'week' | 'month'.
NutritionSeries nutritionSeries(Map<String, Map<String, int>> perDate, List<String> sortedDates, String period, String metric) {
  if (period == 'day') {
    final recent = sortedDates.length > 30 ? sortedDates.sublist(sortedDates.length - 30) : sortedDates;
    return NutritionSeries(
      recent.map(fmtDay).toList(),
      recent.map((d) => (perDate[d]![metric] ?? 0).toDouble()).toList(),
    );
  }
  if (period == 'week') {
    final Map<String, List<String>> buckets = {};
    for (final d in sortedDates) {
      final dt = DateTime.parse(d);
      final monday = dt.subtract(Duration(days: dt.weekday - 1));
      final key = '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      buckets.putIfAbsent(key, () => []).add(d);
    }
    final keys = buckets.keys.toList()..sort();
    return NutritionSeries(
      keys.map(fmtDay).toList(),
      keys.map((k) {
        final ds = buckets[k]!;
        final sum = ds.fold<int>(0, (s, d) => s + (perDate[d]![metric] ?? 0));
        return sum / ds.length;
      }).toList(),
    );
  }
  final Map<String, List<String>> buckets = {};
  for (final d in sortedDates) {
    buckets.putIfAbsent(d.substring(0, 7), () => []).add(d);
  }
  final keys = buckets.keys.toList()..sort();
  return NutritionSeries(
    keys,
    keys.map((k) {
      final ds = buckets[k]!;
      final sum = ds.fold<int>(0, (s, d) => s + (perDate[d]![metric] ?? 0));
      return sum / ds.length;
    }).toList(),
  );
}

/// "$hit of $total days at/above (or at/under, for a ceiling metric like
/// kcal) goal" adherence summary across every date in [dates].
String nutritionAdherenceSummary(Map<String, Map<String, int>> perDate, List<String> dates, String metric, String metricLabel, int goal) {
  if (goal <= 0) return 'Set a $metricLabel goal in Settings to track adherence.';
  final isCeiling = metric == 'kcal';
  int hit = 0;
  for (final d in dates) {
    final v = perDate[d]![metric] ?? 0;
    if (isCeiling ? v <= goal : v >= goal) hit++;
  }
  final verb = isCeiling ? 'at or under goal' : 'at or above goal';
  return '$hit of ${dates.length} days $verb';
}
