import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/doctor_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/brand_app_bar.dart';

/// Doctor reviews uploaded lab results and releases them to the patient
/// (Scope §7.2 / UC-D004, P-FR-028/029).
class DoctorLabReviewScreen extends StatefulWidget {
  const DoctorLabReviewScreen({super.key});

  @override
  State<DoctorLabReviewScreen> createState() => _DoctorLabReviewScreenState();
}

class _DoctorLabReviewScreenState extends State<DoctorLabReviewScreen> {
  late final DoctorService _service;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _service = DoctorService(context.read<AuthController>().token ?? '');
    _reload();
  }

  void _reload() => setState(() => _future = _service.labOrdersForReview());

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'Lab results to review'),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text('${snap.error}', style: TextStyle(color: c.danger))),
              ]);
            }
            final orders = snap.data ?? [];
            if (orders.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 140),
                Center(child: Text('No lab results awaiting review.', style: TextStyle(color: c.text3))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ResultCard(
                order: orders[i],
                onReview: () => _act(() => _service.reviewLabOrder(orders[i]['id'].toString()), 'Marked as reviewed.'),
                onRelease: () => _act(() => _service.releaseLabOrder(orders[i]['id'].toString()), 'Released to patient.'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onReview;
  final VoidCallback onRelease;
  const _ResultCard({required this.order, required this.onReview, required this.onRelease});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final status = order['status']?.toString() ?? '';
    final patient = (order['patient'] as Map?)?.cast<String, dynamic>();
    final result = (order['result'] as Map?)?.cast<String, dynamic>();
    final structured = (result?['structured_results'] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order['test_name']?.toString() ?? 'Test', style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: status == 'reviewed' ? c.infoBg : c.warnBg, borderRadius: BorderRadius.circular(99)),
            child: Text(status, style: TextStyle(color: status == 'reviewed' ? c.info : c.warn, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Patient: ${patient?['full_name'] ?? '—'}', style: TextStyle(color: c.text2)),
        if (structured.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...structured.map((row) {
            final m = (row as Map).cast<String, dynamic>();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(m['name']?.toString() ?? '', style: TextStyle(color: c.text2))),
                Text('${m['value'] ?? ''} ${m['unit'] ?? ''}', style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
        ],
        if (result?['comments'] != null) ...[
          const SizedBox(height: 8),
          Text(result!['comments'].toString(), style: TextStyle(color: c.text3, fontSize: 13, fontStyle: FontStyle.italic)),
        ],
        if (result?['result_file_name'] != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.picture_as_pdf_outlined, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text(result!['result_file_name'].toString(), style: TextStyle(color: c.primary, fontSize: 13)),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          if (status == 'resulted')
            _btn(context, 'Mark reviewed', c.info, onReview),
          if (status == 'reviewed') ...[
            const Spacer(),
            _btn(context, 'Release to patient', c.safe, onRelease),
          ],
        ]),
      ]),
    );
  }

  Widget _btn(BuildContext context, String label, Color color, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
