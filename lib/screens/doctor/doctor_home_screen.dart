import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/clinical_models.dart';
import '../../services/doctor_service.dart';
import '../../theme/app_colors.dart';
import '../common/role_app_bar.dart';
import 'patient_detail_screen.dart';
import 'doctor_lab_review_screen.dart';
import 'doctor_availability_screen.dart';
import 'doctor_profile_screen.dart';

/// Doctor home — today's appointments + patient search by Hayaat ID.
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  late final DoctorService _service;
  Future<List<AppointmentModel>>? _future;

  @override
  void initState() {
    super.initState();
    _service = DoctorService(context.read<AuthController>().token ?? '');
    _reload();
  }

  void _reload() => setState(() => _future = _service.appointments());

  Future<void> _searchPatient() async {
    final hayaatId = await showDialog<String>(
      context: context,
      builder: (_) => const _HayaatIdSearchDialog(),
    );
    if (hayaatId == null || hayaatId.isEmpty) return;
    final digits = hayaatId.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 16) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid 16-digit Hayaat ID.')),
        );
      return;
    }
    try {
      final patient = await _service.searchPatient(digits);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PatientDetailScreen(service: _service, patient: patient),
        ),
      );
    } catch (e) {
      if (mounted) _toast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: RoleAppBar(
        title: 'Doctor',
        subtitle: "Today's schedule",
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              final Widget screen = switch (value) {
                'labs' => const DoctorLabReviewScreen(),
                'availability' => const DoctorAvailabilityScreen(),
                _ => const DoctorProfileScreen(),
              };
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => screen));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'labs',
                child: Text('Lab results to review'),
              ),
              PopupMenuItem(
                value: 'availability',
                child: Text('My availability'),
              ),
              PopupMenuItem(value: 'profile', child: Text('Edit profile')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _searchPatient,
        backgroundColor: c.primary,
        icon: const Icon(Icons.search, color: Colors.white),
        label: const Text(
          'Search patient',
          style: TextStyle(color: Colors.white),
        ),
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
              return _ErrorState(message: '${snap.error}', onRetry: _reload);
            }
            final appts = snap.data ?? [];
            if (appts.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  _EmptyState(text: 'No appointments scheduled.'),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: appts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _AppointmentCard(
                appt: appts[i],
                onConfirm: () =>
                    _act(() => _service.confirmAppointment(appts[i].id)),
                onCheckIn: () =>
                    _act(() => _service.checkInAppointment(appts[i].id)),
                onOpen: () async {
                  final p = appts[i].patient;
                  if (p == null || p['id'] == null) return;
                  try {
                    final summary = await _service.searchPatient(
                      p['card_number']?.toString() ?? '',
                    );
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PatientDetailScreen(
                          service: _service,
                          patient: summary,
                        ),
                      ),
                    );
                  } catch (e) {
                    if (mounted) _toast(context, e.toString());
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      _reload();
    } catch (e) {
      if (mounted) _toast(context, e.toString());
    }
  }
}

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appt;
  final VoidCallback onConfirm;
  final VoidCallback onCheckIn;
  final VoidCallback onOpen;

  const _AppointmentCard({
    required this.appt,
    required this.onConfirm,
    required this.onCheckIn,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appt.patientName,
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusChip(appt.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${appt.date}  ·  ${appt.time}  ·  ${appt.type.replaceAll('_', ' ')}',
              style: TextStyle(color: c.text2),
            ),
            if (appt.notesForDoctor != null &&
                appt.notesForDoctor!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                appt.notesForDoctor!,
                style: TextStyle(color: c.text3, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (appt.status == 'pending')
                  _SmallBtn(
                    label: 'Confirm',
                    color: c.primary,
                    onTap: onConfirm,
                  ),
                if (appt.status == 'confirmed') ...[
                  const SizedBox(width: 8),
                  _SmallBtn(label: 'Check in', color: c.safe, onTap: onCheckIn),
                ],
                const Spacer(),
                Text(
                  'Open record →',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    if (status == 'confirmed') {
      bg = c.safeBg;
      fg = c.safe;
    }
    if (status == 'checked_in') {
      bg = c.mint;
      fg = c.mintFg;
    }
    if (status.startsWith('cancelled') || status == 'no_show') {
      bg = c.dangerBg;
      fg = c.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _HayaatIdSearchDialog extends StatefulWidget {
  const _HayaatIdSearchDialog();
  @override
  State<_HayaatIdSearchDialog> createState() => _HayaatIdSearchDialogState();
}

class _HayaatIdSearchDialogState extends State<_HayaatIdSearchDialog> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search patient by Hayaat ID'),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(hintText: '16-digit Hayaat ID'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Search'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: TextStyle(color: context.c.text3)),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.c.danger),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
