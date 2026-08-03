/// One food item as estimated by the model — mirrors `ParsedMealItem` from
/// `data/meal_line_parser.dart` plus an `emoji`, since that's used for the
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
