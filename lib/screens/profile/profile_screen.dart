import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/card_controller.dart';
import '../../data/mock_data.dart' show UserPatientExtension;
import '../../services/card_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/press_scale.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _changePhoto(BuildContext context) async {
    final cardCtrl = context.read<CardController>();
    if (cardCtrl.card == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request your card first to add a photo.'),
        ),
      );
      return;
    }
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null || res.files.single.bytes == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await CardService().uploadPhoto(res.files.single.bytes!);
      await CardService().setPhotoUrl(url);
      await cardCtrl.load(); // refresh card → keeps profile + card in sync
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final auth = context.watch<AuthController>();
    final cardCtrl = context.watch<CardController>();
    final p = auth.currentUser?.toPatient();
    if (p == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Your patient profile could not be loaded. Please sign in again.',
          ),
        ),
      );
    }
    final photoUrl = cardCtrl.card?.photoUrl;
    final uniqueId = auth.currentUser?.cardNumber ?? p.healthId;
    final email = auth.currentUser?.email ?? '—';

    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Gradient header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 70, 22, 18),
            decoration: BoxDecoration(gradient: brandGradient(context)),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: PressScale(
                    onTap: () => context.push('/settings'),
                    semanticLabel: 'Settings',
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 3,
                            ),
                            image: (photoUrl != null && photoUrl.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(photoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  p.initials,
                                  style: AppText.display.copyWith(
                                    fontSize: 30,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: PressScale(
                            onTap: () => _changePhoto(context),
                            semanticLabel: 'Change photo',
                            child: Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: c.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      p.name,
                      style: AppText.display.copyWith(
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      uniqueId,
                      style: AppText.mono.copyWith(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 11,
                  mainAxisSpacing: 11,
                  childAspectRatio: 2.1,
                  children: [
                    _FactCard(
                      label: 'HAYAAT ID',
                      value: uniqueId,
                      valueSize: 14,
                    ),
                    _FactCard(
                      label: 'BLOOD GROUP',
                      value: p.blood,
                      valueColor: c.danger,
                    ),
                    _FactCard(
                      label: 'DATE OF BIRTH',
                      value: p.dob,
                      valueSize: 15,
                    ),
                    _FactCard(label: 'GENDER', value: p.gender),
                    _FactCard(
                      label: 'PHONE',
                      value: p.phoneMasked,
                      valueSize: 15,
                    ),
                    _FactCard(label: 'EMAIL', value: email, valueSize: 13),
                  ],
                ),
                const SizedBox(height: 14),
                _ChipsCard(
                  label: 'ALLERGIES',
                  items: p.allergies,
                  fg: c.danger,
                  bg: c.dangerBg,
                ),
                const SizedBox(height: 14),
                _ChipsCard(
                  label: 'CHRONIC CONDITIONS',
                  items: p.chronic,
                  fg: c.warn,
                  bg: c.warnBg,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.dangerBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          size: 20,
                          color: c.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMERGENCY CONTACT',
                              style: AppText.small.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.text3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.emergencyName} · ${p.emergencyPhone}',
                              style: AppText.bodyStrong.copyWith(
                                fontSize: 15,
                                color: c.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlineButton2(
                  label: 'Edit profile',
                  onPressed: () => context.push('/edit-profile'),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double valueSize;

  const _FactCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppText.small.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.bodyStrong.copyWith(
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              color: valueColor ?? c.text,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ChipsCard extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color fg;
  final Color bg;

  const _ChipsCard({
    required this.label,
    required this.items,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.small.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item,
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
