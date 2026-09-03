import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/record_controller.dart';
import '../../models/record_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/common/shimmer_loader.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
              child: Text('Lab Reports',
                  style: AppText.display
                      .copyWith(fontSize: 24, color: context.c.text)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Consumer<RecordController>(
                builder: (context, records, child) {
                  final total = records.reports.length;
                  return Text('$total reports',
                      style: AppText.body
                          .copyWith(fontSize: 14, color: context.c.text2));
                },
              ),
            ),
            Expanded(
              child: FakeLoader(
                skeleton: const ShimmerList(count: 4),
                builder: (ctx) {
                  final records = context.watch<RecordController>();
                  final list = records.reports;
                  if (list.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => context.read<RecordController>().refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'No lab reports found.',
                              style: AppText.body.copyWith(color: context.c.text3),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // Group by specialty, non-empty groups only.
                  final groups = <String, List<ReportModel>>{};
                  for (final r in list) {
                    final key = r.specialty.trim().isEmpty ? 'Laboratory' : r.specialty.trim();
                    groups.putIfAbsent(key, () => []).add(r);
                  }
                  final keys = groups.keys.toList()..sort();
                  return RefreshIndicator(
                    onRefresh: () => context.read<RecordController>().refresh(),
                    child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      for (final k in keys) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
                          child: Row(
                            children: [
                              Text(k,
                                  style: AppText.bodyStrong.copyWith(
                                      fontSize: 14, fontWeight: FontWeight.w800, color: context.c.text)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.c.bg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: context.c.border),
                                ),
                                child: Text('${groups[k]!.length}',
                                    style: AppText.small.copyWith(
                                        fontSize: 11, fontWeight: FontWeight.w700, color: context.c.text3)),
                              ),
                            ],
                          ),
                        ),
                        for (final r in groups[k]!) ...[
                          _ReportCard(
                            report: r,
                            onDownload: () {
                              final targetId = 'lab-${r.id}';
                              final exists = records.medicalRecords.any((m) => m.id == targetId);
                              if (exists) {
                                context.push('/record/${Uri.encodeComponent(targetId)}');
                              } else {
                                _snack(context, 'Original report is not available yet.');
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
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

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onDownload;

  const _ReportCard({required this.report, required this.onDownload});

  ({Color fg, Color bg}) _statusColors(BuildContext context) {
    final c = context.c;
    switch (report.status) {
      case 'ready':
        return (fg: c.safe, bg: c.safeBg);
      case 'reviewed':
        return (fg: c.info, bg: c.infoBg);
      case 'abnormal':
        return (fg: c.danger, bg: c.dangerBg);
      default:
        return (fg: c.info, bg: c.infoBg);
    }
  }

  String get _statusLabel => switch (report.status) {
        'ready' => 'Ready',
        'reviewed' => 'Reviewed',
        'abnormal' => 'Abnormal',
        _ => report.status,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final status = _statusColors(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.description_rounded, size: 24, color: c.danger),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.name,
                    style: AppText.bodyStrong.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.text)),
                const SizedBox(height: 3),
                Text('${report.lab} · ${report.date}',
                    style: AppText.caption
                        .copyWith(fontSize: 12.5, color: c.text2)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_statusLabel,
                      style: AppText.small.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: status.fg)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PressScale(
            onTap: onDownload,
            semanticLabel: 'Download ${report.name}',
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.mint,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.download_rounded, size: 19, color: c.mintFg),
            ),
          ),
        ],
      ),
    );
  }
}
