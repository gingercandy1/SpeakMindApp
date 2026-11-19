import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The hero microphone button (doc p.11): 72 diameter, the biggest button
/// in the app, always at the bottom centre of a conversation page.
///
/// Tap to start listening, tap again to stop; the transcript stays in the
/// input field for the user to correct before sending.
class HeroMic extends StatelessWidget {
  const HeroMic({
    super.key,
    required this.listening,
    required this.onPressed,
    this.enabled = true,
  });

  final bool listening;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: listening ? '停止语音' : '语音输入',
      child: SizedBox.square(
        dimension: 72,
        child: Material(
          color: listening ? SpeakMindColors.terracotta : SpeakMindColors.actionGreen,
          shape: const CircleBorder(
            side: BorderSide(color: SpeakMindColors.ink, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Icon(
              listening ? Icons.stop_rounded : Icons.mic,
              size: 34,
              color: listening ? scheme.onError : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
