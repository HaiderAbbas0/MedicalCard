import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/doctor_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

const _days = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// Doctor manages weekly availability slots (Scope §7.2 / UC-D005, P-FR-030).
class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({super.key});

  @override
  State<DoctorAvailabilityScreen> createState() =>
      _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState extends State<DoctorAvailabilityScreen> {
  late final DoctorService _service;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _service = DoctorService(context.read<AuthController>().token ?? '');
    _reload();
  }

  void _reload() => setState(() {
    _future = _service.availability();
  });

  Future<void> _addSlot() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSlotSheet(service: _service),
    );
    if (result == true) _reload();
  }

  Future<void> _delete(String id) async {
    try {
      await _service.deleteAvailability(id);
      _reload();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'My availability'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSlot,
        backgroundColor: c.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add slot', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final slots = snap.data ?? [];
          if (slots.isEmpty) {
            return Center(
              child: Text(
                'No availability slots yet.',
                style: TextStyle(color: c.text3),
              ),
            );
          }
          slots.sort(
            (a, b) =>
                (a['day_of_week'] as num).compareTo(b['day_of_week'] as num),
          );
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: slots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = slots[i];
              final dow = (s['day_of_week'] as num).toInt();
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _days[dow],
                            style: TextStyle(
                              color: c.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s['start_time']} – ${s['end_time']}  ·  ${s['slot_duration_minutes']} min slots',
                            style: TextStyle(color: c.text2, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: c.danger),
                      onPressed: () => _delete(s['id'].toString()),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddSlotSheet extends StatefulWidget {
  final DoctorService service;
  const _AddSlotSheet({required this.service});

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  int _day = 1;
  final _startCtrl = TextEditingController(text: '09:00');
  final _endCtrl = TextEditingController(text: '13:00');
  final _durCtrl = TextEditingController(text: '30');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final duration = int.tryParse(_durCtrl.text.trim());
    if (duration == null || duration <= 0) {
      setState(
        () => _error =
            'Slot length must be a whole number greater than 0 minutes.',
      );
      return;
    }
    if (_startCtrl.text.trim().compareTo(_endCtrl.text.trim()) >= 0) {
      setState(() => _error = 'End time must be later than start time.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.addAvailability(
        dayOfWeek: _day,
        startTime: _startCtrl.text.trim(),
        endTime: _endCtrl.text.trim(),
        slotDurationMinutes: duration,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add availability slot',
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _day,
            decoration: const InputDecoration(labelText: 'Day of week'),
            items: List.generate(
              7,
              (i) => DropdownMenuItem(value: i, child: Text(_days[i])),
            ),
            onChanged: (v) => setState(() => _day = v ?? 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startCtrl,
                  decoration: const InputDecoration(labelText: 'Start (HH:MM)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endCtrl,
                  decoration: const InputDecoration(labelText: 'End (HH:MM)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Slot length (minutes)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: c.danger)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save slot',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
