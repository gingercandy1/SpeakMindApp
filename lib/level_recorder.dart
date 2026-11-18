/// F1: a small recorder for the level page's scored speaking steps.
///
/// Same recording setup as the practice page (16 kHz mono WAV, what
/// `/assess` expects), wrapped so the level page only deals with
/// start/stop and a file path.
library;

import 'package:record/record.dart';

class LevelRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  /// `true` when the microphone permission is available.
  Future<bool> get hasPermission async => _recorder.hasPermission();

  /// Starts recording to [path]. Throws if the recorder cannot start.
  Future<void> start(String path) async {
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  /// Stops and returns the file path, or null if nothing was recorded.
  Future<String?> stop() async {
    try {
      return await _recorder.stop();
    } on Exception {
      return null;
    }
  }

  /// Cancels the current recording without keeping the file.
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } on Exception {
      // Nothing to cancel or already stopped: safe to ignore.
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
