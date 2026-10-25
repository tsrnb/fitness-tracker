import '../../../shared/lib/cloud/api_client.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../nutrition/domain/ai_food_item.dart' show AiConfigException, AiParseException;
import '../../nutrition/data/openai_food_service.dart' show aiModelName;

/// The "Know why" assistant on the Muscle screens. Same Cloudflare Worker
/// proxy (`AI_PROXY_URL` / `AI_PROXY_CLIENT_KEY`, `/chat`) the calibration
/// and food assistants use; this one is a conversational follow-up over a
/// compact digest of the user's own data (see `buildMuscleDigest`).
///
/// Throws [AiConfigException] when the proxy is unset and [AiParseException]
/// on any network or parse failure — the chat screen shows both inline.
class MuscleInsightService {
  static String get _proxyBase => CloudConfig.aiUrl;
  static String get _clientKey => ApiClient.instance.accessToken ?? '';
  static bool get isConfigured => _proxyBase.isNotEmpty && _clientKey.isNotEmpty;

  static const _system = '''
You are the "Know why" assistant inside a personal fitness-tracking app, talking to one person about their muscle-gain progress. You can see a digest of their own data (given below as JSON): weigh-ins and pace, estimated 1RM per tracked lift, weekly volume load, food and protein, tape measurements, and their experience level.

How to talk:
- Conversational and warm, like a good coach in a short chat. Plain text only, no markdown, no bullet lists. Usually 2-4 sentences.
- Answer the question first, then give the reason, citing the person's own numbers (kg, e1RM, kcal, g/kg, cm). Never invent a number that is not in the data.
- If the data needed to answer is missing (for example no tape measurements, or fewer than three weigh-ins), say so plainly and say what would fix it. Do not guess.
- Be calibrated: a target pace band is guidance, not a promise. Tape has about 0.5 cm of error. One soft session is normal.
- Never alarmist, never medical advice. Do not tell them to eat far less or far more than the data supports; a surplus above about +500 kcal mostly adds fat at intermediate and advanced levels.
- When it fits, end with one short follow-up question or a concrete next step.
- If the focusLift field is set, the person opened the chat from that lift: start from it.''';

  Future<String> chat(
    String message, {
    required Map<String, dynamic> digest,
    List<Map<String, String>> history = const [],
  }) async {
    if (!isConfigured) throw AiConfigException();
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_proxyBase/chat'),
            headers: {'Authorization': 'Bearer $_clientKey', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': aiModelName,
              'temperature': 0.5,
              'max_tokens': 450,
              'messages': [
                {'role': 'system', 'content': _system},
                {'role': 'system', 'content': 'The person\'s data:\n${jsonEncode(digest)}'},
                ...history,
                {'role': 'user', 'content': message},
              ],
            }),
          )
          .timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw AiParseException('That took too long to come back — try again.');
    } catch (_) {
      throw AiParseException("Couldn't reach the AI — check your connection and try again.");
    }
    if (res.statusCode != 200) {
      throw AiParseException('That request failed (${res.statusCode}). Try again in a moment.');
    }
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      final msg = (choices!.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
      final text = (msg['content'] as String).trim();
      if (text.isEmpty) throw const FormatException();
      return text;
    } catch (_) {
      throw AiParseException("That didn't come back right — try again.");
    }
  }
}
