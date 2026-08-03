import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/widgets/ai_shimmer_once.dart';
import '../../shared/lib/helpers.dart';
import '../../shared/lib/macro_totals.dart';
import '../../app/app_state.dart';
import 'log_food_sheet.dart';

class NutritionScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const NutritionScreen({super.key, required this.app, required this.controller});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

// Fiber isn't represented in the shared theme's color set — a distinct
// amber/brown tone keeps it visually separate from kcal/protein/carb/fat.
const _fiberColor = Color(0xFFC28A45);

class _NutritionScreenState extends State<NutritionScreen> {
  void _openLogFoodSheet() => showAppSheet(context, LogFoodSheet(app: widget.app, controller: widget.controller));

  void removeMeal(dynamic id) {
    final today = todayStr(widget.app.data.settings);
    widget.controller.update('diet', (prev) {
      final d = Map<String, dynamic>.from(prev ?? {});
      final list = List<Map<String, dynamic>>.from(d[today] ?? []).where((m) => m['id'] != id).toList();
      d[today] = list;
      return d;
    });
  }

  void setWater(int n) {
    final today = todayStr(widget.app.data.settings);
    widget.controller.update('water', (prev) {
      final w = Map<String, dynamic>.from(prev ?? {});
      w[today] = n < 0 ? 0 : n;
      return w;
    });
  }

  Widget _macroBar({required String label, required num value, required num goal, required Color color, String unit = 'g'}) {
    final pct = goal > 0 ? (value / goal).clamp(0, 1).toDouble() : 0.0;
    final done = goal > 0 && value >= goal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.text)),
              Text('${value.round()} / ${goal.round()}$unit', style: mono(fontSize: 12, color: T.muted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 9,
                backgroundColor: T.surface2,
                valueColor: AlwaysStoppedAnimation(done ? T.success : color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mealSummary(Map<String, dynamic> m) {
    final parts = <String>['${m['kcal']} · ${m['protein']}g P'];
    final c = (m['carb'] ?? 0) as num;
    final f = (m['fat'] ?? 0) as num;
    final fi = (m['fiber'] ?? 0) as num;
    if (c > 0) parts.add('${c}g C');
    if (f > 0) parts.add('${f}g F');
    if (fi > 0) parts.add('${fi}g Fib');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.app.data.settings;
    final today = todayStr(st);
    final meals = List<Map<String, dynamic>>.from(widget.app.data.diet[today] ?? []);
    final totals = sumMacros(meals);
    final kcal = totals.kcal;
    final prot = totals.protein;
    final carb = totals.carb;
    final fat = totals.fat;
    final fiber = totals.fiber;
    final calGoal = (st['calorieGoal'] ?? 2000) as num;
    final protGoal = (st['proteinGoal'] ?? 150) as num;
    final carbGoal = (st['carbGoal'] ?? 250) as num;
    final fatGoal = (st['fatGoal'] ?? 65) as num;
    final fiberGoal = (st['fiberGoal'] ?? 30) as num;
    final water = (widget.app.data.water[today] ?? 0) as num;
    final burned = ((widget.app.data.activity[today] ?? {})['kcal'] ?? 0) as num;
    final adjustedGoal = calGoal + burned;
    final tdee = (widget.app.data.plan != null ? widget.app.data.plan!['tdee'] : null) ?? calGoal;
    final deficit = ((tdee as num) - (kcal - burned)).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Ring(value: kcal.toDouble(), goal: adjustedGoal.toDouble(), size: 100, color: T.hero),
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('Calories', style: TextStyle(fontSize: 11, color: T.muted))),
                ]),
                Column(children: [
                  Ring(value: prot.toDouble(), goal: protGoal.toDouble(), size: 100, unit: 'g', color: T.blue),
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('Protein', style: TextStyle(fontSize: 11, color: T.muted))),
                ]),
              ],
            ),
          ),
        ),
        // Carbs/fat/fiber as a plain bar list rather than more rings —
        // rings stop reading well past 2 at a glance (everything starts
        // competing for the same circular real estate), while stacked
        // bars scale to any number of nutrients without crowding, and
        // this screen already treats "Quick add"/"Add custom item" as
        // bare sections with no card wrapper, so this matches that
        // existing lower-emphasis pattern instead of inventing a new one.
        const Eyebrow('Macros'),
        _macroBar(label: 'Carbs', value: carb, goal: carbGoal, color: T.success),
        _macroBar(label: 'Fat', value: fat, goal: fatGoal, color: T.lav),
        _macroBar(label: 'Fiber', value: fiber, goal: fiberGoal, color: _fiberColor),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Center(
            child: Text(
              '${deficit.abs()} kcal ${deficit >= 0 ? 'deficit' : 'surplus'} · vs ~${tdee.round()} maintenance${burned > 0 ? ' (+${burned.round()} from activity)' : ''}',
              style: TextStyle(fontSize: 12, color: T.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  IconBubble(icon: const Icon(Icons.water_drop, size: 16, color: Colors.white), size: 34, background: water * 0.25 >= 3 ? T.success : T.hero),
                  const SizedBox(width: 10),
                  const Eyebrow('Water', margin: EdgeInsets.zero),
                ]),
                Row(children: [
                  IconBubble(icon: Icon(Icons.remove, size: 16, color: T.muted), size: 30, background: T.surface2, onTap: () => setWater(water.toInt() - 1)),
                  const SizedBox(width: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text((water * 0.25).toStringAsFixed(2), style: mono(fontSize: 18)),
                    Text(' / 3.5L', style: mono(fontSize: 12, color: T.muted)),
                  ]),
                  const SizedBox(width: 10),
                  IconBubble(icon: const Icon(Icons.add, size: 16, color: Colors.white), size: 30, background: T.hero, onTap: () => setWater(water.toInt() + 1)),
                ]),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: AiShimmerOnce(
            borderRadius: BorderRadius.circular(T.pill),
            child: PrimaryButton(
              onTap: _openLogFoodSheet,
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 18),
                SizedBox(width: 8),
                Text('Log food'),
              ]),
            ),
          ),
        ),
        const Eyebrow("Today's meals"),
        if (meals.isEmpty)
          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nothing logged yet.', style: TextStyle(color: T.muted, fontSize: 13)))
        else
          ...meals.map((m) => Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.surface2))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(m['name'], style: TextStyle(fontSize: 14, color: T.text))),
                    Row(children: [
                      Text(_mealSummary(m), style: mono(fontSize: 12, color: T.muted)),
                      const SizedBox(width: 12),
                      GestureDetector(onTap: () => removeMeal(m['id']), child: Icon(Icons.close, size: 16, color: T.faint)),
                    ]),
                  ],
                ),
              )),
      ],
    );
  }
}
