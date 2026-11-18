import 'package:speech_to_text/speech_to_text.dart';

/// Voice input for chat, using the phone's own speech recognition
/// (`speech_to_text` 7.3.0). No server, no key, no extra model download:
/// Android uses the system recogniser, iOS uses Apple Speech.
///
/// The caller owns the flow: start listening, show the live transcript,
/// stop, let the user correct the text, then send it as a normal chat
/// message. Nothing is auto-sent, so a mis-heard word never goes to the
/// AI partner by itself.
class VoiceInput {
  VoiceInput();

  final SpeechToText _stt = SpeechToText();

  bool _available = false;
  bool get available => _available;
  bool get isListening => _stt.isListening;

  /// One-time setup. Returns false when this device cannot do speech
  /// recognition at all (e.g. no recogniser installed).
  Future<bool> init() async {
    try {
      _available = await _stt.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// Start listening in the practice language. [onResult] is called with
  /// every partial transcript and again with the final one
  /// (`finalResult == true`).
  ///
  /// Returns false when listening could not start.
  Future<bool> start({
    required String localeId,
    required void Function(String text, bool finalResult) onResult,
  }) async {
    if (!_available) return false;
    final locale = await _pickLocale(localeId);
    try {
      return await _stt.listen(
        onResult: (result) => onResult(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(localeId: locale),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_stt.isListening) await _stt.stop();
  }

  Future<void> cancel() async {
    if (_stt.isListening) await _stt.cancel();
  }

  /// Use the exact locale when the device has it (en_US / es_ES),
  /// otherwise fall back to the requested id and let the platform decide.
  Future<String> _pickLocale(String wanted) async {
    try {
      final locales = await _stt.locales();
      for (final locale in locales) {
        if (locale.localeId == wanted) return wanted;
      }
      final prefix = wanted.split('_').first;
      for (final locale in locales) {
        if (locale.localeId.startsWith(prefix)) return locale.localeId;
      }
    } catch (_) {
      // Fall through to the requested id.
    }
    return wanted;
  }
}
