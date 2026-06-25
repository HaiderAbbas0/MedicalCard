import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/health_card_widget.dart';
import '../../widgets/common/icon_badge.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/common/shimmer_loader.dart';

/// Patient dashboard — branch (bottom-nav) screen.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _greeting(context),
            const SizedBox(height: 18),
            HealthCardWidget(
              patient: mockPatient,
              onShow: () => context.push('/card'),
            ),
            const SizedBox(height: 20),
            _stats(context),
            const SizedBox(height: 20),
            _quickActions(context),
            const SizedBox(height: 24),
            _recentHeader(context),
            const SizedBox(height: 12),
            FakeLoader(
              skeleton: Column(
                children: const [ShimmerListCard(), ShimmerListCard()],
              ),
              builder: _recentCard,
            ),
          ],
        ),
      ),
    );
  }

  // ── Greeting row ──────────────────────────────────────────────────────
  Widget _greeting(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: brandGradient(context),
            shape: BoxShape.circle,
          ),
          child: Text(
            mockPatient.initials,
            style: AppText.title.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assalam-o-Alaikum',
                  style: AppText.caption.copyWith(color: c.text2)),
              const SizedBox(height: 2),
              Text(
                mockPatient.name,
                style: AppText.heading
                    .copyWith(color: c.text, fontSize: 19, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PressScale(
          onTap: () => context.push('/notifications'),
          semanticLabel: 'Notifications',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: c.border),
                ),
                child: Icon(Icons.notifications_outlined,
                    size: 20, color: c.text2),
              ),
              Positioned(
                right: 9,
                top: 9,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 2×2 stats grid ────────────────────────────────────────────────────
  Widget _stats(BuildContext context) {
    final c = context.c;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 11,
      mainAxisSpacing: 11,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          dot: c.safe,
          label: 'Active Meds',
          value: '$kActiveMeds',
          sub: '2 due today',
          onTap: () => context.go('/prescriptions'),
        ),
        _StatCard(
          dot: c.danger,
          label: 'Allergies',
          value: '$kAllergyCount',
          valueColor: c.danger,
          sub: 'Penicillin · Sulfa',
        ),
        _StatCard(
          dot: c.info,
          label: 'Recent Visits',
          value: '$kRecentVisits',
          sub: 'last 6 months',
          onTap: () => context.go('/history'),
        ),
        _StatCard(
          dot: c.primary,
          label: 'Next Appt',
          value: '24 Jun',
          sub: 'Dr. Imran',
        ),
      ],
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────
  Widget _quickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.history_rounded,
            label: 'History',
            onTap: () => context.go('/history'),
          ),
          const SizedBox(width: 13),
          _QuickAction(
            icon: Icons.medication_outlined,
            label: 'Rx',
            onTap: () => context.go('/prescriptions'),
          ),
          const SizedBox(width: 13),
          _QuickAction(
            icon: Icons.description_outlined,
            label: 'Reports',
            onTap: () => context.go('/reports'),
          ),
          const SizedBox(width: 13),
          _QuickAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            onTap: () => context.push('/messages'),
          ),
          const SizedBox(width: 13),
          _QuickAction(
            icon: Icons.sos_rounded,
            label: 'SOS',
            danger: true,
            onTap: () => _showSos(context),
          ),
        ],
      ),
    );
  }

  void _showSos(BuildContext context) {
    final c = context.c;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.sos_rounded, color: c.danger, size: 22),
            const SizedBox(width: 10),
            Text('Emergency SOS', style: AppText.title.copyWith(color: c.text)),
          ],
        ),
        content: Text(
          'Call emergency services on 1122 right away?',
          style: AppText.body.copyWith(color: c.text2),
        ),
        actions: [
          PressScale(
            onTap: () => Navigator.of(ctx).pop(),
            semanticLabel: 'Cancel',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text('Cancel',
                  style: AppText.bodyStrong.copyWith(color: c.text2)),
            ),
          ),
          PressScale(
            onTap: () => Navigator.of(ctx).pop(),
            semanticLabel: 'Call 1122',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: c.danger,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Call 1122',
                  style: AppText.bodyStrong.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent activity ───────────────────────────────────────────────────
  Widget _recentHeader(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Recent activity',
            style: AppText.title
                .copyWith(color: c.text, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        PressScale(
          onTap: () => context.go('/history'),
          semanticLabel: 'See all activity',
          child: Text(
            'See all',
            style: AppText.caption
                .copyWith(color: c.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _recentCard(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < mockRecentActivity.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border2),
            _recentRow(context, i),
          ],
        ],
      ),
    );
  }

  Widget _recentRow(BuildContext context, int i) {
    final c = context.c;
    final a = mockRecentActivity[i];
    return PressScale(
      onTap: () => context.push('/history/${mockVisits[i].id}'),
      semanticLabel: a.dx,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconBadge(
              icon: Icons.favorite_rounded,
              color: c.mintFg,
              background: c.mint,
              size: 38,
              radius: 11,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.dx,
                    style: AppText.bodyStrong.copyWith(color: c.text, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${a.doctor} · ${a.specialty}',
                    style: AppText.caption.copyWith(color: c.text2, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(a.date, style: AppText.small.copyWith(color: c.text3)),
          ],
        ),
      ),
    );
  }
}

/// A single 2×2 stat tile (colored dot + label, big value, caption sub).
class _StatCard extends StatelessWidget {
  final Color dot;
  final String label;
  final String value;
  final Color? valueColor;
  final String sub;
  final VoidCallback? onTap;

  const _StatCard({
    required this.dot,
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppText.caption.copyWith(
                      color: c.text2, fontSize: 12, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppText.heading.copyWith(
                    color: valueColor ?? c.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: AppText.small.copyWith(color: c.text3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return PressScale(onTap: onTap, semanticLabel: label, child: card);
  }
}

/// Mint quick-action box (icon tile + caption label).
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = danger ? c.danger : c.mintFg;
    final bg = danger ? c.dangerBg : c.mint;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: AppText.small.copyWith(
                color: danger ? c.danger : c.text2,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
