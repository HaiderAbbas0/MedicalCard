import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
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
              child: Text('12 reports · 2 new',
                  style: AppText.body
                      .copyWith(fontSize: 14, color: context.c.text2)),
            ),
            Expanded(
              child: FakeLoader(
                skeleton: const ShimmerList(count: 4),
                builder: (ctx) => ListView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 96),
                  children: [
                    for (final r in mockReports) ...[
                      _ReportCard(
                        report: r,
                        onDownload: () =>
                            _snack(context, 'Downloading ${r.name}…'),
                      ),
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

class _ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onDownload;

  const _ReportCard({required this.report, required this.onDownload});

  ({Color fg, Color bg}) _statusColors(BuildContext context) {
    final c = context.c;
    switch (report.status) {
      case ReportStatus.ready:
        return (fg: c.safe, bg: c.safeBg);
      case ReportStatus.reviewed:
        return (fg: c.info, bg: c.infoBg);
      case ReportStatus.abnormal:
        return (fg: c.danger, bg: c.dangerBg);
    }
  }

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
                  child: Text(report.statusLabel,
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
