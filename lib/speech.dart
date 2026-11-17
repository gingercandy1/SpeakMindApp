import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'settings.dart';

/// Reads text aloud. Uses the server's neural voice, and the phone's own
/// speech engine when the server cannot be reached or has no voice.
class Speaker {
  Speaker(this._settings);

  final SettingsStore _settings;
  final _player = AudioPlayer();
  final _fallback = FlutterTts();

  /// Where the audio of a text already fetched is kept, so a repeat is instant.
  final _files = <String, String>{};

  Future<void> speak(String text, AppLanguage language) async {
    await stop();
    try {
      final path = await _audioFile(text, language);
      await _player.play(DeviceFileSource(path));
      return;
    } on ApiException {
      // Fall through to the phone's voice.
    } on FileSystemException {
      // Fall through to the phone's voice.
    }
    await _fallback.setLanguage(language.ttsLocale);
    await _fallback.setSpeechRate(0.45);
    await _fallback.speak(text);
  }

  Future<String> _audioFile(String text, AppLanguage language) async {
    final key = '${language.code}|$text';
    final known = _files[key];
    if (known != null && File(known).existsSync()) return known;

    final wav = await ApiClient(_settings.serverUrl).speak(text: text, language: language.code);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}speakmind_voice_${_files.length}_${key.hashCode.toUnsigned(32)}.wav',
    );
    await file.writeAsBytes(wav, flush: true);
    return _files[key] = file.path;
  }

  Future<void> stop() async {
    await _player.stop();
    await _fallback.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
