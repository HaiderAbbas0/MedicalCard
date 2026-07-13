import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/card_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/brand_app_bar.dart';
import '../../widgets/common/hayaat_card.dart';

/// Full-screen HayaatID card view with the option to order a physical card.
class HealthCardScreen extends StatelessWidget {
  const HealthCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cardCtrl = context.watch<CardController>();
    final card = cardCtrl.card;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'My HayaatID Card'),
      body: cardCtrl.loading
          ? const Center(child: CircularProgressIndicator())
          : card == null
          ? _NoCard(onRequest: () => context.push('/card-request'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              children: [
                HayaatCard(
                  card: card,
                  gender: context.watch<AuthController>().currentUser?.gender,
                ),
                const SizedBox(height: 24),
                _InfoRow(label: 'Hayaat ID', value: card.cardNumber),
                _InfoRow(label: 'Role', value: roleLabel(card.role)),
                _InfoRow(
                  label: 'Status',
                  value: card.physicalRequested
                      ? 'Physical card requested'
                      : 'Virtual card',
                ),
                const SizedBox(height: 24),
                if (!card.physicalRequested)
                  _PrimaryButton(
                    icon: Icons.credit_card,
                    label: 'Order a physical card',
                    onTap: () => context.push('/physical-card'),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.mint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: c.mintFg),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your physical card is on the way.',
                            style: AppText.body.copyWith(color: c.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _SecondaryButton(
                  icon: Icons.edit_outlined,
                  label: 'Update card details',
                  onTap: () => context.push('/card-request'),
                ),
              ],
            ),
    );
  }
}

class _NoCard extends StatelessWidget {
  final VoidCallback onRequest;
  const _NoCard({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 64, color: c.primary),
            const SizedBox(height: 16),
            Text(
              'No card yet',
              style: AppText.heading.copyWith(
                color: c.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Request your HayaatID card to carry your health identity with you.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: c.text2),
            ),
            const SizedBox(height: 20),
            _PrimaryButton(
              icon: Icons.add_card,
              label: 'Request your card',
              onTap: onRequest,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body.copyWith(color: c.text3)),
          Text(value, style: AppText.bodyStrong.copyWith(color: c.text)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: c.primary),
        label: Text(
          label,
          style: TextStyle(color: c.primary, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: c.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
