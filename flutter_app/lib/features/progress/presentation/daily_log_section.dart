import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../domain/day_stat.dart';
import 'widgets/day_ring_column.dart';
import 'widgets/day_editor_sheet.dart';

/// Add-on section for Progress → Nutrition: a week of dual calorie/protein
/// rings (outer = calories vs goal, inner = protein vs goal), tap a day to
/// review or edit what was logged. Appended below the existing trend card —
/// doesn't touch anything else already on that tab.
class DailyLogSection extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const DailyLogSection({super.key, required this.app, required this.controller});

  @override
  State<DailyLogSection> createState() => _DailyLogSectionState();
}

class _DailyLogSectionState extends State<DailyLogSection> {
  int selectedIndex = 6;

  List<String> _lastNDates(String today, int n) {
    final base = DateTime.parse('${today}T00:00:00');
    return List.generate(n, (i) {
      final d = base.subtract(Duration(days: n - 1 - i));
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
  }

  String _dayLabel(String date, String today, String yesterday) {
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yday';
    return DateFormat('EEE').format(DateTime.parse('${date}T00:00:00'));
  }

  void _openDayEditor(DayStat stat, String dateLabel) {
    showAppSheet(
      context,
      DayEditorSheet(
        controller: widget.controller,
        date: stat.date,
        dateLabel: dateLabel,
        adjustedGoal: stat.adjustedGoal,
        proteinGoal: stat.proteinGoal,
        initialMeals: List<Map<String, dynamic>>.from(widget.app.data.diet[stat.date] ?? []),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.app.data.settings;
    final diet = widget.app.data.diet;
    final activity = widget.app.data.activity;
    final calGoal = (st['calorieGoal'] as num?) ?? 2000;
    final proteinGoal = (st['proteinGoal'] as num?) ?? 150;
    final today = todayStr(st);
    final dates = _lastNDates(today, 7);
    final yesterday = dates[dates.length - 2];

    final stats = dates.map((date) {
      final meals = List<Map<String, dynamic>>.from(diet[date] ?? []);
      final kcal = meals.fold<int>(0, (a, b) => a + ((b['kcal'] as num?) ?? 0).toInt());
      final protein = meals.fold<int>(0, (a, b) => a + ((b['protein'] as num?) ?? 0).toInt());
      final burned = ((activity[date] as Map?)?['kcal'] as num?) ?? 0;
      return DayStat(date: date, kcal: kcal, protein: protein, mealsCount: meals.length, adjustedGoal: calGoal + burned, proteinGoal: proteinGoal);
    }).toList();

    int streak = 0;
    for (var i = stats.length - 1; i >= 0; i--) {
      if (stats[i].bothHit) {
        streak++;
      } else {
        break;
      }
    }

    final selected = stats[selectedIndex];
    final selectedLabel = selected.date == today
        ? 'Today'
        : selected.date == yesterday
            ? 'Yesterday'
            : DateFormat('EEEE, MMM d').format(DateTime.parse('${selected.date}T00:00:00'));

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Daily log'),
          if (streak >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(color: T.accentDim, border: Border.all(color: T.accentSoft), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Text('🔥', style: TextStyle(fontSize: 17)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: TextStyle(fontSize: 12, color: T.text, fontWeight: FontWeight.w600), children: [
                        TextSpan(text: '$streak-day', style: const TextStyle(color: T.hero)),
                        const TextSpan(text: ' streak — deficit and protein goal both hit.'),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (ctx, i) {
                final s = stats[i];
                return DayRingColumn(
                  key: ValueKey(s.date),
                  index: i,
                  label: _dayLabel(s.date, today, yesterday),
                  kcalPct: s.kcalPct,
                  proteinPct: s.proteinPct,
                  bothHit: s.bothHit,
                  empty: s.mealsCount == 0,
                  active: i == selectedIndex,
                  onTap: () => setState(() => selectedIndex = i),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: selected.mealsCount == 0
                ? Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(selectedLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: T.text)),
                        Padding(padding: const EdgeInsets.only(top: 2), child: Text('Nothing logged', style: TextStyle(fontSize: 12, color: T.muted))),
                      ]),
                    ),
                    GestureDetector(
                      onTap: () => _openDayEditor(selected, selectedLabel),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: T.hero, borderRadius: BorderRadius.circular(T.pill)),
                        child: const Text('Add food', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    ),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(selectedLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: T.text))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected.vsGoal >= 0 ? T.success.withValues(alpha: 0.16) : T.danger.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(T.pill),
                          ),
                          child: Text(
                            '${selected.vsGoal >= 0 ? '−' : '+'}${selected.vsGoal.abs().round()} kcal',
                            style: mono(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected.vsGoal >= 0 ? T.success : T.danger),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _statChip('${selected.kcal}', 'kcal eaten')),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statChip(
                            '${selected.protein}g',
                            'protein · ${selected.proteinPct.round()}%',
                            color: selected.proteinPct >= 90 ? T.success : (selected.proteinPct >= 60 ? T.blue : T.danger),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _openDayEditor(selected, selectedLabel),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: Text('Edit ${selected.mealsCount} meal${selected.mealsCount == 1 ? '' : 's'}', style: TextStyle(color: T.text, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(11)),
        alignment: Alignment.center,
        child: Column(children: [
          Text(value, style: mono(fontSize: 14.5, fontWeight: FontWeight.w700, color: color ?? T.text)),
          Padding(padding: const EdgeInsets.only(top: 2), child: Text(label, style: TextStyle(fontSize: 9.5, color: T.muted))),
        ]),
      );
}
