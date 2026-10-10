import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../nutrition/domain/ai_food_item.dart' show AiConfigException, AiParseException;
import '../../data/calibration_insight_service.dart';

/// A follow-up conversation pinned to one calibration context (the frozen
/// end-result, or the mid-window deep-dive snapshot). Replays prior turns
/// so "why is that?" resolves against what was just said — same pattern as
/// the nutrition Ask AI chat, different payload.
///
/// Open with [show]; the `context` map is whatever `buildFullCalibration...`
/// or the digest builder produced, passed straight through to the service.
class CalibrationChatSheet extends StatefulWidget {
  final Map<String, dynamic> aiContext;
  final List<String> suggestions;
  const CalibrationChatSheet({super.key, required this.aiContext, this.suggestions = const []});

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> aiContext,
    List<String> suggestions = const [],
  }) {
    return showAppSheet(context, CalibrationChatSheet(aiContext: aiContext, suggestions: suggestions));
  }

  @override
  State<CalibrationChatSheet> createState() => _CalibrationChatSheetState();
}

class _CalibrationChatSheetState extends State<CalibrationChatSheet> {
  final _service = CalibrationInsightService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _history = <Map<String, String>>[]; // replayed to the model
  final _turns = <_Turn>[]; // rendered
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;
    setState(() {
      _turns.add(_Turn(role: _Role.user, text: msg));
      _sending = true;
      _input.clear();
    });
    _scrollDown();
    try {
      final reply = await _service.chat(msg, context: widget.aiContext, history: _history);
      if (!mounted) return;
      _history.add({'role': 'user', 'content': msg});
      _history.add({'role': 'assistant', 'content': reply});
      if (_history.length > 12) _history.removeRange(0, _history.length - 12);
      setState(() => _turns.add(_Turn(role: _Role.ai, text: reply)));
    } on AiConfigException {
      if (mounted) setState(() => _turns.add(_Turn(role: _Role.error, text: "Ask AI isn't set up for this build.")));
    } on AiParseException catch (e) {
      if (mounted) setState(() => _turns.add(_Turn(role: _Role.error, text: e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Row(children: [
              Icon(Icons.auto_awesome, size: 16, color: T.lavAccent),
              const SizedBox(width: 8),
              Text('Ask about this calibration', style: Type.h3),
            ]),
          ),
          Flexible(
            child: ListView(
              controller: _scroll,
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              children: [
                if (_turns.isEmpty)
                  Text(
                    'Everything logged in this window is loaded. Ask about the trend, a specific day, your logging, or what your plan should be.',
                    style: Type.caption,
                  ),
                for (final t in _turns) _bubble(t),
                if (_sending)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: T.muted)),
                    ]),
                  ),
              ],
            ),
          ),
          if (_turns.isEmpty && widget.suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in widget.suggestions)
                    GestureDetector(
                      onTap: () => _send(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(border: Border.all(color: T.line), borderRadius: BorderRadius.circular(999)),
                        child: Text(s, style: mono(fontSize: 10.5, color: T.muted)),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
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
                    hintText: 'Ask about any of your data…',
                    hintStyle: TextStyle(color: T.faint, fontSize: 13),
                    filled: true,
                    fillColor: T.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _send(_input.text),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
                  child: const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Turn t) {
    final isUser = t.role == _Role.user;
    final isError = t.role == _Role.error;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isUser ? T.accentDim : (isError ? T.danger.withValues(alpha: 0.12) : T.surface2),
            border: Border.all(color: isUser ? T.accentSoft : T.line),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(t.text, style: TextStyle(fontSize: 12.5, height: 1.5, color: isError ? T.danger : T.text)),
        ),
      ),
    );
  }
}

enum _Role { user, ai, error }

class _Turn {
  final _Role role;
  final String text;
  const _Turn({required this.role, required this.text});
}
