import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Gradient circle avatar showing initials.
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool ring;
  final List<Color>? gradient;

  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.ring = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient ?? context.c.brandGradient,
        ),
      ),
      child: Text(
        initials,
        style: AppText.title.copyWith(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (!ring) return inner;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: context.c.brandGradient),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: context.c.surface),
        child: inner,
      ),
    );
  }
}
