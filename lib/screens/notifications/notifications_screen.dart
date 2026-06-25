import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/common/shimmer_loader.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  /// Returns the (foreground, background) color pair for a [NotifKind].
  (Color, Color) _kindColors(BuildContext context, NotifKind kind) {
    final c = context.c;
    switch (kind) {
      case NotifKind.safe:
        return (c.safe, c.safeBg);
      case NotifKind.info:
        return (c.info, c.infoBg);
      case NotifKind.primary:
        return (c.primary, c.mint);
      case NotifKind.warn:
        return (c.warn, c.warnBg);
      case NotifKind.danger:
        return (c.danger, c.dangerBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  PressScale(
                    onTap: () => context.pop(),
                    semanticLabel: 'Back',
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.c.border),
                      ),
                      child: Icon(Icons.chevron_left_rounded,
                          size: 24, color: context.c.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notifications',
                    style: AppText.heading.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.c.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FakeLoader(
                skeleton: const ShimmerList(count: 5),
                builder: (ctx) => _buildList(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: mockNotifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final n = mockNotifications[i];
        final (fg, bg) = _kindColors(context, n.kind);
        return AppCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(n.icon, color: fg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: AppText.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.c.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n.sub,
                      style: AppText.caption.copyWith(
                          fontSize: 12.5,
                          height: 1.4,
                          color: context.c.text2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n.time,
                      style: AppText.small
                          .copyWith(fontSize: 11, color: context.c.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
