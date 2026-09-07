import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/record_controller.dart';
import '../../models/medical_specialty.dart';
import '../../models/record_models.dart';
import '../../services/report_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/ai_explain_sheet.dart';
import '../../widgets/common/pdf_export_sheet.dart';

class RecordViewerScreen extends StatefulWidget {
  final String recordId;
  const RecordViewerScreen({super.key, required this.recordId});

  @override
  State<RecordViewerScreen> createState() => _RecordViewerScreenState();
}

class _RecordViewerScreenState extends State<RecordViewerScreen> {
  int _selectedFile = 0;

  @override
  Widget build(BuildContext context) {
    final records = context.watch<RecordController>().medicalRecords;
    MedicalRecordModel? record;
    for (final item in records) {
      if (item.id == widget.recordId) {
        record = item;
        break;
      }
    }
    if (record == null) return const _MissingRecord();
    final item = record;
    final specialty = MedicalSpecialties.byId(item.specialtyId);
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.type.label,
              style: AppText.title.copyWith(fontSize: 16, color: c.text),
            ),
            Text(
              DateFormat('d MMMM yyyy').format(item.date),
              style: AppText.small.copyWith(color: c.text3),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Explain this record',
            icon: Icon(Icons.auto_awesome_rounded, color: c.primary),
            onPressed: () => showAiExplainSheet(context, record: _aiPayload(item)),
          ),
          IconButton(
            tooltip: 'Export / share',
            icon: Icon(Icons.ios_share_rounded, color: c.primary),
            onPressed: () {
              final user = context.read<AuthController>().currentUser;
              showPdfExportSheet(
                context,
                title: 'Export ${item.type.label.toLowerCase()}',
                filename: ReportPdfService.fileName(item.type.label, item.date),
                build: () => ReportPdfService().buildRecordPdf(
                  item,
                  PdfPatientInfo.fromUser(user),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final document = _DocumentArea(
            record: item,
            selectedFile: _selectedFile,
            onSelectFile: (index) => setState(() => _selectedFile = index),
          );
          final metadata = _MetadataPanel(record: item, specialty: specialty);
          if (wide) {
            return Row(
              children: [
                Expanded(child: document),
                Container(width: 1, color: c.border),
                SizedBox(width: 340, child: metadata),
              ],
            );
          }
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(height: constraints.maxHeight * .64, child: document),
              metadata,
            ],
          );
        },
      ),
    );
  }
}

class _DocumentArea extends StatelessWidget {
  final MedicalRecordModel record;
  final int selectedFile;
  final ValueChanged<int> onSelectFile;

  const _DocumentArea({
    required this.record,
    required this.selectedFile,
    required this.onSelectFile,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: context.isDark ? const Color(0xFF080D0B) : const Color(0xFFE9EEEB),
      child: Column(
        children: [
          if (record.fileUrls.length > 1)
            Container(
              height: 54,
              width: double.infinity,
              color: c.surface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: record.fileUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ChoiceChip(
                  selected: selectedFile == index,
                  onSelected: (_) => onSelectFile(index),
                  showCheckmark: false,
                  label: Text(
                    index < record.fileNames.length &&
                            record.fileNames[index].isNotEmpty
                        ? record.fileNames[index]
                        : 'File ${index + 1}',
                  ),
                ),
              ),
            ),
          Expanded(
            child: record.hasOriginalDocument
                ? _OriginalFile(record: record, index: selectedFile)
                : _StructuredRecord(record: record),
          ),
        ],
      ),
    );
  }
}

class _OriginalFile extends StatelessWidget {
  final MedicalRecordModel record;
  final int index;
  const _OriginalFile({required this.record, required this.index});

  @override
  Widget build(BuildContext context) {
    final url = record.fileUrls[index.clamp(0, record.fileUrls.length - 1)];
    final name = index < record.fileNames.length ? record.fileNames[index] : '';
    final mime = index < record.mimeTypes.length ? record.mimeTypes[index] : '';
    final pdf =
        mime == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
    final image =
        mime.startsWith('image/') ||
        RegExp(
          r'\.(png|jpe?g|webp|gif|bmp)$',
          caseSensitive: false,
        ).hasMatch(name);

    if (pdf) {
      return PdfViewer.uri(
        Uri.parse(url),
        params: PdfViewerParams(
          backgroundColor: context.isDark
              ? const Color(0xFF080D0B)
              : const Color(0xFFE9EEEB),
          margin: 16,
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
              Center(
                child: CircularProgressIndicator(
                  value: totalBytes == null
                      ? null
                      : bytesDownloaded / totalBytes,
                ),
              ),
          errorBannerBuilder: (context, error, stackTrace, documentRef) =>
              _FileError(
                message:
                    'This PDF could not be opened. Pull to refresh the record and try again.',
              ),
        ),
      );
    }
    if (image || record.type == MedicalRecordType.imaging) {
      return InteractiveViewer(
        minScale: .8,
        maxScale: 8,
        boundaryMargin: const EdgeInsets.all(80),
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, _, _) => const _FileError(
              message:
                  'This image could not be opened. The secure link may need to be refreshed.',
            ),
          ),
        ),
      );
    }
    return const _FileError(
      message:
          'This file format cannot be previewed inside the app yet. Its metadata is still available below.',
    );
  }
}

class _StructuredRecord extends StatelessWidget {
  final MedicalRecordModel record;
  const _StructuredRecord({required this.record});

  @override
  Widget build(BuildContext context) {
    if (record.type == MedicalRecordType.prescription) {
      return _PrescriptionDocument(record: record);
    }
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.title,
                style: AppText.heading.copyWith(color: c.text),
              ),
              if (record.summary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  record.summary,
                  style: AppText.body.copyWith(color: c.text2),
                ),
              ],
              const SizedBox(height: 22),
              ..._detailWidgets(context, record.details),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionDocument extends StatelessWidget {
  final MedicalRecordModel record;
  const _PrescriptionDocument({required this.record});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final meds = record.details['medications'] as List? ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 34),
          decoration: BoxDecoration(
            color: c.surface,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: brandGradient(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.facility.isEmpty
                              ? 'Digital Prescription'
                              : record.facility,
                          style: AppText.title.copyWith(color: c.text),
                        ),
                        Text(
                          DateFormat('d MMMM yyyy').format(record.date),
                          style: AppText.caption.copyWith(color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rx',
                    style: AppText.display.copyWith(
                      fontSize: 30,
                      color: c.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: c.border),
              const SizedBox(height: 14),
              for (var i = 0; i < meds.length; i++) ...[
                _MedicationLine(
                  index: i + 1,
                  value: Map<String, dynamic>.from(meds[i] as Map),
                ),
                if (i < meds.length - 1) Divider(height: 26, color: c.border2),
              ],
              if (record.summary.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Clinical advice',
                  style: AppText.caption.copyWith(color: c.text3),
                ),
                const SizedBox(height: 5),
                Text(
                  record.summary,
                  style: AppText.body.copyWith(color: c.text),
                ),
              ],
              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (record.details['signatureName'] ?? '')
                              .toString()
                              .isNotEmpty
                          ? record.details['signatureName'].toString()
                          : record.doctor,
                      style: AppText.bodyStrong.copyWith(color: c.text),
                    ),
                    Text(
                      (record.details['signatureCredentials'] ?? '').toString(),
                      style: AppText.caption.copyWith(color: c.text2),
                    ),
                    Text(
                      (record.details['signatureFooter'] ?? '').toString(),
                      style: AppText.small.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationLine extends StatelessWidget {
  final int index;
  final Map<String, dynamic> value;
  const _MedicationLine({required this.index, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final instruction =
        [
              value['strength'],
              value['route'],
              value['frequency'],
              value['duration'],
            ]
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index.', style: AppText.bodyStrong.copyWith(color: c.primary)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value['name']?.toString() ?? 'Medicine',
                style: AppText.bodyStrong.copyWith(fontSize: 16, color: c.text),
              ),
              if (instruction.isNotEmpty)
                Text(
                  instruction,
                  style: AppText.caption.copyWith(color: c.text2),
                ),
              if ((value['instructions'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    value['instructions'].toString(),
                    style: AppText.caption.copyWith(color: c.text),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  final MedicalRecordModel record;
  final MedicalSpecialty specialty;
  const _MetadataPanel({required this.record, required this.specialty});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.surface,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record details', style: AppText.title.copyWith(color: c.text)),
          const SizedBox(height: 18),
          _MetadataRow(
            icon: specialty.icon,
            label: 'Specialty',
            value: specialty.displayName,
          ),
          _MetadataRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: DateFormat('d MMMM yyyy').format(record.date),
          ),
          _MetadataRow(
            icon: Icons.description_outlined,
            label: 'Record type',
            value: record.type.label,
          ),
          if (record.facility.isNotEmpty)
            _MetadataRow(
              icon: Icons.apartment_rounded,
              label: 'Hospital / clinic',
              value: record.facility,
            ),
          if (record.doctor.isNotEmpty)
            _MetadataRow(
              icon: Icons.person_outline_rounded,
              label: 'Doctor',
              value: record.doctor,
            ),
          if (record.fileNames.isNotEmpty)
            _MetadataRow(
              icon: Icons.attach_file_rounded,
              label: 'Original file',
              value: record.fileNames.join(', '),
            ),
          if (record.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Notes', style: AppText.caption.copyWith(color: c.text3)),
            const SizedBox(height: 6),
            Text(record.summary, style: AppText.body.copyWith(color: c.text)),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: c.mintFg),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.small.copyWith(color: c.text3)),
                const SizedBox(height: 2),
                Text(value, style: AppText.caption.copyWith(color: c.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain, JSON-safe summary of a record for the "explain this record"
/// assistant. Excludes file URLs (signed links, not useful to the model).
Map<String, dynamic> _aiPayload(MedicalRecordModel item) => {
  'type': item.type.label,
  'title': item.title,
  'date': DateFormat('d MMMM yyyy').format(item.date),
  'doctor': item.doctor,
  'facility': item.facility,
  'summary': item.summary,
  'details': item.details,
};

List<Widget> _detailWidgets(
  BuildContext context,
  Map<String, dynamic> details,
) {
  final c = context.c;
  final widgets = <Widget>[];
  for (final entry in details.entries) {
    final value = entry.value;
    if (value == null ||
        value.toString().isEmpty ||
        value is List && value.isEmpty) {
      continue;
    }
    widgets.add(
      Text(entry.key, style: AppText.caption.copyWith(color: c.text3)),
    );
    widgets.add(const SizedBox(height: 5));
    if (value is List) {
      for (final item in value) {
        final display = item is Map
            ? item.values
                  .map((part) => part?.toString() ?? '')
                  .where((part) => part.isNotEmpty)
                  .join(' · ')
            : item.toString();
        if (display.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• $display',
                style: AppText.body.copyWith(color: c.text),
              ),
            ),
          );
        }
      }
    } else {
      widgets.add(
        Text(value.toString(), style: AppText.body.copyWith(color: c.text)),
      );
    }
    widgets.add(const SizedBox(height: 18));
  }
  return widgets;
}

class _FileError extends StatelessWidget {
  final String message;
  const _FileError({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.file_present_rounded, size: 42, color: context.c.text3),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: context.c.text2),
          ),
        ],
      ),
    ),
  );
}

class _MissingRecord extends StatelessWidget {
  const _MissingRecord();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Record unavailable')),
    body: Center(
      child: Text(
        'This record could not be found or is no longer available.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: context.c.text2),
      ),
    ),
  );
}
