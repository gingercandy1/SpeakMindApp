/// Data returned by the server's `POST /assess`.
library;

enum Level { good, fair, poor, unknown }

Level parseLevel(Object? value) => switch (value) {
      'good' => Level.good,
      'fair' => Level.fair,
      'poor' => Level.poor,
      _ => Level.unknown,
    };

double? _double(Object? v) => v is num ? v.toDouble() : null;
int? _int(Object? v) => v is num ? v.round() : null;

class PhonemeResult {
  const PhonemeResult({
    required this.ipa,
    required this.score,
    required this.level,
    this.heard,
  });

  final String ipa;
  final int score;
  final Level level;

  /// The phoneme the model heard instead, when the score is not good.
  final String? heard;

  factory PhonemeResult.fromJson(Map<String, dynamic> j) => PhonemeResult(
        ipa: j['ipa'] as String,
        score: _int(j['score']) ?? 0,
        level: parseLevel(j['level']),
        heard: j['heard'] as String?,
      );
}

class WordResult {
  const WordResult({
    required this.word,
    required this.score,
    required this.level,
    required this.phonemes,
  });

  final String word;

  /// Null when the word had no phonemes the model can score.
  final int? score;
  final Level level;
  final List<PhonemeResult> phonemes;

  factory WordResult.fromJson(Map<String, dynamic> j) => WordResult(
        word: j['word'] as String,
        score: _int(j['score']),
        level: parseLevel(j['level']),
        phonemes: [
          for (final p in (j['phonemes'] as List? ?? const []))
            PhonemeResult.fromJson(p as Map<String, dynamic>),
        ],
      );
}

class Pause {
  const Pause({required this.after, required this.seconds});

  final String after;
  final double seconds;

  factory Pause.fromJson(Map<String, dynamic> j) => Pause(
        after: j['after'] as String,
        seconds: _double(j['seconds']) ?? 0,
      );
}

class Fluency {
  const Fluency({
    required this.speakingSeconds,
    required this.phonemesPerSecond,
    required this.pauses,
  });

  final double speakingSeconds;
  final double? phonemesPerSecond;
  final List<Pause> pauses;

  factory Fluency.fromJson(Map<String, dynamic> j) => Fluency(
        speakingSeconds: _double(j['speaking_seconds']) ?? 0,
        phonemesPerSecond: _double(j['phonemes_per_second']),
        pauses: [
          for (final p in (j['pauses'] as List? ?? const []))
            Pause.fromJson(p as Map<String, dynamic>),
        ],
      );
}

/// What `GET /health` says the server can do.
class ServerInfo {
  const ServerInfo({
    required this.model,
    required this.ttsLanguages,
    required this.chat,
  });

  final String model;

  /// Language codes the server has a voice for.
  final List<String> ttsLanguages;

  /// Whether the server has an AI chat service configured.
  final bool chat;

  factory ServerInfo.fromJson(Map<String, dynamic> j) => ServerInfo(
        model: j['model'] as String? ?? '',
        ttsLanguages: [
          for (final l in (j['tts'] as List? ?? const [])) l as String,
        ],
        chat: j['chat'] == true,
      );
}

/// One message of a conversation with the AI partner.
class ChatMessage {
  const ChatMessage({required this.role, required this.content, this.tip});

  /// `user` or `assistant`.
  final String role;
  final String content;

  /// A correction of the user's message, in Chinese (assistant messages only).
  final String? tip;

  bool get fromUser => role == 'user';

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// The partner's answer from `POST /chat`.
class ChatReply {
  const ChatReply({required this.reply, this.tip});

  final String reply;
  final String? tip;

  factory ChatReply.fromJson(Map<String, dynamic> j) =>
      ChatReply(reply: j['reply'] as String? ?? '', tip: j['tip'] as String?);
}

class Assessment {
  const Assessment({
    required this.accuracy,
    required this.level,
    required this.fluency,
    required this.words,
  });

  final int accuracy;
  final Level level;
  final Fluency fluency;
  final List<WordResult> words;

  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
        accuracy: _int(j['accuracy']) ?? 0,
        level: parseLevel(j['level']),
        fluency: Fluency.fromJson(j['fluency'] as Map<String, dynamic>),
        words: [
          for (final w in (j['words'] as List? ?? const []))
            WordResult.fromJson(w as Map<String, dynamic>),
        ],
      );
}
