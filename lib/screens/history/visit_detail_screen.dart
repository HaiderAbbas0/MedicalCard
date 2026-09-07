import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/record_controller.dart';
import '../../models/record_models.dart';
import '../../services/report_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/ai_explain_sheet.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/pdf_export_sheet.dart';
import '../../widgets/common/press_scale.dart';

class VisitDetailScreen extends StatelessWidget {
  final String visitId;

  const VisitDetailScreen({super.key, required this.visitId});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<RecordController>();
    final v = records.visits.firstWhere((e) => e.id == visitId,
        orElse: () => VisitModel(
              id: 'v_fallback',
              dx: 'Unknown Visit',
              doctor: 'Unknown Doctor',
              specialty: 'General Medicine',
              hospital: 'Clinic',
              dateLabel: 'Today',
              time: '00:00',
              symptoms: 'No symptoms recorded.',
              diagnosis: 'No diagnosis recorded.',
              diagnosisNote: '',
              meds: [],
              followUp: 'None',
              advice: '',
            ));
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 70, 22, 18),
            decoration: BoxDecoration(gradient: brandGradient(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PressScale(
                      onTap: () => context.pop(),
                      semanticLabel: 'Back',
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.chevron_left_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('${v.dateLabel} · ${v.time}',
                          style: AppText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.9))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(v.dx,
                    style: AppText.display
                        .copyWith(fontSize: 22, color: Colors.white)),
                const SizedBox(height: 6),
                Text('${v.doctor} · ${v.specialty}',
                    style: AppText.body.copyWith(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.92))),
                const SizedBox(height: 2),
                Text(v.hospital,
                    style: AppText.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('SYMPTOMS'),
                      const SizedBox(height: 8),
                      Text(v.symptoms,
                          style: AppText.body.copyWith(
                              fontSize: 14, height: 1.5, color: c.text)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('DIAGNOSIS'),
                      const SizedBox(height: 8),
                      Text(v.diagnosis,
                          style: AppText.bodyStrong
                              .copyWith(fontSize: 15, color: c.text)),
                      const SizedBox(height: 4),
                      Text(v.diagnosisNote,
                          style: AppText.caption.copyWith(color: c.text2)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('MEDICINES'),
                      const SizedBox(height: 12),
                      for (var i = 0; i < v.meds.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom: i == v.meds.length - 1 ? 0 : 12),
                          child: _MedRow(med: v.meds[i]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: c.sky,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.event_rounded, size: 20, color: c.skyFg),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Follow-up: ${v.followUp}',
                                style: AppText.caption.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: c.skyFg)),
                            const SizedBox(height: 3),
                            Text(v.advice,
                                style: AppText.small.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c.skyFg.withValues(alpha: 0.85))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: 'View prescription',
                  height: 52,
                  onPressed: () {
                    final targetId = 'prescription-${v.id}';
                    final exists = records.medicalRecords.any((m) => m.id == targetId);
                    if (exists) {
                      context.push('/record/${Uri.encodeComponent(targetId)}');
                    } else {
                      _snack(context, 'No prescription document is available for this visit.');
                    }
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    final user = context.read<AuthController>().currentUser;
                    showPdfExportSheet(
                      context,
                      title: 'Export visit summary',
                      filename: ReportPdfService.fileName('visit ${v.dateLabel}'),
                      build: () => ReportPdfService().buildVisitPdf(
                        v,
                        PdfPatientInfo.fromUser(user),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  label: const Text(
                    'Export as PDF',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => showAiExplainSheet(context, record: _visitAiPayload(v)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: const Text(
                    'Explain this visit',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _visitAiPayload(VisitModel v) => {
  'type': 'Visit summary',
  'date': '${v.dateLabel} ${v.time}'.trim(),
  'doctor': v.doctor,
  'specialty': v.specialty,
  'facility': v.hospital,
  'symptoms': v.symptoms,
  'diagnosis': v.diagnosis,
  'diagnosisNote': v.diagnosisNote,
  'medicines': v.meds.map((m) => '${m.name} ${m.strength} · ${m.freq} · ${m.dur}').toList(),
  'followUp': v.followUp,
  'advice': v.advice,
};

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.c.border),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppText.small.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: context.c.text3));
  }
}

class _MedRow extends StatelessWidget {
  final MedModel med;

  const _MedRow({required this.med});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.safeBg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.medication_rounded, size: 19, color: c.safe),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '${med.name} ',
              style: AppText.bodyStrong
                  .copyWith(fontSize: 14, color: c.text),
              children: [
                TextSpan(
                  text: med.strength,
                  style: AppText.bodyStrong.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${med.freq} · ${med.dur}',
            style: AppText.small.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.text2)),
      ],
    );
  }
}
