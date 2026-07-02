import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';

/// Branded gradient app bar for the doctor / lab / receptionist home screens.
/// Shows the role title, the signed-in user's name, and a sign-out action.
class RoleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const RoleAppBar({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 70,
      flexibleSpace: Container(decoration: BoxDecoration(gradient: brandGradient(context))),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
          Text(
            subtitle ?? (auth.currentUser?.name ?? ''),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        ...actions,
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () async {
            await context.read<AuthController>().logout();
            if (context.mounted) context.go('/login');
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}
