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
  // follow-up like "add 10g protein to that" resolves against the items
  // just shown instead of arriving with no context. Only successful,
  // food-containing exchanges are kept — errors and off-topic replies add
  // nothing worth chaining. Capped to the last few exchanges since only
  // recent context matters here and it keeps the request small.
  final List<Map<String, String>> _history = [];
  static const _maxHistoryMessages = 12;

  Future<bool> ping() => _service.ping();

  Future<AiFoodParseResult> send(String description, {required Map<String, dynamic> knownFacts}) async {
    final result = await _service.parseMeal(description, history: _history, knownFacts: knownFacts);
    _pushHistory(description, result.rawContent);
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
