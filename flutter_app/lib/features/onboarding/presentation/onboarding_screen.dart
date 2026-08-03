import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/helpers.dart';
import '../../plan/domain/plan.dart';
import '../../plan/data/plan_generator.dart';
import '../../plan/data/plan_options.dart';
import '../../training/data/training_splits_data.dart';
import '../../training/data/split_effectiveness.dart';

typedef OnboardingComplete = void Function(Map<String, dynamic> profile, Plan plan);

/// Highest-scoring split for a goal, per [rankedSplits] — used both to
/// pre-select a sensible default on the onboarding training step and as a
/// fallback if that step is somehow skipped.
String _topSplitId(String forGoal) => rankedSplits(forGoal).first.id;

class OnboardingScreen extends StatefulWidget {
  final OnboardingComplete onComplete;
  final VoidCallback? onCancel;
  const OnboardingScreen({super.key, required this.onComplete, this.onCancel});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  final steps = const ['name', 'sex', 'stats', 'goal', 'training', 'target', 'activity', 'diet', 'summary'];

  String name = '';
  String sex = 'male';
  String age = '';
  String height = '';
  String currentWeight = '';
  String targetWeight = '';
  String targetDate = '';
  String activity = 'moderate';
  String goalType = 'fatLoss';
  String dietPref = 'veg';

  /// Null until the user actually taps a split — until then, the training
  /// step keeps re-deriving its pre-selection from whatever goal is picked.
  String? trainingSplitId;

  @override
  void initState() {
    super.initState();
    targetDate = DateTime.now().add(const Duration(days: 84)).toIso8601String().substring(0, 10);
  }

  String get cur => steps[step];

  bool canNext() {
    if (cur == 'name') return name.trim().isNotEmpty;
    if (cur == 'stats') return (double.tryParse(age) ?? 0) > 0 && (double.tryParse(height) ?? 0) > 0 && (double.tryParse(currentWeight) ?? 0) > 0;
    if (cur == 'target') return goalType == 'maintain' ? true : (double.tryParse(targetWeight) ?? 0) > 0 && targetDate.isNotEmpty;
    return true;
  }

  Plan buildPlan() {
    final tw = targetWeight.isEmpty ? currentWeight : targetWeight;
    return generatePlan(
      currentWeight: double.tryParse(currentWeight) ?? 0,
      targetWeight: double.tryParse(tw) ?? 0,
      height: double.tryParse(height) ?? 0,
      age: double.tryParse(age) ?? 0,
      sex: sex,
      activity: activity,
      goalType: goalType,
      dietPref: dietPref,
      targetDate: targetDate,
    );
  }

  void next() {
    if (cur == 'target' && goalType == 'maintain' && targetWeight.isEmpty) {
      setState(() => targetWeight = currentWeight);
    }
    if (step < steps.length - 1) {
      setState(() => step++);
    } else {
      finish();
    }
  }

  void back() {
    if (step == 0) {
      widget.onCancel?.call();
    } else {
      setState(() => step--);
    }
  }

  void finish() {
    final tw = targetWeight.isEmpty ? currentWeight : targetWeight;
    final profile = {
      'name': name,
      'sex': sex,
      'age': double.tryParse(age) ?? 0,
      'height': double.tryParse(height) ?? 0,
      'units': 'kg',
      'goalType': goalType,
      'dietPref': dietPref,
      'currentWeight': double.tryParse(currentWeight) ?? 0,
      'targetWeight': double.tryParse(tw) ?? 0,
      'targetDate': targetDate,
      'activity': activity,
      'trainingSplitId': trainingSplitId ?? _topSplitId(goalType),
    };
    widget.onComplete(profile, buildPlan());
  }

  InputDecoration _dec(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: T.faint),
        filled: true,
        fillColor: T.surface2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: T.accent)),
        contentPadding: const EdgeInsets.all(14),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (step > 0 || widget.onCancel != null) ...[
                    IconBubble(
                      icon: Icon(Icons.chevron_left, size: 20, color: T.muted),
                      size: 36,
                      background: T.surface,
                      border: Border.all(color: T.line),
                      onTap: back,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(T.pill),
                      child: LinearProgressIndicator(
                        value: (step + 1) / steps.length,
                        minHeight: 6,
                        backgroundColor: T.surface2,
                        valueColor: const AlwaysStoppedAnimation(T.hero),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Expanded(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previousChildren, if (currentChild != null) currentChild],
                    ),
                    child: KeyedSubtree(key: ValueKey(cur), child: _buildStep()),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                opacity: canNext() ? 1 : 0.45,
                onTap: next,
                child: Text(cur == 'summary' ? 'Create my plan' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(t, style: Type.h1));
  Widget _subtitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Text(t, style: Type.caption));

  Widget _buildStep() {
    switch (cur) {
      case 'name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBubble(icon: Icon(Icons.auto_awesome, size: 20, color: Colors.white), size: 42, background: T.hero),
            const SizedBox(height: 14),
            Text("Let's build your plan", style: Type.display.copyWith(fontSize: 27)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Text("I'll act as your trainer and nutritionist. First — what should I call you?", style: Type.body.copyWith(color: T.muted)),
            ),
            TextField(
              style: TextStyle(color: T.text, fontSize: 17),
              decoration: _dec('Your name'),
              onChanged: (v) => setState(() => name = v),
              controller: TextEditingController.fromValue(TextEditingValue(text: name, selection: TextSelection.collapsed(offset: name.length))),
            ),
          ],
        );
      case 'sex':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Biological sex'),
            _subtitle('Used only to estimate your calorie needs accurately.'),
            OptBtn(active: sex == 'male', onTap: () => setState(() => sex = 'male'), label: 'Male'),
            OptBtn(active: sex == 'female', onTap: () => setState(() => sex = 'female'), label: 'Female'),
          ],
        );
      case 'stats':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Your stats'),
            const SizedBox(height: 16),
            const Eyebrow('Age'),
            Padding(padding: const EdgeInsets.only(bottom: 14), child: NumIn(value: age, onChange: (v) => setState(() => age = v), ph: '28', suffix: 'yrs')),
            const Eyebrow('Height'),
            Padding(padding: const EdgeInsets.only(bottom: 14), child: NumIn(value: height, onChange: (v) => setState(() => height = v), ph: '175', suffix: 'cm')),
            const Eyebrow('Current weight'),
            NumIn(value: currentWeight, onChange: (v) => setState(() => currentWeight = v), ph: '78', suffix: 'kg'),
          ],
        );
      case 'goal':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Your goal'),
            const SizedBox(height: 16),
            OptBtn(active: goalType == 'fatLoss', onTap: () => setState(() => goalType = 'fatLoss'), icon: const Icon(Icons.local_fire_department, size: 22), label: goalLabel('fatLoss'), sub: 'Cut while keeping muscle'),
            OptBtn(active: goalType == 'weightGain', onTap: () => setState(() => goalType = 'weightGain'), icon: const Icon(Icons.trending_up, size: 22), label: goalLabel('weightGain'), sub: 'Lean weight gain'),
            OptBtn(active: goalType == 'maintain', onTap: () => setState(() => goalType = 'maintain'), icon: const Icon(Icons.adjust, size: 22), label: goalLabel('maintain'), sub: 'Recomp & hold'),
          ],
        );
      case 'training':
        final ranked = rankedSplits(goalType);
        final selected = trainingSplitId ?? ranked.first.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Training plan'),
            _subtitle("Based on your goal, here's what tends to work best — pick one, or change it anytime in Settings."),
            ...ranked.map((s) => OptBtn(
                  active: selected == s.id,
                  onTap: () => setState(() => trainingSplitId = s.id),
                  icon: Icon(s.icon, size: 20),
                  label: s.name,
                  sub: '${splitEffectiveness(s)[goalType] ?? 0}% match · ${s.shortTag}',
                )),
          ],
        );
      case 'target':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(goalType == 'maintain' ? 'Timeline' : 'Target'),
            _subtitle("By when do you want to see the result? I'll check if it's realistic."),
            if (goalType != 'maintain') ...[
              const Eyebrow('Target weight'),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: NumIn(value: targetWeight, onChange: (v) => setState(() => targetWeight = v), ph: goalType == 'fatLoss' ? '72' : '84', suffix: 'kg'),
              ),
            ],
            const Eyebrow('Target date'),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(targetDate) ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (picked != null) setState(() => targetDate = picked.toIso8601String().substring(0, 10));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
                child: Text(targetDate, style: mono(fontSize: 16, color: T.text)),
              ),
            ),
          ],
        );
      case 'activity':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Daily activity'),
            const SizedBox(height: 16),
            OptBtn(active: activity == 'sedentary', onTap: () => setState(() => activity = 'sedentary'), label: 'Sedentary', sub: 'Desk job, little to no exercise'),
            OptBtn(active: activity == 'light', onTap: () => setState(() => activity = 'light'), label: 'Light', sub: 'Light exercise 1-3 days/week'),
            OptBtn(active: activity == 'moderate', onTap: () => setState(() => activity = 'moderate'), label: 'Moderate', sub: 'On your feet / regular walks'),
            OptBtn(active: activity == 'active', onTap: () => setState(() => activity = 'active'), label: 'Active', sub: 'Physical job / lots of steps'),
            OptBtn(active: activity == 'veryActive', onTap: () => setState(() => activity = 'veryActive'), label: 'Very active', sub: 'Hard exercise daily or physical job + training'),
          ],
        );
      case 'diet':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Diet preference'),
            const SizedBox(height: 16),
            OptBtn(active: dietPref == 'veg', onTap: () => setState(() => dietPref = 'veg'), icon: const Icon(Icons.eco, size: 22), label: 'Vegetarian'),
            OptBtn(active: dietPref == 'egg', onTap: () => setState(() => dietPref = 'egg'), icon: const Icon(Icons.egg, size: 22), label: 'Eggetarian', sub: 'Veg + eggs'),
            OptBtn(active: dietPref == 'nonveg', onTap: () => setState(() => dietPref = 'nonveg'), icon: const Icon(Icons.set_meal, size: 22), label: 'Non-vegetarian'),
          ],
        );
      case 'summary':
        final plan = buildPlan();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your plan, $name', style: Type.h1),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(plan.headline, style: Type.caption)),
            if (!plan.feasible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  borderColor: T.accent,
                  padding: const EdgeInsets.all(16),
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 13, color: T.text, height: 1.5),
                      children: [
                        const TextSpan(text: 'That timeline is aggressive for muscle-safe progress. A healthier target date is '),
                        TextSpan(text: plan.suggestedDate != null ? fmtDay(plan.suggestedDate!) : 'later', style: mono(color: T.accent, fontSize: 13)),
                        const TextSpan(text: ". You can still proceed — I'll cap the pace safely."),
                      ],
                    ),
                  ),
                ),
              ),
            Row(children: [
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Eyebrow('Calories'),
                    Text('${plan.calorieGoal}', style: mono(fontSize: 24, fontWeight: FontWeight.w600)),
                    Text('kcal/day · TDEE ${plan.tdee}', style: TextStyle(fontSize: 11, color: T.muted)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Eyebrow('Protein'),
                    Text('${plan.proteinGoal}g', style: mono(fontSize: 24, fontWeight: FontWeight.w600)),
                    Text('per day', style: TextStyle(fontSize: 11, color: T.muted)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Training'),
                Text('${splitById(trainingSplitId ?? _topSplitId(goalType)).name} · ${splitById(trainingSplitId ?? _topSplitId(goalType)).shortTag}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.text)),
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(plan.splitNote, style: TextStyle(fontSize: 13, height: 1.5, color: T.muted))),
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(plan.cardioNote, style: TextStyle(fontSize: 13, color: T.muted))),
              ]),
            ),
            const SizedBox(height: 12),
            Center(child: Text('You can fine-tune anything later in Settings.', style: TextStyle(fontSize: 12, color: T.faint))),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
