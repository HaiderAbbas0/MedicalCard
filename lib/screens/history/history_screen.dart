import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/record_controller.dart';
import '../../models/record_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/common/shimmer_loader.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _sorts = ['All', 'Doctor', 'Hospital', 'Date'];
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
              child: Text('Medical History',
                  style: AppText.display
                      .copyWith(fontSize: 24, color: context.c.text)),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: _sorts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _Chip(
                  label: _sorts[i],
                  selected: _selected == i,
                  onTap: () => setState(() => _selected = i),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FakeLoader(
                skeleton: const ShimmerList(count: 4),
                builder: (ctx) {
                  final records = context.watch<RecordController>();
                  final list = records.visits;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 96),
                    children: [
                      if (list.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Text(
                              'No medical history records found.',
                              style: AppText.body.copyWith(color: context.c.text3),
                            ),
                          ),
                        )
                      else
                        for (final v in list) ...[
                          _VisitCard(visit: v),
                          const SizedBox(height: 12),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: selected ? brandGradient(context) : null,
          color: selected ? null : context.c.surface,
          borderRadius: BorderRadius.circular(12),
          border:
              selected ? null : Border.all(color: context.c.border),
        ),
        child: Text(
          label,
          style: AppText.caption.copyWith(
              color: selected ? Colors.white : context.c.text2),
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final VisitModel visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: () => context.push('/history/${visit.id}'),
      child: Container(
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
                Expanded(
                  child: Text(visit.dateLabel,
                      style: AppText.mono
                          .copyWith(fontSize: 12, color: c.primary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(visit.specialty,
                      style: AppText.small.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.text2)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(visit.dx,
                style: AppText.bodyStrong.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.text)),
            const SizedBox(height: 4),
            Text('${visit.doctor} · ${visit.hospital}',
                style: AppText.caption.copyWith(color: c.text2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Divider(height: 1, color: c.border2),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.medication_rounded,
                      size: 15, color: c.text3),
                ),
                const SizedBox(width: 8),
                Text('${visit.meds.length} medicines',
                    style: AppText.caption
                        .copyWith(fontSize: 12.5, color: c.text2)),
                const Spacer(),
                Text('View details ›',
                    style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w700, color: c.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
