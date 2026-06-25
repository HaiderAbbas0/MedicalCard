import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Rounded-square tinted icon badge (mint background by default).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;
  final double radius;

  const IconBadge({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 44,
    this.radius = 13,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.c.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}
