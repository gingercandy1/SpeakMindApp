/// F1: real six-step level gameplay.
///
/// One level, six steps (levels dev doc §6):
///
/// 1. 剧情引入 — Brasa's Chinese intro + the NPC's Spanish opening line
///    (playable with TTS).
/// 2. 热身卡片 — 5-8 words; record each word once, a light /assess marks
///    the card done (no grading). Skippable.
/// 3. 跟读闯关 — 2-3 core sentences, scored by /assess; need 2 of 3 (or
///    all, when there are only 2) at the world's pass line to move on.
/// 4. 情境对话 — voice-first chat with the level's NPC via /chat; the
///    NPC's `dialogue_opening` is the first assistant message, and the
///    level's `npc_prompt` is sent along (the current server ignores it —
///    full persona needs the small server-side change, see README).
///    Typing is behind a small "打字" toggle; the hint button shows a
///    full-sentence suggestion (unlimited in W1-W2).
/// 5. 挑战任务 — a spoken variant sentence, scored by /assess; pass at
///    the pass line, "excellent" at GOP >= 90.
/// 6. 结算 — stars + XP through [ProgressStore.completeLevel], which also
///    unlocks the next level.
///
/// Levels are Spanish-only (the English line is paused). Dialogue turns
/// are free speech and cannot be GOP-scored — only the spoken steps
/// (shadowing + challenge) feed the pronunciation average. Nothing is
/// auto-passed: when the server cannot be reached the step shows the
/// error and a retry. Progress inside a level is not saved across app
/// restarts (later polish); the JSON content itself is local, so a level
/// always opens offline.
library;

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../api.dart';
import '../level_recorder.dart';
import '../level_scoring.dart';
import '../levels.dart';
import '../models.dart';
import '../progress.dart';
import '../settings.dart';
import '../speech.dart';
import '../theme.dart';
import '../voice_input.dart';
import '../widgets/result_view.dart';

/// The six steps of every level (levels dev doc §6).
const levelSteps = <String>[
  '1 剧情引入',
  '2 学词句',
  '3 跟读闯关',
  '4 情境对话',
  '5 挑战题',
  '6 结算',
];

class LevelPage extends StatefulWidget {
  const LevelPage({
    super.key,
    required this.node,
    required this.graph,
    required this.progress,
    required this.settings,
  });

  final LevelNode node;
  final LevelGraph graph;
  final ProgressStore progress;

  /// Settings (server URL + voices). Levels are Spanish-only.
  final SettingsStore settings;

  @override
  State<LevelPage> createState() => _LevelPageState();
}

enum _RecPhase { idle, recording, scoring }

class _LevelPageState extends State<LevelPage> {
  /// The server rejects recordings longer than this.
  static const _maxSeconds = 30;

  /// Levels are Spanish-only; the TTS / assess / chat language is fixed.
  static const _spanish = AppLanguage(
    code: 'es',
    label: 'ES',
    name: '西班牙语',
    ttsLocale: 'es-ES',
    builtIn: builtInSentencesEs,
    customKey: 'custom_sentences_es',
  );

  late final Speaker _speaker = Speaker(widget.settings);
  final _recorder = LevelRecorder();
  final _voice = VoiceInput();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  int _step = 0;
  String? _error;

  /// Which spoken item is being recorded, e.g. `('word', 1)`.
  ({String kind, int index})? _recTarget;
  _RecPhase _recPhase = _RecPhase.idle;
  Future<void> Function(String path)? _onRecordDone;
  Timer? _ticker;
  DateTime? _startedAt;
  int _elapsed = 0;
  bool _playingOpening = false;

  // Step 2: warm-up cards.
  final Set<int> _wordDone = {};
  final Map<int, int> _wordScores = {};

  // Step 3: shadowing.
  late final List<Assessment?> _shadowResults =
      List.filled(widget.node.sentences.length, null);
  late final List<int?> _shadowSelected =
      List.filled(widget.node.sentences.length, null);

  // Step 4: dialogue.
  late final List<ChatMessage> _messages = [
    ChatMessage(
      role: 'assistant',
      content: widget.node.dialogueOpening ?? '¡Hola!',
    ),
  ];
  bool _sending = false;
  bool _listening = false;
  bool _voiceAvailable = false;
  bool _showTyping = false;
  int _hintsUsed = 0;
  String? _hintText;

  // Step 5: challenge.
  Assessment? _challengeResult;

  // Step 6: results.
  bool _completed = false;
  int _earnedStars = 0;
  int _earnedXp = 0;
  double _pronAvg = 0;
  int _revealedStars = 0;

  LevelNode get _node => widget.node;

  /// False for nodes whose teaching content has not been written yet
  /// (branch/hidden/W3+ nodes): show the "in production" card instead.
  bool get _hasContent =>
      _node.words.isNotEmpty &&
      _node.sentences.isNotEmpty &&
      _node.dialogueOpening != null;

  int get _roundsTarget => _node.rounds ?? 4;

  int get _userTurns => _messages.where((m) => m.fromUser).length;

  bool get _dialogueDone => _userTurns >= _roundsTarget;

  int get _shadowNeeded => neededShadowPasses(_node.sentences.length);

  int get _shadowPassed => _shadowResults
      .where((r) => r != null && r.accuracy >= _node.passGop)
      .length;

  bool get _challengePassed =>
      _challengeResult != null &&
      _challengeResult!.accuracy >= _node.passGop;

  bool get _challengeExcellent =>
      _challengeResult != null &&
      _challengeResult!.accuracy >= challengeExcellentGop;

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final available = await _voice.init();
    if (!mounted) return;
    setState(() => _voiceAvailable = available);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _voice.cancel();
    _input.dispose();
    _scroll.dispose();
    _speaker.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Navigation between steps.
  // ------------------------------------------------------------------

  void _goToStep(int step) {
    if (_recPhase != _RecPhase.idle || _sending) return;
    setState(() {
      _step = step;
      _error = null;
    });
    if (step == 5) _finish();
  }

  /// Runs once when the results step opens: scores the level, stores the
  /// stars + XP (and unlocks the next level) via ProgressStore.
  Future<void> _finish() async {
    if (_completed) return;
    final scores = [
      for (final r in _shadowResults) r?.accuracy,
      _challengeResult?.accuracy,
    ];
    final avg = pronunciationAverage(scores);
    final stars = computeStars(
      dialogueDone: true,
      challengePassed: true,
      challengeExcellent: _challengeExcellent,
      pronunciationAvg: avg,
      passGop: _node.passGop,
    );
    final firstTime = !widget.progress.isCompleted(_node.id);
    final reward = LevelRewards.forKind(_node.kind);
    setState(() {
      _completed = true;
      _earnedStars = stars;
      _earnedXp = firstTime ? reward : reward ~/ 2;
      _pronAvg = avg;
    });
    await widget.progress.completeLevel(_node, widget.graph, stars: stars);
    for (var i = 1; i <= stars; i++) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _revealedStars = i);
    }
  }

  // ------------------------------------------------------------------
  // Recording + scoring (shared by steps 2, 3 and 5).
  // ------------------------------------------------------------------

  Future<void> _startRecording(
    ({String kind, int index}) target,
    Future<void> Function(String path) onDone,
  ) async {
    if (_recPhase != _RecPhase.idle) return;
    if (!await _recorder.hasPermission) {
      setState(() => _error = '需要麦克风权限才能录音，请在系统设置里允许');
      return;
    }
    await _speaker.stop();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}${Platform.pathSeparator}speakmind_level.wav';
    try {
      await _recorder.start(path);
    } catch (e) {
      setState(() => _error = '无法开始录音：$e');
      return;
    }
    if (!mounted) return;
    _onRecordDone = onDone;
    _recTarget = target;
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final seconds = DateTime.now().difference(_startedAt!).inSeconds;
      if (seconds >= _maxSeconds) {
        _stopRecording();
      } else if (seconds != _elapsed) {
        setState(() => _elapsed = seconds);
      }
    });
    setState(() {
      _recPhase = _RecPhase.recording;
      _elapsed = 0;
      _error = null;
    });
  }

  Future<void> _stopRecording() async {
    if (_recPhase != _RecPhase.recording) return;
    _ticker?.cancel();
    setState(() => _recPhase = _RecPhase.scoring);
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    final done = _onRecordDone;
    _onRecordDone = null;
    if (path == null || done == null) {
      if (mounted) {
        setState(() {
          _error = '录音失败，请再试一次';
          _recPhase = _RecPhase.idle;
          _recTarget = null;
        });
      }
      return;
    }
    await done(path);
    if (mounted) {
      setState(() {
        _recPhase = _RecPhase.idle;
        _recTarget = null;
      });
    }
  }

  /// Scores a recording against [text]; null (with [_error] set) on failure.
  Future<Assessment?> _assess(String path, String text) async {
    try {
      return await ApiClient(widget.settings.serverUrl)
          .assess(audioPath: path, text: text, language: 'es');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Step 2: warm-up (light assess, marks the card done, no grading).
  // ------------------------------------------------------------------

  Future<void> _recordWord(int i) async {
    if (_recPhase != _RecPhase.idle) return;
    final gloss = splitGloss(_node.words[i]);
    await _startRecording((kind: 'word', index: i), (path) async {
      final result = await _assess(path, gloss.es);
      if (!mounted || result == null) return;
      setState(() {
        _wordDone.add(i);
        _wordScores[i] = result.accuracy;
      });
    });
  }

  // ------------------------------------------------------------------
  // Step 3: shadowing.
  // ------------------------------------------------------------------

  Future<void> _recordSentence(int i) async {
    if (_recPhase != _RecPhase.idle) return;
    final gloss = splitGloss(_node.sentences[i]);
    await _startRecording((kind: 'sentence', index: i), (path) async {
      final result = await _assess(path, gloss.es);
      if (!mounted || result == null) return;
      setState(() {
        _shadowResults[i] = result;
        _shadowSelected[i] = _weakestWord(result);
      });
    });
  }

  /// The lowest-scoring word that is not already good, so the user sees
  /// straight away what to work on.
  static int? _weakestWord(Assessment result) {
    int? weakest;
    for (final (i, word) in result.words.indexed) {
      final score = word.score;
      if (score == null || word.level == Level.good) continue;
      if (weakest == null || score < result.words[weakest].score!) {
        weakest = i;
      }
    }
    return weakest;
  }

  /// Index of the lowest-scored shadow sentence, for the results screen.
  int? _weakestSentenceIndex() {
    int? weakest;
    for (var i = 0; i < _shadowResults.length; i++) {
      final score = _shadowResults[i]?.accuracy;
      if (score == null) continue;
      if (weakest == null || score < _shadowResults[weakest]!.accuracy) {
        weakest = i;
      }
    }
    return weakest;
  }

  // ------------------------------------------------------------------
  // Step 4: dialogue.
  // ------------------------------------------------------------------

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _hintText = null;
      _showTyping = false;
    });
    await _requestReply();
  }

  Future<void> _requestReply() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    _scrollToEnd();
    try {
      final reply = await ApiClient(widget.settings.serverUrl).chat(
        messages: _messages,
        language: 'es',
        levelId: _node.id,
        npcPrompt: _node.npcPrompt,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: reply.reply,
            tip: reply.tip,
          ),
        );
        _sending = false;
      });
      // The user may have left the page while the reply was on its way.
      try {
        await _speaker.speak(reply.reply, _spanish);
      } catch (_) {
        // Playback was interrupted (e.g. page disposed): safe to ignore.
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _sending = false;
      });
    }
    _scrollToEnd();
  }

  /// Mic toggle: start listening, or stop and keep the transcript in the
  /// input field for the user to correct before sending.
  Future<void> _toggleVoice() async {
    if (_sending) return;
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_voiceAvailable) {
      setState(() => _error = '这台设备不支持语音识别，请直接打字');
      return;
    }
    await _speaker.stop();
    final started = await _voice.start(
      localeId: 'es_ES',
      onResult: (text, _) {
        if (!mounted) return;
        _input.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        if (!_showTyping) setState(() => _showTyping = true);
      },
    );
    if (!mounted) return;
    setState(() {
      _listening = started;
      if (started) _error = null;
      if (!started) _error = '没能开始语音识别，请再试一次';
    });
  }

  /// Shows the next core sentence as a full-sentence suggestion (W1-W2
  /// hints are unlimited; the count is shown, not capped).
  void _showHint() {
    final sentences = _node.sentences;
    if (sentences.isEmpty) return;
    final gloss = splitGloss(sentences[_hintsUsed % sentences.length]);
    setState(() {
      _hintText = gloss.es;
      _hintsUsed++;
      _showTyping = true;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ------------------------------------------------------------------
  // Step 5: challenge.
  // ------------------------------------------------------------------

  Future<void> _recordChallenge() async {
    if (_recPhase != _RecPhase.idle) return;
    final gloss = splitGloss(_node.challengeSentence ?? '');
    if (gloss.es.isEmpty) return;
    await _startRecording((kind: 'challenge', index: 0), (path) async {
      final result = await _assess(path, gloss.es);
      if (!mounted || result == null) return;
      setState(() => _challengeResult = result);
    });
  }

  Future<void> _playText(String text) async {
    await _speaker.stop();
    await _speaker.speak(text, _spanish);
  }

  Future<void> _playOpening() async {
    if (_playingOpening) return;
    setState(() => _playingOpening = true);
    try {
      await _playText(_node.dialogueOpening ?? '¡Hola!');
    } finally {
      if (mounted) setState(() => _playingOpening = false);
    }
  }

  // ------------------------------------------------------------------
  // Build.
  // ------------------------------------------------------------------

  String get _kindLabel => switch (_node.kind) {
        LevelKind.main => '主线',
        LevelKind.branch => '分支',
        LevelKind.hidden => '隐藏',
      };

  @override
  Widget build(BuildContext context) {
    final world = widget.graph.worldById(_node.world);
    // Nodes whose teaching content has not been written yet (branch nodes
    // unlocked by finishing 2-5, hidden nodes, W3+): show the "in
    // production" card instead of a dead-end level flow.
    if (!_hasContent) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${_node.id} ${_node.title}'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Chip(label: Text(_kindLabel)),
                const SizedBox(width: 8),
                Chip(label: Text('W${_node.world} ${world.nameZh}')),
                const SizedBox(width: 8),
                Chip(label: Text(_node.cefr)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _node.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: SpeakMindColors.ink,
              ),
            ),
            Text(
              _node.titleZh,
              style: const TextStyle(fontSize: 17, color: SpeakMindColors.ink),
            ),
            const SizedBox(height: 16),
            const Card(
              color: Color(0xFFFFF3D6),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '本关内容还在制作中：单词、句型、NPC 对话与挑战任务都还是空的。'
                  '分支关内容在 F2 填，W3 以后的世界在 F2–F3 填。先回去打主线吧。',
                  style: TextStyle(color: SpeakMindColors.ink),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('回地图'),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${_node.id} ${_node.title}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${levelSteps[_step]} · 第 ${_step + 1} 步 / 共 6 步',
              style: const TextStyle(fontSize: 12, color: SpeakMindColors.fog),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: switch (_step) {
                  0 => _buildIntro(world.nameZh),
                  1 => _buildWarmUp(),
                  2 => _buildShadowing(),
                  3 => _buildDialogue(),
                  4 => _buildChallenge(),
                  _ => _buildResults(),
                },
              ),
            ),
            if (_step < 5) _buildNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(String worldNameZh) {
    final opening = _node.dialogueOpening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Chip(label: Text(_kindLabel)),
            const SizedBox(width: 8),
            Chip(label: Text('W${_node.world} $worldNameZh')),
            const SizedBox(width: 8),
            Chip(label: Text(_node.cefr)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _node.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: SpeakMindColors.ink,
          ),
        ),
        Text(
          _node.titleZh,
          style: const TextStyle(fontSize: 17, color: SpeakMindColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          _node.scene ?? '',
          style: const TextStyle(color: SpeakMindColors.fog),
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFFFF3D6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🐉 Brasa 说',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _node.intro ?? '',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        if (opening != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NPC 开场白（先听一遍）',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(opening, style: const TextStyle(fontSize: 17, height: 1.4)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _playingOpening ? null : _playOpening,
                    icon: _playingOpening
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_up_outlined),
                    label: const Text('听 NPC 说'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '发音过关线：GOP ${_node.passGop} 分 · 已得星星：'
          '${'★' * widget.progress.stars(_node.id)}'
          '${'☆' * (3 - widget.progress.stars(_node.id))}',
          style: const TextStyle(color: SpeakMindColors.fog),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
      ],
    );
  }

  Widget _buildWarmUp() {
    final done = _wordDone.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '先认认本关的单词：点麦克风读一遍，读过就打勾，不评分。',
          style: TextStyle(color: SpeakMindColors.fog),
        ),
        const SizedBox(height: 4),
        Text(
          '已读 $done / ${_node.words.length} 个',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _node.words.length; i++) ...[
          _WordCard(
            gloss: splitGloss(_node.words[i]),
            done: _wordDone.contains(i),
            score: _wordScores[i],
            recording:
                _recTarget?.kind == 'word' && _recTarget?.index == i,
            phase: _recPhase,
            elapsed: _elapsed,
            onMic: _recPhase == _RecPhase.idle
                ? () => _recordWord(i)
                : _recTarget?.kind == 'word' && _recTarget?.index == i
                    ? _stopRecording
                    : null,
            onPlay: () => _playText(splitGloss(_node.words[i]).es),
          ),
          const SizedBox(height: 10),
        ],
        if (_node.keySounds.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final sound in _node.keySounds)
                Chip(label: Text('发音重点：$sound')),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
      ],
    );
  }

  Widget _buildShadowing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '跟读本关的 ${_node.sentences.length} 句核心句：$_shadowPassed / $_shadowNeeded 句达到 '
          'GOP ${_node.passGop} 分就能过关。点麦克风读，读完点停止。',
          style: const TextStyle(color: SpeakMindColors.fog),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _node.sentences.length; i++) ...[
          _SentenceCard(
            gloss: splitGloss(_node.sentences[i]),
            result: _shadowResults[i],
            selectedWord: _shadowSelected[i],
            onSelectWord: (w) => setState(() => _shadowSelected[i] = w),
            recording:
                _recTarget?.kind == 'sentence' && _recTarget?.index == i,
            phase: _recPhase,
            elapsed: _elapsed,
            passGop: _node.passGop,
            onMic: _recPhase == _RecPhase.idle
                ? () => _recordSentence(i)
                : _recTarget?.kind == 'sentence' && _recTarget?.index == i
                    ? _stopRecording
                    : null,
            onPlay: () => _playText(splitGloss(_node.sentences[i]).es),
          ),
          const SizedBox(height: 14),
        ],
        if (_error != null) ...[
          const SizedBox(height: 4),
          _ErrorBox(message: _error!),
        ],
      ],
    );
  }

  Widget _buildDialogue() {
    final done = _dialogueDone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '任务：${_node.task ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('已说 $_userTurns / $_roundsTarget 轮 · 提示用了 $_hintsUsed 次（本世界不限次数）'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final message in _messages)
          _DialogueBubble(
            message: message,
            onSpeak: message.fromUser
                ? null
                : () => _playText(message.content),
          ),
        if (_sending)
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        if (_hintText != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hintText!,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        _input.text = _hintText!;
                        setState(() => _hintText = null);
                      },
                      child: const Text('填入输入框'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _hintText = null),
                      child: const Text('不用了'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_listening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('正在听… 说完点麦克风停止，可改一下再发送')),
                ],
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _ErrorBox(
            message: _error!,
            onRetry: _messages.isNotEmpty && _messages.last.fromUser
                ? _requestReply
                : null,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton.icon(
              onPressed: _sending ? null : _showHint,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('给一句提示'),
            ),
            TextButton(
              onPressed: _sending
                  ? null
                  : () => setState(() => _showTyping = !_showTyping),
              child: Text(_showTyping ? '收起打字' : '打字'),
            ),
            const Spacer(),
            if (done)
              const Chip(
                label: Text('✓ 轮数够了，可以下一步'),
                backgroundColor: Color(0xFFDFF3DF),
              ),
          ],
        ),
        if (_showTyping)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 300,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Escribe en español…',
                    border: OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: '发送',
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _sending ? null : _toggleVoice,
              icon: Icon(
                _listening ? Icons.stop_rounded : Icons.mic,
                color: _listening ? Theme.of(context).colorScheme.error : null,
              ),
              label: Text(_listening ? '停止，说完了' : '语音输入'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _sending ? null : _send,
              child: const Text('发送'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChallenge() {
    final gloss = splitGloss(_node.challengeSentence ?? '');
    final result = _challengeResult;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '变式挑战：换个说法再说一遍，录音评分。',
          style: TextStyle(color: SpeakMindColors.fog),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFFFF3D6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _node.challengePrompt ?? '',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  gloss.es,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                Text(
                  gloss.zh,
                  style: const TextStyle(color: SpeakMindColors.fog),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _playText(gloss.es),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('听示范'),
                    ),
                    const SizedBox(width: 8),
                    _MicButton(
                      recording:
                          _recTarget?.kind == 'challenge',
                      phase: _recPhase,
                      elapsed: _elapsed,
                      onTap: _recPhase == _RecPhase.idle
                          ? _recordChallenge
                          : _recTarget?.kind == 'challenge'
                              ? _stopRecording
                              : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 16),
          ResultView(
            result: result,
            selectedWord: _weakestWord(result),
            onSelectWord: (_) {},
          ),
          const SizedBox(height: 8),
          Text(
            _challengePassed
                ? _challengeExcellent
                    ? '🎉 出色！这句发音 ${result.accuracy} 分，够拿 3 星了。'
                    : '✓ 过关！这句发音 ${result.accuracy} 分，达到 GOP ${_node.passGop} 分。'
                : '这句发音 ${result.accuracy} 分，还没到 GOP ${_node.passGop} 分，再读一次。',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 8),
        Text(
          '评分标准：${_node.taskRubric ?? ''}',
          style: const TextStyle(color: SpeakMindColors.fog),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final weakest = _weakestSentenceIndex();
    final next = widget.graph.nextOf(_node);
    final nextUnlocked = next != null && widget.progress.isUnlocked(next.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  i < _revealedStars ? Icons.star : Icons.star_border,
                  size: 56,
                  color: i < _revealedStars
                      ? SpeakMindColors.amber
                      : SpeakMindColors.fog,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '¡Felicidades! 通关 ${_node.id} ${_node.titleZh}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '发音平均 ${_pronAvg.toStringAsFixed(0)} 分（过关线 GOP ${_node.passGop} 分）'
          ' · +$_earnedXp XP',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SpeakMindColors.fog),
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFFFF3D6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              brasaComment(_earnedStars),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ),
        if (weakest != null) ...[
          const SizedBox(height: 16),
          const Text('最弱的一句，再听听示范：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            splitGloss(_node.sentences[weakest]).es,
            style: const TextStyle(fontSize: 17, height: 1.4),
          ),
          Text(
            splitGloss(_node.sentences[weakest]).zh,
            style: const TextStyle(color: SpeakMindColors.fog),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                _playText(splitGloss(_node.sentences[weakest]).es),
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('听示范'),
          ),
        ],
        const SizedBox(height: 24),
        if (nextUnlocked)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => LevelPage(
                  node: next,
                  graph: widget.graph,
                  progress: widget.progress,
                  settings: widget.settings,
                ),
              ),
            ),
            child: Text('下一关：${next.id} ${next.title}'),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => LevelPage(
                node: _node,
                graph: widget.graph,
                progress: widget.progress,
                settings: widget.settings,
              ),
            ),
          ),
          child: const Text('重打本关'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('回地图'),
        ),
      ],
    );
  }

  Widget _buildNavBar() {
    final busy = _recPhase != _RecPhase.idle || _sending;
    final canNext = switch (_step) {
      0 => true,
      1 => _wordDone.length == _node.words.length,
      2 => _shadowPassed >= _shadowNeeded,
      3 => _dialogueDone,
      4 => _challengePassed,
      _ => false,
    };
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: busy ? null : () => _goToStep(_step - 1),
              child: const Text('← 上一步'),
            )
          else
            const Spacer(),
          const Spacer(),
          if (_step == 1)
            TextButton(
              onPressed: busy ? null : () => _goToStep(2),
              child: const Text('跳过热身'),
            ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: busy || !canNext ? null : () => _goToStep(_step + 1),
            child: Text(switch (_step) {
              3 => '去挑战 →',
              4 => '完成挑战 →',
              _ => '下一步 →',
            }),
          ),
        ],
      ),
    );
  }
}

/// Error box with an optional retry button.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

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
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

/// Round record button: mic when idle, stop while recording, a spinner
/// while the take is being scored. Shows the elapsed seconds under it.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.recording,
    required this.phase,
    required this.elapsed,
    required this.onTap,
  });

  /// True when this button's item is the one being recorded/scored.
  final bool recording;
  final _RecPhase phase;
  final int elapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = recording && phase != _RecPhase.idle;
    final color = active ? scheme.error : scheme.primary;
    final iconColor =
        onTap == null ? scheme.onSurfaceVariant : scheme.onPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 56,
          child: Material(
            color:
                onTap == null ? scheme.surfaceContainerHighest : color,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: phase == _RecPhase.scoring && recording
                    ? SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(
                        active ? Icons.stop_rounded : Icons.mic,
                        size: 28,
                        color: iconColor,
                        semanticLabel: active ? '停止录音' : '开始录音',
                      ),
              ),
            ),
          ),
        ),
        if (active && phase == _RecPhase.recording)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('$elapsed 秒'),
          ),
      ],
    );
  }
}

/// One warm-up word: Spanish + Chinese gloss, listen + record, done tick.
class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.gloss,
    required this.done,
    required this.score,
    required this.recording,
    required this.phase,
    required this.elapsed,
    required this.onMic,
    required this.onPlay,
  });

  final ({String es, String zh}) gloss;
  final bool done;
  final int? score;
  final bool recording;
  final _RecPhase phase;
  final int elapsed;
  final VoidCallback? onMic;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: done ? const Color(0xFFDFF3DF) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gloss.es,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    gloss.zh,
                    style: const TextStyle(color: SpeakMindColors.fog),
                  ),
                  if (done)
                    Text(
                      '✓ 已读${score == null ? '' : ' · $score 分'}',
                      style: const TextStyle(color: SpeakMindColors.actionGreen),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: '听示范',
              onPressed: onPlay,
              icon: const Icon(Icons.volume_up_outlined),
            ),
            _MicButton(
              recording: recording,
              phase: phase,
              elapsed: elapsed,
              onTap: onMic,
            ),
          ],
        ),
      ),
    );
  }
}

/// One shadowing sentence: text + gloss, listen + record, and the score
/// breakdown (ResultView) once it has been scored.
class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.gloss,
    required this.result,
    required this.selectedWord,
    required this.onSelectWord,
    required this.recording,
    required this.phase,
    required this.elapsed,
    required this.passGop,
    required this.onMic,
    required this.onPlay,
  });

  final ({String es, String zh}) gloss;
  final Assessment? result;
  final int? selectedWord;
  final ValueChanged<int> onSelectWord;
  final bool recording;
  final _RecPhase phase;
  final int elapsed;
  final int passGop;
  final VoidCallback? onMic;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final passed = result != null && result.accuracy >= passGop;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gloss.es,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            Text(
              gloss.zh,
              style: const TextStyle(color: SpeakMindColors.fog),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('听示范'),
                ),
                const SizedBox(width: 8),
                _MicButton(
                  recording: recording,
                  phase: phase,
                  elapsed: elapsed,
                  onTap: onMic,
                ),
                if (result != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      passed
                          ? '✓ ${result.accuracy} 分，过关'
                          : '${result.accuracy} 分，未到 $passGop 分',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: passed
                            ? SpeakMindColors.actionGreen
                            : SpeakMindColors.terracotta,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              ResultView(
                result: result,
                selectedWord: selectedWord,
                onSelectWord: onSelectWord,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One dialogue turn: user on the right, NPC on the left, with a speak
/// button on NPC lines and the server's tip (when there is one).
class _DialogueBubble extends StatelessWidget {
  const _DialogueBubble({required this.message, required this.onSpeak});

  final ChatMessage message;

  /// Reads the message aloud; null for the user's own messages.
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.fromUser;
    final tip = message.tip;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: mine
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SelectableText(
                        message.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: mine
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (onSpeak != null) ...[
                      const SizedBox(width: 6),
                      InkResponse(
                        onTap: onSpeak,
                        radius: 18,
                        child: Icon(
                          Icons.volume_up_outlined,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                          semanticLabel: '朗读',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (tip != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: scheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            tip,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
