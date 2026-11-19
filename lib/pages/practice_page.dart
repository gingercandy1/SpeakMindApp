import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../models.dart';
import '../settings.dart';
import '../speech.dart';
import '../theme.dart';
import '../widgets/result_view.dart';
import 'chat_page.dart';
import 'settings_page.dart';

enum _Phase { idle, recording, scoring }

/// Read a sentence aloud, get it scored, see which sounds were off.
class PracticePage extends StatefulWidget {
  const PracticePage({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  /// The server rejects recordings longer than this.
  static const _maxSeconds = 30;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  late final _speaker = Speaker(widget.settings);

  _Phase _phase = _Phase.idle;
  bool _starting = false;
  bool _loadingVoice = false;
  late String _sentence = widget.settings.sentences.first;

  Assessment? _result;
  String? _error;
  String? _takePath;
  int? _selectedWord;

  Timer? _ticker;
  DateTime? _startedAt;
  int _elapsedSeconds = 0;
  StreamSubscription<Amplitude>? _amplitudeSub;
  double _loudness = 0;

  List<String> get _sentences => widget.settings.sentences;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _speaker.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    // The current sentence may have been deleted from the list.
    if (!_sentences.contains(_sentence)) {
      _showSentence(_sentences.first);
    } else {
      setState(() {});
    }
  }

  void _showSentence(String sentence) {
    _player.stop();
    _speaker.stop();
    setState(() {
      _sentence = sentence;
      _result = null;
      _error = null;
      _takePath = null;
      _selectedWord = null;
    });
  }

  void _step(int delta) {
    final list = _sentences;
    final next = (list.indexOf(_sentence) + delta) % list.length;
    _showSentence(list[next]);
  }

  Future<void> _startRecording() async {
    if (_phase != _Phase.idle || _starting) return;
    _starting = true;
    try {
      if (!await _recorder.hasPermission()) {
        _fail('需要麦克风权限才能录音，请在系统设置里允许');
        return;
      }
      await _player.stop();
      await _speaker.stop();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}${Platform.pathSeparator}speakmind_take.wav';
      // 16 kHz mono WAV is exactly what the server's model consumes.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (e) {
      _fail('无法开始录音：$e');
      return;
    } finally {
      _starting = false;
    }
    if (!mounted) return;

    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final seconds = DateTime.now().difference(_startedAt!).inSeconds;
      if (seconds >= _maxSeconds) {
        _stopAndScore();
      } else if (seconds != _elapsedSeconds) {
        setState(() => _elapsedSeconds = seconds);
      }
    });
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amplitude) {
      // dBFS: about -50 is quiet room noise, 0 is the loudest possible.
      final loudness = ((amplitude.current + 50) / 50).clamp(0.0, 1.0);
      if (mounted) setState(() => _loudness = loudness);
    });
    setState(() {
      _phase = _Phase.recording;
      _elapsedSeconds = 0;
      _loudness = 0;
      _result = null;
      _error = null;
      _selectedWord = null;
    });
  }

  Future<void> _stopAndScore() async {
    if (_phase != _Phase.recording) return;
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    setState(() => _phase = _Phase.scoring);

    final sentence = _sentence;
    final language = widget.settings.language.code;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    if (path == null) {
      _fail('录音失败，请再试一次');
      return;
    }
    _takePath = path;

    try {
      final result = await ApiClient(widget.settings.serverUrl)
          .assess(audioPath: path, text: sentence, language: language);
      if (!mounted) return;
      setState(() {
        _result = result;
        _selectedWord = _weakestWord(result);
        _phase = _Phase.idle;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _phase = _Phase.idle;
    });
  }

  /// The lowest-scoring word that is not already good, so the user sees
  /// straight away what to work on.
  static int? _weakestWord(Assessment result) {
    int? weakest;
    for (final (i, word) in result.words.indexed) {
      final score = word.score;
      if (score == null || word.level == Level.good) continue;
      if (weakest == null || score < result.words[weakest].score!) weakest = i;
    }
    return weakest;
  }

  Future<void> _playExample() async {
    if (_loadingVoice) return;
    await _player.stop();
    setState(() => _loadingVoice = true);
    try {
      await _speaker.speak(_sentence, widget.settings.language);
    } finally {
      if (mounted) setState(() => _loadingVoice = false);
    }
  }

  Future<void> _playTake() async {
    final path = _takePath;
    if (path == null) return;
    await _speaker.stop();
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  Future<void> _pickSentence() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SentenceSheet(settings: widget.settings, current: _sentence),
    );
    if (picked != null && picked != _sentence) _showSentence(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idle = _phase == _Phase.idle;
    final result = _result;
    final error = _error;
    final position = _sentences.indexOf(_sentence) + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpeakMind'),
        actions: [
          IconButton(
            tooltip: 'AI 聊天',
            onPressed: idle
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatPage(settings: widget.settings),
                      ),
                    )
                : null,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: '选择句子',
            onPressed: idle ? _pickSentence : null,
            icon: const Icon(Icons.format_list_bulleted),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: idle
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SettingsPage(settings: widget.settings),
                      ),
                    )
                : null,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '第 $position 句 / 共 ${_sentences.length} 句',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SegmentedButton<AppLanguage>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          segments: [
                            for (final l in languages)
                              ButtonSegment(value: l, label: Text(l.label), tooltip: l.name),
                          ],
                          selected: {widget.settings.language},
                          onSelectionChanged: idle
                              ? (selection) => widget.settings.setLanguage(selection.first)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (result == null)
                      Text(
                        _sentence,
                        style: widget.settings.language.code == 'es'
                            ? SpeakMindText.spanish(size: 24)
                            : theme.textTheme.headlineSmall
                                ?.copyWith(height: 1.4),
                      )
                    else
                      ResultView(
                        result: result,
                        selectedWord: _selectedWord,
                        onSelectWord: (i) => setState(() => _selectedWord = i),
                      ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: idle && !_loadingVoice ? _playExample : null,
                          icon: _loadingVoice
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.volume_up_outlined),
                          label: const Text('听示范'),
                        ),
                        OutlinedButton.icon(
                          onPressed: idle && _takePath != null ? _playTake : null,
                          icon: const Icon(Icons.replay),
                          label: const Text('听我的录音'),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 20),
                      _ErrorBox(message: error),
                    ],
                  ],
                ),
              ),
            ),
            _Controls(
              phase: _phase,
              elapsedSeconds: _elapsedSeconds,
              maxSeconds: _maxSeconds,
              loudness: _loudness,
              hasResult: result != null,
              onPrevious: idle ? () => _step(-1) : null,
              onNext: idle ? () => _step(1) : null,
              onMic: switch (_phase) {
                _Phase.idle => _startRecording,
                _Phase.recording => _stopAndScore,
                _Phase.scoring => null,
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar: previous sentence, the record button, next sentence.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.phase,
    required this.elapsedSeconds,
    required this.maxSeconds,
    required this.loudness,
    required this.hasResult,
    required this.onPrevious,
    required this.onNext,
    required this.onMic,
  });

  final _Phase phase;
  final int elapsedSeconds;
  final int maxSeconds;
  final double loudness;
  final bool hasResult;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onMic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recording = phase == _Phase.recording;
    final buttonColor = recording ? scheme.error : scheme.primary;
    final iconColor = recording ? scheme.onError : scheme.onPrimary;

    final hint = switch (phase) {
      _Phase.idle => hasResult ? '点麦克风再读一次' : '点麦克风开始朗读',
      _Phase.recording => '正在录音 $elapsedSeconds 秒（最长 $maxSeconds 秒），读完点停止',
      _Phase.scoring => '正在评分…',
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hint, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                tooltip: '上一句',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              SizedBox.square(
                dimension: 104,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ring that grows with the voice, so the user can see the
                    // microphone is picking them up.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: recording ? 76 + 28 * loudness : 76,
                      height: recording ? 76 + 28 * loudness : 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: buttonColor.withValues(alpha: 0.22),
                      ),
                    ),
                    SizedBox.square(
                      dimension: 76,
                      child: Material(
                        color: onMic == null ? scheme.surfaceContainerHighest : buttonColor,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onMic,
                          child: Center(
                            child: phase == _Phase.scoring
                                ? const SizedBox.square(
                                    dimension: 28,
                                    child: CircularProgressIndicator(strokeWidth: 3),
                                  )
                                : Icon(
                                    recording ? Icons.stop_rounded : Icons.mic,
                                    size: 36,
                                    color: iconColor,
                                    semanticLabel: recording ? '停止录音' : '开始录音',
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: '下一句',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pick a sentence to practise, or add one of your own.
class _SentenceSheet extends StatefulWidget {
  const _SentenceSheet({required this.settings, required this.current});

  final SettingsStore settings;
  final String current;

  @override
  State<_SentenceSheet> createState() => _SentenceSheetState();
}

class _SentenceSheetState extends State<_SentenceSheet> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await widget.settings.addSentence(text);
    if (mounted) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Keeps the text field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 300,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        labelText: widget.settings.language.code == 'es'
                            ? '添加自己的西语句子'
                            : '添加自己的英文句子',
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '添加',
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.settings,
                builder: (context, _) {
                  final custom = widget.settings.customSentences.toSet();
                  final sentences = widget.settings.sentences;
                  return ListView.builder(
                    itemCount: sentences.length,
                    itemBuilder: (context, i) {
                      final sentence = sentences[i];
                      return ListTile(
                        title: Text(sentence),
                        selected: sentence == widget.current,
                        selectedTileColor: theme.colorScheme.secondaryContainer,
                        onTap: () => Navigator.of(context).pop(sentence),
                        trailing: custom.contains(sentence)
                            ? IconButton(
                                tooltip: '删除',
                                onPressed: () => widget.settings.removeSentence(sentence),
                                icon: const Icon(Icons.delete_outline),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
