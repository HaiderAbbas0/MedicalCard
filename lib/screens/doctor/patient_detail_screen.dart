import 'package:flutter/material.dart';

import '../../models/clinical_models.dart';
import '../../services/doctor_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';
import 'new_encounter_screen.dart';
import 'patient_medications_screen.dart';

/// Patient record as seen by a doctor: summary, allergies, active conditions,
/// and a reverse-chronological encounter timeline (Scope §7.2 / UC-D002).
class PatientDetailScreen extends StatefulWidget {
  final DoctorService service;
  final PatientSummary patient;
  const PatientDetailScreen({super.key, required this.service, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  Future<List<Map<String, dynamic>>>? _timeline;
  late List<Map<String, dynamic>> _allergies;

  @override
  void initState() {
    super.initState();
    _allergies = List<Map<String, dynamic>>.from(widget.patient.allergies);
    _reload();
  }

  void _reload() => setState(() => _timeline = widget.service.patientTimeline(widget.patient.id));

  Future<void> _recordAllergy() async {
    final substanceCtrl = TextEditingController();
    final reactionCtrl = TextEditingController();
    String criticality = 'high';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Record allergy'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: substanceCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Substance (e.g. Penicillin)')),
            const SizedBox(height: 12),
            TextField(controller: reactionCtrl, decoration: const InputDecoration(hintText: 'Reaction (optional)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: criticality,
              decoration: const InputDecoration(labelText: 'Criticality'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'unable_to_assess', child: Text('Unable to assess')),
              ],
              onChanged: (v) => setLocal(() => criticality = v ?? criticality),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && substanceCtrl.text.trim().isNotEmpty) {
      try {
        await widget.service.recordAllergy(
          widget.patient.id,
          substanceCtrl.text.trim(),
          criticality: criticality,
          reaction: reactionCtrl.text.trim().isEmpty ? null : reactionCtrl.text.trim(),
        );
        setState(() => _allergies.add({'substance_name': substanceCtrl.text.trim(), 'criticality': criticality}));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allergy recorded.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = widget.patient;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: BrandAppBar(
        title: p.fullName,
        subtitle: 'CNIC ${p.cnic}',
        actions: [
          IconButton(
            tooltip: 'Record allergy',
            icon: const Icon(Icons.add_alert_outlined, color: Colors.white),
            onPressed: _recordAllergy,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.primary,
        icon: const Icon(Icons.note_add_outlined, color: Colors.white),
        label: const Text('New encounter', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => NewEncounterScreen(service: widget.service, patient: p),
          ));
          if (created == true) _reload();
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _SummaryCard(patient: p),
          if (_allergies.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AllergyBanner(allergies: _allergies),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.medication_outlined),
            label: const Text('View all active medications'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.primary,
              side: BorderSide(color: c.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 0),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PatientMedicationsScreen(
                service: widget.service,
                patientId: p.id,
                patientName: p.fullName,
              ),
            )),
          ),
          const SizedBox(height: 20),
          Text('Health timeline', style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _timeline,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return Text('No finalized encounters yet.', style: TextStyle(color: c.text3));
              }
              return Column(
                children: items.map((e) => _EncounterTile(encounter: e)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final PatientSummary patient;
  const _SummaryCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(patient.fullName, style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text('CNIC ${patient.cnic}', style: TextStyle(color: c.text2)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (patient.bloodGroup != null) _pill(context, 'Blood ${patient.bloodGroup}'),
            if (patient.gender != null) _pill(context, patient.gender!),
            if (patient.dateOfBirth != null) _pill(context, 'DOB ${patient.dateOfBirth}'),
          ]),
          if (patient.activeConditions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Active conditions', style: TextStyle(color: c.text3, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final cond in patient.activeConditions)
                _pill(context, cond['condition_display']?.toString() ?? '—'),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.mint, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: c.mintFg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _AllergyBanner extends StatelessWidget {
  final List<Map<String, dynamic>> allergies;
  const _AllergyBanner({required this.allergies});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final names = allergies.map((a) => a['substance_name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(13)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, color: c.danger, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Allergies', style: TextStyle(color: c.danger, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(names, style: TextStyle(color: c.text2, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

class _EncounterTile extends StatelessWidget {
  final Map<String, dynamic> encounter;
  const _EncounterTile({required this.encounter});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final conditions = (encounter['conditions'] as List?) ?? [];
    final meds = (encounter['medications'] as List?) ?? [];
    final dx = conditions.isNotEmpty ? conditions.first['condition_display']?.toString() : (encounter['assessment']?.toString() ?? 'Consultation');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(dx ?? 'Consultation', style: TextStyle(color: c.text, fontWeight: FontWeight.w700))),
          Text(encounter['encounter_date']?.toString() ?? '', style: TextStyle(color: c.text3, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        Text('Dr. ${encounter['doctor_name'] ?? ''}', style: TextStyle(color: c.text2, fontSize: 13)),
        if (encounter['chief_complaint'] != null) ...[
          const SizedBox(height: 8),
          Text(encounter['chief_complaint'].toString(), style: TextStyle(color: c.text3, fontSize: 13)),
        ],
        if (meds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${meds.length} medication(s) prescribed', style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}
