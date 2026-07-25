import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/lib/helpers.dart';
import '../../app/app_state.dart';

class ActivityProgressScreen extends StatelessWidget {
  final AppState app;
  final VoidCallback openActivity;
  const ActivityProgressScreen({super.key, required this.app, required this.openActivity});

  @override
  Widget build(BuildContext context) {
    final today = todayStr();
    final entries = app.data.activity.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final stepData = entries.map((e) => {'d': fmtDay(e.key), 'v': ((e.value['steps'] ?? 0) as num).toDouble()}).toList();
    final kcalData = entries.map((e) => {'d': fmtDay(e.key), 'v': ((e.value['kcal'] ?? 0) as num).toDouble()}).toList();
    final last7 = entries.where((e) {
      final df = daysBetween(e.key, today);
      return df >= 0 && df < 7;
    }).toList();
    final totSteps = last7.fold<num>(0, (x, e) => x + ((e.value['steps'] ?? 0) as num));
    final totKcal = last7.fold<num>(0, (x, e) => x + ((e.value['kcal'] ?? 0) as num));
    final totMin = last7.fold<num>(0, (x, e) => x + ((e.value['min'] ?? 0) as num));
    final avg = last7.isNotEmpty ? (totSteps / last7.length).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: PrimaryButton(
            padding: const EdgeInsets.all(13),
            onTap: openActivity,
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text("Log today's activity"),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Expanded(
              child: PaperCard(
                child: Row(children: [
                  const IconBubble(icon: Icon(Icons.directions_walk, size: 18, color: Colors.white), size: 40, background: T.hero),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('${totSteps.round()}', style: mono(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('avg $avg/day', style: const TextStyle(fontSize: 11.5, color: T.paperMuted)),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PaperCard(
                child: Row(children: [
                  const IconBubble(icon: Icon(Icons.local_fire_department, size: 18, color: Colors.white), size: 40, background: T.hero),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('${totKcal.round()}', style: mono(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('kcal · ${totMin.round()} min', style: const TextStyle(fontSize: 11.5, color: T.paperMuted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        if (stepData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Steps'),
                SizedBox(height: 170, child: _chart(stepData, filled: true)),
              ]),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AppCard(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Log steps and cardio to see trends.', style: TextStyle(color: T.muted, fontSize: 13))))),
          ),
        if (kcalData.any((x) => (x['v'] as double) > 0))
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Cardio calories'),
              SizedBox(height: 170, child: _chart(kcalData, filled: false)),
            ]),
          ),
      ],
    );
  }

  Widget _chart(List<Map<String, dynamic>> data, {required bool filled}) {
    final labels = data.map((e) => e['d'] as String).toList();
    final values = data.map((e) => e['v'] as double).toList();
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: T.surface2, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, getTitlesWidget: (v, m) => Text(v.round().toString(), style: TextStyle(color: T.faint, fontSize: 10)))),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (v, m) {
                final i = v.round();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                if (labels.length > 6 && i % (labels.length / 6).ceil() != 0) return const SizedBox.shrink();
                return Padding(padding: EdgeInsets.only(top: 4), child: Text(labels[i], style: TextStyle(color: T.faint, fontSize: 10)));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => T.surface,
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.round()}', TextStyle(color: T.text, fontWeight: FontWeight.w600))).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
            isCurved: true,
            color: T.accent,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: filled
                ? BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [T.accent.withValues(alpha: 0.35), T.accent.withValues(alpha: 0)]))
                : BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
