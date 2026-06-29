import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Patient views their recorded allergy list (P-FR-017).
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

  Color _critColor(BuildContext context, String? crit) {
    final c = context.c;
    return crit == 'high' ? c.danger : (crit == 'low' ? c.safe : c.warn);
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
          final allergies = snap.data ?? [];
          if (allergies.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 48, color: c.safe),
                const SizedBox(height: 12),
                Text('No allergies on record.', style: TextStyle(color: c.text3)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: allergies.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final a = allergies[i];
              final crit = a['criticality']?.toString();
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, color: _critColor(context, crit)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a['substance_name']?.toString() ?? '—', style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16)),
                      if (a['reaction_description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(a['reaction_description'].toString(), style: TextStyle(color: c.text2)),
                      ],
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, children: [
                        _tag(context, (a['category'] ?? 'medication').toString()),
                        if (crit != null) _tag(context, '$crit criticality', color: _critColor(context, crit)),
                      ]),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
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
