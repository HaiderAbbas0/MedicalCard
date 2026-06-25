import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'press_scale.dart';

/// "Title ............ See all" row used above list sections.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: AppText.title.copyWith(color: context.c.text)),
        ),
        if (actionLabel != null)
          PressScale(
            onTap: onAction,
            semanticLabel: actionLabel,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(actionLabel!,
                  style: AppText.caption.copyWith(
                      color: context.c.primary, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}
