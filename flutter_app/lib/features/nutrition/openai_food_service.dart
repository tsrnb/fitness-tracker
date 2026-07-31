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
  /// Foods the user stated a standing/corrected macro value for (e.g.
  /// "yogurt is 101kcal, 11g protein") rather than just a one-off portion —
  /// the caller persists these so they're known in future chat sessions,
  /// unlike `history` which is only replayed within the current one.
  final List<AiFoodItem> remember;
  /// The model's raw JSON response text, kept so the caller can replay it
  /// back as an assistant turn in `history` on the next call — that's what
  /// lets a follow-up like "add 10g protein to that" resolve against the
  /// items just shown instead of landing with no context.
  final String rawContent;
  const AiFoodParseResult({required this.items, required this.rawContent, this.reply, this.remember = const []});
}

/// Thrown when `AI_PROXY_URL`/`AI_PROXY_CLIENT_KEY` weren't provided at build time.
class AiConfigException implements Exception {}

/// Thrown for anything else that goes wrong — network, bad response shape,
/// or the model legitimately couldn't find any food in the message. The
/// message is written to be shown to the user directly.
class AiParseException implements Exception {
  final String message;
  AiParseException(this.message);
}

/// Calls a small Cloudflare Worker (`cf-worker/`) instead of OpenAI directly.
/// A key baked into this compiled web bundle would be scraped from the
/// public gh-pages site and auto-revoked by OpenAI's own leaked-key
/// scanning — that happened twice before this proxy existed. The real
/// OPENAI_API_KEY now only ever lives in Cloudflare (`wrangler secret put`).
/// `AI_PROXY_CLIENT_KEY` below is *not* that key — it's a low-value shared
/// secret whose only job is stopping randoms who find this URL from
/// spending your OpenAI credits; it still ends up in the compiled JS same
/// as before, but there's nothing here for a scanner to find and kill.
class OpenAiFoodService {
  static const _proxyBase = String.fromEnvironment('AI_PROXY_URL');
  static const _clientKey = String.fromEnvironment('AI_PROXY_CLIENT_KEY');
  static bool get isConfigured => _proxyBase.isNotEmpty && _clientKey.isNotEmpty;

  static Map<String, String> get _headers => {
        'X-Client-Key': _clientKey,
        'Content-Type': 'application/json',
      };

  /// Reachability check for the chat screen to run on open — hits the
  /// proxy's `/health` route (which itself does a free `GET /v1/models`
  /// against OpenAI) rather than spending a real chat completion just to
  /// find out if the service is up.
  Future<bool> ping() async {
    if (!isConfigured) return false;
    try {
      final res = await http.get(Uri.parse('$_proxyBase/health'), headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  static const _systemPrompt = '''
You are a nutrition estimator embedded in a personal fitness-tracking app. The user will describe what they ate in casual language — often Indian home-cooked meals (rotis, dal, sabzi, curd, rice, and similar) but not exclusively. Break their message into distinct food items and estimate calories and macros for each, using realistic home-cooking portions when no quantity is given (assume one normal serving).

Respond with ONLY valid JSON, no markdown fences, no commentary outside the JSON, in exactly this shape:
{
  "reply": "one short, friendly sentence introducing the breakdown, referencing what they described",
  "items": [
    {"name": "string", "emoji": "single emoji that best represents this food", "kcal": number, "protein": number, "carb": number, "fat": number, "fiber": number}
  ],
  "remember": [
    {"name": "string", "emoji": "single emoji", "kcal": number, "protein": number, "carb": number, "fat": number, "fiber": number}
  ]
}

All macro numbers are grams except kcal, all rounded to whole numbers. If the message doesn't describe any food (e.g. a greeting or unrelated question), return an empty items array and a reply that gently asks them to describe a meal instead.

Earlier turns in this conversation may be included for context. If the user's new message is a correction or addition referring to what was just discussed (e.g. "add 10g protein to that", "make it 2 rotis instead", "actually no butter") rather than a new standalone meal, apply the change to the most recent item breakdown and return the full corrected set of items — not just the delta.

A "Known food facts" line may be included above the conversation listing standing values the user has already taught you for specific foods in past sessions — use those values whenever the user mentions that food again instead of re-estimating.

The "remember" array is separate from "items": include a food in it only when the user is stating or correcting a fixed, reusable value for that food itself (e.g. "yogurt is always 101kcal and 11g protein", "actually peanut butter is 100kcal not 90"), not when they're just describing what they ate today. Most replies will have an empty remember array.
''';

  Future<AiFoodParseResult> parseMeal(
    String description, {
    List<Map<String, String>> history = const [],
    Map<String, dynamic> knownFacts = const {},
  }) async {
    if (!isConfigured) throw AiConfigException();

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      if (knownFacts.isNotEmpty) {'role': 'system', 'content': _describeKnownFacts(knownFacts)},
      ...history,
      {'role': 'user', 'content': description},
    ];

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_proxyBase/chat'),
            headers: _headers,
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'temperature': 0.3,
              'response_format': {'type': 'json_object'},
              'messages': messages,
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

    final items = _applyKnownFacts(_parseItems(rawItems), knownFacts);
    final remember = _parseItems(parsed['remember'] as List?);

    return AiFoodParseResult(items: items, remember: remember, reply: parsed['reply'] as String?, rawContent: content);
  }

  /// The "Known food facts" system message only *asks* the model to reuse
  /// remembered values — it's not reliable enough on its own (small models
  /// still re-estimate from scratch a lot of the time, especially once a
  /// stale figure is also sitting in the replayed history). This forces an
  /// exact-name match to the stored per-serving values in code, so a
  /// remembered fact actually sticks instead of being a suggestion the model
  /// can ignore. Trade-off: it overrides flatly, so if the model scaled an
  /// item for a stated quantity (e.g. "2 servings of yogurt"), the override
  /// clobbers that scaling back to the single-serving figure.
  static List<AiFoodItem> _applyKnownFacts(List<AiFoodItem> items, Map<String, dynamic> knownFacts) {
    if (knownFacts.isEmpty) return items;
    return items.map((it) {
      final fact = knownFacts[it.name.toLowerCase()] as Map?;
      if (fact == null) return it;
      return AiFoodItem(
        name: it.name,
        emoji: it.emoji,
        kcal: ((fact['kcal'] as num?) ?? it.kcal).round(),
        protein: ((fact['protein'] as num?) ?? it.protein).round(),
        carb: ((fact['carb'] as num?) ?? it.carb).round(),
        fat: ((fact['fat'] as num?) ?? it.fat).round(),
        fiber: ((fact['fiber'] as num?) ?? it.fiber).round(),
      );
    }).toList();
  }

  static List<AiFoodItem> _parseItems(List? raw) {
    if (raw == null) return const [];
    return raw.map((r) {
      final m = r as Map<String, dynamic>;
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
  }

  /// Renders persisted per-user food facts (see `AppData.aiFoodMemory`) into
  /// a system message so they're available on the very first message of a
  /// brand-new chat session, not just once mentioned within one.
  static String _describeKnownFacts(Map<String, dynamic> facts) {
    final lines = facts.entries.map((e) {
      final v = e.value as Map;
      return '- ${e.key}: ${v['kcal']}kcal, ${v['protein']}g protein, ${v['carb']}g carb, ${v['fat']}g fat, ${v['fiber']}g fiber (per serving)';
    });
    return 'Known food facts from previous sessions:\n${lines.join('\n')}';
  }

  /// Turns an error response into a message that tells the user what to
  /// actually do about it. Two sources land here: the proxy's own 401
  /// ("unauthorized" — `AI_PROXY_CLIENT_KEY` mismatch) and OpenAI's errors
  /// passed through verbatim by the proxy (`insufficient_quota` and
  /// `rate_limit_exceeded` both come back as HTTP 429 but mean very
  /// different things, so the status code alone isn't enough).
  String _describeError(http.Response res) {
    Map<String, dynamic>? error;
    try {
      error = (jsonDecode(res.body) as Map<String, dynamic>)['error'] as Map<String, dynamic>?;
    } catch (_) {
      // Not JSON (e.g. an upstream proxy/CDN error page) — fall through to the status-code messages below.
    }
    final code = error?['code'] as String?;
    final apiMessage = error?['message'] as String?;

    if (apiMessage == 'unauthorized' && code == null) {
      return "This app's proxy credentials look wrong — check AI_PROXY_CLIENT_KEY in secrets.json.";
    }
    if (res.statusCode == 401 || code == 'invalid_api_key') {
      return "The proxy's OpenAI key looks invalid — check the Cloudflare Worker's OPENAI_API_KEY secret.";
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
