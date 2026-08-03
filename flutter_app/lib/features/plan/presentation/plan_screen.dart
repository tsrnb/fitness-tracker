import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../shared/lib/macro_totals.dart';
import '../../../app/app_state.dart';
import '../../training/domain/training_split.dart';
import '../../training/data/training_splits_data.dart';

/// Full-page "Your Plan" (replacing the old modal sheet — a bottom sheet
/// squeezed a headline, 3 stat tiles, a training card and a full meal list
/// into one cramped scroll with no breathing room). Same content, laid out
/// with real hierarchy: one hero stat row instead of 3 tiny boxes, and
/// consistent section chrome via [pageScaffold]. The weekly split is a real
/// drag-to-swap calendar strip rather than static text.
class PlanScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const PlanScreen({super.key, required this.app, required this.controller});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late TrainingSplit split;
  late List<String?> schedule;
  final _infoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    split = activeSplit(widget.app.data.settings);
    schedule = scheduleFromSettings(widget.app.data.settings, split);
  }

  @override
  void didUpdateWidget(covariant PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSplit = activeSplit(widget.app.data.settings);
    if (newSplit.id != split.id) {
      setState(() {
        split = newSplit;
        schedule = scheduleFromSettings(widget.app.data.settings, split);
      });
    }
  }

  void _swap(int a, int b) {
    if (a == b) return;
    setState(() {
      final tmp = schedule[a];
      schedule[a] = schedule[b];
      schedule[b] = tmp;
    });
    widget.controller.patchSettings('schedule', schedule);
  }

  void _showInfoBubble(String text) {
    final box = _infoKey.currentContext!.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final iconRect = (box.localToGlobal(Offset.zero, ancestor: overlay) & box.size).translate(0, box.size.height + 8);
    showMenu(
      context: context,
      color: T.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: T.line)),
      position: RelativeRect.fromRect(iconRect, Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(width: 230, child: Text(text, style: Type.caption)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.app.data.settings;
    final plan = widget.app.data.plan;
    if (plan == null) {
      return pageScaffold(
        context: context,
        title: 'Your plan',
        onBack: () => Navigator.of(context).pop(),
        child: Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Text('No plan yet.', style: Type.caption))),
      );
    }
    final meals = List<Map<String, dynamic>>.from(plan['meals']);
    final mealTotals = sumMacros(meals);
    final mealKcal = mealTotals.kcal;
    final mealProt = mealTotals.protein;
    final feasible = plan['feasible'] as bool;
    final suggestedDate = plan['suggestedDate'] as String?;

    return pageScaffold(
      context: context,
      title: 'Your plan',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan['headline'], style: Type.body.copyWith(color: T.muted)),
          const SizedBox(height: 16),
          AppCard(
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _heroStat(icon: Icons.local_fire_department, color: T.hero, label: 'Calories', value: '${plan['calorieGoal']}')),
                  Container(width: 1, color: T.line),
                  Expanded(child: _heroStat(icon: Icons.bolt, color: T.blue, label: 'Protein', value: '${plan['proteinGoal']}g')),
                  Container(width: 1, color: T.line),
                  Expanded(child: _heroStat(icon: Icons.directions_walk, color: T.success, label: 'Steps', value: '${((plan['stepGoal'] as num) / 1000).toStringAsFixed(0)}k')),
                ],
              ),
            ),
          ),
          if (!feasible && suggestedDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: AppCard(
                borderColor: T.accent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: T.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(style: Type.body.copyWith(height: 1.5), children: [
                          const TextSpan(text: "That timeline is aggressive for muscle-safe progress. A healthier target date is "),
                          TextSpan(text: fmtDay(suggestedDate), style: mono(fontSize: 14, color: T.accent, fontWeight: FontWeight.w600)),
                          const TextSpan(text: '. You can still proceed — the pace is capped safely either way.'),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Eyebrow('Training — ${split.name}', margin: EdgeInsets.zero),
              GestureDetector(
                key: _infoKey,
                onTap: () => _showInfoBubble(plan['cardioNote'] as String),
                child: Icon(Icons.info_outline, size: 15, color: T.faint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: List.generate(7, (i) => Expanded(child: _weekDayCell(i)))),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text('Press & hold a day, then drag it onto another to swap.', style: Type.caption),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Eyebrow('Simple day of eating', margin: EdgeInsets.zero),
              Text('~$mealKcal kcal · ${mealProt}g P', style: mono(fontSize: 12, color: T.muted)),
            ],
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${st['dietPref'] == 'nonveg' ? 'Non-veg' : (st['dietPref'] ?? '')} · scale portions to hit ${plan['calorieGoal']} kcal',
                  style: Type.caption,
                ),
                const SizedBox(height: 6),
                ...List.generate(meals.length, (i) {
                  final m = meals[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: i > 0 ? BoxDecoration(border: Border(top: BorderSide(color: T.surface2))) : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m['name'], style: Type.h3),
                            Text(m['time'], style: mono(fontSize: 11, color: T.faint)),
                          ]),
                        ),
                        Text('${m['kcal']} · ${m['protein']}g', style: mono(fontSize: 13, color: T.muted)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  // Cycled by the day-type's position in the active split's dayOrder, so any
  // split (3 to 6 distinct day types) gets a stable, distinct color per type.

  Color _dayColor(String dayType) {
    final idx = split.dayOrder.indexOf(dayType);
    return dayPalette[(idx < 0 ? 0 : idx) % dayPalette.length];
  }

  String _dayAbbr(String dayType) => split.dayAbbr[dayType] ?? dayType.substring(0, dayType.length < 2 ? dayType.length : 2);

  /// One day of the weekly split, as a real calendar strip instead of a
  /// paragraph of prose + a flat row of pill tags — today is highlighted,
  /// rest days just get a muted outline + moon icon. Draggable+droppable so
  /// two days can be swapped (e.g. rest on Wed, train on Sun instead).
  Widget _weekDayCell(int dow) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != dow,
        onAcceptWithDetails: (details) => _swap(details.data, dow),
        builder: (context, candidateData, rejectedData) {
          final hovering = candidateData.isNotEmpty;
          return LongPressDraggable<int>(
            data: dow,
            feedback: Material(
              color: Colors.transparent,
              child: _dayCircle(dow, scale: 1.15, elevated: true),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: _dayCell(dow)),
            child: hovering ? _dayCell(dow, highlight: true) : _dayCell(dow),
          );
        },
      ),
    );
  }

  Widget _dayCell(int dow, {bool highlight = false}) {
    final isToday = DateTime.now().weekday % 7 == dow;
    return Column(
      children: [
        Text(
          _dayLetters[dow],
          style: mono(fontSize: 10, color: isToday ? T.text : T.faint, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500),
        ),
        const SizedBox(height: 6),
        _dayCircle(dow, highlight: highlight),
      ],
    );
  }

  Widget _dayCircle(int dow, {bool highlight = false, double scale = 1, bool elevated = false}) {
    final dayType = schedule[dow];
    final isToday = DateTime.now().weekday % 7 == dow;
    final color = dayType != null ? _dayColor(dayType) : T.faint;
    return Container(
      width: 38 * scale,
      height: 38 * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dayType != null ? color.withValues(alpha: 0.16) : (elevated ? T.surface : Colors.transparent),
        border: Border.all(color: highlight ? T.accent : (isToday ? color : T.line), width: highlight ? 2.5 : (isToday ? 2 : 1)),
        boxShadow: elevated ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
      ),
      child: dayType != null
          ? Text(_dayAbbr(dayType), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))
          : Icon(Icons.bedtime, size: 15, color: T.faint),
    );
  }

  Widget _heroStat({required IconData icon, required Color color, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: mono(fontSize: 20, fontWeight: FontWeight.w700, color: T.text)),
          const SizedBox(height: 2),
          Text(label, style: Type.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
