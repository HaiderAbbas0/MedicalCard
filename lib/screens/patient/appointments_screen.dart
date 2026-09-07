import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/clinical_models.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';
import '../../widgets/common/voice_input_button.dart';

/// Patient views upcoming/past appointments and can cancel (P-FR-014/015).
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late final PatientService _service;
  Future<List<AppointmentModel>>? _future;

  @override
  void initState() {
    super.initState();
    _service = PatientService(context.read<AuthController>().token ?? '');
    _reload();
  }

  void _reload() => setState(() {
    _future = _service.myAppointments();
  });

  Future<void> _cancel(AppointmentModel a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text('Cancel your appointment with ${a.doctorName ?? 'the doctor'} on ${a.date}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel it')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.cancelAppointment(a.id, reason: 'Cancelled by patient');
        _reload();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'My appointments'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final booked = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: c.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => _BookAppointmentSheet(service: _service),
          );
          if (booked == true) _reload();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Book'),
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
              return ListView(children: [const SizedBox(height: 120), Center(child: Text('${snap.error}', style: TextStyle(color: c.danger)))]);
            }
            final appts = (snap.data ?? [])..sort((a, b) => b.date.compareTo(a.date));
            if (appts.isEmpty) {
              return ListView(children: [const SizedBox(height: 140), Center(child: Text('No appointments yet.', style: TextStyle(color: c.text3)))]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: appts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final a = appts[i];
                final cancellable = _canCancelAppointment(a);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(a.doctorName ?? 'Doctor', style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16))),
                      _StatusChip(a.status),
                    ]),
                    const SizedBox(height: 6),
                    Text('${a.date}  ·  ${a.time}  ·  ${a.type.replaceAll('_', ' ')}', style: TextStyle(color: c.text2)),
                    if (a.clinicName != null) ...[
                      const SizedBox(height: 2),
                      Text(a.clinicName!, style: TextStyle(color: c.text3, fontSize: 13)),
                    ],
                    if (cancellable) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _cancel(a),
                          style: TextButton.styleFrom(foregroundColor: c.danger),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
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

bool _canCancelAppointment(AppointmentModel a) {
  if (a.status != 'pending' && a.status != 'confirmed') return false;
  final when = DateTime.tryParse('${a.date}T${a.time}');
  if (when == null) return true;
  return when.isAfter(DateTime.now().add(const Duration(hours: 24)));
}

class _BookAppointmentSheet extends StatefulWidget {
  final PatientService service;
  const _BookAppointmentSheet({required this.service});

  @override
  State<_BookAppointmentSheet> createState() => _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends State<_BookAppointmentSheet> {
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  List<Map<String, dynamic>> _doctors = const [];
  List<Map<String, dynamic>> _slots = const [];
  Map<String, dynamic>? _doctor;
  Map<String, dynamic>? _slot;
  DateTime? _date;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doctors = await widget.service.searchDoctors(_searchCtrl.text);
      if (mounted) setState(() => _doctors = doctors);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDoctor(Map<String, dynamic> doctor) async {
    final initialDate = DateTime.now().add(const Duration(days: 1));
    setState(() {
      _doctor = doctor;
      _slot = null;
      _slots = const [];
      _date = initialDate;
      _loading = true;
      _error = null;
    });
    await _loadSlots(initialDate);
  }

  Future<void> _loadSlots(DateTime date) async {
    final doctor = _doctor;
    if (doctor == null) return;
    try {
      final slots = await widget.service.availableAppointmentSlots(
        doctorId: doctor['id'].toString(),
        date: date.toIso8601String().substring(0, 10),
      );
      if (mounted) setState(() => _slots = slots);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _slot = null;
        _slots = const [];
        _loading = true;
        _error = null;
      });
      await _loadSlots(picked);
    }
  }

  Future<void> _book() async {
    final doctor = _doctor;
    final slot = _slot;
    final date = _date;
    if (doctor == null || slot == null || date == null) {
      setState(() => _error = 'Choose a doctor, slot, and date.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final clinic = doctor['clinic'] as Map?;
      await widget.service.bookAppointment(
        doctorId: doctor['id'].toString(),
        clinicId: slot['clinic_id']?.toString() ?? clinic?['id']?.toString(),
        date: date.toIso8601String().substring(0, 10),
        time: slot['slot_time'].toString(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment request submitted.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        minChildSize: .58,
        maxChildSize: .96,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Row(
              children: [
                Expanded(child: Text('Book appointment', style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)),
                hintText: 'Search doctor or specialty',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: c.danger)),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_doctor == null)
              ..._doctors.map(_doctorTile)
            else ...[
              _SelectedDoctor(doctor: _doctor!, onChange: () => setState(() { _doctor = null; _slot = null; _date = null; })),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Available appointment times', style: TextStyle(color: c.text, fontWeight: FontWeight.w800))),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(_date == null ? 'Pick date' : _date!.toIso8601String().substring(0, 10)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_slots.isEmpty)
                Text('No open times for this date. Choose another date or try a different doctor.', style: TextStyle(color: c.text3))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _slots.map((slot) {
                    final selected = identical(slot, _slot);
                    final label = (slot['slot_label'] ?? slot['slot_time'] ?? '').toString();
                    return ChoiceChip(
                      selected: selected,
                      label: Text(label),
                      onSelected: (_) => setState(() => _slot = slot),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Reason for visit or notes for doctor',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: VoiceInputButton(controller: _notesCtrl),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : _book,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(_busy ? 'Booking...' : 'Submit appointment request'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _doctorTile(Map<String, dynamic> doctor) {
    final c = context.c;
    final clinic = doctor['clinic'] as Map?;
    return Card(
      elevation: 0,
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.mint, child: Icon(Icons.medical_services_outlined, color: c.mintFg)),
        title: Text(doctor['full_name']?.toString() ?? 'Doctor'),
        subtitle: Text([
          doctor['specialization_primary']?.toString() ?? 'General Medicine',
          if (clinic?['name'] != null) clinic!['name'].toString(),
        ].join(' · ')),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _selectDoctor(doctor),
      ),
    );
  }
}

class _SelectedDoctor extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onChange;
  const _SelectedDoctor({required this.doctor, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final clinic = doctor['clinic'] as Map?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.mint, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.person_rounded, color: c.mintFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${doctor['full_name'] ?? 'Doctor'}\n${doctor['specialization_primary'] ?? 'General Medicine'}${clinic?['name'] == null ? '' : ' · ${clinic!['name']}'}',
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Color bg = c.infoBg, fg = c.info;
    if (status == 'confirmed') { bg = c.safeBg; fg = c.safe; }
    if (status == 'checked_in') { bg = c.mint; fg = c.mintFg; }
    if (status.startsWith('cancelled') || status == 'no_show') { bg = c.dangerBg; fg = c.danger; }
    if (status == 'completed') { bg = c.mint; fg = c.mintFg; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
