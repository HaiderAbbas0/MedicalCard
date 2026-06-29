import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Patient searches for doctors and books an appointment (P-FR-012/013).
class FindDoctorScreen extends StatefulWidget {
  const FindDoctorScreen({super.key});

  @override
  State<FindDoctorScreen> createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  late final PatientService _service;
  final _searchCtrl = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _service = PatientService(context.read<AuthController>().token ?? '');
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search() => setState(() => _future = _service.searchDoctors(_searchCtrl.text.trim()));

  Future<void> _book(Map<String, dynamic> doctor) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookSheet(service: _service, doctor: doctor),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment requested.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'Find a doctor'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search by name or specialization',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}', style: TextStyle(color: c.danger)));
                }
                final doctors = snap.data ?? [];
                if (doctors.isEmpty) {
                  return Center(child: Text('No doctors found.', style: TextStyle(color: c.text3)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: doctors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _DoctorCard(doctor: doctors[i], onBook: () => _book(doctors[i])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onBook;
  const _DoctorCard({required this.doctor, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final clinic = (doctor['clinic'] as Map?)?.cast<String, dynamic>();
    final fee = doctor['consultation_fee_pkr'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(doctor['full_name']?.toString() ?? '', style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        Text(doctor['specialization_primary']?.toString() ?? '', style: TextStyle(color: c.primary, fontWeight: FontWeight.w600)),
        if (doctor['bio'] != null) ...[
          const SizedBox(height: 6),
          Text(doctor['bio'].toString(), style: TextStyle(color: c.text3, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (clinic != null) Expanded(child: Text(clinic['name']?.toString() ?? '', style: TextStyle(color: c.text2, fontSize: 13))),
          if (fee != null) Text('PKR $fee', style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onBook,
            style: FilledButton.styleFrom(backgroundColor: c.primary),
            child: const Text('Book appointment', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _BookSheet extends StatefulWidget {
  final PatientService service;
  final Map<String, dynamic> doctor;
  const _BookSheet({required this.service, required this.doctor});

  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = 'in_person';
  List<Map<String, dynamic>> _slots = [];
  bool _busy = false;
  String? _error;

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    widget.service.doctorAvailability(widget.doctor['id'].toString()).then((s) {
      if (mounted) setState(() => _slots = s);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_dateCtrl.text.trim().isEmpty || _timeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a date and time.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final clinic = (widget.doctor['clinic'] as Map?)?.cast<String, dynamic>();
      await widget.service.bookAppointment(
        doctorId: widget.doctor['id'].toString(),
        clinicId: clinic?['id']?.toString(),
        date: _dateCtrl.text.trim(),
        time: _timeCtrl.text.trim(),
        type: _type,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Book with ${widget.doctor['full_name']}', style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          if (_slots.isNotEmpty)
            Text(
              'Available: ${_slots.map((s) => '${_dayNames[(s['day_of_week'] as num).toInt()]} ${s['start_time']}-${s['end_time']}').join(', ')}',
              style: TextStyle(color: c.text3, fontSize: 12),
            ),
          const SizedBox(height: 16),
          TextField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
          const SizedBox(height: 12),
          TextField(controller: _timeCtrl, decoration: const InputDecoration(labelText: 'Time (HH:MM)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'in_person', child: Text('In person')),
              DropdownMenuItem(value: 'follow_up', child: Text('Follow-up')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'in_person'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Reason for visit (optional)')),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: TextStyle(color: c.danger))],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: c.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm booking', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
