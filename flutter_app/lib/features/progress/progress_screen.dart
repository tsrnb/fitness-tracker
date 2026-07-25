import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/lib/helpers.dart';
import '../../app/app_state.dart';
import 'activity_progress_screen.dart';

class ProgressScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  final VoidCallback openActivity;
  const ProgressScreen({super.key, required this.app, required this.controller, required this.openActivity});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String tab = 'weight';
  String? exSel;
  String nutriPeriod = 'day';
  String nutriMetric = 'kcal';
  final wCtrl = TextEditingController();

  @override
  void dispose() {
    wCtrl.dispose();
    super.dispose();
  }

  void _logWeight() {
    final v = double.tryParse(wCtrl.text);
    if (v == null) return;
    final d = todayStr();
    final loggedAt = DateTime.now().millisecondsSinceEpoch;
    widget.controller.update('weight', (prev) {
      // Every log is kept as its own point (rather than overwriting the
      // day's earlier reading) so logging more than once in a day still
      // builds up a real trend instead of silently collapsing to one entry.
      final list = List<Map<String, dynamic>>.from(prev ?? []);
      list.add({'date': d, 'weight': v, 'loggedAt': loggedAt});
      list.sort((a, b) {
        final byDate = (a['date'] as String).compareTo(b['date'] as String);
        if (byDate != 0) return byDate;
        return ((a['loggedAt'] as num?) ?? 0).compareTo((b['loggedAt'] as num?) ?? 0);
      });
      return list;
    });
    widget.controller.update('settings', (prev) {
      final s = Map<String, dynamic>.from(prev ?? {});
      s['currentWeight'] = v;
      return s;
    });
    wCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.app.data.settings;
    final history = widget.app.data.history;
    exSel ??= history.keys.isNotEmpty ? history.keys.first : 'Barbell Bench Press';

    final weightData = widget.app.data.weight;
    final exHist = List<Map<String, dynamic>>.from(history[exSel] ?? []);
    final strengthData = exHist.map((e) {
      final sets = List<Map<String, dynamic>>.from(e['sets']);
      final best = sets.fold<int>(0, (m, x) => [m, epley((x['weight'] as num), (x['reps'] as num))].reduce((a, b) => a > b ? a : b));
      return {'d': fmtDay(e['date']), 'v': best};
    }).toList();

    final prs = history.entries.map((entry) {
      final hist = List<Map<String, dynamic>>.from(entry.value);
      int best = 0;
      num bestW = 0;
      for (final e in hist) {
        for (final x in List<Map<String, dynamic>>.from(e['sets'])) {
          final oneRm = epley(x['weight'] as num, x['reps'] as num);
          if (oneRm > best) best = oneRm;
          if ((x['weight'] as num) > bestW) bestW = x['weight'] as num;
        }
      }
      return {'n': entry.key, 'best': best, 'bestW': bestW};
    }).where((p) => (p['best'] as int) > 0).toList()
      ..sort((a, b) => (b['best'] as int).compareTo(a['best'] as int));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
            SizedBox(height: 8),
        PillTabs(
          options: const [MapEntry('weight', 'Weight'), MapEntry('strength', 'Strength'), MapEntry('nutrition', 'Nutrition'), MapEntry('activity', 'Activity')],
          value: tab,
          onChange: (v) => setState(() => tab = v),
          scroll: true,
        ),
        if (tab == 'weight') ..._weightTab(weightData, st),
        if (tab == 'strength') ..._strengthTab(strengthData, prs, history),
        if (tab == 'nutrition') ..._nutritionTab(widget.app.data.diet, st),
        if (tab == 'activity') ActivityProgressScreen(app: widget.app, openActivity: widget.openActivity),
      ],
    );
  }

  List<Widget> _weightTab(List<Map<String, dynamic>> weightData, Map<String, dynamic> st) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('Log weigh-in (${st['units'] ?? 'kg'})'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: wCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: mono(fontSize: 16, color: T.text),
                    decoration: InputDecoration(
                      hintText: 'e.g. 78.4',
                      hintStyle: TextStyle(color: T.faint),
                      filled: true,
                      fillColor: T.surface2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: T.accent)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _logWeight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: T.accent, borderRadius: BorderRadius.circular(T.pill)),
                    child: const Text('Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Weight trend'),
            if (weightData.length > 1)
              SizedBox(height: 200, child: _areaChart(weightData.map((w) => (w['weight'] as num).toDouble()).toList(), weightData.map((w) => fmtDay(w['date'])).toList()))
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Log two or more weigh-ins to see your trend.', style: TextStyle(color: T.muted, fontSize: 13))),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _strengthTab(List<Map<String, dynamic>> strengthData, List<Map<String, dynamic>> prs, Map<String, dynamic> history) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: history.keys.isEmpty
            ? Text('Log workouts to track strength.', style: TextStyle(color: T.muted, fontSize: 13))
            : SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: history.keys.map((n) {
                    final active = exSel == n;
                    return GestureDetector(
                      onTap: () => setState(() => exSel = n),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? T.hero : T.surface,
                          border: Border.all(color: active ? T.hero : T.line),
                          borderRadius: BorderRadius.circular(T.pill),
                        ),
                        alignment: Alignment.center,
                        child: Text(n, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : T.text)),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
      if (strengthData.isNotEmpty)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('Estimated 1RM · $exSel'),
              SizedBox(height: 200, child: _lineChart(strengthData.map((e) => (e['v'] as int).toDouble()).toList(), strengthData.map((e) => e['d'] as String).toList())),
            ],
          ),
        )
      else
        AppCard(child: Center(child: Padding(padding: EdgeInsets.all(12), child: Text('No logged sets yet for this lift.', style: TextStyle(color: T.muted, fontSize: 13))))),
      if (prs.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Personal records'),
                ...prs.take(6).map((p) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: T.surface2))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(children: [
                              const IconBubble(icon: Icon(Icons.emoji_events, size: 14, color: Colors.white), size: 30, background: T.hero),
                              const SizedBox(width: 10),
                              Expanded(child: Text(p['n'] as String, style: TextStyle(fontSize: 14, color: T.text), overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                          Text('${p['bestW']}kg · ~${p['best']} 1RM', style: mono(fontSize: 13, color: T.muted)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _nutritionTab(Map<String, dynamic> diet, Map<String, dynamic> st) {
    final Map<String, Map<String, int>> perDate = {};
    diet.forEach((date, meals) {
      final list = List<Map<String, dynamic>>.from(meals as List);
      int kcal = 0, protein = 0, carb = 0, fat = 0, fiber = 0;
      for (final m in list) {
        kcal += ((m['kcal'] as num?) ?? 0).toInt();
        protein += ((m['protein'] as num?) ?? 0).toInt();
        carb += ((m['carb'] as num?) ?? 0).toInt();
        fat += ((m['fat'] as num?) ?? 0).toInt();
        fiber += ((m['fiber'] as num?) ?? 0).toInt();
      }
      perDate[date] = {'kcal': kcal, 'protein': protein, 'carb': carb, 'fat': fat, 'fiber': fiber};
    });

    final dates = perDate.keys.toList()..sort();

    final periodPicker = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PillTabs(
        options: const [MapEntry('day', 'Day'), MapEntry('week', 'Week'), MapEntry('month', 'Month')],
        value: nutriPeriod,
        onChange: (v) => setState(() => nutriPeriod = v),
      ),
    );
    final metricPicker = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PillTabs(
        options: const [MapEntry('kcal', 'Calories'), MapEntry('protein', 'Protein'), MapEntry('carb', 'Carbs'), MapEntry('fat', 'Fat'), MapEntry('fiber', 'Fiber')],
        value: nutriMetric,
        onChange: (v) => setState(() => nutriMetric = v),
        scroll: true,
      ),
    );

    if (dates.isEmpty) {
      return [
        periodPicker,
        metricPicker,
        AppCard(child: Center(child: Padding(padding: const EdgeInsets.all(12), child: Text('Log meals to see nutrition trends.', style: TextStyle(color: T.muted, fontSize: 13))))),
      ];
    }

    const metricLabels = {'kcal': 'Calories', 'protein': 'Protein', 'carb': 'Carbs', 'fat': 'Fat', 'fiber': 'Fiber'};
    const goalKeys = {'kcal': 'calorieGoal', 'protein': 'proteinGoal', 'carb': 'carbGoal', 'fat': 'fatGoal', 'fiber': 'fiberGoal'};
    final metricLabel = metricLabels[nutriMetric]!;
    final goal = ((st[goalKeys[nutriMetric]!] as num?) ?? 0).toInt();

    List<String> labels = [];
    List<double> values = [];

    if (nutriPeriod == 'day') {
      final recent = dates.length > 30 ? dates.sublist(dates.length - 30) : dates;
      labels = recent.map((d) => fmtDay(d)).toList();
      values = recent.map((d) => (perDate[d]![nutriMetric] ?? 0).toDouble()).toList();
    } else if (nutriPeriod == 'week') {
      final Map<String, List<String>> buckets = {};
      for (final d in dates) {
        final dt = DateTime.parse(d);
        final monday = dt.subtract(Duration(days: dt.weekday - 1));
        final key = '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
        buckets.putIfAbsent(key, () => []).add(d);
      }
      final keys = buckets.keys.toList()..sort();
      labels = keys.map((k) => fmtDay(k)).toList();
      values = keys.map((k) {
        final ds = buckets[k]!;
        final sum = ds.fold<int>(0, (s, d) => s + (perDate[d]![nutriMetric] ?? 0));
        return sum / ds.length;
      }).toList();
    } else {
      final Map<String, List<String>> buckets = {};
      for (final d in dates) {
        buckets.putIfAbsent(d.substring(0, 7), () => []).add(d);
      }
      final keys = buckets.keys.toList()..sort();
      labels = keys;
      values = keys.map((k) {
        final ds = buckets[k]!;
        final sum = ds.fold<int>(0, (s, d) => s + (perDate[d]![nutriMetric] ?? 0));
        return sum / ds.length;
      }).toList();
    }

    String summary;
    if (goal > 0) {
      final isCeiling = nutriMetric == 'kcal';
      int hit = 0;
      for (final d in dates) {
        final v = perDate[d]![nutriMetric] ?? 0;
        if (isCeiling ? v <= goal : v >= goal) hit++;
      }
      final verb = isCeiling ? 'at or under goal' : 'at or above goal';
      summary = '$hit of ${dates.length} days $verb';
    } else {
      summary = 'Set a $metricLabel goal in Settings to track adherence.';
    }

    return [
      periodPicker,
      metricPicker,
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('$metricLabel trend'),
            if (values.length > 1)
              SizedBox(height: 200, child: _areaChart(values, labels))
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Log meals across more days to see your trend.', style: TextStyle(color: T.muted, fontSize: 13))),
              ),
            const SizedBox(height: 12),
            Text(summary, style: TextStyle(color: T.muted, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ];
  }

  Widget _areaChart(List<double> values, List<String> labels) {
    final minV = values.reduce((a, b) => a < b ? a : b) - 1;
    final maxV = values.reduce((a, b) => a > b ? a : b) + 1;
    return LineChart(
      LineChartData(
        minY: minV,
        maxY: maxV,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: T.surface2, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: _titlesData(labels),
        lineTouchData: _touchData(labels),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
            isCurved: true,
            color: T.accent,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [T.accent.withValues(alpha: 0.35), T.accent.withValues(alpha: 0)])),
          ),
        ],
      ),
    );
  }

  Widget _lineChart(List<double> values, List<String> labels) {
    final minV = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxV = values.reduce((a, b) => a > b ? a : b) + 2;
    return LineChart(
      LineChartData(
        minY: minV,
        maxY: maxV,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: T.surface2, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: _titlesData(labels),
        lineTouchData: _touchData(labels),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
            isCurved: true,
            color: T.accent,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  FlTitlesData _titlesData(List<String> labels) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (v, meta) => Text(v.round().toString(), style: TextStyle(color: T.faint, fontSize: 10)))),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 20,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.round();
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
            if (labels.length > 6 && i % (labels.length / 6).ceil() != 0) return const SizedBox.shrink();
            return Padding(padding: EdgeInsets.only(top: 4), child: Text(labels[i], style: TextStyle(color: T.faint, fontSize: 10)));
          },
        ),
      ),
    );
  }

  LineTouchData _touchData(List<String> labels) {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => T.surface,
        getTooltipItems: (spots) => spots
            .map((s) => LineTooltipItem('${s.y.round()}', TextStyle(color: T.text, fontWeight: FontWeight.w600)))
            .toList(),
      ),
    );
  }
}
