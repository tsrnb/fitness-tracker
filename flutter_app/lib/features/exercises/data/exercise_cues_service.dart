import '../../../shared/lib/cloud/api_client.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../nutrition/data/openai_food_service.dart' show aiModelName;

/// Form cues, written by the AI.
///
/// Same AI proxy as the rest of the app's AI features (same
/// `AI_URL`, same `/chat` route). Cues are
/// intrinsic to an exercise and never change, so the first answer for an
/// exercise is cached to disk and every later open is instant and free.
///
/// Any failure — proxy not configured, offline, bad response — falls back to
/// the hand-written cues in the exercise library, so the screen always has
/// something to show.
class ExerciseCuesService {
  static String get _proxyBase => CloudConfig.aiUrl;
  static String get _clientKey => ApiClient.instance.accessToken ?? '';
  static bool get isConfigured =>
      _proxyBase.isNotEmpty && _clientKey.isNotEmpty;

  /// Cache-key version — bump to re-fetch everything after a prompt change.
  static const _v = 'aiCues.v1';

  /// [cues] and whether they came from the AI ([ai] false → the [fallback]
  /// library cues, because the proxy is off / offline / errored).
  static Future<({List<String> cues, bool ai})> cuesFor(
    String name, {
    required String target,
    required List<String> fallback,
  }) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_v.$name');
      if (cached != null) {
        final list = (jsonDecode(cached) as List)
            .map((e) => e.toString())
            .toList();
        if (list.isNotEmpty) return (cues: list, ai: true);
      }
    } catch (_) {}

    if (!isConfigured) return (cues: fallback, ai: false);

    try {
      final cues = await _fetch(name, target);
      if (cues.length >= 2) {
        await prefs?.setString('$_v.$name', jsonEncode(cues));
        return (cues: cues, ai: true);
      }
    } catch (_) {}

    return (cues: fallback, ai: false);
  }

  static const _system = '''
You are a strength and conditioning coach. For the exercise the user names, write 3-4 form cues — the specific things a lifter should focus on to perform it safely and get the target muscle working. Each cue is one imperative sentence, roughly 4-12 words, concrete and exercise-specific. No numbering, no "step 1" setup trivia, no fluff.

Respond with ONLY valid JSON, no markdown fences: {"cues": ["...", "...", "..."]}
''';

  static Future<List<String>> _fetch(String name, String target) async {
    final res = await http
        .post(
          Uri.parse('$_proxyBase/chat'),
          headers: {
            'Authorization': 'Bearer $_clientKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': aiModelName,
            'max_completion_tokens': 300,
            'response_format': {'type': 'json_object'},
            'messages': [
              {'role': 'system', 'content': _system},
              {
                'role': 'user',
                'content': 'Exercise: $name\nPrimary target: $target',
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('cues ${res.statusCode}');

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) throw Exception('cues: empty');
    final message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) throw Exception('cues: empty');

    final parsed = jsonDecode(content) as Map<String, dynamic>;
    return (parsed['cues'] as List? ?? [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
