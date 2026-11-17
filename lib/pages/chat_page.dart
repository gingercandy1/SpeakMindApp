import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../models.dart';
import '../settings.dart';
import '../speech.dart';
import '../voice_input.dart';

/// Free conversation with an AI partner in the language being practised.
///
/// The server holds the AI key and the prompt; the app sends the history.
/// Voice input uses the phone's own speech recognition (see
/// `lib/voice_input.dart`): tap the mic, speak, tap stop, correct the
/// transcript if needed, then send. The reply is still read aloud with
/// the server's Piper voice when one is available.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// Fixed for the life of the page: switching language starts a new chat.
  late final AppLanguage _language = widget.settings.language;
  late final Speaker _speaker = Speaker(widget.settings);
  final _voice = VoiceInput();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late final List<ChatMessage> _messages = [
    ChatMessage(
      role: 'assistant',
      content: _language.code == 'es'
          ? '¡Hola! Vamos a conversar. ¿Qué hiciste hoy?'
          : "Hi! Let's chat. What did you do today?",
    ),
  ];
  bool _sending = false;
  bool _autoSpeak = true;
  bool _listening = false;
  bool _voiceAvailable = false;
  String? _error;

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
    _voice.cancel();
    _input.dispose();
    _scroll.dispose();
    _speaker.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() => _messages.add(ChatMessage(role: 'user', content: text)));
    await _requestReply();
  }

  /// Asks for the partner's answer to the conversation so far.
  Future<void> _requestReply() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    _scrollToEnd();
    try {
      final reply = await ApiClient(widget.settings.serverUrl)
          .chat(messages: _messages, language: _language.code);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply.reply, tip: reply.tip));
        _sending = false;
      });
      if (_autoSpeak) _speaker.speak(reply.reply, _language);
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
    // Stop the partner's voice first, so it is not picked up as input.
    await _speaker.stop();
    final started = await _voice.start(
      localeId: _language.code == 'es' ? 'es_ES' : 'en_US',
      onResult: (text, _) {
        if (!mounted) return;
        // Keep the caret at the end while the transcript grows.
        _input.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _listening = started;
      if (started) _error = null;
      if (!started) _error = '没能开始语音识别，请再试一次';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;
    final canRetry = error != null && _messages.last.fromUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_language.name}聊天'),
        actions: [
          IconButton(
            tooltip: _autoSpeak ? '自动朗读：开' : '自动朗读：关',
            onPressed: () {
              if (_autoSpeak) _speaker.stop();
              setState(() => _autoSpeak = !_autoSpeak);
            },
            icon: Icon(_autoSpeak ? Icons.volume_up_outlined : Icons.volume_off_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _Typing();
                  final message = _messages[i];
                  return _Bubble(
                    message: message,
                    onSpeak: message.fromUser ? null : () => _speaker.speak(message.content, _language),
                  );
                },
              ),
            ),
            if (_listening)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '正在听… 说完点麦克风停止，可改一下再发送',
                          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                      if (canRetry)
                        TextButton(
                          onPressed: _sending ? null : _requestReply,
                          child: const Text('重试'),
                        ),
                    ],
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _language.code == 'es' ? 'Escribe en español…' : 'Type in English…',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: _listening ? '停止语音' : '语音输入',
                    onPressed: _sending ? null : _toggleVoice,
                    icon: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic,
                      color: _listening ? theme.colorScheme.error : null,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onSpeak});

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
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
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
                          color: mine ? scheme.onPrimaryContainer : scheme.onSurface,
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
                        Icon(Icons.lightbulb_outline, size: 18, color: scheme.onTertiaryContainer),
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

/// "Partner is typing" placeholder while the reply is on its way.
class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
