import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLogoutSheet(BuildContext context) {
    final c = context.c;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.dangerBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.logout_rounded, size: 26, color: c.danger),
                ),
                const SizedBox(height: 16),
                Text('Log out?',
                    style: AppText.display.copyWith(fontSize: 20, color: c.text)),
                const SizedBox(height: 8),
                Text(
                  "You'll need your email or phone and password to sign back in.",
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(fontSize: 14, color: c.text2),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlineButton2(
                        label: 'Cancel',
                        height: 52,
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PressScale(
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await context.read<AuthProvider>().signOut();
                          if (context.mounted) context.go('/login');
                        },
                        semanticLabel: 'Log out',
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.danger,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('Log out',
                              style: AppText.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isUrdu = context.watch<LanguageProvider>().isUrdu;
    final isDark = context.watch<ThemeProvider>().isDark(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          children: [
            Row(
              children: [
                PressScale(
                  onTap: () => context.pop(),
                  semanticLabel: 'Back',
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.chevron_left_rounded,
                        size: 24, color: c.text),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Settings',
                    style:
                        AppText.display.copyWith(fontSize: 22, color: c.text)),
              ],
            ),
            const SizedBox(height: 24),
            // ── Preferences ──────────────────────────────────────────────
            const _SectionLabel('PREFERENCES'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  PressScale(
                    onTap: () => context.read<LanguageProvider>().setLanguage(
                        isUrdu ? AppLanguage.english : AppLanguage.urdu),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Language',
                                style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w600, color: c.text)),
                          ),
                          Text(isUrdu ? 'اردو' : 'English',
                              style: AppText.caption.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary)),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: c.border2),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Appearance',
                              style: AppText.body.copyWith(
                                  fontWeight: FontWeight.w600, color: c.text)),
                        ),
                        _TogglePill(
                          on: isDark,
                          onTap: () =>
                              context.read<ThemeProvider>().toggleDark(!isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // ── Security & Privacy ───────────────────────────────────────
            const _SectionLabel('SECURITY & PRIVACY'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _NavRow(
                    label: 'Change password',
                    onTap: () => _snack(context, 'Coming soon'),
                  ),
                  Divider(height: 1, color: c.border2),
                  _NavRow(
                    label: 'Login & security',
                    onTap: () => _snack(context, 'Coming soon'),
                  ),
                  Divider(height: 1, color: c.border2),
                  _NavRow(
                    label: 'Consent management',
                    onTap: () => _snack(context, 'Coming soon'),
                  ),
                  Divider(height: 1, color: c.border2),
                  _NavRow(
                    label: 'Help & support',
                    onTap: () => _snack(context, 'Coming soon'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // ── Log out ──────────────────────────────────────────────────
            PressScale(
              onTap: () => _showLogoutSheet(context),
              semanticLabel: 'Log out',
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.dangerBg,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: c.danger, width: 1.5),
                ),
                child: Text('Log out',
                    style: AppText.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800, color: c.danger)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: AppText.small.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: context.c.text3)),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppText.body.copyWith(
                      fontWeight: FontWeight.w600, color: c.text)),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;

  const _TogglePill({required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Toggle dark mode',
      child: Container(
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: on ? c.primary : c.border,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
