import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Patient views their recorded allergy list (P-FR-017): active vs past,
/// with severity, reaction, trigger and notes.
class AllergiesScreen extends StatefulWidget {
  const AllergiesScreen({super.key});

  @override
  State<AllergiesScreen> createState() => _AllergiesScreenState();
}

class _AllergiesScreenState extends State<AllergiesScreen> {
  late final PatientService _service;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _service = PatientService(context.read<AuthController>().token ?? '');
    _future = _service.myAllergies();
  }

  Color _sevColor(BuildContext context, String? sev) {
    final c = context.c;
    switch (sev) {
      case 'severe':
        return c.danger;
      case 'mild':
        return c.safe;
      default:
        return c.warn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'My allergies'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}', style: TextStyle(color: c.danger)));
          }
          final all = snap.data ?? [];
          if (all.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 48, color: c.safe),
                const SizedBox(height: 12),
                Text('No allergies on record.', style: TextStyle(color: c.text3)),
              ]),
            );
          }
          final active = all.where((a) => (a['clinical_status'] ?? 'active') == 'active').toList();
          final past = all.where((a) => (a['clinical_status'] ?? 'active') != 'active').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (active.isNotEmpty) ...[
                _header(context, 'Active', active.length, c.danger),
                for (final a in active) _card(context, a),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                _header(context, 'Past / Resolved', past.length, c.text3),
                for (final a in past) _card(context, a, dimmed: true),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String title, int count, Color accent) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(color: c.text3, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> a, {bool dimmed = false}) {
    final c = context.c;
    final sev = a['severity']?.toString();
    final crit = a['criticality']?.toString();
    final reaction = a['reaction_description']?.toString();
    final trigger = a['trigger_note']?.toString();
    final accent = dimmed ? c.text3 : _sevColor(context, sev);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(dimmed ? Icons.history_rounded : Icons.warning_amber_rounded, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['substance_name']?.toString() ?? '—',
                style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16)),
            if (reaction != null && reaction.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Reaction: $reaction', style: TextStyle(color: c.text2)),
            ],
            if (trigger != null && trigger.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Trigger: $trigger', style: TextStyle(color: c.text2, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (sev != null) _tag(context, '$sev severity', color: _sevColor(context, sev)),
              if (crit != null) _tag(context, '$crit criticality', color: crit == 'high' ? c.danger : c.text3),
              _tag(context, (a['category'] ?? 'medication').toString()),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(BuildContext context, String text, {Color? color}) {
    final c = context.c;
    final col = color ?? c.text3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
