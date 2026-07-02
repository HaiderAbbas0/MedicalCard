import 'package:flutter/material.dart';

import '../../services/doctor_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Consolidated active-medication list for a patient across all encounters,
/// as seen by a doctor (P-FR-033).
class PatientMedicationsScreen extends StatefulWidget {
  final DoctorService service;
  final String patientId;
  final String patientName;
  const PatientMedicationsScreen({
    super.key,
    required this.service,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientMedicationsScreen> createState() => _PatientMedicationsScreenState();
}

class _PatientMedicationsScreenState extends State<PatientMedicationsScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.patientMedications(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: BrandAppBar(title: 'Active medications', subtitle: widget.patientName),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}', style: TextStyle(color: c.danger)));
          }
          final meds = snap.data ?? [];
          if (meds.isEmpty) {
            return Center(child: Text('No active medications.', style: TextStyle(color: c.text3)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: meds.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final m = meds[i];
              final dose = [m['dosage_value'], m['dosage_unit']].where((x) => x != null).join(' ');
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                child: Row(children: [
                  Icon(Icons.medication_outlined, color: c.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['medication_name']?.toString() ?? '—', style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        [dose, (m['frequency'] ?? '').toString().replaceAll('_', ' ')].where((x) => x.toString().isNotEmpty).join('  ·  '),
                        style: TextStyle(color: c.text2, fontSize: 13),
                      ),
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
}
