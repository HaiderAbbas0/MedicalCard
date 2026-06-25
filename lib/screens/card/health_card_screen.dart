import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/screen_header.dart';

/// Full-screen digital health card — pushed screen.
class HealthCardScreen extends StatelessWidget {
  const HealthCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final auth = context.watch<AuthController>();
    final p = auth.currentUser?.toPatient() ?? mockPatient;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 18),
              _card(context, p),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlineButton2(
                      label: 'Download',
                      icon: Icons.download_rounded,
                      height: 52,
                      onPressed: () => _snack(context, 'Card downloaded'),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: GradientButton(
                      label: 'Share',
                      icon: Icons.ios_share_rounded,
                      height: 52,
                      onPressed: () => _snack(context, 'Sharing health card…'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _privacyBanner(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    return Row(
      children: [
        HeaderIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          semanticLabel: 'Back',
          onTap: () => context.pop(),
        ),
        const SizedBox(width: 12),
        Text(
          'Health Card',
          style: AppText.heading
              .copyWith(color: context.c.text, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  // ── Gradient card ─────────────────────────────────────────────────────
  Widget _card(BuildContext context, Patient p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: brandGradient(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppShadows.brandCard,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SEHAT ID',
                    style: AppText.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Center(
                child: Container(
                  width: 172,
                  height: 172,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Hero(
                    tag: 'health-qr',
                    child: QrImageView(
                      data: '${p.healthId}|${p.name}|${p.blood}|${p.dob}',
                      version: QrVersions.auto,
                      size: 172,
                      padding: EdgeInsets.zero,
                      // ignore: deprecated_member_use
                      foregroundColor: kPrimary,
                      // ignore: deprecated_member_use
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  p.initials,
                  style: AppText.heading.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.name,
                style: AppText.heading.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'DOB ${p.dob}',
                style: AppText.mono
                    .copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 20),
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field('HEALTH ID', p.healthId, mono: true),
                  ),
                  _field('BLOOD', p.blood),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, {bool mono = false}) {
    final valueStyle = mono
        ? AppText.mono.copyWith(color: Colors.white, fontSize: 14)
        : AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.small.copyWith(
              color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(value, style: valueStyle),
      ],
    );
  }

  // ── Privacy banner ────────────────────────────────────────────────────
  Widget _privacyBanner(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: c.sky,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: c.skyFg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data stays private',
                  style: AppText.caption.copyWith(
                      color: c.skyFg, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Only verified doctors can access your full record — and only '
                  'after you approve.',
                  style: AppText.caption.copyWith(
                      color: c.skyFg.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.c.primary,
        content:
            Text(message, style: AppText.body.copyWith(color: Colors.white)),
      ),
    );
  }
}
