import '../domain/ai_food_item.dart';
import 'openai_food_service.dart';

/// Owns the network call and the conversation history replayed to the
/// model — pulled out of the chat screen's State so that bookkeeping isn't
/// tangled with UI-only state (typing indicator, transcript entries,
/// session running totals), which stays in the widget.
class AskAiController {
  final OpenAiFoodService _service;
  AskAiController([OpenAiFoodService? service]) : _service = service ?? OpenAiFoodService();

  // Prior user/assistant turns replayed to the model on each call so a
  // follow-up — "add 10g protein to that" on a meal breakdown, or "what
  // about a vegetarian version" on advice just given — resolves against
  // what was actually just said instead of arriving with no context. Only
  // successful exchanges are kept (advice-only turns included, now that
  // those succeed instead of throwing — see OpenAiFoodService.chat); a
  // network/parse error adds nothing worth chaining. Capped to the last
  // few exchanges since only recent context matters here and it keeps the
  // request small — bumped from 12 to 16 since a real nutrition Q&A thread
  // tends to run a couple of turns longer than a meal-logging one.
  final List<Map<String, String>> _history = [];
  static const _maxHistoryMessages = 16;

  Future<bool> ping() => _service.ping();

  Future<AiFoodParseResult> send(String message, {required Map<String, dynamic> knownFacts, String? profileContext}) async {
    final result = await _service.chat(message, history: _history, knownFacts: knownFacts, profileContext: profileContext);
    _pushHistory(message, result.rawContent);
    return result;
  }

  void _pushHistory(String userText, String assistantRawContent) {
    _history.add({'role': 'user', 'content': userText});
    _history.add({'role': 'assistant', 'content': assistantRawContent});
    if (_history.length > _maxHistoryMessages) {
      _history.removeRange(0, _history.length - _maxHistoryMessages);
    }
  }
}
