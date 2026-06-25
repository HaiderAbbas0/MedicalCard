import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  AppLanguage _sel = AppLanguage.english;

  void _continue() {
    context.read<LanguageProvider>().setLanguage(
          _sel == AppLanguage.urdu ? AppLanguage.urdu : AppLanguage.english,
        );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 80, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your language',
                style: AppText.display.copyWith(color: c.text, fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'اپنی زبان منتخب کریں',
                style: AppText.body.copyWith(color: c.text2),
              ),
              const SizedBox(height: 30),
              _LanguageRow(
                badge: 'EN',
                badgeSize: 16,
                title: 'English',
                subtitle: 'Continue in English',
                selected: _sel == AppLanguage.english,
                onTap: () => setState(() => _sel = AppLanguage.english),
              ),
              const SizedBox(height: 14),
              _LanguageRow(
                badge: 'اُ',
                badgeSize: 18,
                title: 'اردو',
                subtitle: 'اردو میں جاری رکھیں',
                selected: _sel == AppLanguage.urdu,
                onTap: () => setState(() => _sel = AppLanguage.urdu),
              ),
              const Spacer(),
              GradientButton(label: 'Continue', onPressed: _continue),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String badge;
  final double badgeSize;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageRow({
    required this.badge,
    required this.badgeSize,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: AppText.bodyStrong.copyWith(
                  color: c.mintFg,
                  fontSize: badgeSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.title.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.caption.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
            _Radio(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.primary : Colors.transparent,
        border: Border.all(
          color: selected ? c.primary : c.border,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
          : null,
    );
  }
}
