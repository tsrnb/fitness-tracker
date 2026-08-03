import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/widgets/trend_chart.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';

class ActivityProgressScreen extends StatelessWidget {
  final AppState app;
  final VoidCallback openActivity;
  const ActivityProgressScreen({super.key, required this.app, required this.openActivity});

  @override
  Widget build(BuildContext context) {
    final today = todayStr(app.data.settings);
    final entries = app.data.activity.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final stepData = entries.map((e) => {'d': fmtDay(e.key), 'v': ((e.value['steps'] ?? 0) as num).toDouble()}).toList();
    final kcalData = entries.map((e) => {'d': fmtDay(e.key), 'v': ((e.value['kcal'] ?? 0) as num).toDouble()}).toList();
    final last7 = lastNDaysEntries(app.data.activity, today, 7);
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
    return TrendLineChart(values: values, labels: labels, filled: filled, leftAxisWidth: 42);
  }
}
