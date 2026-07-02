import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'role_app_bar.dart';

/// Admins are served by the React web portal, not the mobile app (Scope §2.1).
class AdminNoticeScreen extends StatelessWidget {
  const AdminNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const RoleAppBar(title: 'Administrator'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.desktop_windows_outlined, size: 56, color: c.primary),
              const SizedBox(height: 16),
              Text('Admin portal is web-based',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                'System administrators manage approvals, users, and clinics from the React web portal. Please sign in there from a browser.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text2, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
