import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/lib/helpers.dart';
import '../../../app/app_state.dart';
import '../../nutrition/domain/ai_food_item.dart' show AiConfigException, AiParseException;
import '../data/muscle_insight_service.dart';
import '../data/muscle_store.dart';
import '../domain/muscle_models.dart';
import '../domain/muscle_stats.dart';
import 'widgets/muscle_bits.dart';

/// "Know why": a conversation with the person's own muscle data in context.
/// Opened from the Muscle screen, a lift, or the Dashboard card; every
/// conversation saves itself and can be reopened from History.
class KnowWhyScreen extends ConsumerStatefulWidget {
  /// Set when opened from one lift, so the chat starts on it.
  final String? focusLift;
  const KnowWhyScreen({super.key, this.focusLift});

  static Future<void> open(BuildContext context, {String? focusLift}) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => KnowWhyScreen(focusLift: focusLift)));

  @override
  ConsumerState<KnowWhyScreen> createState() => _KnowWhyScreenState();
}

class _Msg {
  final bool user;
  final String text;
  final bool error;
  const _Msg(this.user, this.text, {this.error = false});
}

class _KnowWhyScreenState extends ConsumerState<KnowWhyScreen> {
  final _service = MuscleInsightService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  int? _chatId;
  bool _sending = false;
  bool _history = false;
  late String? _focus = widget.focusLift;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  AppController get _controller => ref.read(appControllerProvider.notifier);

  MuscleProfile _profile(AppData data) => muscleProfileOf(data) ?? defaultMuscleProfile(data, todayStr(data.settings));

  List<String> _starters() {
    if (_focus != null) return ['Why did this lift move the way it did?', 'What should I do next session?', 'Is this normal for my level?'];
    return const ['Am I gaining at the right speed?', 'Is this muscle or fat?', 'Should I eat more?'];
  }

  String _greeting() => _focus != null
      ? 'You are looking at $_focus. I can see its recent sessions, your other lifts and your weight, so ask me anything about it.'
      : 'Hi. I can see your weigh-ins, lifts, food and tape measurements, so ask me anything about your progress and I will use your own numbers. Where do you want to start?';

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;
    final data = ref.read(appControllerProvider).data;
    final today = todayStr(data.settings);
    final digest = buildMuscleDigest(data, _profile(data), today, focusLift: _focus);
    final history = [
      for (final m in _msgs.where((m) => !m.error)) {'role': m.user ? 'user' : 'assistant', 'content': m.text}
    ];
    final trimmed = history.length > 12 ? history.sublist(history.length - 12) : history;
    setState(() {
      _msgs.add(_Msg(true, q));
      _sending = true;
      _input.clear();
    });
    _chatId ??= DateTime.now().millisecondsSinceEpoch;
    await _save();
    _scrollDown();
    try {
      final reply = await _service.chat(q, digest: digest, history: trimmed);
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(false, reply)));
      await _save();
    } on AiConfigException {
      if (mounted) setState(() => _msgs.add(const _Msg(false, "Ask AI isn't set up for this build.", error: true)));
    } on AiParseException catch (e) {
      if (mounted) setState(() => _msgs.add(_Msg(false, e.message, error: true)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollDown();
    }
  }

  Future<void> _save() async {
    final real = _msgs.where((m) => !m.error).toList();
    if (real.isEmpty || _chatId == null) return;
    final first = real.first.text;
    await upsertChat(_controller, {
      'id': _chatId,
      'title': first.length > 44 ? '${first.substring(0, 42)}…' : first,
      'tag': _focus != null ? 'Lifts' : 'Progress',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'msgs': [for (final m in real) {'r': m.user ? 'u' : 'a', 't': m.text}],
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  void _newChat() => setState(() {
        _msgs.clear();
        _chatId = null;
        _focus = null;
        _history = false;
      });

  void _openChat(Map<String, dynamic> c) => setState(() {
        _msgs
          ..clear()
          ..addAll([for (final m in List<dynamic>.from(c['msgs'] ?? const [])) _Msg(m['r'] == 'u', m['t'] as String)]);
        _chatId = c['id'] as int?;
        _focus = null;
        _history = false;
      });

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(children: [
          _topBar(app),
          Expanded(child: _history ? _historyList(app) : _chat(app)),
          if (!_history) _inputBar(),
        ]),
      ),
    );
  }

  Widget _topBar(AppState app) {
    final n = muscleProfileOf(app.data)?.chats.length ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.line))),
      child: Column(children: [
        Row(children: [
          IconBubble(
            icon: Icon(_history ? Icons.arrow_back : Icons.close, size: 18, color: T.muted),
            size: 36,
            background: T.surface,
            border: Border.all(color: T.line),
            onTap: () => _history ? setState(() => _history = false) : Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Icon(Icons.auto_awesome, size: 16, color: T.accent),
          const SizedBox(width: 6),
          Expanded(child: Text(_history ? 'Saved chats' : 'Know why', style: Type.h2)),
          if (!_history)
            PressableScale(
              onTap: () => setState(() => _history = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
                child: Text(n > 0 ? 'History · $n' : 'History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.text)),
              ),
            ),
        ]),
        if (!_history) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 24,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final c in _contextChips(app.data)) c],
            ),
          ),
        ],
      ]),
    );
  }

  List<Widget> _contextChips(AppData data) {
    final today = todayStr(data.settings);
    final p = _profile(data);
    final foodDays = data.diet.entries.where((e) {
      final age = daysBetween(e.key, today);
      return age >= 0 && age < 14 && (e.value as List).isNotEmpty;
    }).length;
    final tracked = summarizeLifts(data.history, p.tracked).length;
    final items = [
      ('Weight', '${data.weight.length} weigh-ins'),
      ('Lifts', '$tracked tracked'),
      ('Food', '$foodDays days'),
      ('Tape', p.tape.isEmpty ? 'none yet' : (p.tape.length == 1 ? 'baseline' : '${p.tape.length} entries')),
      ('Level', p.levelInfo.label),
    ];
    return [
      for (final i in items)
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(T.pill)),
          child: Row(children: [
            Icon(Icons.check, size: 11, color: T.success),
            const SizedBox(width: 4),
            Text('${i.$1} · ${i.$2}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: T.muted)),
          ]),
        ),
    ];
  }

  Widget _chat(AppState app) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      children: [
        if (_msgs.isEmpty) ...[
          _bubble(_Msg(false, _greeting())),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in _starters())
              PressableScale(
                onTap: () => _send(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill), color: T.surface),
                  child: Text(s, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.text)),
                ),
              ),
          ]),
        ],
        for (final m in _msgs) _bubble(m),
        if (_sending) const Padding(padding: EdgeInsets.only(top: 10), child: Align(alignment: Alignment.centerLeft, child: _TypingDots())),
      ],
    );
  }

  Widget _bubble(_Msg m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: m.user ? T.accentDim : (m.error ? T.danger.withValues(alpha: 0.12) : T.surface),
            border: Border.all(color: m.user ? T.accentSoft : T.line),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(m.user ? 18 : 5),
              bottomRight: Radius.circular(m.user ? 5 : 18),
            ),
          ),
          child: Text(m.text, style: TextStyle(fontSize: 14, height: 1.5, color: m.error ? T.danger : T.text)),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: T.line))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _input,
            style: Type.body,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: _send,
            decoration: InputDecoration(
              hintText: 'Ask about your progress',
              hintStyle: TextStyle(color: T.faint, fontSize: 14),
              filled: true,
              fillColor: T.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(T.pill), borderSide: BorderSide(color: T.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.pill), borderSide: BorderSide(color: T.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.pill), borderSide: const BorderSide(color: T.accent)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Send',
          child: GestureDetector(
            onTap: () => _send(_input.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
              child: const Icon(Icons.arrow_upward, size: 20, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _historyList(AppState app) {
    final chats = [...(muscleProfileOf(app.data)?.chats ?? const <Map<String, dynamic>>[])]..sort((a, b) => ((b['ts'] as num?) ?? 0).compareTo((a['ts'] as num?) ?? 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        PrimaryButton(onTap: _newChat, child: const Text('New chat')),
        const SizedBox(height: 16),
        if (chats.isEmpty) Text('No saved chats yet. Ask something and it will show up here.', style: Type.caption),
        for (final c in chats) _historyTile(c),
      ],
    );
  }

  String _when(num? ts) {
    if (ts == null) return '';
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts.toInt()));
    if (d.inMinutes < 2) return 'Just now';
    if (d.inHours < 24 && DateTime.now().day == DateTime.fromMillisecondsSinceEpoch(ts.toInt()).day) return 'Today';
    if (d.inDays < 2) return 'Yesterday';
    return '${d.inDays} days ago';
  }

  Widget _historyTile(Map<String, dynamic> c) {
    final msgs = List<dynamic>.from(c['msgs'] ?? const []);
    final last = msgs.lastWhere((m) => m['r'] == 'a', orElse: () => null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => _openChat(c),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(c['title'] as String? ?? 'Chat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.text))),
            Semantics(
              button: true,
              label: 'Delete chat',
              child: GestureDetector(
                onTap: () => deleteChat(_controller, c['id']!),
                behavior: HitTestBehavior.opaque,
                child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 16, color: T.faint)),
              ),
            ),
          ]),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(last['t'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: T.muted, height: 1.4)),
            ),
          Row(children: [
            MuscleChip(c['tag'] as String? ?? 'Progress', T.lavAccent),
            const SizedBox(width: 8),
            Text(_when(c['ts'] as num?), style: TextStyle(fontSize: 11.5, color: T.faint)),
          ]),
        ]),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(18)),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: T.muted.withValues(alpha: ((_c.value * 3 - i) % 3 < 1) ? 1.0 : 0.3)),
            ),
        ]),
      ),
    );
  }
}
