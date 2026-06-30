import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/record_controller.dart';
import '../../controllers/card_controller.dart';
import '../../data/mock_data.dart';
import '../../models/record_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/hayaat_card.dart';
import '../../widgets/common/icon_badge.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/common/shimmer_loader.dart';

/// Patient dashboard — branch (bottom-nav) screen.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final rec = context.watch<RecordController>();
    final cardCtrl = context.watch<CardController>();
    final p = auth.currentUser?.toPatient() ?? mockPatient;

    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final token = auth.token;
            if (token != null) await rec.loadRecords(token);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _greeting(context, p),
              const SizedBox(height: 18),
              _cardSection(context, cardCtrl),
              const SizedBox(height: 20),
              _stats(context, rec, p),
              const SizedBox(height: 20),
              _quickActions(context),
              const SizedBox(height: 24),
              _recentHeader(context),
              const SizedBox(height: 12),
              if (rec.isLoading)
                Column(children: const [ShimmerListCard(), ShimmerListCard()])
              else
                _recentCard(context, rec),
            ],
          ),
        ),
      ),
    );
  }

  // ── Greeting row ──────────────────────────────────────────────────────
  Widget _greeting(BuildContext context, Patient p) {
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
            p.initials,
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
                p.name,
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

  // ── HayaatID card (virtual) or request CTA ────────────────────────────
  Widget _cardSection(BuildContext context, CardController cardCtrl) {
    if (cardCtrl.card != null) {
      return GestureDetector(
        onTap: () => context.push('/card'),
        child: HayaatCard(card: cardCtrl.card!, gender: context.read<AuthController>().currentUser?.gender),
      );
    }
    return GestureDetector(
      onTap: () => context.push('/card-request'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: brandGradient(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.brandCard,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.add_card_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request your HayaatID card',
                      style: AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Get your unique health ID and digital card.',
                      style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ── 2×2 stats grid (live) ─────────────────────────────────────────────
  Widget _stats(BuildContext context, RecordController rec, Patient p) {
    final c = context.c;

    final medPreview = rec.activePrescriptions
        .take(4)
        .map((m) => StatPreviewItem(text: '${m.name} (${m.strength})', color: m.warn != null ? c.danger : c.safe))
        .toList();

    final allergyPreview = rec.allergies
        .take(4)
        .map((a) => StatPreviewItem(text: (a['substance_name'] ?? '').toString()))
        .toList();

    final visitPreview = rec.visits
        .take(6)
        .map((v) => StatPreviewItem(text: '${v.specialty} · ${v.dateLabel}'))
        .toList();

    final next = rec.nextAppointment;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 11,
      mainAxisSpacing: 11,
      childAspectRatio: 1.08,
      children: [
        _StatCard(
          dot: c.safe,
          label: 'Active Meds',
          value: '${rec.activeMedsCount}',
          sub: rec.activeMedsCount == 0 ? 'None active' : 'Tap to view',
          previewItems: medPreview,
          onTap: () => context.go('/prescriptions'),
        ),
        _StatCard(
          dot: c.danger,
          label: 'Allergies',
          value: '${rec.allergyCount}',
          valueColor: c.danger,
          sub: rec.allergyCount == 0 ? 'None recorded' : 'Tap to view',
          previewItems: allergyPreview,
          onTap: () => context.push('/my-allergies'),
        ),
        _StatCard(
          dot: c.info,
          label: 'Recent Visits',
          value: '${rec.recentVisitsCount}',
          sub: 'All time',
          previewItems: visitPreview,
          onTap: () => context.go('/history'),
        ),
        _StatCard(
          dot: c.primary,
          label: 'Next Appt',
          value: next == null ? '—' : _shortDate(next.date),
          sub: next?.doctorName ?? 'None booked',
          previewItems: next == null
              ? const []
              : [
                  StatPreviewItem(text: next.doctorName ?? ''),
                  if (next.clinicName != null) StatPreviewItem(text: next.clinicName!),
                  StatPreviewItem(text: '${next.date} · ${next.time}'),
                ],
          onTap: () => context.push('/my-appointments'),
        ),
      ],
    );
  }

  /// Format an ISO date (YYYY-MM-DD) as e.g. "06 Jul".
  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}';
  }

  // ── Quick actions ─────────────────────────────────────────────────────
  Widget _quickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.event_available_outlined,
            label: 'Appts',
            onTap: () => context.push('/my-appointments'),
          ),
          const SizedBox(width: 13),
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
            icon: Icons.alarm_rounded,
            label: 'Reminders',
            onTap: () => context.push('/reminders'),
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

  Widget _recentCard(BuildContext context, RecordController rec) {
    final c = context.c;
    final recent = rec.visits.take(3).toList();

    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Text('No visits yet.', style: AppText.body.copyWith(color: c.text3)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border2),
            _recentRow(context, recent[i]),
          ],
        ],
      ),
    );
  }

  Widget _recentRow(BuildContext context, VisitModel v) {
    final c = context.c;
    return PressScale(
      onTap: () => context.push('/history/${v.id}'),
      semanticLabel: v.dx,
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
                    v.dx,
                    style: AppText.bodyStrong.copyWith(color: c.text, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${v.doctor} · ${v.specialty}',
                    style: AppText.caption.copyWith(color: c.text2, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(v.dateLabel, style: AppText.small.copyWith(color: c.text3)),
          ],
        ),
      ),
    );
  }
}

/// A preview item inside the stats card with optional custom text color.
class StatPreviewItem {
  final String text;
  final Color? color;
  const StatPreviewItem({required this.text, this.color});
}

/// A single 2×2 stat tile (colored dot + label, big value, caption sub).
class _StatCard extends StatelessWidget {
  final Color dot;
  final String label;
  final String value;
  final Color? valueColor;
  final String sub;
  final List<StatPreviewItem>? previewItems;
  final VoidCallback? onTap;

  const _StatCard({
    required this.dot,
    required this.label,
    required this.value,
    required this.sub,
    this.previewItems,
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
          const SizedBox(height: 6),
          if (previewItems != null && previewItems!.isNotEmpty) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in previewItems!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: item.color ?? dot.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: AppText.small.copyWith(
                                    color: item.color ?? c.text2,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 6),
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
                style: AppText.small.copyWith(color: c.text3, fontSize: 11),
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
