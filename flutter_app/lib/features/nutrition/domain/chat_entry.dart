import 'ai_food_item.dart';

/// One entry in the Ask AI chat transcript — a view-model for what's shown
/// on screen, not persisted anywhere (the transcript resets whenever the
/// chat screen is reopened; see `AskAiController` for what *is* replayed
/// to the model within a session).
sealed class ChatEntry {}

class UserTextEntry extends ChatEntry {
  final String text;
  UserTextEntry(this.text);
}

class AssistantTextEntry extends ChatEntry {
  final String text;
  AssistantTextEntry(this.text);
}

class AssistantTypingEntry extends ChatEntry {}

class AssistantResultEntry extends ChatEntry {
  final AiFoodParseResult result;
  bool added = false;
  // Whether these items have been saved to the food library (Quick add) —
  // independent of [added], since logging today's meal and keeping the item
  // around for next time are two different asks.
  bool saved = false;
  AssistantResultEntry(this.result);
}

class AssistantErrorEntry extends ChatEntry {
  final String message;
  AssistantErrorEntry(this.message);
}
