import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// A single-series line/area trend chart with the app's standard axis
/// styling and tooltip — the same fl_chart boilerplate (grid, titles,
/// touch tooltip, label thinning past 6 points) was hand-rolled separately
/// for weight/strength trends (Progress tab) and steps/cardio trends
/// (Activity tab).
class TrendLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final bool filled;
  final double? minY;
  final double? maxY;
  final double leftAxisWidth;
  const TrendLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.filled = false,
    this.minY,
    this.maxY,
    this.leftAxisWidth = 34,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: T.surface2, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: leftAxisWidth, getTitlesWidget: (v, meta) => Text(v.round().toString(), style: TextStyle(color: T.faint, fontSize: 10))),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                if (labels.length > 6 && i % (labels.length / 6).ceil() != 0) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(labels[i], style: TextStyle(color: T.faint, fontSize: 10)));
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
