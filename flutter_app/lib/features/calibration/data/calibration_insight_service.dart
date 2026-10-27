import '../../../shared/lib/cloud/api_client.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../nutrition/domain/ai_food_item.dart' show AiConfigException, AiParseException;
import '../../nutrition/data/openai_food_service.dart' show aiModelName;
import '../domain/calibration_ai.dart';

/// Every AI touchpoint in the 14-Day Calibration — all through the same
/// Cloudflare Worker proxy (`AI_PROXY_URL` / `AI_PROXY_CLIENT_KEY`, `/chat`
/// route) `OpenAiFoodService` already uses, just with calibration-shaped
/// prompts and JSON responses.
///
///  - [analyzeResult]  end-of-window: narrative + ranked sized causes +
///                     confidence + a tempered TDEE. Feeds the results screen.
///  - [deepDive]       user-triggered mid-window: evidence-cited observations
///                     over the full raw record.
///  - [chat]           free-form follow-up over a pinned context (result or
///                     deep-dive), replaying prior turns.
///  - [preflight]      before Day 1: go / tighten-logging / pick-window +
///                     an Observe-vs-Controlled recommendation.
///  - [midpoint]       once on Day 7: keep-going / restart / switch.
///
/// Every method throws [AiConfigException] when the proxy is unset and
/// [AiParseException] on a network/parse failure — the callers all fall
/// back to their existing deterministic behaviour.
class CalibrationInsightService {
  static String get _proxyBase => CloudConfig.aiUrl;
  static String get _clientKey => ApiClient.instance.accessToken ?? '';
  static bool get isConfigured => _proxyBase.isNotEmpty && _clientKey.isNotEmpty;

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer $_clientKey',
        'Content-Type': 'application/json',
      };

  static const _coachVoice =
      'You are a calm, knowledgeable coach embedded in a personal fitness-tracking app. Never alarmist, never "just eat less" (the app frames that elsewhere), never claim certainty about a cause. Ground everything in the numbers given.';

  // -------------------------------------------------------------------------
  // End-of-window analysis
  // -------------------------------------------------------------------------

  static const _analyzeSystem = '''
$_coachVoice

The user just finished a "calibration" window: they logged food and weigh-ins while the app compared its calorie-model prediction against what actually happened. You get a day-by-day digest and the app's own rule flags.

14 days of daily weigh-ins and food logs is a substantial dataset — treat it as one. Reach a firm conclusion and commit to it. Name the single biggest driver of the gap and state it as the finding, not as one option among several. Do NOT hedge with "this could be X or Y" or "hard to say" when the data supports a call — it usually does.

Attribute the expected-vs-observed gap to specific causes you can see in the data (weekend over-eating, a water/sodium spike on a given day, under-logging on unlogged days, a genuinely low TDEE, glycogen shifts). Size each one: a kg estimate and a share of the total gap. Rank most-likely first.

Confidence: 95-99 whenever food was logged on 11+ of the 14 days AND there are 10+ weigh-ins — a normal calibration earns a hard verdict, and this number should read as one. Drop below 70 ONLY when the data is genuinely too sparse to conclude (food logged on fewer than 9 days, or fewer than 8 weigh-ins); in that case say so plainly and the next step is to re-run, not to guess. Do not use the 70-94 range — a calibration is either conclusive (95+) or too thin (<70).

"verdictAction" is the one decisive move you're recommending:
- "adjust_plan" — the gap is metabolic; the plan's TDEE / calorie target should move. This is the answer for most conclusive studies where the scale and the logged intake disagree.
- "hold" — the plan's numbers are right; the fix is behavioural (logging accuracy, a one-off heavy week, a water spike). No number change.
- "rerun" — ONLY when confidence is below 70. Never pick this for a conclusive study; the user does not want to be told to calibrate again when the data already answered the question.

"nextStep" is one imperative sentence, 16 words or fewer, no hedging — the single thing the user does on closing this screen ("Raise your maintenance estimate by ~240 kcal and keep the same deficit." / "Hold your current targets and tighten weekend logging — the plan is fine." / "Run the two weeks again with a weigh-in every morning.").

Give a "tempered" TDEE: if most of the gap is behaviour or water rather than metabolism, move the plan's TDEE LESS than a straight-line kcal calculation would; if the trend is clean, match it.

The "headline" is the one line the user reads first — it is the whole verdict. One plain sentence, 14 words or fewer, stating the finding as fact ("Your body burns about 240 more calories a day than your plan assumed" / "You're eating roughly 300 calories a day more than you're logging" / "The logging this round was too thin to draw a conclusion — re-run it"). No hedging clauses, no stats dump.

Respond with ONLY valid JSON, no markdown fences:
{
  "headline": "one plain sentence, <=14 words, the verdict",
  "narrative": "2-3 plain sentences of reasoning that name the biggest driver as fact.",
  "verdictAction": "adjust_plan | hold | rerun",
  "nextStep": "one imperative sentence, <=16 words",
  "causes": [ { "name": "short label", "kg": number, "share": number (0-1), "note": "one sentence citing the data" } ],
  "confidence": number (0-100),
  "temperedTdee": number (kcal),
  "temperedRationale": "one sentence"
}''';

  Future<CalibrationAiReport> analyzeResult({
    required Map<String, dynamic> digest,
    required double expectedKg,
    required double observedKg,
  }) async {
    final user = jsonEncode({
      'expectedKgChange': double.parse(expectedKg.toStringAsFixed(2)),
      'observedKgChange': double.parse(observedKg.toStringAsFixed(2)),
      'gapKg': double.parse((observedKg - expectedKg).toStringAsFixed(2)),
      ...digest,
    });
    final parsed = await _postJson(_analyzeSystem, user, maxTokens: 900);
    return CalibrationAiReport.fromJson(parsed);
  }

  // -------------------------------------------------------------------------
  // Deep dive
  // -------------------------------------------------------------------------

  static const _deepDiveSystem = '''
$_coachVoice

The user asked you to look at everything logged so far in a running calibration and tell them what you see. You get the raw record: every weigh-in with its date, every logged meal with macros, each workout's sets, steps, and the frozen Day-1 baseline.

Do your own aggregation. Surface 3-6 SPECIFIC observations a fixed rule wouldn't catch — a pattern tied to particular days, a weight move that's clearly noise, something worth watching, something that's working. Each observation cites the actual data behind it. Order them by how much they matter. Don't invent data that isn't there; if the window is short, say less.

Classify each: "pattern" (a real behavioural pattern), "noise" (a reading that isn't what it looks like), "watch" (worth keeping an eye on), "working" (going well).

Respond with ONLY valid JSON, no markdown fences:
{
  "summary": "1-2 sentences framing the read.",
  "observations": [ { "type": "pattern|noise|watch|working", "headline": "short", "body": "2-3 sentences", "evidence": ["short data citation", "..."] } ]
}''';

  Future<CalibrationDeepDive> deepDive(Map<String, dynamic> context) async {
    final parsed = await _postJson(_deepDiveSystem, jsonEncode(context), maxTokens: 1100);
    return CalibrationDeepDive.fromJson(parsed);
  }

  // -------------------------------------------------------------------------
  // Follow-up chat
  // -------------------------------------------------------------------------

  static const _chatSystem = '''
$_coachVoice

You are answering follow-up questions about the user's calibration. The full data context is given as a system message below. Answer directly and specifically, drawing on that data. Plain conversational text, no markdown, usually 2-4 sentences. If asked to predict, be explicit that it's a projection from the current trend.''';

  Future<String> chat(
    String message, {
    required Map<String, dynamic> context,
    List<Map<String, String>> history = const [],
  }) async {
    if (!isConfigured) throw AiConfigException();
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _chatSystem},
      {'role': 'system', 'content': 'Calibration data:\n${jsonEncode(context)}'},
      ...history,
      {'role': 'user', 'content': message},
    ];
    final res = await _post(messages, maxTokens: 500, jsonObject: false);
    return _plainContent(res);
  }

  // -------------------------------------------------------------------------
  // Pre-flight
  // -------------------------------------------------------------------------

  static const _preflightSystem = '''
$_coachVoice

The user is about to start a 14-day calibration. You get a digest of the 3 weeks before today: how many days food and weigh-ins were logged, weekend coverage, average intake, and its day-to-day spread (intakeCv).

Decide one verdict:
- "go" — logging is complete enough (roughly 70%+ food, 60%+ weigh-ins) to calibrate now.
- "tighten" — too many gaps; a week of tighter logging first would pay off.
- "window" — logging is fine but something looks off about this specific window (e.g. almost no weekends covered).

Also recommend a mode: "observe" if intake swings a lot day to day (they'd fight a controlled hold), "controlled" if it's already steady.

Respond with ONLY valid JSON, no markdown fences:
{ "verdict": "go|tighten|window", "summary": "2-3 sentences", "recommendedMode": "observe|controlled", "modeReason": "one sentence" }''';

  Future<CalibrationPreflight> preflight(Map<String, dynamic> digest) async {
    final parsed = await _postJson(_preflightSystem, jsonEncode(digest), maxTokens: 400);
    return CalibrationPreflight.fromJson(parsed);
  }

  // -------------------------------------------------------------------------
  // Midpoint (day 7)
  // -------------------------------------------------------------------------

  static const _midpointSystem = '''
$_coachVoice

The user is halfway through a calibration. You get days 1-7 compared against the baseline week captured on Day 1.

Decide one status:
- "on_track" — days 1-7 look like their normal routine; nothing to change.
- "restart" — intake or training has drifted far enough from baseline that the window is now measuring a different routine, and restarting would give a truer read.
- "switch" — the noise is high and switching to a Controlled hold for the rest would sharpen the result.

Respond with ONLY valid JSON, no markdown fences:
{ "status": "on_track|restart|switch", "message": "2-3 sentences, ending on the concrete option" }''';

  Future<CalibrationMidpoint> midpoint(Map<String, dynamic> digest) async {
    final parsed = await _postJson(_midpointSystem, jsonEncode(digest), maxTokens: 300);
    return CalibrationMidpoint.fromJson(parsed);
  }

  // -------------------------------------------------------------------------
  // transport
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> _postJson(String system, String user, {required int maxTokens}) async {
    if (!isConfigured) throw AiConfigException();
    final res = await _post([
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ], maxTokens: maxTokens, jsonObject: true);
    final content = _plainContent(res);
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw AiParseException("That didn't come back in a form I could read — try again.");
    }
  }

  Future<http.Response> _post(
    List<Map<String, String>> messages, {
    required int maxTokens,
    required bool jsonObject,
  }) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_proxyBase/chat'),
            headers: _headers,
            body: jsonEncode({
              'model': aiModelName,
              'max_completion_tokens': maxTokens,
              if (jsonObject) 'response_format': {'type': 'json_object'},
              'messages': messages,
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
    return res;
  }

  String _plainContent(http.Response res) {
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
    if (content == null || content.isEmpty) {
      throw AiParseException("That didn't come back right — try again.");
    }
    return content;
  }
}
