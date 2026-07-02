import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/record_controller.dart';
import '../../models/record_models.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/brand_app_bar.dart';
import '../../widgets/common/press_scale.dart';

/// A single scheduled dose for "today".
class _Dose {
  final PrescriptionModel med;
  final String label; // morning | afternoon | evening | night
  _Dose(this.med, this.label);
  String get key => '${med.id}|$label';
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final PatientService _service;
  Map<String, String> _log = {}; // doseKey -> taken|skipped
  bool _loading = true;
  final _busy = <String>{};

  static const _order = ['morning', 'afternoon', 'evening', 'night'];
  static const _titles = {
    'morning': 'Morning',
    'afternoon': 'Afternoon',
    'evening': 'Evening',
    'night': 'Night',
  };
  static const _icons = {
    'morning': Icons.wb_twilight_rounded,
    'afternoon': Icons.wb_sunny_rounded,
    'evening': Icons.wb_cloudy_rounded,
    'night': Icons.nightlight_round,
  };

  @override
  void initState() {
    super.initState();
    _service = PatientService(context.read<AuthController>().token ?? '');
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      final log = await _service.todaysDoseLog();
      if (mounted) setState(() { _log = log; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mark(_Dose dose, String status) async {
    // Optimistic update, rolled back if the write fails so the UI never shows a
    // dose as logged when it wasn't.
    final previous = _log[dose.key];
    setState(() {
      _busy.add(dose.key);
      _log[dose.key] = status;
    });
    try {
      await _service.logDose(dose.med.id, dose.label, status);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (previous == null) {
            _log.remove(dose.key);
          } else {
            _log[dose.key] = previous;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save — please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(dose.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final records = context.watch<RecordController>();
    final meds = records.activePrescriptions.where((m) => m.doseLabels.isNotEmpty).toList();

    // Bucket doses by time of day.
    final buckets = <String, List<_Dose>>{for (final t in _order) t: []};
    for (final m in meds) {
      for (final label in m.doseLabels) {
        buckets[label]?.add(_Dose(m, label));
      }
    }
    final totalDoses = buckets.values.fold<int>(0, (s, l) => s + l.length);
    final takenCount = _log.values.where((v) => v == 'taken').length;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'Medicine reminders'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : totalDoses == 0
              ? _empty(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _adherenceCard(context, takenCount, totalDoses),
                    const SizedBox(height: 16),
                    for (final t in _order)
                      if (buckets[t]!.isNotEmpty) ...[
                        _timeHeader(context, t),
                        for (final d in buckets[t]!) _doseCard(context, d),
                        const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 8),
                    Center(
                      child: Text('Doses reset each day. Marking helps your doctor track adherence.',
                          textAlign: TextAlign.center,
                          style: AppText.caption.copyWith(color: c.text3)),
                    ),
                  ],
                ),
    );
  }

  Widget _adherenceCard(BuildContext context, int taken, int total) {
    final pct = total == 0 ? 0.0 : taken / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: brandGradient(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                Text('${(pct * 100).round()}%',
                    style: AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's doses",
                    style: AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text('$taken of $total taken',
                    style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeHeader(BuildContext context, String t) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
      child: Row(children: [
        Icon(_icons[t], size: 18, color: c.primary),
        const SizedBox(width: 8),
        Text(_titles[t] ?? t,
            style: AppText.bodyStrong.copyWith(fontSize: 15, color: c.text)),
      ]),
    );
  }

  Widget _doseCard(BuildContext context, _Dose d) {
    final c = context.c;
    final status = _log[d.key];
    final busy = _busy.contains(d.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status == 'taken' ? c.safe.withValues(alpha: 0.5) : c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.safeBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.medication_rounded, color: c.safe, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.med.name,
                    style: AppText.bodyStrong.copyWith(fontSize: 15, color: c.text)),
                if (d.med.strength.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(d.med.strength, style: AppText.caption.copyWith(color: c.text2)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (status == 'taken')
            _stateChip(context, 'Taken', c.safe, c.safeBg, Icons.check_rounded)
          else if (status == 'skipped')
            _stateChip(context, 'Skipped', c.text3, c.bg, Icons.close_rounded)
          else
            Row(children: [
              _actionBtn(context, 'Skip', false, () => _mark(d, 'skipped')),
              const SizedBox(width: 8),
              _actionBtn(context, 'Take', true, () => _mark(d, 'taken')),
            ]),
        ],
      ),
    );
  }

  Widget _stateChip(BuildContext context, String label, Color fg, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: 4),
        Text(label, style: AppText.small.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }

  Widget _actionBtn(BuildContext context, String label, bool primary, VoidCallback onTap) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: primary ? brandGradient(context) : null,
          color: primary ? null : c.bg,
          borderRadius: BorderRadius.circular(10),
          border: primary ? null : Border.all(color: c.border),
        ),
        child: Text(label,
            style: AppText.small.copyWith(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: primary ? Colors.white : c.text2)),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)),
            child: Icon(Icons.alarm_off_rounded, size: 32, color: c.text3),
          ),
          const SizedBox(height: 16),
          Text('No scheduled doses', style: AppText.bodyStrong.copyWith(fontSize: 16, color: c.text)),
          const SizedBox(height: 6),
          Text('When a doctor prescribes a medicine with a daily schedule, your reminders will show here.',
              textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.text3)),
        ]),
      ),
    );
  }
}
