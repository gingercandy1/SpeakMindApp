/// RPG-style typewriter text: reveals [text] character by character;
/// tap to show it all at once. Restarts when the text changes (the caller
/// keys it by content).
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

class TypewriterText extends StatefulWidget {
  const TypewriterText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<TypewriterText> createState() => TypewriterTextState();
}

class TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  void _start() {
    _timer?.cancel();
    _shown = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      if (!mounted) return;
      setState(() {
        _shown++;
        if (_shown >= widget.text.characters.length) timer.cancel();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A Listener (not a GestureDetector): SelectableText owns the tap
    // gesture for selection, so a tap recogniser here would lose the
    // arena and never fire.
    return Listener(
      onPointerUp: (_) => setState(() {
        _timer?.cancel();
        _shown = widget.text.characters.length;
      }),
      child: SelectableText(
        widget.text.characters.take(_shown).toString(),
        style: widget.style,
      ),
    );
  }
}
