import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/clinical_models.dart';
import '../../services/receptionist_service.dart';
import '../../theme/app_colors.dart';
import '../common/role_app_bar.dart';

/// Receptionist home — today's clinic schedule with check-in, plus a walk-in
/// booking flow (Scope §7.4 / UC-R001..R003). Demographic data only.
class ReceptionHomeScreen extends StatefulWidget {
  const ReceptionHomeScreen({super.key});

  @override
  State<ReceptionHomeScreen> createState() => _ReceptionHomeScreenState();
}

class _ReceptionHomeScreenState extends State<ReceptionHomeScreen> {
  late final ReceptionistService _service;
  Future<List<AppointmentModel>>? _future;

  @override
  void initState() {
    super.initState();
    _service = ReceptionistService(context.read<AuthController>().token ?? '');
    _reload();
  }

  void _reload() => setState(() => _future = _service.clinicAppointments());

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _book() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookingSheet(service: _service),
    );
    if (result == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const RoleAppBar(title: 'Reception', subtitle: "Today's clinic schedule"),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book,
        backgroundColor: c.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New appointment', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<AppointmentModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text('${snap.error}', style: TextStyle(color: c.danger))),
                Center(child: TextButton(onPressed: _reload, child: const Text('Retry'))),
              ]);
            }
            final appts = snap.data ?? [];
            if (appts.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 140),
                Center(child: Text('No appointments for this clinic.', style: TextStyle(color: c.text3))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: appts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final a = appts[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(a.patientName, style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16))),
                      Text(a.time, style: TextStyle(color: c.text2, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${a.doctorName ?? ''}  ·  ${a.status.replaceAll('_', ' ')}', style: TextStyle(color: c.text3, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(children: [
                      if (a.status == 'confirmed' || a.status == 'pending')
                        TextButton(
                          onPressed: () => _act(() => _service.checkIn(a.id)),
                          style: TextButton.styleFrom(
                            backgroundColor: c.safe.withValues(alpha: 0.12),
                            foregroundColor: c.safe,
                          ),
                          child: const Text('Check in', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(width: 8),
                      if (!a.status.startsWith('cancelled'))
                        TextButton(
                          onPressed: () => _act(() => _service.cancel(a.id, reason: 'Cancelled at reception')),
                          style: TextButton.styleFrom(foregroundColor: c.danger),
                          child: const Text('Cancel'),
                        ),
                    ]),
                  ]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Bottom sheet: search patient by CNIC → pick doctor → date/time → book.
class _BookingSheet extends StatefulWidget {
  final ReceptionistService service;
  const _BookingSheet({required this.service});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _cnicCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _doctors = [];
  String? _doctorId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.service.clinicDoctors().then((d) {
      if (mounted) setState(() => _doctors = d);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _cnicCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _findPatient() async {
    setState(() { _error = null; _busy = true; });
    try {
      final p = await widget.service.searchPatient(_cnicCtrl.text.trim());
      setState(() => _patient = p);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_patient == null || _doctorId == null || _dateCtrl.text.isEmpty || _timeCtrl.text.isEmpty) {
      setState(() => _error = 'Find a patient and fill in doctor, date, and time.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.service.bookAppointment(
        patientId: _patient!['id'].toString(),
        doctorId: _doctorId!,
        date: _dateCtrl.text.trim(),
        time: _timeCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = e.toString(); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New appointment', style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: _cnicCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Patient CNIC'))),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy ? null : _findPatient, child: const Text('Find')),
          ]),
          if (_patient != null) ...[
            const SizedBox(height: 8),
            Text('Patient: ${_patient!['full_name']}', style: TextStyle(color: c.safe, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _doctorId,
            decoration: const InputDecoration(labelText: 'Doctor'),
            items: _doctors
                .map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['full_name']?.toString() ?? '')))
                .toList(),
            onChanged: (v) => setState(() => _doctorId = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
          const SizedBox(height: 12),
          TextField(controller: _timeCtrl, decoration: const InputDecoration(labelText: 'Time (HH:MM)')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: c.danger)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: c.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Book appointment', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
