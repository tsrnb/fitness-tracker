import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// One food item as estimated by the model — mirrors `ParsedMealItem` from
/// `parse_meal_lines.dart` plus an `emoji`, since that's used for the
/// decorated list in the Ask AI chat but has no place in the plain
/// text-parser flow.
class AiFoodItem {
  final String name;
  final String emoji;
  final int kcal;
  final int protein;
  final int carb;
  final int fat;
  final int fiber;
  const AiFoodItem({
    required this.name,
    required this.emoji,
    required this.kcal,
    required this.protein,
    this.carb = 0,
    this.fat = 0,
    this.fiber = 0,
  });
}

class AiFoodParseResult {
  final String? reply;
  final List<AiFoodItem> items;
  const AiFoodParseResult({required this.items, this.reply});
}

/// Thrown when `OPENAI_API_KEY` wasn't provided at build time.
class AiConfigException implements Exception {}

/// Thrown for anything else that goes wrong — network, bad response shape,
/// or the model legitimately couldn't find any food in the message. The
/// message is written to be shown to the user directly.
class AiParseException implements Exception {
  final String message;
  AiParseException(this.message);
}

/// Talks directly to the OpenAI Chat Completions API from the client —
/// deliberate for this app (a 2-person personal project with no backend),
/// not a pattern to copy for anything shared more broadly: the key is
/// baked into the compiled web bundle via --dart-define-from-file, visible
/// to anyone who has the deployed URL and opens dev tools.
class OpenAiFoodService {
  static const _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  static bool get isConfigured => _apiKey.isNotEmpty;

  static const _systemPrompt = '''
You are a nutrition estimator embedded in a personal fitness-tracking app. The user will describe what they ate in casual language — often Indian home-cooked meals (rotis, dal, sabzi, curd, rice, and similar) but not exclusively. Break their message into distinct food items and estimate calories and macros for each, using realistic home-cooking portions when no quantity is given (assume one normal serving).

Respond with ONLY valid JSON, no markdown fences, no commentary outside the JSON, in exactly this shape:
{
  "reply": "one short, friendly sentence introducing the breakdown, referencing what they described",
  "items": [
    {"name": "string", "emoji": "single emoji that best represents this food", "kcal": number, "protein": number, "carb": number, "fat": number, "fiber": number}
  ]
}

All macro numbers are grams except kcal, all rounded to whole numbers. If the message doesn't describe any food (e.g. a greeting or unrelated question), return an empty items array and a reply that gently asks them to describe a meal instead.
''';

  Future<AiFoodParseResult> parseMeal(String description) async {
    if (!isConfigured) throw AiConfigException();

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'temperature': 0.3,
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': description},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw AiParseException("That took too long to come back — try again.");
    } catch (_) {
      throw AiParseException("Couldn't reach the AI — check your connection and try again.");
    }

    if (res.statusCode != 200) {
      throw AiParseException(_describeError(res));
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiParseException("That didn't come back right — try again.");
    }

    final choices = body['choices'] as List?;
    String? content;
    if (choices != null && choices.isNotEmpty) {
      final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
      content = message?['content'] as String?;
    }
    if (content == null) throw AiParseException("That didn't come back right — try again.");

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw AiParseException("Couldn't make sense of that reply — try rephrasing what you ate.");
    }

    final rawItems = parsed['items'] as List?;
    if (rawItems == null || rawItems.isEmpty) {
      throw AiParseException((parsed['reply'] as String?) ?? "I couldn't find any food in that — try describing a meal.");
    }

    final items = rawItems.map((raw) {
      final m = raw as Map<String, dynamic>;
      return AiFoodItem(
        name: (m['name'] as String?)?.trim().isNotEmpty == true ? (m['name'] as String).trim() : 'Item',
        emoji: (m['emoji'] as String?) ?? '🍽️',
        kcal: ((m['kcal'] as num?) ?? 0).round(),
        protein: ((m['protein'] as num?) ?? 0).round(),
        carb: ((m['carb'] as num?) ?? 0).round(),
        fat: ((m['fat'] as num?) ?? 0).round(),
        fiber: ((m['fiber'] as num?) ?? 0).round(),
      );
    }).toList();

    return AiFoodParseResult(items: items, reply: parsed['reply'] as String?);
  }

  /// Turns an OpenAI error response into a message that tells the user what
  /// to actually do about it, rather than just surfacing a status code —
  /// `insufficient_quota` and `rate_limit_exceeded` both come back as HTTP
  /// 429, but they mean very different things (no billing set up, vs. sending
  /// requests too fast), so the status code alone isn't enough.
  String _describeError(http.Response res) {
    Map<String, dynamic>? error;
    try {
      error = (jsonDecode(res.body) as Map<String, dynamic>)['error'] as Map<String, dynamic>?;
    } catch (_) {
      // Not JSON (e.g. an upstream proxy/CDN error page) — fall through to the status-code messages below.
    }
    final code = error?['code'] as String?;
    final apiMessage = error?['message'] as String?;

    if (res.statusCode == 401 || code == 'invalid_api_key') {
      return "That API key looks invalid — check secrets.json.";
    }
    if (code == 'insufficient_quota') {
      return "This OpenAI account has no billing set up (or hit its usage cap) — add a payment method at platform.openai.com/settings/organization/billing, then try again.";
    }
    if (res.statusCode == 429 || code == 'rate_limit_exceeded') {
      return "Too many requests at once — wait a few seconds and try again.";
    }
    if (res.statusCode >= 500) {
      return "OpenAI's having a moment — try again shortly.";
    }
    return apiMessage ?? 'That request failed (${res.statusCode}). Try again in a moment.';
  }
}
