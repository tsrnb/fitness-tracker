import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../../shared/lib/muscle_map.dart';
import '../../../app/app_state.dart';
import '../../exercises/data/exercise_library_data.dart';
import '../../exercises/presentation/exercise_detail_screen.dart';
import '../domain/training_split.dart';
import '../data/training_splits_data.dart';
import '../data/exercise_swaps.dart';
import '../../../shared/responsive.dart';

class TrainScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  final String? initialDay;
  const TrainScreen({
    super.key,
    required this.app,
    required this.controller,
    this.initialDay,
  });

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  late TrainingSplit split;
  late String day;

  @override
  void initState() {
    super.initState();
    split = activeSplit(widget.app.data.settings);
    final jsDow = DateTime.now().weekday % 7;
    day =
        widget.initialDay ??
        scheduleFromSettings(widget.app.data.settings, split)[jsDow] ??
        split.dayOrder.first;
  }

  @override
  void didUpdateWidget(covariant TrainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSplit = activeSplit(widget.app.data.settings);
    if (newSplit.id != split.id) {
      setState(() {
        split = newSplit;
        final jsDow = DateTime.now().weekday % 7;
        day =
            scheduleFromSettings(widget.app.data.settings, split)[jsDow] ??
            split.dayOrder.first;
      });
      return;
    }
    if (widget.initialDay != null &&
        widget.initialDay != oldWidget.initialDay) {
      setState(() => day = widget.initialDay!);
    }
  }

  void _changeDay(String d) => setState(() => day = d);

  bool _savedToday(String name) => isLoggedToday(
    widget.app.data.history,
    name,
    todayStr(widget.app.data.settings),
  );

  List<String> _skippedToday() {
    final all = Map<String, dynamic>.from(
      widget.app.data.settings['workoutSkips'] ?? {},
    );
    return List<String>.from(
      all[todayStr(widget.app.data.settings)] ?? const [],
    );
  }

  void _openExercise(String name, String slotName, int sets, String reps) {
    ExerciseDetailScreen.push(
      context,
      name,
      training: ExerciseTrainingArgs(
        app: widget.app,
        controller: widget.controller,
        dayType: day,
        slotName: slotName,
        targetSets: sets,
        repRange: reps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final originalItems = split.program[day]!.items;
    final swaps = swapsForDay(widget.app.data.settings, split.id, day);
    final items = applySwaps(originalItems, swaps);
    final skipped = _skippedToday();
    final doneCount = items
        .where((it) => _savedToday(it.name) || skipped.contains(it.name))
        .length;
    return LayoutBuilder(builder: (context, c) {
    final wide = c.maxWidth >= Responsive.wideContent;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const SizedBox(height: 8),
        Text(
          split.program[day]!.focus,
          style: TextStyle(fontSize: 13, color: T.muted),
        ),
        const SizedBox(height: 4),
        PillTabs(
          options: split.dayOrder.map((d) => MapEntry(d, d)).toList(),
          value: day,
          onChange: _changeDay,
          scroll: true,
        ),
        PaperCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const IconBubble(
                    icon: Icon(
                      Icons.fitness_center,
                      size: 20,
                      color: Colors.white,
                    ),
                    size: 48,
                    background: T.hero,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$day day',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$doneCount of ${items.length} exercises done today',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: T.paperMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Ring(
                value: doneCount.toDouble(),
                goal: items.length.toDouble(),
                size: 72,
                onPaper: true,
                color: T.hero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...splitColumns(wide, c.maxWidth - 32, items.asMap().entries.map((entry) {
          final slotItem = originalItems[entry.key];
          final it = entry.value;
          final isSwapped = it.name != slotItem.name;
          final info = lib[it.name];
          final hist = List<dynamic>.from(
            widget.app.data.history[it.name] ?? [],
          );
          final prev = hist.isNotEmpty
              ? hist.last as Map<String, dynamic>
              : null;
          final saved = _savedToday(it.name);
          final isSkipped = skipped.contains(it.name);
          final allTop =
              prev != null &&
              prev['date'] != todayStr(widget.app.data.settings) &&
              List.from(prev['sets']).length >= it.sets &&
              List<Map<String, dynamic>>.from(
                prev['sets'],
              ).every((x) => (x['reps'] as num) >= topReps(it.reps));
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  _openExercise(it.name, slotItem.name, it.sets, it.reps),
              child: Opacity(
                opacity: isSkipped ? 0.55 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: T.surface,
                    border: Border.all(
                      color: saved ? const Color(0x807FCB86) : T.line,
                    ),
                    borderRadius: BorderRadius.circular(T.rL),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 56,
                        child: Center(
                          child: MuscleMap(
                            view: info?.view ?? 'front',
                            primary: info?.primary ?? const <String>[],
                            secondary: info?.secondary ?? const <String>[],
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: T.text,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${it.sets} × ${it.reps}${it.kg != null ? ' @ ${it.kg! % 1 == 0 ? it.kg!.toInt() : it.kg} kg' : ''}',
                                  style: mono(fontSize: 12, color: T.muted),
                                ),
                                if (allTop) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_upward,
                                    size: 11,
                                    color: T.accent,
                                  ),
                                  const Text(
                                    'add weight',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: T.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (isSwapped)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: T.accentDim,
                                    borderRadius: BorderRadius.circular(T.pill),
                                  ),
                                  child: Text(
                                    'swapped in for ${slotItem.name}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: T.accent,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (saved) ...[
                        Icon(Icons.check, size: 14, color: T.success),
                        const SizedBox(width: 3),
                        Text(
                          'Logged',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: T.success,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ] else if (isSkipped) ...[
                        Icon(Icons.skip_next, size: 14, color: T.faint),
                        const SizedBox(width: 3),
                        Text(
                          'Skipped',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: T.faint,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(Icons.chevron_right, size: 18, color: T.faint),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList()),
      ],
    );
    });
  }
}
