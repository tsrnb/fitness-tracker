import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/widgets/pressable_scale.dart';
import '../../app/app_state.dart';
import '../plan/plan_generator.dart';
import '../training/plan_chooser_screen.dart';
import '../training/splits.dart';
import 'profiles_page.dart';

/// Full-page Settings, replacing the old modal sheet. A private nested
/// [Navigator] gives each group (Personal, Goals, Macros, Diet, Appearance,
/// Data) its own drill-down page while sharing one `f` (draft settings) map
/// and one save/recalculate flow, so "back" within Settings doesn't have to
/// leave the whole screen.
class SettingsScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const SettingsScreen({super.key, required this.app, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _navKey = GlobalKey<NavigatorState>();
  late Map<String, dynamic> f;
  bool _exporting = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    f = Map<String, dynamic>.from(widget.app.data.settings);
    f['calorieBuffer'] ??= 0;
    f['themeMode'] ??= 'dark';
    final plan = widget.app.data.plan;
    f['proteinGoal'] ??= plan?['proteinGoal'] ?? 0;
    f['carbGoal'] ??= plan?['carbGoal'] ?? 0;
    f['fatGoal'] ??= plan?['fatGoal'] ?? 0;
    f['fiberGoal'] ??= plan?['fiberGoal'] ?? 0;
  }

  void set(String key, dynamic value) => setState(() => f[key] = value);

  Plan _generate() {
    final currentWeight = double.tryParse('${f['currentWeight'] ?? ''}') ?? 0;
    final targetWeight = double.tryParse('${f['targetWeight'] ?? ''}') ?? currentWeight;
    final height = double.tryParse('${f['height'] ?? ''}') ?? 0;
    final age = double.tryParse('${f['age'] ?? ''}') ?? 0;
    return generatePlan(
      currentWeight: currentWeight,
      targetWeight: targetWeight,
      height: height,
      age: age,
      sex: f['sex'] ?? 'male',
      activity: f['activity'] ?? 'moderate',
      goalType: f['goalType'] ?? 'fatLoss',
      dietPref: f['dietPref'] ?? 'veg',
      targetDate: f['targetDate'] ?? '',
      calorieBuffer: (f['calorieBuffer'] as num?)?.toInt() ?? 0,
    );
  }

  void recalculateMacros() {
    final plan = _generate();
    setState(() {
      f['proteinGoal'] = plan.proteinGoal;
      f['carbGoal'] = plan.carbGoal;
      f['fatGoal'] = plan.fatGoal;
      f['fiberGoal'] = plan.fiberGoal;
    });
  }

  void save() {
    final currentWeight = double.tryParse('${f['currentWeight'] ?? ''}') ?? 0;
    final targetWeight = double.tryParse('${f['targetWeight'] ?? ''}') ?? currentWeight;
    final height = double.tryParse('${f['height'] ?? ''}') ?? 0;
    final age = double.tryParse('${f['age'] ?? ''}') ?? 0;
    final profile = {
      ...f,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'height': height,
      'age': age,
    };
    final plan = _generate();
    profile['calorieGoal'] = plan.calorieGoal;
    profile['stepGoal'] = plan.stepGoal;
    profile['proteinGoal'] = f['proteinGoal'];
    profile['carbGoal'] = f['carbGoal'];
    profile['fatGoal'] = f['fatGoal'];
    profile['fiberGoal'] = f['fiberGoal'];
    widget.controller.update('settings', (_) => profile);
    widget.controller.update('plan', (_) => plan.toJson());
    _navKey.currentState!.popUntil((r) => r.isFirst);
  }

  void setThemeMode(String mode) {
    set('themeMode', mode);
    AppTheme.set(mode == 'light' ? Brightness.light : Brightness.dark);
    // Persisted immediately (unlike the other groups) since there's no
    // natural "Save" action tied to appearance and it should stick right away.
    widget.controller.update('settings', (prev) {
      final s = Map<String, dynamic>.from(prev ?? {});
      s['themeMode'] = mode;
      return s;
    });
  }

  static const _exportKeys = ['settings', 'weight', 'history', 'sessions', 'diet', 'water', 'activity', 'plan'];

  Future<void> exportDb() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      // Always the JSON payload (not the raw native .sqlite file) so what
      // Export produces is exactly what Import (JSON-only, every platform)
      // can read back — a native-only raw-db export used to be paired with
      // a JSON-only import, so round-tripping a native export silently
      // failed to parse.
      final data = widget.app.data;
      final payload = {
        'user': widget.app.user?.name,
        'settings': data.settings,
        'weight': data.weight,
        'history': data.history,
        'sessions': data.sessions,
        'diet': data.diet,
        'water': data.water,
        'activity': data.activity,
        'plan': data.plan,
        'foods': widget.app.foods
            .map((f) => {'name': f.name, 'kcal': f.kcal, 'protein': f.protein, 'carb': f.carb, 'fat': f.fat, 'fiber': f.fiber})
            .toList(),
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'cuttracker_export.json', mimeType: 'application/json')],
        text: 'CutTracker data export',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> importDb() async {
    if (_importing) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      _toast('That file isn\'t a valid CutTracker export.');
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.surface,
        title: Text('Replace current data?', style: TextStyle(color: T.text)),
        content: Text(
          'Importing will overwrite this profile\'s settings, logs, and plan with the contents of the file. This can\'t be undone.',
          style: TextStyle(color: T.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: TextStyle(color: T.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Import', style: TextStyle(color: T.accent))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      for (final key in _exportKeys) {
        if (payload[key] != null) await widget.controller.update(key, (_) => payload[key]);
      }
      final foods = payload['foods'];
      if (foods is List) {
        for (final food in foods) {
          final row = Map<String, dynamic>.from(food as Map);
          await widget.controller.addFood(
            row['name'] as String,
            (row['kcal'] as num).toDouble(),
            (row['protein'] as num).toDouble(),
            (row['carb'] as num?)?.toDouble() ?? 0,
            (row['fat'] as num?)?.toDouble() ?? 0,
            (row['fiber'] as num?)?.toDouble() ?? 0,
          );
        }
      }
      if (mounted) setState(() => f = Map<String, dynamic>.from(widget.app.data.settings));
      _toast('Data imported.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Widget _field(String label, String key, {bool num = false, bool date = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          date
              ? GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse('${f[key] ?? ''}') ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) set(key, picked.toIso8601String().substring(0, 10));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
                    child: Text('${f[key] ?? ''}', style: mono(fontSize: 16, color: T.text)),
                  ),
                )
              : TextField(
                  controller: TextEditingController.fromValue(TextEditingValue(text: '${f[key] ?? ''}', selection: TextSelection.collapsed(offset: '${f[key] ?? ''}'.length))),
                  onChanged: (v) => set(key, v),
                  keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                  style: TextStyle(color: T.text, fontSize: 16, fontFamily: num ? monoFont : null),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: T.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.accent)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _seg(String label, String key, List<MapEntry<String, String>> opts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opts.map((o) {
              final active = f[key] == o.key;
              return GestureDetector(
                onTap: () => set(key, o.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? T.hero : T.surface2,
                    border: Border.all(color: active ? T.hero : T.line),
                    borderRadius: BorderRadius.circular(T.pill),
                  ),
                  child: Text(o.value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : T.text)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _segInt(String label, String key, List<int> opts, String Function(int) fmt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opts.map((o) {
              final active = ((f[key] as num?)?.toInt() ?? 0) == o;
              return GestureDetector(
                onTap: () => set(key, o),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? T.hero : T.surface2,
                    border: Border.all(color: active ? T.hero : T.line),
                    borderRadius: BorderRadius.circular(T.pill),
                  ),
                  child: Text(fmt(o), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : T.text)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _macroField(String label, String key) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(label),
            NumIn(value: '${f[key] ?? 0}', onChange: (v) => set(key, v), suffix: 'g'),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: PrimaryButton(
          onTap: save,
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome, size: 17),
            SizedBox(width: 8),
            Text('Save & recalculate plan'),
          ]),
        ),
      );

  Widget _navRow(BuildContext context, {required IconData icon, required String label, required String sub, required String route}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => _navKey.currentState!.pushNamed(route),
        child: Row(children: [
          IconBubble(icon: Icon(icon, size: 16, color: T.muted), size: 32, background: T.surface2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: T.text)),
                Text(sub, style: TextStyle(fontSize: 12, color: T.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: T.faint),
        ]),
      ),
    );
  }

  /// A settings row with a trailing status pill instead of a plain chevron —
  /// shows the current value (goal, split, macros...) right on the row.
  Widget _badgeRow(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String sub,
    required String badge,
    required Color badgeBg,
    required Color badgeColor,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _navKey.currentState!.pushNamed(route),
        child: Row(children: [
          IconBubble(icon: Icon(icon, size: 16, color: iconColor), size: 32, background: iconBg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: T.text)),
                Text(sub, style: TextStyle(fontSize: 12, color: T.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(T.pill)),
            child: Text(badge, style: mono(fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor)),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Eyebrow(text);

  String _goalLabel(String key) => goalOptions.firstWhere((o) => o.key == key, orElse: () => const MapEntry('', '')).value;

  /// "Fat loss · 8.0kg to go" — nothing to chase for `maintain`, so that case
  /// just shows the goal name.
  String _heroSubtitle() {
    final goal = (f['goalType'] as String?) ?? 'fatLoss';
    final label = _goalLabel(goal);
    if (goal == 'maintain') return label;
    final cur = double.tryParse('${f['currentWeight'] ?? ''}') ?? 0;
    final tgt = double.tryParse('${f['targetWeight'] ?? ''}') ?? cur;
    final diff = (cur - tgt).abs();
    if (diff <= 0) return label;
    return '$label · ${diff.toStringAsFixed(1)}kg to go';
  }

  Widget _heroCard(BuildContext context) {
    final app = widget.app;
    final name = app.user?.name ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final split = activeSplit(f);
    final calorieGoal = (f['calorieGoal'] as num?)?.round() ?? 0;
    final proteinGoal = (f['proteinGoal'] as num?)?.round() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: PressableScale(
        onTap: () => _navKey.currentState!.pushNamed('profiles'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [T.accent.withValues(alpha: 0.15), T.accent.withValues(alpha: 0.04)]),
            border: Border.all(color: T.accent.withValues(alpha: 0.22)),
            borderRadius: BorderRadius.circular(T.rXL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
                    child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(color: T.text, fontWeight: FontWeight.w800, fontSize: 18)),
                        Padding(padding: const EdgeInsets.only(top: 2), child: Text(_heroSubtitle(), style: TextStyle(color: T.muted, fontSize: 13))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
                    child: Text('Edit', style: mono(fontSize: 12, fontWeight: FontWeight.w700, color: T.muted)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _heroStat('$calorieGoal', 'kcal/day')),
                const SizedBox(width: 7),
                Expanded(child: _heroStat('${proteinGoal}g', 'protein')),
                const SizedBox(width: 7),
                Expanded(child: _heroStat('${split.daysPerWeek}d', 'wk split')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rM)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: mono(fontSize: 17, fontWeight: FontWeight.w700, color: T.accent)),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(label, style: TextStyle(fontSize: 12.5, color: T.muted))),
          ],
        ),
      );

  Widget _rootList(BuildContext context) {
    final split = activeSplit(f);
    final rows = <Widget>[
      _heroCard(context),
      _sectionLabel('Health & training'),
      _badgeRow(context,
          icon: Icons.flag, iconColor: T.hero, iconBg: T.accentDim,
          label: 'Goals', sub: 'Goal type & activity level',
          badge: _goalLabel((f['goalType'] as String?) ?? 'fatLoss'), badgeBg: T.accentDim, badgeColor: T.hero,
          route: 'goals'),
      _badgeRow(context,
          icon: Icons.fitness_center, iconColor: T.lav, iconBg: T.lavSoft,
          label: 'Training plan', sub: 'Ranked by effectiveness',
          badge: split.name, badgeBg: T.lavSoft, badgeColor: T.lav,
          route: 'trainingPlan'),
      _badgeRow(context,
          icon: Icons.pie_chart, iconColor: T.blue, iconBg: T.blue.withValues(alpha: 0.16),
          label: 'Macros & calories', sub: 'Buffer, protein, carbs, fat',
          badge: '${(f['calorieGoal'] as num?)?.round() ?? 0} kcal', badgeBg: T.blue.withValues(alpha: 0.16), badgeColor: T.blue,
          route: 'macros'),
      _sectionLabel('Preferences'),
      _badgeRow(context,
          icon: Icons.restaurant, iconColor: T.success, iconBg: T.success.withValues(alpha: 0.16),
          label: 'Diet preference', sub: 'Veg, egg, non-veg',
          badge: switch (f['dietPref']) { 'egg' => 'Egg', 'nonveg' => 'Non-veg', _ => 'Veg' },
          badgeBg: T.success.withValues(alpha: 0.16), badgeColor: T.success,
          route: 'diet'),
      _badgeRow(context,
          icon: Icons.palette, iconColor: T.muted, iconBg: T.surface2,
          label: 'Appearance', sub: 'Theme',
          badge: f['themeMode'] == 'light' ? 'Light' : 'Dark', badgeBg: T.surface2, badgeColor: T.muted,
          route: 'appearance'),
      _sectionLabel('You & data'),
      _navRow(context, icon: Icons.badge, label: 'Personal details', sub: 'Name, age, height, weight', route: 'personal'),
      _navRow(context, icon: Icons.storage, label: 'Data & export', sub: 'Export your database', route: 'data'),
    ];
    return pageScaffold(
      context: context,
      title: 'Settings',
      onBack: () => Navigator.of(context, rootNavigator: true).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(rows.length, (i) => StaggerIn(index: i, child: rows[i])),
        ],
      ),
    );
  }

  Widget _personalPage(BuildContext context) {
    return pageScaffold(
      context: context,
      title: 'Personal details',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Name', 'name'),
          Row(children: [
            Expanded(child: _field('Age', 'age', num: true)),
            const SizedBox(width: 10),
            Expanded(child: _field('Height (cm)', 'height', num: true)),
          ]),
          Row(children: [
            Expanded(child: _field('Current (kg)', 'currentWeight', num: true)),
            const SizedBox(width: 10),
            Expanded(child: _field('Target (kg)', 'targetWeight', num: true)),
          ]),
          _field('Target date', 'targetDate', date: true),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _goalsPage(BuildContext context) {
    return pageScaffold(
      context: context,
      title: 'Goals',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seg('Goal', 'goalType', goalOptions),
          _seg('Activity', 'activity', const [
            MapEntry('sedentary', 'Sedentary'),
            MapEntry('light', 'Light'),
            MapEntry('moderate', 'Moderate'),
            MapEntry('active', 'Active'),
            MapEntry('veryActive', 'Very active'),
          ]),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _macrosPage(BuildContext context) {
    return pageScaffold(
      context: context,
      title: 'Macros & calories',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segInt('Calorie buffer', 'calorieBuffer', calorieBufferOptions, (v) => '+$v'),
          Row(children: [
            _macroField('Protein', 'proteinGoal'),
            const SizedBox(width: 10),
            _macroField('Carbs', 'carbGoal'),
          ]),
          Row(children: [
            _macroField('Fat', 'fatGoal'),
            const SizedBox(width: 10),
            _macroField('Fiber', 'fiberGoal'),
          ]),
          GestureDetector(
            onTap: recalculateMacros,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh, size: 14, color: T.accent),
                const SizedBox(width: 6),
                Text('Recalculate from plan', style: TextStyle(fontSize: 12, color: T.accent, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _dietPage(BuildContext context) {
    return pageScaffold(
      context: context,
      title: 'Diet preference',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seg('Diet', 'dietPref', const [MapEntry('veg', 'Veg'), MapEntry('egg', 'Egg'), MapEntry('nonveg', 'Non-veg')]),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _appearancePage(BuildContext context) {
    return pageScaffold(
      context: context,
      title: 'Appearance',
      onBack: () => Navigator.of(context).pop(),
      child: StatefulBuilder(
        builder: (context, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Theme'),
            // Light mode switching is disabled for now — kept visible (not
            // removed) so it's clear the option exists and isn't just missing.
            Opacity(
              opacity: 0.5,
              child: IgnorePointer(
                child: PillTabs(
                  options: const [MapEntry('dark', 'Dark'), MapEntry('light', 'Light')],
                  value: 'dark',
                  onChange: (_) {},
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text('Light mode is coming soon.', style: Type.caption),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataActionCard(
    BuildContext context, {
    required Widget illustration,
    required String title,
    required String description,
    required String buttonLabel,
    required IconData buttonIcon,
    required bool loading,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            illustration,
            const SizedBox(height: 14),
            Text(title, style: Type.h3),
            const SizedBox(height: 6),
            Text(description, style: Type.caption),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: filled
                  ? PrimaryButton(
                      onTap: onTap,
                      opacity: loading ? 0.6 : 1,
                      child: _dataActionButtonContent(buttonIcon, buttonLabel, loading, Colors.white),
                    )
                  : PressableScale(
                      onTap: loading ? null : onTap,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(T.rM),
                          border: Border.all(color: T.line),
                        ),
                        alignment: Alignment.center,
                        child: _dataActionButtonContent(buttonIcon, buttonLabel, loading, T.text),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataActionButtonContent(IconData icon, String label, bool loading, Color color) {
    if (loading) {
      return SizedBox(height: 17, width: 17, child: CircularProgressIndicator(strokeWidth: 2, color: color));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
    ]);
  }

  Widget _dataPage(BuildContext context) {
    return pageScaffold(
      context: context,
      title: 'Data & export',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(kIsWeb ? 'storage: browser' : 'storage: sqlite', style: mono(fontSize: 11, color: T.faint)),
          ),
          _dataActionCard(
            context,
            illustration: const _DataIllustration(kind: _DataIllustrationKind.export),
            title: 'Export data',
            description: 'Save a copy of your profile, weight, workouts, diet log, and foods as a .json file. Keep it somewhere safe, or use it to move your data to another device.',
            buttonLabel: 'Export as JSON',
            buttonIcon: Icons.ios_share,
            loading: _exporting,
            onTap: exportDb,
            filled: true,
          ),
          _dataActionCard(
            context,
            illustration: const _DataIllustration(kind: _DataIllustrationKind.import),
            title: 'Import data',
            description: 'Restore a previously exported .json file. This replaces this profile\'s current settings, logs, and plan — export first if you want to keep a backup.',
            buttonLabel: 'Choose JSON file',
            buttonIcon: Icons.folder_open,
            loading: _importing,
            onTap: importDb,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navKey,
      onGenerateRoute: (routeSettings) {
        final builder = switch (routeSettings.name) {
          'personal' => _personalPage,
          'goals' => _goalsPage,
          'trainingPlan' => (ctx) => TrainingPlanChooserScreen(app: widget.app, controller: widget.controller),
          'macros' => _macrosPage,
          'diet' => _dietPage,
          'appearance' => _appearancePage,
          'data' => _dataPage,
          'profiles' => (ctx) => ProfilesPage(app: widget.app, controller: widget.controller),
          _ => _rootList,
        };
        return MaterialPageRoute(settings: routeSettings, builder: builder);
      },
    );
  }
}

enum _DataIllustrationKind { export, import }

/// A small illustrated tray-and-document motif for the export/import cards,
/// built entirely from layered shapes (no external image asset) so it stays
/// theme-aware in light/dark automatically, per T.* tokens.
class _DataIllustration extends StatelessWidget {
  final _DataIllustrationKind kind;
  const _DataIllustration({required this.kind});

  @override
  Widget build(BuildContext context) {
    final isExport = kind == _DataIllustrationKind.export;
    final tone = isExport ? T.hero : T.lav;
    final badgeInk = isExport ? Colors.white : T.lavInk;
    return SizedBox(
      width: 72,
      height: 66,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 4,
            child: Container(
              width: 58,
              height: 30,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tone.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 38,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
              decoration: BoxDecoration(
                color: T.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tone, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(3, (i) {
                  return Container(
                    margin: EdgeInsets.only(bottom: i < 2 ? 5 : 0),
                    height: 3,
                    width: i == 2 ? 14 : double.infinity,
                    decoration: BoxDecoration(color: tone.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                  );
                }),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle, border: Border.all(color: T.surface, width: 2.5)),
              child: Icon(isExport ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: badgeInk),
            ),
          ),
        ],
      ),
    );
  }
}
