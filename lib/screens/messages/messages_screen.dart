import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/common/shimmer_loader.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(title: 'Messages'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _warningBanner(context),
            ),
            Expanded(
              child: FakeLoader(
                skeleton: const ShimmerList(count: 3),
                builder: (ctx) => _buildList(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.c.warnBg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: context.c.warn, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppText.caption
                    .copyWith(fontSize: 12, color: context.c.warn),
                children: [
                  const TextSpan(text: 'For emergencies, call '),
                  TextSpan(
                    text: '1122',
                    style: AppText.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.c.warn),
                  ),
                  const TextSpan(
                      text: ' — do not wait for a reply here.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final chat = context.watch<ChatController>();
    final list = chat.conversations;
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.',
          style: AppText.body.copyWith(color: context.c.text3),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final c = list[i];
        return AppCard(
          radius: 16,
          padding: const EdgeInsets.all(13),
          onTap: () => context.push('/chat/${c.doctorId}'),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.c.mint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  c.initials,
                  style: AppText.bodyStrong.copyWith(
                      color: context.c.mintFg, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: AppText.body.copyWith(
                          color: context.c.text,
                          fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.last,
                      style: AppText.caption.copyWith(color: context.c.text2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    c.time,
                    style: AppText.small
                        .copyWith(fontSize: 11, color: context.c.text3),
                  ),
                  if (c.unread > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.c.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${c.unread}',
                        style: AppText.small.copyWith(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
