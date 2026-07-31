import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/lib/helpers.dart';
import '../../app/app_state.dart';
import 'ai_gradient.dart';
import 'openai_food_service.dart';
import 'parse_meal_lines.dart';
import 'meal_log.dart';

/// Full-screen conversational food logging — "the flagship path," per the
/// confirmed design: describe a meal in plain words, the model breaks it
/// into items with macros, and one tap adds it to today's log through the
/// same `addMealEntries` every other logging path already uses. Styled with
/// a consistent gradient/sparkle language distinct from the app's single
/// accent-orange, so anything from the assistant reads as "the assistant
/// said this," never confused with a normal control.
class AskAiChatScreen extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const AskAiChatScreen({super.key, required this.app, required this.controller});

  @override
  State<AskAiChatScreen> createState() => _AskAiChatScreenState();
}

sealed class _Entry {}

class _UserText extends _Entry {
  final String text;
  _UserText(this.text);
}

class _AssistantText extends _Entry {
  final String text;
  _AssistantText(this.text);
}

class _AssistantTyping extends _Entry {}

class _AssistantResult extends _Entry {
  final AiFoodParseResult result;
  bool added = false;
  _AssistantResult(this.result);
}

class _AssistantError extends _Entry {
  final String message;
  _AssistantError(this.message);
}

class _AskAiChatScreenState extends State<AskAiChatScreen> {
  final _service = OpenAiFoodService();
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final List<_Entry> _entries = [];
  bool _showChips = true;
  bool _busy = false;

  // Prior user/assistant turns replayed to the model on each call so a
  // follow-up like "add 10g protein to that" resolves against the items
  // just shown instead of arriving with no context. Only successful,
  // food-containing exchanges are kept — errors and off-topic replies add
  // nothing worth chaining. Capped to the last few exchanges since only
  // recent context matters here and it keeps the request small.
  final List<Map<String, String>> _history = [];
  static const _maxHistoryMessages = 12;

  // Seeded from persisted per-user data and kept locally in sync so a fact
  // remembered mid-session is usable by the next message in *this* session
  // too — `widget.app` is a one-time snapshot from when this screen was
  // pushed, it won't pick up controller.update() on its own.
  late Map<String, dynamic> _knownFacts;

  Future<void> _rememberFacts(List<AiFoodItem> facts) async {
    final next = Map<String, dynamic>.from(_knownFacts);
    for (final f in facts) {
      next[f.name.toLowerCase()] = {
        'kcal': f.kcal,
        'protein': f.protein,
        'carb': f.carb,
        'fat': f.fat,
        'fiber': f.fiber,
      };
    }
    _knownFacts = next;
    await widget.controller.update('aiFoodMemory', (_) => next);
  }

  void _pushHistory(String userText, String assistantRawContent) {
    _history.add({'role': 'user', 'content': userText});
    _history.add({'role': 'assistant', 'content': assistantRawContent});
    if (_history.length > _maxHistoryMessages) {
      _history.removeRange(0, _history.length - _maxHistoryMessages);
    }
  }

  // Running total of what's been added to the log *this session*, so each
  // new suggestion's "fits your day" numbers account for earlier ones
  // without needing to re-read from the (static) app snapshot.
  num _sessionKcal = 0;
  num _sessionProtein = 0;

  late final num _consumedKcal;
  late final num _consumedProtein;
  late final num _kcalGoal;
  late final num _proteinGoal;

  @override
  void initState() {
    super.initState();
    _knownFacts = Map<String, dynamic>.from(widget.app.data.aiFoodMemory);
    final st = widget.app.data.settings;
    final today = todayStr(st);
    final meals = List<Map<String, dynamic>>.from(widget.app.data.diet[today] ?? []);
    _consumedKcal = meals.fold<num>(0, (a, b) => a + ((b['kcal'] as num?) ?? 0));
    _consumedProtein = meals.fold<num>(0, (a, b) => a + ((b['protein'] as num?) ?? 0));
    final burned = ((widget.app.data.activity[today] as Map?)?['kcal'] as num?) ?? 0;
    _kcalGoal = ((st['calorieGoal'] as num?) ?? 2000) + burned;
    _proteinGoal = (st['proteinGoal'] as num?) ?? 150;
    _checkAvailability();
  }

  // Pinged here rather than gating the Log Food sheet's entry card — a
  // ping stale by even a few seconds would show a card that's actually
  // dead, so it's more honest to always offer the card and only find out
  // once the user has committed to it, explain why, and hand them back.
  Future<void> _checkAvailability() async {
    final ok = await _service.ping();
    if (!mounted || ok) return;
    setState(() {
      _entries.add(_AssistantError("Ask AI isn't reachable right now — taking you back so you can log it yourself."));
      _showChips = false;
    });
    _scrollToEnd();
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? preset]) async {
    final msg = (preset ?? _inputCtrl.text).trim();
    if (msg.isEmpty || _busy) return;
    setState(() {
      _entries.add(_UserText(msg));
      _entries.add(_AssistantTyping());
      _inputCtrl.clear();
      _showChips = false;
      _busy = true;
    });
    _scrollToEnd();

    try {
      final result = await _service.parseMeal(msg, history: _history, knownFacts: _knownFacts);
      if (!mounted) return;
      _pushHistory(msg, result.rawContent);
      if (result.remember.isNotEmpty) await _rememberFacts(result.remember);
      setState(() {
        _entries.removeWhere((e) => e is _AssistantTyping);
        if (result.reply != null && result.reply!.isNotEmpty) _entries.add(_AssistantText(result.reply!));
        _entries.add(_AssistantResult(result));
      });
    } on AiConfigException {
      if (!mounted) return;
      setState(() {
        _entries.removeWhere((e) => e is _AssistantTyping);
        _entries.add(_AssistantError("Ask AI isn't set up yet — add an OpenAI key to secrets.json and rebuild."));
      });
    } on AiParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _entries.removeWhere((e) => e is _AssistantTyping);
        _entries.add(_AssistantError(e.message));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries.removeWhere((e) => e is _AssistantTyping);
        _entries.add(_AssistantError("Something went wrong — try again."));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _scrollToEnd();
  }

  void _addToLog(_AssistantResult entry) {
    final items = entry.result.items.map((i) => ParsedMealItem(i.name, i.kcal, i.protein, i.carb, i.fat, i.fiber)).toList();
    addMealEntries(widget.controller, items);
    final kcal = items.fold<num>(0, (a, b) => a + b.kcal);
    final protein = items.fold<num>(0, (a, b) => a + b.protein);
    setState(() {
      entry.added = true;
      _sessionKcal += kcal;
      _sessionProtein += protein;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.app.user?.name ?? '';
    final firstName = name.contains(' ') ? name.split(' ').first : name;
    final kcalLeft = (_kcalGoal - _consumedKcal - _sessionKcal).round();
    final proteinLeft = (_proteinGoal - _consumedProtein - _sessionProtein).round();
    final kcalPct = _kcalGoal > 0 ? (((_consumedKcal + _sessionKcal) / _kcalGoal) * 100).clamp(0, 100) : 0.0;
    final proteinPct = _proteinGoal > 0 ? (((_consumedProtein + _sessionProtein) / _proteinGoal) * 100).clamp(0, 100) : 0.0;

    return Scaffold(
      backgroundColor: T.bg,
      body: Stack(children: [
        Positioned.fill(
          child: AiGradientWash(base: T.bg, alpha: 0.14, child: const SizedBox.expand()),
        ),
        Positioned(
          top: -60,
          left: -70,
          child: _blurOrb(220, aiColor1.withValues(alpha: 0.22)),
        ),
        Positioned(
          top: 40,
          right: -90,
          child: _blurOrb(240, aiColor3.withValues(alpha: 0.16)),
        ),
        Column(children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_left, size: 18, color: T.muted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _AssistantOrb(size: 30, pulse: true),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ask AI', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Describe a meal to log it', style: TextStyle(fontSize: 10.5, color: T.muted)),
                  ]),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _statChip('$kcalLeft', 'kcal left · ${kcalPct.round()}%', T.hero, kcalPct / 100)),
                  const SizedBox(width: 8),
                  Expanded(child: _statChip('${proteinLeft}g', 'protein left · ${proteinPct.round()}%', aiColor2, proteinPct / 100)),
                ]),
              ]),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                children: [
                  _assistantBubble("Hey $firstName 👋 What did you eat? Type it however feels natural — I'll fill in the rest."),
                  if (_showChips)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, top: 8),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        _quickChip('🍳 Breakfast', () => _send('For breakfast I had ')),
                        _quickChip('🍛 Lunch', () => _send('For lunch I had ')),
                        _quickChip('🍿 Snack', () => _send('As a snack I had ')),
                      ]),
                    ),
                  ..._entries.map(_buildEntry),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(fontSize: 13, color: T.text),
                      decoration: InputDecoration(border: InputBorder.none, hintText: 'Describe what you ate…', hintStyle: TextStyle(color: T.faint, fontSize: 13)),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _busy ? null : () => _send(),
                  child: AiGradient(
                    builder: (context, gradient) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildEntry(_Entry e) {
    return switch (e) {
      _UserText() => Padding(padding: const EdgeInsets.only(bottom: 12), child: _userBubble(e.text)),
      _AssistantText() => Padding(padding: const EdgeInsets.only(bottom: 12), child: _assistantBubble(e.text)),
      _AssistantTyping() => const Padding(padding: EdgeInsets.only(bottom: 12), child: _TypingBubble()),
      _AssistantResult() => Padding(padding: const EdgeInsets.only(bottom: 12), child: _resultCard(e)),
      _AssistantError() => Padding(padding: const EdgeInsets.only(bottom: 12), child: _errorBubble(e.message)),
    };
  }

  Widget _assistantBubble(String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AssistantOrb(size: 24),
      const SizedBox(width: 8),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
          )),
          child: Text(text, style: TextStyle(fontSize: 12.5, color: T.text, height: 1.5)),
        ),
      ),
    ]);
  }

  Widget _errorBubble(String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AssistantOrb(size: 24),
      const SizedBox(width: 8),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: T.danger.withValues(alpha: 0.1), border: Border.all(color: T.danger.withValues(alpha: 0.3)), borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
          )),
          child: Text(text, style: TextStyle(fontSize: 12.5, color: T.text, height: 1.5)),
        ),
      ),
    ]);
  }

  Widget _userBubble(String text) {
    final initial = (widget.app.user?.name.isNotEmpty == true) ? widget.app.user!.name[0].toUpperCase() : '?';
    return Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [T.hero, Color(0xFFFF7A52)]), borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4),
          )),
          child: Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.5)),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(initial, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: T.text)),
      ),
    ]);
  }

  Widget _resultCard(_AssistantResult entry) {
    final items = entry.result.items;
    final totalKcal = items.fold<int>(0, (a, b) => a + b.kcal);
    final totalProtein = items.fold<int>(0, (a, b) => a + b.protein);
    final projectedKcal = _consumedKcal + _sessionKcal + totalKcal;
    final projectedProtein = _consumedProtein + _sessionProtein + totalProtein;
    final kcalRingPct = _kcalGoal > 0 ? (projectedKcal / _kcalGoal * 100).clamp(0, 100) : 0.0;
    final proteinRingPct = _proteinGoal > 0 ? (projectedProtein / _proteinGoal * 100).clamp(0, 100) : 0.0;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AssistantOrb(size: 24),
      const SizedBox(width: 8),
      Expanded(
        child: _GradientBorder(
          radius: 17,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: const Color(0xFF17161D), borderRadius: BorderRadius.circular(15.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      SizedBox(width: 20, child: Text(it.emoji, style: const TextStyle(fontSize: 15))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(it.name, style: TextStyle(fontSize: 12, color: T.text))),
                      Text('${it.kcal} · ${it.protein}g P', style: mono(fontSize: 10.5, color: T.muted)),
                    ]),
                  )),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.only(top: 9),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF26252E)))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.text)),
                  Text('$totalKcal kcal · ${totalProtein}g P', style: mono(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text)),
                ]),
              ),
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: aiColor1.withValues(alpha: 0.08), border: Border.all(color: aiColor1.withValues(alpha: 0.22)), borderRadius: BorderRadius.circular(11)),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      'That puts you at ${projectedKcal.round()} / ${_kcalGoal.round()} kcal and ${projectedProtein.round()} / ${_proteinGoal.round()}g protein today.',
                      style: TextStyle(fontSize: 10.5, color: T.text, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _miniRing(kcalRingPct / 100, T.hero),
                  const SizedBox(width: 4),
                  _miniRing(proteinRingPct / 100, aiColor2),
                ]),
              ),
              const SizedBox(height: 11),
              if (entry.added)
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, size: 15, color: T.success),
                    const SizedBox(width: 6),
                    Text('Added to today\'s log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.success)),
                  ]),
                )
              else
                GestureDetector(
                  onTap: () => _addToLog(entry),
                  child: AiGradient(
                    builder: (context, gradient) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(999)),
                      alignment: Alignment.center,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('✨ ', style: TextStyle(fontSize: 12.5)),
                        Text('Add to today\'s log', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _miniRing(double pct, Color color) {
    return SizedBox(width: 22, height: 22, child: CustomPaint(painter: _RingPainter(pct.clamp(0.0, 1.0), color)));
  }

  Widget _statChip(String value, String label, Color barColor, double pct) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: mono(fontSize: 13, fontWeight: FontWeight.w700, color: T.text)),
        Padding(padding: const EdgeInsets.only(top: 1), child: Text(label, style: TextStyle(fontSize: 9, color: T.muted))),
        Container(
          margin: const EdgeInsets.only(top: 6),
          height: 3,
          decoration: BoxDecoration(color: const Color(0xFF26252E), borderRadius: BorderRadius.circular(2)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct.clamp(0.0, 1.0),
            child: Container(decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(2))),
          ),
        ),
      ]),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.text)),
      ),
    );
  }

  Widget _blurOrb(double size, Color color) {
    return IgnorePointer(
      child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]))),
    );
  }
}

class _AssistantOrb extends StatefulWidget {
  final double size;
  final bool pulse;
  const _AssistantOrb({required this.size, this.pulse = false});

  @override
  State<_AssistantOrb> createState() => _AssistantOrbState();
}

class _AssistantOrbState extends State<_AssistantOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: widget.pulse);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(scale: widget.pulse ? 1 + _c.value * 0.08 : 1, child: child),
      child: AiGradient(
        builder: (context, gradient) => Container(
          width: widget.size,
          height: widget.size,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
          alignment: Alignment.center,
          child: Icon(Icons.auto_awesome, size: widget.size * 0.46, color: Colors.white),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AssistantOrb(size: 24),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
        )),
        child: const _TypingDots(),
      ),
    ]);
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
          final t = ((_c.value - i * 0.15) % 1.0 + 1.0) % 1.0;
          final bump = t < 0.3 ? math.sin(t / 0.3 * math.pi) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.translate(
              offset: Offset(0, -bump * 3),
              child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: T.muted.withValues(alpha: 0.4 + bump * 0.6))),
            ),
          );
        }));
      },
    );
  }
}

class _GradientBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  const _GradientBorder({required this.child, required this.radius});

  @override
  Widget build(BuildContext context) {
    return AiGradient(
      builder: (context, gradient) => Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), gradient: gradient),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  _RingPainter(this.pct, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 1.75;
    final track = Paint()
      ..color = const Color(0xFF26252E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, r, track);
    if (pct <= 0) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * pct, false, stroke);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct || old.color != color;
}
