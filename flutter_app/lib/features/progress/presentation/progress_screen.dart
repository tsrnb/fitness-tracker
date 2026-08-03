import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/widgets/trend_chart.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../data/personal_records.dart';
import '../data/nutrition_stats_service.dart';
import 'activity_progress_screen.dart';
import 'daily_log_section.dart';

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
    final d = todayStr(widget.app.data.settings);
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
    widget.controller.patchSettings('currentWeight', v);
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

    final prs = computePersonalRecords(history);

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

  List<Widget> _strengthTab(List<Map<String, dynamic>> strengthData, List<PersonalRecord> prs, Map<String, dynamic> history) {
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
                              Expanded(child: Text(p.name, style: TextStyle(fontSize: 14, color: T.text), overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                          Text('${p.bestWeight}kg · ~${p.best} 1RM', style: mono(fontSize: 13, color: T.muted)),
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
    final perDate = nutritionTotalsByDate(diet);
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

    final series = nutritionSeries(perDate, dates, nutriPeriod, nutriMetric);
    final summary = nutritionAdherenceSummary(perDate, dates, nutriMetric, metricLabel, goal);

    return [
      periodPicker,
      metricPicker,
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('$metricLabel trend'),
              if (series.values.length > 1)
                SizedBox(height: 200, child: _areaChart(series.values, series.labels))
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
      ),
      DailyLogSection(app: widget.app, controller: widget.controller),
    ];
  }

  Widget _areaChart(List<double> values, List<String> labels) {
    final minV = values.reduce((a, b) => a < b ? a : b) - 1;
    final maxV = values.reduce((a, b) => a > b ? a : b) + 1;
    return TrendLineChart(values: values, labels: labels, filled: true, minY: minV, maxY: maxV);
  }

  Widget _lineChart(List<double> values, List<String> labels) {
    final minV = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxV = values.reduce((a, b) => a > b ? a : b) + 2;
    return TrendLineChart(values: values, labels: labels, minY: minV, maxY: maxV);
  }
}
