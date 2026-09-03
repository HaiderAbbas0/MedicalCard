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
import '../../widgets/common/shimmer_loader.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: FakeLoader(
          skeleton: const ShimmerList(count: 5),
          builder: (_) {
            final controller = context.watch<RecordController>();
            final records = controller.medicalRecords;
            final groups = _groups(records);
            final visible = groups.entries.where((entry) {
              final specialty = MedicalSpecialties.byId(entry.key);
              final query = _query.toLowerCase();
              return query.isEmpty ||
                  specialty.name.toLowerCase().contains(query) ||
                  specialty.bodySystem.toLowerCase().contains(query) ||
                  entry.value.any(
                    (record) =>
                        record.title.toLowerCase().contains(query) ||
                        record.type.label.toLowerCase().contains(query),
                  );
            }).toList();

            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      recordCount: records.length,
                      specialtyCount: groups.length,
                      onSearch: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                  ),
                  if (controller.errorMessage != null)
                    SliverToBoxAdapter(
                      child: _Notice(message: controller.errorMessage!),
                    ),
                  if (records.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyLibrary(),
                    )
                  else if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoMatches(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.crossAxisExtent >= 720
                              ? 2
                              : 1;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 142,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final entry = visible[index];
                              return _SpecialtyFolder(
                                specialty: MedicalSpecialties.byId(entry.key),
                                records: entry.value,
                              );
                            }, childCount: visible.length),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, List<MedicalRecordModel>> _groups(
    List<MedicalRecordModel> records,
  ) {
    final result = <String, List<MedicalRecordModel>>{};
    for (final record in records) {
      result.putIfAbsent(record.specialtyId, () => []).add(record);
    }
    for (final list in result.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }
    final entries = result.entries.toList()
      ..sort((a, b) => b.value.first.date.compareTo(a.value.first.date));
    return Map.fromEntries(entries);
  }
}

class _Header extends StatelessWidget {
  final int recordCount;
  final int specialtyCount;
  final ValueChanged<String> onSearch;

  const _Header({
    required this.recordCount,
    required this.specialtyCount,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Health Records',
                      style: AppText.display.copyWith(
                        fontSize: 26,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      specialtyCount == 0
                          ? 'Organized automatically as your care history grows'
                          : '$recordCount records across $specialtyCount ${specialtyCount == 1 ? 'specialty' : 'specialties'}',
                      style: AppText.body.copyWith(
                        fontSize: 14,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: brandGradient(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.card,
                ),
                child: const Icon(
                  Icons.folder_special_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            style: AppText.body.copyWith(color: c.text),
            decoration: InputDecoration(
              hintText: 'Find a specialty or record',
              hintStyle: AppText.body.copyWith(color: c.text3),
              prefixIcon: Icon(Icons.search_rounded, color: c.text3),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: c.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: c.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Only specialties containing your records are shown.',
                  style: AppText.caption.copyWith(color: c.text2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecialtyFolder extends StatelessWidget {
  final MedicalSpecialty specialty;
  final List<MedicalRecordModel> records;

  const _SpecialtyFolder({required this.specialty, required this.records});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final latest = records.first;
    return PressScale(
      semanticLabel: '${specialty.name}, ${records.length} records',
      onTap: () => context.push('/specialty/${specialty.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: c.mint,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(specialty.icon, color: c.mintFg, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    specialty.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(
                      fontSize: 16,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    specialty.bodySystem,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: c.text2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${records.length} ${records.length == 1 ? 'record' : 'records'} · Latest ${DateFormat('d MMM yyyy').format(latest.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String message;
  const _Notice({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.c.warnBg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: AppText.caption.copyWith(color: context.c.warn),
    ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) => _CenteredState(
    icon: Icons.folder_open_rounded,
    title: 'Your record library is empty',
    message:
        'Specialty folders will appear automatically after a consultation, test result, or document is added to your profile.',
  );
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) => const _CenteredState(
    icon: Icons.search_off_rounded,
    title: 'No matching records',
    message: 'Try a specialty, body system, doctor, or record type.',
  );
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: c.text3, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title.copyWith(color: c.text),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: c.text2),
            ),
          ],
        ),
      ),
    );
  }
}
