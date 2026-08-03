import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Thrown when the device can't start listening — either the user denied
/// microphone/speech permission, or this device/browser has no recognizer
/// at all (e.g. non-Chromium browsers on web). [message] is written to be
/// shown to the user directly.
class SpeechUnavailableException implements Exception {
  final String message;
  SpeechUnavailableException(this.message);
}

/// Thin wrapper around the `speech_to_text` plugin (on-device speech
/// recognition — iOS Speech framework / Android SpeechRecognizer / Chrome's
/// Web Speech API) — isolates its init/listen/callback API behind a small
/// surface so the voice screen just awaits a stream of text updates instead
/// of juggling the plugin directly.
class SpeechRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  /// Starts listening. [onResult] fires with the best-guess transcript as it
  /// updates (interim results included, so it visibly builds up word by
  /// word) and whether that particular update is the final one for this
  /// utterance. [onDone] fires once the plugin considers the session over —
  /// e.g. after [SpeechListenOptions.pauseFor] of silence — so the caller
  /// can settle the UI without the user having to tap stop themselves.
  /// [onError] fires for anything that interrupts listening (permission
  /// revoked mid-session, no microphone, a network hiccup for the
  /// server-backed recognizers) with a message safe to show directly.
  ///
  /// Throws [SpeechUnavailableException] if permission was denied or no
  /// recognizer is available; the caller isn't left guessing why nothing
  /// happened.
  Future<void> startListening({
    required void Function(String text, {required bool isFinal}) onResult,
    required void Function() onDone,
    required void Function(String message) onError,
  }) async {
    final ready = await _speech.initialize(
      // The web implementation (Chrome's Web Speech API) never reports a
      // "final" result type, and the plugin's own 'done' status is
      // suppressed whenever the latest result was non-final — so on web
      // 'done' simply never arrives. 'notListening' fires whenever the
      // recognizer actually stops (silence timeout, stop(), or an error)
      // on every platform, so it's the one status that's safe to key off.
      onStatus: (status) {
        if (status == 'notListening') onDone();
      },
      onError: (error) => onError(_describeError(error.errorMsg)),
    );
    if (!ready) {
      final permitted = await _speech.hasPermission;
      throw SpeechUnavailableException(
        permitted
            ? "Speech recognition isn't available on this device."
            : "Microphone access was denied — enable it in Settings to use voice.",
      );
    }
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, isFinal: result.finalResult),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  /// Browser/OS error codes are terse and inconsistent across platforms —
  /// translate the ones worth calling out by name, and fall back to a
  /// generic retry message rather than surfacing a raw code like
  /// `"no-speech"` to the user.
  String _describeError(String code) {
    switch (code) {
      case 'not-allowed':
      case 'service-not-allowed':
      case 'permission':
        return "Microphone access was denied — enable it in your browser or Settings to use voice.";
      case 'audio-capture':
        return "No microphone found on this device.";
      case 'network':
        return "A network error interrupted listening — check your connection and try again.";
      case 'no-speech':
        return "Didn't catch that — try again.";
      default:
        return "Something interrupted listening — try again.";
    }
  }

  bool get isListening => _speech.isListening;
  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
}
