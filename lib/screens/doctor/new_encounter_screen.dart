import 'package:flutter/material.dart';

import '../../models/clinical_models.dart';
import '../../services/doctor_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Create an encounter for a patient: chief complaint, diagnoses, medications
/// (with allergy check), vitals, then finalize (Scope §7.2 / UC-D003).
class NewEncounterScreen extends StatefulWidget {
  final DoctorService service;
  final PatientSummary patient;
  const NewEncounterScreen({super.key, required this.service, required this.patient});

  @override
  State<NewEncounterScreen> createState() => _NewEncounterScreenState();
}

class _NewEncounterScreenState extends State<NewEncounterScreen> {
  final _chiefCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();
  String? _encounterId;
  bool _creating = true;
  bool _busy = false;
  String? _error;

  final List<String> _diagnoses = [];
  final List<String> _medications = [];
  final List<String> _vitals = [];
  final List<String> _labOrders = [];
  List<Map<String, dynamic>> _labs = [];

  @override
  void initState() {
    super.initState();
    _createDraft();
  }

  @override
  void dispose() {
    _chiefCtrl.dispose();
    _followUpCtrl.dispose();
    super.dispose();
  }

  Future<void> _createDraft() async {
    try {
      final enc = await widget.service.createEncounter(widget.patient.id);
      final labs = await widget.service.labs();
      setState(() {
        _encounterId = enc['id']?.toString();
        _labs = labs;
        _creating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _creating = false;
      });
    }
  }

  Future<void> _addDiagnosis() async {
    final value = await _prompt('Add diagnosis', 'Condition (e.g. Hypertension)');
    if (value == null || value.isEmpty || _encounterId == null) return;
    await _run(() async {
      await widget.service.addCondition(_encounterId!, value);
      setState(() => _diagnoses.add(value));
    });
  }

  Future<void> _addMedication() async {
    final value = await _prompt('Prescribe medication', 'Medication name');
    if (value == null || value.isEmpty || _encounterId == null) return;
    await _run(() async {
      final res = await widget.service.addMedication(_encounterId!, value);
      setState(() => _medications.add(value));
      final warning = res['allergy_warning'];
      if (warning != null && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: Icon(Icons.warning_amber_rounded, color: context.c.danger, size: 36),
            title: const Text('Allergy warning'),
            content: Text(warning.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Acknowledge'))],
          ),
        );
      }
    });
  }

  Future<void> _addVital() async {
    final value = await _prompt('Record vital', 'e.g. Blood Pressure Systolic = 130');
    if (value == null || value.isEmpty || _encounterId == null) return;
    await _run(() async {
      // Parse "Name = value" into display + quantity when possible.
      final parts = value.split('=');
      final display = parts.first.trim();
      final qty = parts.length > 1 ? num.tryParse(parts[1].trim()) : null;
      await widget.service.addVital(_encounterId!, display, value: qty);
      setState(() => _vitals.add(value));
    });
  }

  Future<void> _addLabOrder() async {
    if (_encounterId == null) return;
    if (_labs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active labs available.')));
      return;
    }
    final testCtrl = TextEditingController();
    String labId = _labs.first['id'].toString();
    String priority = 'routine';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Order a lab test'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: testCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Test name (e.g. CBC)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: labId,
              decoration: const InputDecoration(labelText: 'Lab'),
              items: _labs.map((l) => DropdownMenuItem(value: l['id'].toString(), child: Text(l['name']?.toString() ?? ''))).toList(),
              onChanged: (v) => labId = v ?? labId,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 'routine', child: Text('Routine')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                DropdownMenuItem(value: 'stat', child: Text('STAT')),
              ],
              onChanged: (v) => setLocal(() => priority = v ?? priority),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Order')),
          ],
        ),
      ),
    );
    if (ok == true && testCtrl.text.trim().isNotEmpty) {
      await _run(() async {
        await widget.service.addLabOrder(_encounterId!, testCtrl.text.trim(), labId, priority: priority);
        setState(() => _labOrders.add('${testCtrl.text.trim()} (${priority.toUpperCase()})'));
      });
    }
  }

  Future<void> _finalize() async {
    if (_encounterId == null) return;
    setState(() => _busy = true);
    try {
      // Persist chief complaint + follow-up onto the draft before locking it.
      final patch = <String, dynamic>{};
      if (_chiefCtrl.text.trim().isNotEmpty) patch['chief_complaint'] = _chiefCtrl.text.trim();
      if (_followUpCtrl.text.trim().isNotEmpty) {
        patch['follow_up_required'] = true;
        patch['follow_up_date'] = _followUpCtrl.text.trim();
      }
      if (patch.isNotEmpty) await widget.service.updateEncounter(_encounterId!, patch);
      await widget.service.finalizeEncounter(_encounterId!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<String?> _prompt(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: BrandAppBar(title: 'New encounter', subtitle: widget.patient.fullName),
      body: _creating
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.danger))))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(widget.patient.fullName, style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('CNIC ${widget.patient.cnic}', style: TextStyle(color: c.text2)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _chiefCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Chief complaint',
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Section(title: 'Diagnoses', items: _diagnoses, onAdd: _addDiagnosis),
                    _Section(title: 'Medications', items: _medications, onAdd: _addMedication),
                    _Section(title: 'Vitals', items: _vitals, onAdd: _addVital),
                    _Section(title: 'Lab orders', items: _labOrders, onAdd: _addLabOrder),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _followUpCtrl,
                      decoration: InputDecoration(
                        labelText: 'Follow-up date (YYYY-MM-DD, optional)',
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _finalize,
                        style: FilledButton.styleFrom(
                          backgroundColor: c.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _busy
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Finalize encounter', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: Text('Once finalized, the record is locked.', style: TextStyle(color: c.text3, fontSize: 12))),
                  ],
                ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> items;
  final VoidCallback onAdd;
  const _Section({required this.title, required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w700))),
          TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
        ]),
        if (items.isEmpty)
          Text('None added.', style: TextStyle(color: c.text3, fontSize: 13))
        else
          ...items.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(Icons.check_circle_outline, size: 16, color: c.safe),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e, style: TextStyle(color: c.text2))),
                ]),
              )),
      ]),
    );
  }
}
