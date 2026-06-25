import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'press_scale.dart';

/// 2×2 dashboard quick-stat card (dot + value + label).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color dotColor;
  final IconData icon;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.dotColor,
    required this.icon,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: '$label $value',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const Spacer(),
                Icon(icon, size: 18, color: c.text3),
              ],
            ),
            const SizedBox(height: 14),
            Text(value,
                style: AppText.display.copyWith(color: c.text, fontSize: 24)),
            const SizedBox(height: 2),
            Text(label,
                style: AppText.caption.copyWith(color: c.text2)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  style: AppText.small.copyWith(color: c.text3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
