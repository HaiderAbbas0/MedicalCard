import 'package:flutter/material.dart';

import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';

/// A small speaker button that reads [text] aloud via text-to-speech.
class SpeakButton extends StatefulWidget {
  final String text;
  final double size;
  const SpeakButton({super.key, required this.text, this.size = 30});

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  bool _speaking = false;

  Future<void> _toggle() async {
    if (_speaking) {
      await VoiceService.instance.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await VoiceService.instance.speak(widget.text);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: widget.text.trim().isEmpty ? null : _toggle,
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        child: Icon(
          _speaking ? Icons.volume_up_rounded : Icons.volume_up_outlined,
          size: widget.size * 0.6,
          color: _speaking ? c.primary : c.text3,
        ),
      ),
    );
  }
}
