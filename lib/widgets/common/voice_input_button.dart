import 'package:flutter/material.dart';

import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';

/// A mic button that dictates speech into [controller]. Tap once to start
/// listening (appends to whatever text is already there), tap again to stop.
class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;
  final double size;
  const VoiceInputButton({super.key, required this.controller, this.size = 38});

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  bool _listening = false;
  String _baseText = '';

  @override
  void dispose() {
    if (_listening) VoiceService.instance.stopListening();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await VoiceService.instance.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }

    _baseText = widget.controller.text;
    final started = await VoiceService.instance.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        final combined = _baseText.isEmpty ? text : '$_baseText $text';
        widget.controller.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length),
        );
        if (isFinal) {
          _baseText = combined;
          setState(() => _listening = false);
        }
      },
    );
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone unavailable. Check permissions.')),
      );
      return;
    }
    setState(() => _listening = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _listening ? c.danger.withValues(alpha: 0.12) : c.bg,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
          size: widget.size * 0.55,
          color: _listening ? c.danger : c.text2,
        ),
      ),
    );
  }
}
