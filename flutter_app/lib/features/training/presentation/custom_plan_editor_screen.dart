import 'package:flutter/material.dart';
import '../../../app/app_state.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../exercises/data/exercise_library_data.dart';
import '../../exercises/presentation/library_screen.dart';
import '../data/custom_plan.dart';
import '../../../shared/responsive.dart';

const _repPresets = ['5', '6-8', '8-10', '10-12', '12-15', '15-20'];
const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

enum _Field { sets, reps, kg }

/// Settings → Training plan → Build your own. A sheet-style table per day:
/// tap a Sets / Reps / kg cell and a quick-pick panel replaces the Save bar.
/// Exercises are chosen through the existing [LibraryScreen]. Saving writes
/// `settings['customPlan']` and switches `trainingSplitId` to 'custom'.
class CustomPlanEditorScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const CustomPlanEditorScreen({super.key, required this.app, required this.controller});

  @override
  State<CustomPlanEditorScreen> createState() => _CustomPlanEditorScreenState();
}

class _CustomPlanEditorScreenState extends State<CustomPlanEditorScreen> {
  late CustomPlan plan;
  late final TextEditingController _name;
  late TextEditingController _dayName;
  int day = 0;
  ({int row, _Field field})? editing;
  bool dirty = false;

  CustomDay get cur => plan.days[day];

  @override
  void initState() {
    super.initState();
    plan = customPlanFromSettings(widget.app.data.settings) ?? CustomPlan.blank();
    _name = TextEditingController(text: plan.name);
    _dayName = TextEditingController(text: cur.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _dayName.dispose();
    super.dispose();
  }

  void _touch(VoidCallback fn) => setState(() {
        fn();
        dirty = true;
      });

  void _selectDay(int i) => setState(() {
        day = i;
        editing = null;
        _dayName.text = cur.name;
      });

  void _addDay() {
    _touch(() => plan.days.add(CustomDay('Day ${plan.days.length + 1}')));
    _selectDay(plan.days.length - 1);
  }

  void _deleteDay() {
    if (plan.days.length < 2) return;
    final removed = day;
    _touch(() {
      plan.days.removeAt(removed);
      plan.schedule = plan.schedule.map((v) => v == removed ? null : (v != null && v > removed ? v - 1 : v)).toList();
    });
    _selectDay(0);
  }

  Future<void> _addExercise() async {
    final picked = await Navigator.of(context).push<String>(AppRoute(
      builder: (ctx) => Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
          backgroundColor: T.bg,
          elevation: 0,
          foregroundColor: T.text,
          title: Text('Add to ${cur.name}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.text)),
        ),
        body: LibraryScreen(openExercise: (n) => Navigator.of(ctx).pop(n)),
      ),
    ));
    if (picked == null || !mounted) return;
    if (cur.items.any((e) => e.name == picked)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$picked is already in ${cur.name}')));
      return;
    }
    _touch(() {
      cur.items.add(CustomExercise(picked));
      editing = (row: cur.items.length - 1, field: _Field.sets);
    });
  }

  void _toggleCell(int row, _Field f) => setState(() {
        editing = (editing?.row == row && editing?.field == f) ? null : (row: row, field: f);
      });

  Future<void> _save() async {
    plan.name = _name.text.trim().isEmpty ? 'My plan' : _name.text.trim();
    final json = plan.toJson();
    Map<String, dynamic>? saved;
    await widget.controller.update('settings', (prev) {
      final s = Map<String, dynamic>.from(prev ?? {});
      s['customPlan'] = json;
      s['trainingSplitId'] = customSplitId;
      s.remove('schedule'); // day names changed; fall back to the plan's own week
      saved = s;
      return s;
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    // PopScope blocks pops while dirty, so clear it and pop after the rebuild.
    setState(() => dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.pop(saved);
      messenger.showSnackBar(SnackBar(content: Text('${plan.name} is now your training plan.')));
    });
  }

  Future<bool> _confirmDiscard() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.surface,
        title: Text('Discard changes?', style: TextStyle(color: T.text)),
        content: Text('Your edits to this plan have not been saved.', style: TextStyle(color: T.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Keep editing', style: TextStyle(color: T.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Discard', style: TextStyle(color: T.danger, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final canSave = plan.days.any((d) => d.items.isNotEmpty);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
          backgroundColor: T.bg,
          elevation: 0,
          foregroundColor: T.text,
          title: Text('Build your plan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.text)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    TextField(
                      controller: _name,
                      maxLength: 30,
                      onChanged: (_) => dirty = true,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: T.text),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Plan name',
                        hintStyle: TextStyle(color: T.faint),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: T.line)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: T.accent)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _dayChips(),
                    const SizedBox(height: 12),
                    _dayNameRow(),
                    const SizedBox(height: 12),
                    _table(),
                    const SizedBox(height: 12),
                    _addButton(),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${cur.items.length} exercises · ${cur.items.fold(0, (a, e) => a + e.sets)} sets · ~${(cur.items.fold(0, (a, e) => a + e.sets) * 3.2).round()} min',
                        style: TextStyle(fontSize: 12, color: T.muted),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _weekRow(),
                  ],
                ),
              ),
              if (editing != null && editing!.row < cur.items.length)
                _quickPanel()
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: PrimaryButton(onTap: canSave ? _save : null, opacity: canSave ? 1 : 0.4, child: const Text('Save & use plan')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {required bool on, required VoidCallback onTap, bool dashed = false, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? T.text : Colors.transparent,
          borderRadius: BorderRadius.circular(T.pill),
          border: Border.all(color: on ? T.text : (dashed ? T.accent : T.line)),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? T.bg : (color ?? (dashed ? T.accent : T.muted)))),
      ),
    );
  }

  Widget _dayChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < plan.days.length; i++) _chip(plan.days[i].name, on: i == day, onTap: () => _selectDay(i)),
          _chip('+ Day', on: false, dashed: true, onTap: _addDay),
        ]),
      );

  Widget _dayNameRow() => Row(children: [
        Expanded(
          child: TextField(
            controller: _dayName,
            maxLength: 16,
            onChanged: (v) => _touch(() => cur.name = v),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: T.text),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: T.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: T.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: T.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: T.accent)),
            ),
          ),
        ),
        if (plan.days.length > 1) ...[
          const SizedBox(width: 8),
          _chip('Delete day', on: false, color: T.danger, onTap: _deleteDay),
        ],
      ]);

  String _kgText(double kg) => kg % 1 == 0 ? kg.toInt().toString() : kg.toString();

  Widget _cell(String text, int row, _Field f) {
    final on = editing?.row == row && editing?.field == f;
    return GestureDetector(
      onTap: () => _toggleCell(row, f),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? T.accentDim : T.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? T.accent : Colors.transparent),
        ),
        child: Text(text, style: mono(fontSize: 14, fontWeight: FontWeight.w700, color: on ? T.accent : T.text)),
      ),
    );
  }

  Widget _table() {
    Widget head(String t) => Center(child: Text(t.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: T.muted)));
    const widths = <int, TableColumnWidth>{
      0: FlexColumnWidth(),
      1: FixedColumnWidth(46),
      2: FixedColumnWidth(70),
      3: FixedColumnWidth(62),
      4: FixedColumnWidth(32),
    };
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: T.line)),
      child: Column(children: [
        Container(
          color: T.surface2,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Table(columnWidths: widths, children: [
            TableRow(children: [
              Text('EXERCISE', style: TextStyle(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: T.muted)),
              head('Sets'),
              head('Reps'),
              head('kg'),
              const SizedBox.shrink(),
            ]),
          ]),
        ),
        if (cur.items.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text('No exercises yet. Add one below.', style: TextStyle(fontSize: 12, color: T.muted))),
        for (var i = 0; i < cur.items.length; i++)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: T.line))),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Table(
              columnWidths: widths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((lib[cur.items[i].name]?.group ?? '').toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: T.lavAccent)),
                      Text(cur.items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.text)),
                    ]),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _cell('${cur.items[i].sets}', i, _Field.sets)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _cell(cur.items[i].reps, i, _Field.reps)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _cell(_kgText(cur.items[i].kg), i, _Field.kg)),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Remove ${cur.items[i].name}',
                    icon: Icon(Icons.close, size: 16, color: T.faint),
                    onPressed: () => _touch(() {
                      cur.items.removeAt(i);
                      editing = null;
                    }),
                  ),
                ]),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _addButton() => GestureDetector(
        onTap: _addExercise,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: T.line, width: 1.5)),
          child: const Text('+ Add exercise', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: T.accent)),
        ),
      );

  Widget _weekRow() {
    final names = plan.uniqueDayNames();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('YOUR WEEK', style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: T.muted)),
      const SizedBox(height: 4),
      Text('Tap a weekday to cycle through your days. Rest is the default.', style: TextStyle(fontSize: 12, color: T.muted)),
      const SizedBox(height: 10),
      Row(children: [
        for (var d = 0; d < 7; d++)
          Expanded(
            child: GestureDetector(
              onTap: () => _touch(() {
                final v = plan.schedule[d];
                plan.schedule[d] = v == null ? 0 : (v + 1 < plan.days.length ? v + 1 : null);
              }),
              child: Container(
                margin: EdgeInsets.only(right: d == 6 ? 0 : 5),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: plan.schedule[d] != null ? T.accent : T.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text(_weekdays[d], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: plan.schedule[d] != null ? T.accentInk : T.muted)),
                  const SizedBox(height: 4),
                  Text(
                    plan.schedule[d] != null ? customDayAbbr(names[plan.schedule[d]!]) : '–',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: plan.schedule[d] != null ? T.accentInk : T.faint),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    ]);
  }

  Widget _quickPanel() {
    final e = cur.items[editing!.row];
    final f = editing!.field;
    final title = {_Field.sets: 'Sets', _Field.reps: 'Reps', _Field.kg: 'Weight'}[f]!;
    final value = f == _Field.sets ? '${e.sets}' : f == _Field.reps ? e.reps : '${_kgText(e.kg)} kg';

    Widget btn(String label, bool on, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: () => _touch(onTap),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? T.accent : T.surface2, borderRadius: BorderRadius.circular(12)),
              child: Text(label, style: mono(fontSize: 14, fontWeight: FontWeight.w700, color: on ? T.accentInk : T.text)),
            ),
          ),
        );

    final List<Widget> chips;
    if (f == _Field.sets) {
      chips = [for (final v in [1, 2, 3, 4, 5, 6]) btn('$v', e.sets == v, () => e.sets = v)];
    } else if (f == _Field.reps) {
      chips = [for (final v in _repPresets) btn(v, e.reps == v, () => e.reps = v)];
    } else {
      chips = [
        for (final d in [-5.0, -2.5, 2.5, 5.0, 10.0])
          btn('${d > 0 ? '+' : '−'}${_kgText(d.abs())}', false, () => e.kg = (e.kg + d).clamp(0, 400).toDouble()),
      ];
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(color: T.surface, border: Border(top: BorderSide(color: T.line))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(
            child: Text('${e.name} · $title'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: T.muted)),
          ),
          Padding(padding: const EdgeInsets.only(right: 6), child: Text(value, style: mono(fontSize: 24, fontWeight: FontWeight.w700, color: T.text))),
        ]),
        const SizedBox(height: 10),
        Row(children: chips),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => setState(() => editing = null),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(T.pill)),
              child: Text('Done', style: TextStyle(fontWeight: FontWeight.w800, color: T.text)),
            ),
          ),
        ),
      ]),
    );
  }
}
