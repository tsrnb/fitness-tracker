import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../nutrition/domain/ai_food_item.dart' show AiConfigException, AiParseException;
import '../../nutrition/data/openai_food_service.dart' show aiModelName;
import '../domain/kg_progress.dart';

/// Explains a [KgGapInsight] in plain language — reuses the exact same
/// Cloudflare Worker proxy `OpenAiFoodService` calls for meal parsing (same
/// `AI_PROXY_URL`/`AI_PROXY_CLIENT_KEY`, same `/chat` route, same
/// never-ships-a-real-OpenAI-key reasoning), just with a different prompt
/// and a plain-text reply instead of a JSON schema — there's only one
/// sentence-shaped thing being asked for here, not structured data.
class WeightInsightService {
  static const _proxyBase = String.fromEnvironment('AI_PROXY_URL');
  static const _clientKey = String.fromEnvironment('AI_PROXY_CLIENT_KEY');
  static bool get isConfigured => _proxyBase.isNotEmpty && _clientKey.isNotEmpty;

  static Map<String, String> get _headers => {
        'X-Client-Key': _clientKey,
        'Content-Type': 'application/json',
      };

  static const _systemPrompt = '''
You are a calm, knowledgeable coach embedded in a personal fitness-tracking app. The user logs their food, and the app separately estimates their weight trend from that log versus what their scale actually shows. Given the numbers below, write a short, friendly, reassuring explanation (3-4 sentences, plain conversational language, no headers or bullet points, no markdown) of the most likely reasons for a gap like this between the food-log estimate and the scale reading, and end with one practical, concrete next step.

Ground it in real, common causes — water retention from sodium/carbs, a bowel-movement/hydration-timing difference between weigh-ins, muscle gain masking fat loss if they train, or the food log itself under/over-counting portions — rather than vague reassurance. Don't be alarmist: a gap like this over a week or two is rarely fat gained, and say so plainly rather than hedging around it.
''';

  Future<String> explainGap(KgGapInsight gap) async {
    if (!isConfigured) throw AiConfigException();

    final prompt = '''
Previous weigh-in: ${gap.previousDate}, ${gap.previousWeight.toStringAsFixed(1)} kg
Latest weigh-in: ${gap.latestDate}, ${gap.actualWeight.toStringAsFixed(1)} kg
Food log predicted: ${gap.predictedWeight.toStringAsFixed(1)} kg by the latest weigh-in
Gap: ${gap.gapKg.abs().toStringAsFixed(1)} kg ${gap.gapKg >= 0 ? 'more than predicted' : 'less than predicted'}
Days between weigh-ins: ${gap.daysBetween}
Of those, days with food actually logged: ${gap.daysLogged}
''';

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_proxyBase/chat'),
            headers: _headers,
            body: jsonEncode({
              'model': aiModelName,
              'temperature': 0.4,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': prompt},
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
      throw AiParseException('That request failed (${res.statusCode}). Try again in a moment.');
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
      content = (message?['content'] as String?)?.trim();
    }
    if (content == null || content.isEmpty) throw AiParseException("That didn't come back right — try again.");
    return content;
  }
}
