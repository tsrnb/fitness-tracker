import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../app/app_state.dart';
import '../../plan/domain/plan.dart';
import '../../plan/data/plan_generator.dart';
import '../../plan/data/plan_options.dart';
import '../../training/presentation/plan_chooser_screen.dart';
import '../../training/data/training_splits_data.dart';
import '../data/settings_backup_service.dart';
import 'profiles_page.dart';
import 'widgets/settings_fields.dart';
import 'widgets/settings_rows.dart';
import 'widgets/data_action_card.dart';
import 'widgets/day_boundary_sheet.dart';
import 'widgets/pace_slider.dart';
import 'widgets/theme_picker.dart';

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
  final _backup = SettingsBackupService();
  late Map<String, dynamic> f;
  bool _exporting = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    f = Map<String, dynamic>.from(widget.app.data.settings);
    f['calorieBuffer'] ??= 0;
    f['themeMode'] ??= 'dark';
    f['dayStartMinutes'] ??= 0;
    final plan = widget.app.data.plan;
    f['proteinGoal'] ??= plan?['proteinGoal'] ?? 0;
    f['carbGoal'] ??= plan?['carbGoal'] ?? 0;
    f['fatGoal'] ??= plan?['fatGoal'] ?? 0;
    f['fiberGoal'] ??= plan?['fiberGoal'] ?? 0;
    // Seed the pace slider from whatever this plan is already running at
    // (if it was generated the old target-date-derived way, that's still a
    // sensible starting point), falling back to a plain moderate default.
    final planDailyPace = (plan?['dailyPace'] as num?)?.toInt();
    final currentGoalType = (f['goalType'] as String?) ?? 'fatLoss';
    f['paceDeficitKcal'] ??= (currentGoalType == 'fatLoss' ? planDailyPace : null) ?? 500;
    f['paceSurplusKcal'] ??= (currentGoalType == 'weightGain' ? planDailyPace : null) ?? 300;
  }

  void set(String key, dynamic value) => setState(() => f[key] = value);

  Plan _generate() => buildPlanFromSettings(f);

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
    widget.controller.patchSettings('themeMode', mode);
  }

  void setDayStartMinutes(int minutes) {
    set('dayStartMinutes', minutes);
    // Same immediate-persist rationale as appearance — this only changes how
    // "today" is computed going forward, nothing here feeds plan/macro
    // recalculation, so there's no reason to gate it behind Save.
    widget.controller.patchSettings('dayStartMinutes', minutes);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> exportDb() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await _backup.export(widget.app);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> importDb() async {
    if (_importing) return;
    Map<String, dynamic>? payload;
    try {
      payload = await _backup.pickImportPayload();
    } on InvalidBackupFileException {
      _toast('That file isn\'t a valid CutTracker export.');
      return;
    }
    if (payload == null) return;

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
      await _backup.applyImport(widget.controller, payload);
      if (mounted) setState(() => f = Map<String, dynamic>.from(widget.app.data.settings));
      _toast('Data imported.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Widget _sectionLabel(String text) => Eyebrow(text);

  /// "Fat loss · 8.0kg to go" — nothing to chase for `maintain`, so that case
  /// just shows the goal name.
  String _heroSubtitle() {
    final goal = (f['goalType'] as String?) ?? 'fatLoss';
    final label = goalLabel(goal);
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
      settingsBadgeRow(context,
          icon: Icons.flag, iconColor: T.hero, iconBg: T.accentDim,
          label: 'Goals', sub: 'Goal type & activity level',
          badge: goalLabel((f['goalType'] as String?) ?? 'fatLoss'), badgeBg: T.accentDim, badgeColor: T.hero,
          onTap: () => _navKey.currentState!.pushNamed('goals')),
      settingsBadgeRow(context,
          icon: Icons.fitness_center, iconColor: T.lavAccent, iconBg: T.lavAccent.withValues(alpha: 0.16),
          label: 'Training plan', sub: 'Ranked by effectiveness',
          badge: split.name, badgeBg: T.lavAccent.withValues(alpha: 0.16), badgeColor: T.lavAccent,
          onTap: () => _navKey.currentState!.pushNamed('trainingPlan')),
      settingsBadgeRow(context,
          icon: Icons.pie_chart, iconColor: T.blue, iconBg: T.blue.withValues(alpha: 0.16),
          label: 'Macros & calories', sub: 'Buffer, protein, carbs, fat',
          badge: '${(f['calorieGoal'] as num?)?.round() ?? 0} kcal', badgeBg: T.blue.withValues(alpha: 0.16), badgeColor: T.blue,
          onTap: () => _navKey.currentState!.pushNamed('macros')),
      _sectionLabel('Preferences'),
      settingsBadgeRow(context,
          icon: Icons.restaurant, iconColor: T.success, iconBg: T.success.withValues(alpha: 0.16),
          label: 'Diet preference', sub: 'Veg, egg, non-veg',
          badge: switch (f['dietPref']) { 'egg' => 'Egg', 'nonveg' => 'Non-veg', _ => 'Veg' },
          badgeBg: T.success.withValues(alpha: 0.16), badgeColor: T.success,
          onTap: () => _navKey.currentState!.pushNamed('diet')),
      settingsBadgeRow(context,
          icon: Icons.schedule, iconColor: T.blue, iconBg: T.blue.withValues(alpha: 0.16),
          label: 'Day starts at', sub: 'When logs roll to the next day',
          badge: formatDayStart((f['dayStartMinutes'] as num?)?.toInt() ?? 0),
          badgeBg: T.blue.withValues(alpha: 0.16), badgeColor: T.blue,
          onTap: () => showDayBoundarySheet(context, initialMinutes: (f['dayStartMinutes'] as num?)?.toInt() ?? 0, onApplied: setDayStartMinutes)),
      settingsBadgeRow(context,
          icon: Icons.palette, iconColor: T.muted, iconBg: T.surface2,
          label: 'Appearance', sub: 'Theme',
          badge: f['themeMode'] == 'light' ? 'Light' : 'Dark', badgeBg: T.surface2, badgeColor: T.muted,
          onTap: () => _navKey.currentState!.pushNamed('appearance')),
      _sectionLabel('You & data'),
      settingsNavRow(context, icon: Icons.badge, label: 'Personal details', sub: 'Name, age, height, weight', onTap: () => _navKey.currentState!.pushNamed('personal')),
      settingsNavRow(context, icon: Icons.storage, label: 'Data & export', sub: 'Export your database', onTap: () => _navKey.currentState!.pushNamed('data')),
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
          settingsTextField(context, label: 'Name', value: '${f['name'] ?? ''}', onChange: (v) => set('name', v)),
          Row(children: [
            Expanded(child: settingsTextField(context, label: 'Age', value: '${f['age'] ?? ''}', onChange: (v) => set('age', v), num: true)),
            const SizedBox(width: 10),
            Expanded(child: settingsTextField(context, label: 'Height (cm)', value: '${f['height'] ?? ''}', onChange: (v) => set('height', v), num: true)),
          ]),
          Row(children: [
            Expanded(child: settingsTextField(context, label: 'Current (kg)', value: '${f['currentWeight'] ?? ''}', onChange: (v) => set('currentWeight', v), num: true)),
            const SizedBox(width: 10),
            Expanded(child: settingsTextField(context, label: 'Target (kg)', value: '${f['targetWeight'] ?? ''}', onChange: (v) => set('targetWeight', v), num: true)),
          ]),
          settingsTextField(context, label: 'Target date', value: '${f['targetDate'] ?? ''}', onChange: (v) => set('targetDate', v), date: true),
          settingsSaveButton(save),
        ],
      ),
    );
  }

  /// The deficit/surplus slider — direct input instead of derived from
  /// target weight/date, with the plan (calorie goal, weekly rate, safety
  /// floor, tentative goal date) recalculated live off [f] on every drag.
  /// Absent for `maintain`, which has no pace to set.
  Widget _paceCard(BuildContext context) {
    final goal = (f['goalType'] as String?) ?? 'fatLoss';
    if (goal != 'fatLoss' && goal != 'weightGain') return _maintainPaceCard();

    final isLoss = goal == 'fatLoss';
    final paceKey = isLoss ? 'paceDeficitKcal' : 'paceSurplusKcal';
    final min = isLoss ? 100.0 : 150.0;
    final max = isLoss ? 1000.0 : 500.0;
    final value = ((f[paceKey] as num?) ?? (isLoss ? 500 : 300)).toDouble().clamp(min, max);
    final plan = _generate();

    final String band;
    final Color bandColor;
    if (isLoss) {
      band = value <= 400 ? 'Gentle' : value <= 700 ? 'Moderate' : 'Aggressive';
      bandColor = value <= 400 ? T.success : value <= 700 ? T.accent : T.danger;
    } else {
      band = value <= 250 ? 'Lean' : value <= 380 ? 'Standard' : 'Fast';
      bandColor = value <= 250 ? T.success : value <= 380 ? T.accent : T.danger;
    }
    final ceiling = isLoss ? (plan.tdee - plan.safetyFloorKcal).toDouble() : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rL)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isLoss ? 'Daily deficit' : 'Daily surplus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: T.text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: bandColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(T.pill)),
                child: Text(band, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: bandColor)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 14),
            child: Text(
              isLoss
                  ? "How hard to push below maintenance, every day. The muted zone past the marker is below this app's safety minimum."
                  : 'How far above maintenance to eat. Faster gain tends to mean more of it is fat, not muscle.',
              style: TextStyle(fontSize: 11.5, color: T.muted, height: 1.5),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${value.round()}', style: mono(fontSize: 30, fontWeight: FontWeight.w800, color: T.text)),
              const SizedBox(width: 7),
              Text('kcal / day ${isLoss ? 'below' : 'above'} maintenance', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.muted)),
            ],
          ),
          PaceSlider(min: min, max: max, value: value, ceiling: ceiling, onChanged: (v) => set(paceKey, v.round())),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${min.round()}', style: mono(fontSize: 10, color: T.faint)),
              Text(isLoss ? 'Gentle · Moderate · Aggressive' : 'Lean · Standard · Fast', style: mono(fontSize: 9.5, color: T.faint)),
              Text('${max.round()}', style: mono(fontSize: 10, color: T.faint)),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _paceStat('Calorie goal', '${plan.calorieGoal}')),
            const SizedBox(width: 8),
            Expanded(child: _paceStat('Weekly rate', '${plan.weeklyRate.toStringAsFixed(2)} kg')),
          ]),
          if (isLoss && plan.paceCapped)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: T.danger.withValues(alpha: 0.1), border: Border.all(color: T.danger.withValues(alpha: 0.32)), borderRadius: BorderRadius.circular(10)),
                child: Text.rich(
                  TextSpan(style: TextStyle(fontSize: 11, color: T.text, height: 1.5), children: [
                    TextSpan(text: '⚑ That\'s aggressive. ', style: TextStyle(fontWeight: FontWeight.w700, color: T.danger)),
                    TextSpan(
                        text:
                            "${plan.calorieGoal} kcal/day is below this app's built-in safety minimum (${plan.safetyFloorKcal} kcal). You can still use it — nothing's stopping you — just know it's past what's usually recommended."),
                  ]),
                ),
              ),
            ),
          if (!isLoss && band == 'Fast')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: T.blue.withValues(alpha: 0.1), border: Border.all(color: T.blue.withValues(alpha: 0.32)), borderRadius: BorderRadius.circular(10)),
                child: Text('ⓘ More of this is likely fat, not muscle. Most people get a better ratio staying under ~350 kcal/day.',
                    style: TextStyle(fontSize: 11, color: T.text, height: 1.5)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: plan.tentativeDate != null
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: T.accentDim, border: Border.all(color: T.accentSoft), borderRadius: BorderRadius.circular(T.rM)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🎯 TENTATIVE GOAL DATE', style: mono(fontSize: 10, fontWeight: FontWeight.w800, color: T.accent).copyWith(letterSpacing: 0.6)),
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(_fmtGoalDate(plan.tentativeDate!), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: T.text))),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text('If kept up every day — not a promise. Recalculates as you move the slider.', style: TextStyle(fontSize: 11, color: T.muted, height: 1.5)),
                        ),
                      ],
                    ),
                  )
                // No target weight set above (fat loss: below) the current
                // one, so there's no gap to project a date from — say why,
                // instead of just leaving the date silently missing.
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rM)),
                    child: Text(
                      isLoss
                          ? 'Set a target weight below your current one (in Personal details) to see a tentative goal date.'
                          : 'Set a target weight above your current one (in Personal details) to see a tentative goal date.',
                      style: TextStyle(fontSize: 12, color: T.muted, height: 1.5),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _paceStat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rM)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: T.faint)),
            Padding(padding: const EdgeInsets.only(top: 3), child: Text(value, style: mono(fontSize: 14, fontWeight: FontWeight.w700, color: T.text))),
          ],
        ),
      );

  /// Maintain has no pace to set — rather than leave a blank gap in the
  /// same slot, a quiet static card states the one number that's still
  /// true: today's maintenance calories.
  Widget _maintainPaceCard() {
    final plan = _generate();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rL)),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), shape: BoxShape.circle),
            child: const Text('⚖️', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          Text('Nothing to pace', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: T.text)),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: Text(
              "Maintain isn't chasing a number up or down, so there's no deficit or surplus to dial in — just eating around maintenance.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: T.muted, height: 1.6),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rM)),
            child: Column(children: [
              Text('${plan.calorieGoal}', style: mono(fontSize: 20, fontWeight: FontWeight.w800, color: T.text)),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('kcal/day maintenance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: T.faint)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmtGoalDate(String iso) => DateFormat('EEE, MMM d, yyyy').format(DateTime.parse(iso));

  Widget _goalsPage(BuildContext context) {
    return pageScaffold(
      context: context,
      title: 'Goals',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          settingsSegmented('Goal', (f['goalType'] as String?) ?? 'fatLoss', goalOptions, (v) => set('goalType', v)),
          const Eyebrow('Pace'),
          _paceCard(context),
          const SizedBox(height: 12),
          settingsSegmented('Activity', (f['activity'] as String?) ?? 'moderate', const [
            MapEntry('sedentary', 'Sedentary'),
            MapEntry('light', 'Light'),
            MapEntry('moderate', 'Moderate'),
            MapEntry('active', 'Active'),
            MapEntry('veryActive', 'Very active'),
          ], (v) => set('activity', v)),
          settingsSaveButton(save),
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
          settingsSegmentedInt('Calorie buffer', (f['calorieBuffer'] as num?)?.toInt() ?? 0, calorieBufferOptions, (v) => '+$v', (v) => set('calorieBuffer', v)),
          Row(children: [
            settingsMacroField('Protein', '${f['proteinGoal'] ?? 0}', (v) => set('proteinGoal', v)),
            const SizedBox(width: 10),
            settingsMacroField('Carbs', '${f['carbGoal'] ?? 0}', (v) => set('carbGoal', v)),
          ]),
          Row(children: [
            settingsMacroField('Fat', '${f['fatGoal'] ?? 0}', (v) => set('fatGoal', v)),
            const SizedBox(width: 10),
            settingsMacroField('Fiber', '${f['fiberGoal'] ?? 0}', (v) => set('fiberGoal', v)),
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
          settingsSaveButton(save),
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
          settingsSegmented('Diet', (f['dietPref'] as String?) ?? 'veg', const [MapEntry('veg', 'Veg'), MapEntry('egg', 'Egg'), MapEntry('nonveg', 'Non-veg')], (v) => set('dietPref', v)),
          settingsSaveButton(save),
        ],
      ),
    );
  }

  Widget _appearancePage(BuildContext context) {
    final mode = f['themeMode'] == 'light' ? 'light' : 'dark';
    return pageScaffold(
      context: context,
      title: 'Appearance',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Theme'),
          // setThemeMode both flips AppTheme.mode (repaints the whole app
          // immediately) and calls this screen's own setState via `set()`,
          // so the picker's selected card and the badge back on the
          // Settings list stay in sync with no extra wiring here.
          ThemePicker(value: mode, onChange: setThemeMode),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              mode == 'light' ? 'Light applies everywhere, right away.' : 'Dark applies everywhere, right away.',
              style: Type.caption,
            ),
          ),
        ],
      ),
    );
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
          dataActionCard(
            context,
            illustration: const DataIllustration(kind: DataIllustrationKind.export),
            title: 'Export data',
            description: 'Save a copy of your profile, weight, workouts, diet log, and foods as a .json file. Keep it somewhere safe, or use it to move your data to another device.',
            buttonLabel: 'Export as JSON',
            buttonIcon: Icons.ios_share,
            loading: _exporting,
            onTap: exportDb,
            filled: true,
          ),
          dataActionCard(
            context,
            illustration: const DataIllustration(kind: DataIllustrationKind.import),
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
