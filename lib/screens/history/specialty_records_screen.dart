import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/record_controller.dart';
import '../../models/medical_specialty.dart';
import '../../models/record_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/press_scale.dart';

class SpecialtyRecordsScreen extends StatefulWidget {
  final String specialtyId;
  const SpecialtyRecordsScreen({super.key, required this.specialtyId});

  @override
  State<SpecialtyRecordsScreen> createState() => _SpecialtyRecordsScreenState();
}

class _SpecialtyRecordsScreenState extends State<SpecialtyRecordsScreen> {
  MedicalRecordType? _filter;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final specialty = MedicalSpecialties.byId(widget.specialtyId);
    final allRecords =
        context
            .watch<RecordController>()
            .medicalRecords
            .where((record) => record.specialtyId == specialty.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final types = allRecords.map((record) => record.type).toSet().toList();
    final records = _filter == null
        ? allRecords
        : allRecords.where((record) => record.type == _filter).toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back to specialties',
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          specialty.name,
          style: AppText.title.copyWith(color: c.text),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: context.read<RecordController>().refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: brandGradient(context),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppShadows.brandCard,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              specialty.icon,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  specialty.bodySystem,
                                  style: AppText.bodyStrong.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${allRecords.length} ${allRecords.length == 1 ? 'record' : 'records'} · Newest first',
                                  style: AppText.caption.copyWith(
                                    color: Colors.white.withValues(alpha: .82),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (types.length > 1) ...[
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _filter == null,
                              onTap: () => setState(() => _filter = null),
                            ),
                            for (final type in types) ...[
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: type.label,
                                selected: _filter == type,
                                onTap: () => setState(() => _filter = type),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (records.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No records in this category.',
                    style: AppText.body.copyWith(color: c.text2),
                  ),
                ),
              )
            else
              ..._yearSections(records),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  List<Widget> _yearSections(List<MedicalRecordModel> records) {
    final years = <int, List<MedicalRecordModel>>{};
    for (final record in records) {
      years.putIfAbsent(record.date.year, () => []).add(record);
    }
    return [
      for (final entry in years.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 9),
            child: Text(
              '${entry.key}',
              style: AppText.mono.copyWith(
                fontSize: 13,
                color: context.c.text3,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _RecordCard(record: entry.value[index]),
          ),
        ),
      ],
    ];
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    labelStyle: AppText.caption.copyWith(
      color: selected ? Colors.white : context.c.text2,
    ),
    selectedColor: context.c.primary,
    backgroundColor: context.c.surface,
    side: BorderSide(color: selected ? context.c.primary : context.c.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    showCheckmark: false,
  );
}

class _RecordCard extends StatelessWidget {
  final MedicalRecordModel record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      semanticLabel: '${record.type.label}: ${record.title}',
      onTap: () => context.push('/record/${Uri.encodeComponent(record.id)}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _recordColor(context, record.type).$2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _recordIcon(record.type),
                color: _recordColor(context, record.type).$1,
                size: 23,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.type.label,
                          style: AppText.small.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _recordColor(context, record.type).$1,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('d MMM').format(record.date),
                        style: AppText.monoSmall.copyWith(
                          fontSize: 10.5,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    record.title,
                    style: AppText.bodyStrong.copyWith(
                      fontSize: 15.5,
                      color: c.text,
                    ),
                  ),
                  if (record.facility.isNotEmpty ||
                      record.doctor.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        record.facility,
                        record.doctor,
                      ].where((item) => item.isNotEmpty).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: c.text2),
                    ),
                  ],
                  if (record.hasOriginalDocument) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          size: 14,
                          color: c.text3,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${record.fileUrls.length} original ${record.fileUrls.length == 1 ? 'file' : 'files'}',
                          style: AppText.small.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 7),
            Icon(Icons.chevron_right_rounded, color: c.text3),
          ],
        ),
      ),
    );
  }
}

(Color, Color) _recordColor(BuildContext context, MedicalRecordType type) {
  final c = context.c;
  return switch (type) {
    MedicalRecordType.prescription ||
    MedicalRecordType.medicationHistory => (c.safe, c.safeBg),
    MedicalRecordType.laboratory ||
    MedicalRecordType.vitalSigns => (c.info, c.infoBg),
    MedicalRecordType.imaging => (c.skyFg, c.sky),
    MedicalRecordType.allergy => (c.danger, c.dangerBg),
    MedicalRecordType.chronicDisease ||
    MedicalRecordType.diagnosis => (c.warn, c.warnBg),
    _ => (c.primary, c.mint),
  };
}

IconData _recordIcon(MedicalRecordType type) => switch (type) {
  MedicalRecordType.prescription ||
  MedicalRecordType.medicationHistory => Icons.medication_rounded,
  MedicalRecordType.laboratory => Icons.science_rounded,
  MedicalRecordType.imaging => Icons.image_search_rounded,
  MedicalRecordType.medicalCertificate => Icons.workspace_premium_rounded,
  MedicalRecordType.dischargeSummary => Icons.exit_to_app_rounded,
  MedicalRecordType.procedureNote => Icons.medical_services_rounded,
  MedicalRecordType.vaccination => Icons.vaccines_rounded,
  MedicalRecordType.referral => Icons.forward_to_inbox_rounded,
  MedicalRecordType.vitalSigns => Icons.monitor_heart_rounded,
  MedicalRecordType.diagnosis ||
  MedicalRecordType.chronicDisease => Icons.health_and_safety_rounded,
  MedicalRecordType.allergy => Icons.warning_amber_rounded,
  _ => Icons.description_rounded,
};
