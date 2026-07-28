import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../app/app_state.dart';
import '../../shared/lib/helpers.dart';
import '../nutrition/meal_log.dart';
import '../nutrition/parse_meal_lines.dart';

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

class _DayStat {
  final String date;
  final int kcal;
  final int protein;
  final int mealsCount;
  final num adjustedGoal;
  final num proteinGoal;
  const _DayStat({required this.date, required this.kcal, required this.protein, required this.mealsCount, required this.adjustedGoal, required this.proteinGoal});

  double get kcalPct => adjustedGoal > 0 ? (kcal / adjustedGoal * 100) : 0;
  double get proteinPct => proteinGoal > 0 ? (protein / proteinGoal * 100) : 0;
  bool get bothHit => mealsCount > 0 && kcal <= adjustedGoal && proteinPct >= 90;
  num get vsGoal => adjustedGoal - kcal; // positive = under budget (deficit), negative = over
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

  void _openDayEditor(_DayStat stat, String dateLabel) {
    showAppSheet(
      context,
      _DayEditorSheet(
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
      return _DayStat(date: date, kcal: kcal, protein: protein, mealsCount: meals.length, adjustedGoal: calGoal + burned, proteinGoal: proteinGoal);
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
                return _DayRingColumn(
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

class _DayRingColumn extends StatefulWidget {
  final int index;
  final String label;
  final double kcalPct;
  final double proteinPct;
  final bool bothHit;
  final bool empty;
  final bool active;
  final VoidCallback onTap;
  const _DayRingColumn({
    super.key,
    required this.index,
    required this.label,
    required this.kcalPct,
    required this.proteinPct,
    required this.bothHit,
    required this.empty,
    required this.active,
    required this.onTap,
  });

  @override
  State<_DayRingColumn> createState() => _DayRingColumnState();
}

class _DayRingColumnState extends State<_DayRingColumn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _outer;
  late Animation<double> _inner;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _outer = Tween<double>(begin: 0, end: widget.empty ? 0 : widget.kcalPct.clamp(0, 100)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _inner = Tween<double>(begin: 0, end: widget.empty ? 0 : widget.proteinPct.clamp(0, 100)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _checkScale = CurvedAnimation(parent: _c, curve: const Interval(0.78, 1.0, curve: Curves.elasticOut));
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    Future.delayed(reduceMotion ? Duration.zero : Duration(milliseconds: 90 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _DayRingColumn old) {
    super.didUpdateWidget(old);
    if (old.kcalPct != widget.kcalPct || old.proteinPct != widget.proteinPct || old.empty != widget.empty) {
      _outer = Tween<double>(begin: _outer.value, end: widget.empty ? 0 : widget.kcalPct.clamp(0, 100)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
      _inner = Tween<double>(begin: _inner.value, end: widget.empty ? 0 : widget.proteinPct.clamp(0, 100)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: widget.active ? T.surface : Colors.transparent,
          border: Border.all(color: widget.active ? T.accentSoft : Colors.transparent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.active ? T.text : T.muted)),
            const SizedBox(height: 6),
            SizedBox(
              width: 44,
              height: 44,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Stack(alignment: Alignment.center, children: [
                  CustomPaint(size: const Size(44, 44), painter: _DualRingPainter(outerPct: _outer.value, innerPct: _inner.value)),
                  if (widget.bothHit)
                    Transform.scale(scale: _checkScale.value, child: const Icon(Icons.check_circle, size: 15, color: T.success)),
                  if (widget.empty) Text('—', style: TextStyle(fontSize: 12, color: T.faint)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DualRingPainter extends CustomPainter {
  final double outerPct;
  final double innerPct;
  _DualRingPainter({required this.outerPct, required this.innerPct});

  void _ring(Canvas canvas, Offset center, double r, double pct, Color stroke) {
    final trackPaint = Paint()
      ..color = T.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, r, trackPaint);
    final clamped = pct.clamp(0, 100) / 100;
    if (clamped <= 0.004) return;
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * clamped;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, sweep, false, strokePaint);
    // Leading dot at the current tip of the arc, so a ring mid-animation
    // reads as an active fill in progress rather than a static wedge.
    final angle = -math.pi / 2 + sweep;
    final dot = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    canvas.drawCircle(dot, 3, Paint()..color = stroke);
    canvas.drawCircle(dot, 3, Paint()
      ..color = T.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    _ring(canvas, center, size.width / 2 - 2, outerPct, T.hero);
    _ring(canvas, center, size.width / 2 - 9, innerPct, T.blue);
  }

  @override
  bool shouldRepaint(covariant _DualRingPainter old) => old.outerPct != outerPct || old.innerPct != innerPct;
}

/// Add/remove meals for a specific past (or present) date — the same
/// `diet` map today's log uses, just addressed by an explicit date instead
/// of always defaulting to today.
class _DayEditorSheet extends StatefulWidget {
  final AppController controller;
  final String date;
  final String dateLabel;
  final num adjustedGoal;
  final num proteinGoal;
  final List<Map<String, dynamic>> initialMeals;
  const _DayEditorSheet({
    required this.controller,
    required this.date,
    required this.dateLabel,
    required this.adjustedGoal,
    required this.proteinGoal,
    required this.initialMeals,
  });

  @override
  State<_DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<_DayEditorSheet> {
  late List<Map<String, dynamic>> meals = List<Map<String, dynamic>>.from(widget.initialMeals);
  final cName = TextEditingController();
  final cK = TextEditingController();
  final cP = TextEditingController();
  final logTextCtrl = TextEditingController();
  bool showAdd = false;
  // null = choosing between the two entry modes; set once a mode is picked.
  String? addMode;

  @override
  void dispose() {
    cName.dispose();
    cK.dispose();
    cP.dispose();
    logTextCtrl.dispose();
    super.dispose();
  }

  void _remove(dynamic id) {
    removeMealEntry(widget.controller, widget.date, id);
    setState(() => meals.removeWhere((m) => m['id'] == id));
  }

  void _closeAdd() {
    showAdd = false;
    addMode = null;
  }

  void _add() {
    final name = cName.text.trim();
    final k = double.tryParse(cK.text);
    if (name.isEmpty || k == null || k < 0) return;
    final p = double.tryParse(cP.text) ?? 0;
    addMealEntry(widget.controller, name, k, p, 0, 0, 0, widget.date);
    setState(() {
      meals.add({'id': DateTime.now().millisecondsSinceEpoch, 'name': name, 'kcal': k.round(), 'protein': p.round(), 'carb': 0, 'fat': 0, 'fiber': 0});
      cName.clear();
      cK.clear();
      cP.clear();
      _closeAdd();
    });
  }

  void _logQuick(List<ParsedMealItem> items) {
    if (items.isEmpty) return;
    addMealEntries(widget.controller, items, widget.date);
    setState(() {
      for (final it in items) {
        meals.add({'id': DateTime.now().millisecondsSinceEpoch + meals.length, 'name': it.name, 'kcal': it.kcal, 'protein': it.protein, 'carb': it.carb, 'fat': it.fat, 'fiber': it.fiber});
      }
      logTextCtrl.clear();
      _closeAdd();
    });
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: T.faint),
        filled: true,
        fillColor: T.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: T.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: T.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: T.accent)),
      );

  Widget _modeButton(String label, String sub, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: T.accent),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text)),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: TextStyle(fontSize: 10, color: T.muted), textAlign: TextAlign.center)),
          ]),
        ),
      );

  Widget _backHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => addMode = null),
            child: Icon(Icons.chevron_left, size: 20, color: T.muted),
          ),
          Expanded(child: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final kcal = meals.fold<num>(0, (a, b) => a + ((b['kcal'] as num?) ?? 0));
    final protein = meals.fold<num>(0, (a, b) => a + ((b['protein'] as num?) ?? 0));
    final vsGoal = widget.adjustedGoal - kcal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('Edit — ${widget.dateLabel}', style: Type.h2)),
          IconBubble(icon: Icon(Icons.close, size: 18, color: T.muted), size: 34, background: T.surface2, onTap: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: Column(children: [
                Text('${kcal.round()}', style: mono(fontSize: 15, fontWeight: FontWeight.w700, color: T.text)),
                Padding(padding: const EdgeInsets.only(top: 2), child: Text('kcal eaten', style: TextStyle(fontSize: 9.5, color: T.muted))),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: Column(children: [
                Text('${vsGoal >= 0 ? '−' : '+'}${vsGoal.abs().round()}', style: mono(fontSize: 15, fontWeight: FontWeight.w700, color: vsGoal >= 0 ? T.success : T.danger)),
                Padding(padding: const EdgeInsets.only(top: 2), child: Text('vs goal', style: TextStyle(fontSize: 9.5, color: T.muted))),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: Column(children: [
                Text('${protein.round()}g', style: mono(fontSize: 15, fontWeight: FontWeight.w700, color: T.text)),
                Padding(padding: const EdgeInsets.only(top: 2), child: Text('protein', style: TextStyle(fontSize: 9.5, color: T.muted))),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        const Eyebrow('Meals', margin: EdgeInsets.zero),
        if (meals.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Nothing logged this day yet — add what you remember below.', style: TextStyle(color: T.muted, fontSize: 13)))
        else
          ...meals.map((m) => Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.surface2))),
                child: Row(children: [
                  Expanded(child: Text(m['name'], style: TextStyle(fontSize: 14, color: T.text))),
                  Text('${m['kcal']} kcal · ${m['protein']}g P', style: mono(fontSize: 12, color: T.muted)),
                  const SizedBox(width: 12),
                  GestureDetector(onTap: () => _remove(m['id']), child: Icon(Icons.close, size: 16, color: T.faint)),
                ]),
              )),
        const SizedBox(height: 8),
        if (!showAdd)
          GestureDetector(
            onTap: () => setState(() => showAdd = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(border: Border.all(color: T.line, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text('＋ Add food', style: TextStyle(color: T.muted, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          )
        else if (addMode == null)
          Row(children: [
            Expanded(child: _modeButton('Custom add', 'One item, exact macros', Icons.edit_note, () => setState(() => addMode = 'custom'))),
            const SizedBox(width: 8),
            Expanded(child: _modeButton('Quick add', 'Log a meal, one line each', Icons.bolt, () => setState(() => addMode = 'quick'))),
          ])
        else if (addMode == 'custom')
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _backHeader('Custom add'),
              TextField(controller: cName, style: TextStyle(color: T.text, fontSize: 14), decoration: _dec('Food name')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: NumIn(value: cK.text, onChange: (v) => setState(() => cK.text = v), ph: 'e.g. 250', suffix: 'kcal')),
                const SizedBox(width: 8),
                Expanded(child: NumIn(value: cP.text, onChange: (v) => setState(() => cP.text = v), ph: 'e.g. 20', suffix: 'g P')),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: PrimaryButton(padding: const EdgeInsets.all(12), onTap: _add, child: const Text('Add to this day')),
              ),
            ]),
          )
        else
          Builder(builder: (context) {
            final parsedPreview = parseMealLines(logTextCtrl.text);
            final previewKcal = parsedPreview.fold<int>(0, (a, b) => a + b.kcal);
            final previewProtein = parsedPreview.fold<int>(0, (a, b) => a + b.protein);
            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _backHeader('Quick log a meal'),
                TextField(
                  controller: logTextCtrl,
                  onChanged: (_) => setState(() {}),
                  maxLines: 3,
                  style: mono(fontSize: 13, color: T.text),
                  decoration: _dec('2 Rotis, 240, 6\nDal tadka, 180, 12'),
                ),
                if (parsedPreview.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(children: [
                      ...parsedPreview.map((it) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Expanded(child: Text(it.name, style: TextStyle(fontSize: 12, color: T.muted))),
                              Text('${it.kcal} · ${it.protein}g', style: mono(fontSize: 12, color: T.muted)),
                            ]),
                          )),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: T.line))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total (${parsedPreview.length} item${parsedPreview.length > 1 ? "s" : ""})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.text)),
                            Text('$previewKcal · ${previewProtein}g', style: mono(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: PrimaryButton(
                    padding: const EdgeInsets.all(12),
                    opacity: parsedPreview.isNotEmpty ? 1 : 0.45,
                    onTap: parsedPreview.isEmpty ? null : () => _logQuick(parsedPreview),
                    child: const Text('Log meal'),
                  ),
                ),
              ]),
            );
          }),
      ],
    );
  }
}
