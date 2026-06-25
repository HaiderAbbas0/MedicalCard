import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';

/// Small rounded status pill (Active / Normal / Abnormal …).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 10 : 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: AppText.small.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// Removable chip used for allergies etc.
class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onRemove;

  const TagChip(
      {super.key, required this.label, required this.color, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 7, onRemove == null ? 12 : 7, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: AppText.caption
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
          if (onRemove != null) ...[
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close_rounded, size: 15, color: color),
            ),
          ],
        ],
      ),
    );
  }
}
