import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'press_scale.dart';

/// Primary gradient CTA button with brand shadow and press feedback.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool enabled;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.enabled = true,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading && onPressed != null;
    return Opacity(
      opacity: active ? 1 : 0.5,
      child: PressScale(
        onTap: active ? onPressed : null,
        semanticLabel: label,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: brandGradient(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: active ? AppShadows.button : null,
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Text(label,
                        style: AppText.bodyLarge.copyWith(color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Outlined / ghost variant used for secondary actions.
class OutlineButton2 extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final Color? color;

  const OutlineButton2({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.c.primary;
    return PressScale(
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.45), width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: c, size: 20),
              const SizedBox(width: 10),
            ],
            Text(label, style: AppText.bodyLarge.copyWith(color: c)),
          ],
        ),
      ),
    );
  }
}
