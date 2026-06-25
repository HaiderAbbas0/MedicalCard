import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Six-box OTP input. Drive it via a [GlobalKey] to [shake] or [clear].
class OtpField extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpField({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpField> createState() => OtpFieldState();
}

class OtpFieldState extends State<OtpField>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void shake() {
    _shake.forward(from: 0);
  }

  void clear() {
    _ctrl.clear();
    setState(() {});
  }

  void _onChanged(String v) {
    setState(() {});
    widget.onChanged?.call(v);
    if (v.length == widget.length) widget.onCompleted?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final dx = _shake.isAnimating
            ? 8 *
                (1 - _shake.value) *
                ((_shake.value * 6).floor().isEven ? 1 : -1)
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < widget.length; i++)
                  _box(context, i, text),
              ],
            ),
            // Invisible field capturing the actual input.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  showCursor: false,
                  onChanged: _onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(BuildContext context, int i, String text) {
    final c = context.c;
    final filled = i < text.length;
    final isCurrent = i == text.length && _focus.hasFocus;
    return AnimatedScale(
      scale: filled ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 50,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled || isCurrent ? c.primary : c.border,
            width: filled || isCurrent ? 1.8 : 1.2,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                      color: c.primary.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Text(
          filled ? text[i] : '',
          style: AppText.heading.copyWith(color: c.text, fontSize: 24),
        ),
      ),
    );
  }
}
