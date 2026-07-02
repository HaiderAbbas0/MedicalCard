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
  int _view = 0; // 0 = By specialty, 1 = Timeline

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
              child: Text('Medical History',
                  style: AppText.display.copyWith(fontSize: 24, color: c.text)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _Segmented(
                labels: const ['By specialty', 'Timeline'],
                selected: _view,
                onTap: (i) => setState(() => _view = i),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FakeLoader(
                skeleton: const ShimmerList(count: 4),
                builder: (ctx) {
                  final records = context.watch<RecordController>();
                  final visits = records.visits;
                  return RefreshIndicator(
                    onRefresh: () => context.read<RecordController>().refresh(),
                    child: visits.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 60),
                              _Empty(
                                icon: Icons.folder_open_rounded,
                                title: 'No medical history yet',
                                subtitle:
                                    'Your visits, diagnoses and prescriptions will appear here after a doctor finalizes a consultation.',
                              ),
                            ],
                          )
                        : _view == 0
                            ? _SpecialtyView(visits: visits)
                            : _TimelineView(visits: visits),
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

// ── By-specialty view ─────────────────────────────────────────────────────────
class _SpecialtyView extends StatelessWidget {
  final List<VisitModel> visits;
  const _SpecialtyView({required this.visits});

  @override
  Widget build(BuildContext context) {
    // Group by specialty, keep only non-empty groups, newest first within each.
    final groups = <String, List<VisitModel>>{};
    for (final v in visits) {
      final key = v.specialty.trim().isEmpty ? 'General Medicine' : v.specialty.trim();
      groups.putIfAbsent(key, () => []).add(v);
    }
    final keys = groups.keys.toList()..sort();
    for (final k in keys) {
      groups[k]!.sort((a, b) => b.dateLabel.compareTo(a.dateLabel));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 96),
      children: [
        for (final k in keys) ...[
          _SpecialtyGroup(specialty: k, visits: groups[k]!),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SpecialtyGroup extends StatefulWidget {
  final String specialty;
  final List<VisitModel> visits;
  const _SpecialtyGroup({required this.specialty, required this.visits});

  @override
  State<_SpecialtyGroup> createState() => _SpecialtyGroupState();
}

class _SpecialtyGroupState extends State<_SpecialtyGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          PressScale(
            onTap: () => setState(() => _open = !_open),
            semanticLabel: widget.specialty,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: brandGradient(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_iconFor(widget.specialty), color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.specialty,
                            style: AppText.bodyStrong.copyWith(fontSize: 15, color: c.text)),
                        const SizedBox(height: 2),
                        Text('${widget.visits.length} visit${widget.visits.length == 1 ? '' : 's'}',
                            style: AppText.caption.copyWith(color: c.text3)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more_rounded, color: c.text3),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Divider(height: 1, color: c.border2),
                  const SizedBox(height: 8),
                  for (final v in widget.visits) ...[
                    _VisitCard(visit: v),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ── Timeline view ─────────────────────────────────────────────────────────────
class _TimelineView extends StatelessWidget {
  final List<VisitModel> visits;
  const _TimelineView({required this.visits});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = [...visits]..sort((a, b) => b.dateLabel.compareTo(a.dateLabel));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 96),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final v = list[i];
        final isLast = i == list.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline rail
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bg, width: 2),
                    ),
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 2, color: c.border)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: _VisitCard(visit: v),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared pieces ─────────────────────────────────────────────────────────────
IconData _iconFor(String specialty) {
  final s = specialty.toLowerCase();
  if (s.contains('cardio')) return Icons.favorite_rounded;
  if (s.contains('derma')) return Icons.healing_rounded;
  if (s.contains('pedia')) return Icons.child_care_rounded;
  if (s.contains('gyn') || s.contains('obst')) return Icons.pregnant_woman_rounded;
  if (s.contains('ortho')) return Icons.accessibility_new_rounded;
  if (s.contains('ent')) return Icons.hearing_rounded;
  if (s.contains('ophthal') || s.contains('eye')) return Icons.visibility_rounded;
  if (s.contains('neuro')) return Icons.psychology_rounded;
  if (s.contains('psych')) return Icons.self_improvement_rounded;
  if (s.contains('gastro')) return Icons.restaurant_rounded;
  if (s.contains('pulmo')) return Icons.air_rounded;
  if (s.contains('dent')) return Icons.medical_services_rounded;
  if (s.contains('uro') || s.contains('nephro')) return Icons.water_drop_rounded;
  if (s.contains('onco')) return Icons.coronavirus_rounded;
  if (s.contains('endo')) return Icons.bloodtype_rounded;
  return Icons.medical_information_rounded;
}

class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;
  const _Segmented({required this.labels, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: PressScale(
                onTap: () => onTap(i),
                semanticLabel: labels[i],
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected == i ? brandGradient(context) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected == i ? Colors.white : c.text2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Empty({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)),
              child: Icon(icon, size: 32, color: c.text3),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppText.bodyStrong.copyWith(fontSize: 16, color: c.text), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: AppText.caption.copyWith(color: c.text3), textAlign: TextAlign.center),
          ],
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
                      style: AppText.mono.copyWith(fontSize: 12, color: c.primary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(visit.specialty,
                      style: AppText.small.copyWith(
                          fontSize: 11, fontWeight: FontWeight.w700, color: c.text2)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(visit.dx,
                style: AppText.bodyStrong.copyWith(
                    fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
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
                  child: Icon(Icons.medication_rounded, size: 15, color: c.text3),
                ),
                const SizedBox(width: 8),
                Text('${visit.meds.length} medicines',
                    style: AppText.caption.copyWith(fontSize: 12.5, color: c.text2)),
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
