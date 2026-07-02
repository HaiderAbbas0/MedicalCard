import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Branded gradient app bar with a white back button, for pushed/detail screens.
/// Drop-in replacement for a plain [AppBar].
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  const BrandAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      automaticallyImplyLeading: showBack,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: Container(decoration: BoxDecoration(gradient: brandGradient(context))),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          if (subtitle != null)
            Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ],
      ),
      actions: actions,
    );
  }
}
