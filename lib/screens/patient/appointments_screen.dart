import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/clinical_models.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

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

  void _reload() => setState(() => _future = _service.myAppointments());

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
                final cancellable = a.status == 'pending' || a.status == 'confirmed';
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
