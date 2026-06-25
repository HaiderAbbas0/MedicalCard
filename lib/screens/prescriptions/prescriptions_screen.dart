import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/icon_badge.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/common/shimmer_loader.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    final items =
        mockPrescriptions.where((r) => r.active == _active).toList();
    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
              child: Text('Prescriptions',
                  style: AppText.display
                      .copyWith(fontSize: 24, color: context.c.text)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.c.border),
                ),
                child: Row(
                  children: [
                    _Segment(
                      label: 'Active',
                      selected: _active,
                      onTap: () => setState(() => _active = true),
                    ),
                    _Segment(
                      label: 'Past',
                      selected: !_active,
                      onTap: () => setState(() => _active = false),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FakeLoader(
                skeleton: const ShimmerList(count: 4),
                builder: (ctx) => ListView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 96),
                  children: [
                    for (final rx in items) ...[
                      _RxCard(rx: rx),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressScale(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? brandGradient(context) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : context.c.text2),
          ),
        ),
      ),
    );
  }
}

class _RxCard extends StatelessWidget {
  final Prescription rx;

  const _RxCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.medication_rounded,
                color: c.safe,
                background: c.safeBg,
                size: 44,
                radius: 13,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: rx.name,
                        style: AppText.bodyStrong.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text),
                        children: [
                          TextSpan(
                            text: ' ${rx.strength}',
                            style: AppText.bodyStrong.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.text2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${rx.freq} · ${rx.dur}',
                        style: AppText.caption.copyWith(color: c.text2)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(active: rx.active),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: c.border2),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('By ${rx.by}',
                    style: AppText.caption
                        .copyWith(fontSize: 12.5, color: c.text2)),
              ),
              Text(rx.date,
                  style: AppText.caption
                      .copyWith(fontSize: 12.5, color: c.text3)),
            ],
          ),
          if (rx.warn != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.warnBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: c.warn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(rx.warn!,
                        style: AppText.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.warn)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;

  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = active ? c.safe : c.text3;
    final bg = active ? c.safeBg : c.bg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(active ? 'Active' : 'Past',
          style: AppText.small.copyWith(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
