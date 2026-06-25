import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'press_scale.dart';

/// Standard back-arrow + title header used by detail screens.
class ScreenHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;

  const ScreenHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          if (showBack)
            HeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack ??
                  () => context.canPop() ? context.pop() : context.go('/dashboard'),
            ),
          if (showBack) const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: AppText.heading.copyWith(color: context.c.text),
                overflow: TextOverflow.ellipsis),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Circular surface icon button for headers.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? semanticLabel;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.c.border),
        ),
        child: Icon(icon, size: 19, color: color ?? context.c.text),
      ),
    );
  }
}
