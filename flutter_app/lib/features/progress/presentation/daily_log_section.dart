import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../app/app_state.dart';
import '../../../shared/lib/helpers.dart';
import '../domain/day_stat.dart';
import 'widgets/day_ring_column.dart';
import 'widgets/day_editor_sheet.dart';
import 'widgets/dual_ring_painter.dart';

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

/// What's currently under a long-press: which day (by strip index) and its
/// stat, so both the floating peek ring and the inline legend card below the
/// strip can render off one source of truth.
class _PeekData {
  final int index;
  final DayStat stat;
  final String label;
  const _PeekData({required this.index, required this.stat, required this.label});
}

class _DailyLogSectionState extends State<DailyLogSection> {
  int selectedIndex = 6;

  // One LayerLink per strip position — each DayRingColumn's ring registers
  // itself as a CompositedTransformTarget against its link, so the floating
  // peek card (inserted into the app's Overlay, well outside the strip's own
  // horizontally-clipped ListView) can track its exact on-screen position,
  // including mid-scroll, without any manual offset math.
  final List<LayerLink> _links = List.generate(7, (_) => LayerLink());
  final ValueNotifier<_PeekData?> _peek = ValueNotifier(null);
  final _ringScroll = ScrollController();
  OverlayEntry? _peekEntry;

  @override
  void initState() {
    super.initState();
    // The enlarged rings (56px + 10px gaps) no longer all fit one screen
    // width the way the old 44px/4px strip did, so — same as opening on
    // today's stats below — the strip should open scrolled to today rather
    // than leaving it off the right edge until someone thinks to swipe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ringScroll.hasClients) _ringScroll.jumpTo(_ringScroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _peekEntry?.remove();
    _peek.dispose();
    _ringScroll.dispose();
    super.dispose();
  }

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

  void _startPeek(int i, DayStat stat, String label) {
    _peek.value = _PeekData(index: i, stat: stat, label: label);
    // Inserted lazily on first hold and then kept alive for the rest of the
    // section's life — cheap to leave mounted since it renders nothing (a
    // SizedBox) whenever nothing is being held.
    _peekEntry ??= OverlayEntry(builder: (_) => _PeekLayer(peek: _peek, links: _links));
    if (_peekEntry!.mounted == false) {
      Overlay.of(context).insert(_peekEntry!);
    }
  }

  void _endPeek() => _peek.value = null;

  @override
  Widget build(BuildContext context) {
    final st = widget.app.data.settings;
    final diet = widget.app.data.diet;
    final activity = widget.app.data.activity;
    final calGoal = (st['calorieGoal'] as num?) ?? 2000;
    final proteinGoal = (st['proteinGoal'] as num?) ?? 150;
    // Same maintenance figure Home and the Diet tab use for "true deficit" —
    // pulled from the plan when one exists, falling back to the calorie
    // goal like those other two screens do.
    final tdee = (widget.app.data.plan != null ? widget.app.data.plan!['tdee'] : null) as num? ?? calGoal;
    final today = todayStr(st);
    final dates = _lastNDates(today, 7);
    final yesterday = dates[dates.length - 2];

    final stats = dates.map((date) {
      final meals = List<Map<String, dynamic>>.from(diet[date] ?? []);
      final kcal = meals.fold<int>(0, (a, b) => a + ((b['kcal'] as num?) ?? 0).toInt());
      final protein = meals.fold<int>(0, (a, b) => a + ((b['protein'] as num?) ?? 0).toInt());
      final burned = ((activity[date] as Map?)?['kcal'] as num?) ?? 0;
      return DayStat(date: date, kcal: kcal, protein: protein, mealsCount: meals.length, adjustedGoal: calGoal + burned, proteinGoal: proteinGoal, tdee: tdee, burned: burned);
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
            height: 104,
            child: ListView.separated(
              controller: _ringScroll,
              scrollDirection: Axis.horizontal,
              // Long-pressed rings float a peek card above this strip via
              // the app's Overlay (see _PeekLayer) — that card is free to
              // paint outside these bounds, but the strip itself still has
              // to clip to scroll horizontally, so nothing here should ever
              // grow past its own row.
              itemCount: stats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final s = stats[i];
                final label = _dayLabel(s.date, today, yesterday);
                return ValueListenableBuilder<_PeekData?>(
                  valueListenable: _peek,
                  builder: (context, peek, _) => DayRingColumn(
                    key: ValueKey(s.date),
                    index: i,
                    label: label,
                    kcalPct: s.kcalPct,
                    proteinPct: s.proteinPct,
                    bothHit: s.bothHit,
                    empty: s.mealsCount == 0,
                    active: i == selectedIndex,
                    peeked: peek?.index == i,
                    link: _links[i],
                    onTap: () => setState(() => selectedIndex = i),
                    onHoldStart: () => _startPeek(i, s, label),
                    onHoldEnd: _endPeek,
                  ),
                );
              },
            ),
          ),
          // Legend for whichever day is currently held — unfolds directly
          // under the strip and, since the floating peek ring is painted in
          // the app's Overlay (above everything), it visually spotlights
          // over the top of this card as it opens.
          ValueListenableBuilder<_PeekData?>(
            valueListenable: _peek,
            builder: (context, peek, _) => AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: peek == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _LegendCard(stat: peek.stat, label: peek.label),
                    ),
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
                      // True deficit (primary) and budget (secondary) are
                      // one trailing cluster, stacked and right-aligned
                      // together — same number/wording as Home and the
                      // Diet tab, and no longer split across two different
                      // alignments on the same card.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(selectedLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: T.text))),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: selected.trueDeficit >= 0 ? T.success.withValues(alpha: 0.16) : T.danger.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(T.pill),
                                ),
                                child: Text(
                                  '${selected.trueDeficit.abs().round()} kcal ${selected.trueDeficit >= 0 ? 'deficit' : 'surplus'}',
                                  style: mono(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected.trueDeficit >= 0 ? T.success : T.danger),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: BudgetChip(budgetLeft: selected.vsGoal, isToday: selected.date == today),
                              ),
                            ],
                          ),
                        ],
                      ),
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

/// Lives in the app's Overlay (via a single long-lived OverlayEntry), so it
/// paints above the whole screen — including the strip's own clipped
/// ListView and the legend card it's meant to spotlight over. Tracks
/// whichever ring is held through that ring's LayerLink, so it stays glued
/// to it even mid-scroll, and renders nothing when no day is held.
class _PeekLayer extends StatelessWidget {
  final ValueNotifier<_PeekData?> peek;
  final List<LayerLink> links;
  const _PeekLayer({required this.peek, required this.links});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_PeekData?>(
      valueListenable: peek,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        // The Overlay hands its (non-Positioned) children tight constraints
        // matching the full screen — without this Align, that tightness
        // propagates straight through the Follower to the card below,
        // forcing its "width: 104" card to stretch to fill the whole
        // screen instead. Align re-loosens those constraints for its child
        // (and doesn't otherwise matter here: the Follower repositions its
        // child at paint time via the layer link, not through Align's own
        // alignment).
        return Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: links[data.index],
            showWhenUnlinked: false,
            targetAnchor: Alignment.center,
            followerAnchor: Alignment.center,
            child: IgnorePointer(
              // Keyed by index so a hold moving to a different day (which
              // can't happen mid-gesture today, but keeps this correct if
              // it ever can) restarts the pop-in instead of jump-cutting.
              child: _PeekCard(key: ValueKey(data.index), stat: data.stat, label: data.label),
            ),
          ),
        );
      },
    );
  }
}

/// The enlarged ring itself — same visual language as the small strip ring
/// (surface card, same colors) at roughly the strip ring's size grown to the
/// scale that read best in review, just floating instead of scaled in place.
class _PeekCard extends StatelessWidget {
  final DayStat stat;
  final String label;
  const _PeekCard({super.key, required this.stat, required this.label});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(opacity: t.clamp(0, 1), child: Transform.scale(scale: 0.55 + 0.45 * t, child: child)),
      child: Container(
        key: const Key('peekCardBox'),
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.text)),
            const SizedBox(height: 10),
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(76, 76), painter: DualRingPainter(outerPct: stat.kcalPct, innerPct: stat.proteinPct, strokeWidth: 6)),
                if (stat.bothHit) Icon(Icons.check_circle, size: 20, color: T.success),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which ring is which — outer/calories vs. inner/protein — plus the day's
/// actual numbers, in the same colors used to draw the rings themselves.
class _LegendCard extends StatelessWidget {
  final DayStat stat;
  final String label;
  const _LegendCard({required this.stat, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: T.text)),
          const SizedBox(height: 8),
          _row(T.hero, 'Calories (outer)', '${stat.kcal} / ${stat.adjustedGoal.round()}'),
          const SizedBox(height: 6),
          _row(T.blue, 'Protein (inner)', '${stat.protein}g / ${stat.proteinGoal.round()}g'),
        ],
      ),
    );
  }

  Widget _row(Color color, String label, String value) => Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.muted))),
        Text(value, style: mono(fontSize: 12, fontWeight: FontWeight.w700, color: T.text)),
      ]);
}
