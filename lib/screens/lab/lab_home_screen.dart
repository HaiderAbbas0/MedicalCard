import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/clinical_models.dart';
import '../../services/lab_service.dart';
import '../../theme/app_colors.dart';
import '../common/role_app_bar.dart';

/// Lab worker home — priority-sorted order queue with sample tracking and
/// result upload (Scope §7.3 / UC-L001). Patient identity is masked.
class LabHomeScreen extends StatefulWidget {
  const LabHomeScreen({super.key});

  @override
  State<LabHomeScreen> createState() => _LabHomeScreenState();
}

class _LabHomeScreenState extends State<LabHomeScreen> {
  late final LabService _service;
  Future<List<LabOrderModel>>? _future;

  @override
  void initState() {
    super.initState();
    _service = LabService(context.read<AuthController>().token ?? '');
    _reload();
  }

  void _reload() => setState(() {
    _future = _service.queue();
  });

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _uploadResult(LabOrderModel order) async {
    final commentsCtrl = TextEditingController();
    String? pickedPath;
    String? pickedName;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Upload result — ${order.testName}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: Text(pickedName ?? 'Choose result file (PDF)'),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                  withData: false,
                );
                if (result != null && result.files.single.path != null) {
                  setLocal(() {
                    pickedPath = result.files.single.path;
                    pickedName = result.files.single.name;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: commentsCtrl, decoration: const InputDecoration(hintText: 'Comments (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit result')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final comments = commentsCtrl.text.trim().isEmpty ? null : commentsCtrl.text.trim();
    if (pickedPath != null) {
      // Real multipart upload of the selected file (enforced 25 MB server-side).
      await _act(() => _service.uploadResultFile(order.id, pickedPath!, comments: comments));
    } else {
      // No file chosen — fall back to a metadata-only (simulated) result.
      await _act(() => _service.uploadResult(
            order.id,
            fileName: '${order.testName.replaceAll(' ', '_').toLowerCase()}.pdf',
            comments: comments,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const RoleAppBar(title: 'Lab', subtitle: 'Order queue'),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<LabOrderModel>>(
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
            final orders = snap.data ?? [];
            if (orders.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 140),
                Center(child: Text('No pending orders for your lab.', style: TextStyle(color: c.text3))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _OrderCard(
                order: orders[i],
                onCollect: () => _act(() => _service.markCollected(orders[i].id)),
                onProcess: () => _act(() => _service.markProcessing(orders[i].id)),
                onUpload: () => _uploadResult(orders[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final LabOrderModel order;
  final VoidCallback onCollect;
  final VoidCallback onProcess;
  final VoidCallback onUpload;

  const _OrderCard({
    required this.order,
    required this.onCollect,
    required this.onProcess,
    required this.onUpload,
  });

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order.testName, style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 16))),
          _PriorityChip(order.priority),
        ]),
        const SizedBox(height: 6),
        Text('Patient: ${order.patientDisplay}', style: TextStyle(color: c.text2)),
        if (order.clinicalIndication != null) ...[
          const SizedBox(height: 4),
          Text(order.clinicalIndication!, style: TextStyle(color: c.text3, fontSize: 13)),
        ],
        const SizedBox(height: 6),
        Text('Status: ${order.status.replaceAll('_', ' ')}', style: TextStyle(color: c.text3, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          if (order.status == 'ordered')
            _btn(context, 'Mark collected', c.primary, onCollect),
          if (order.status == 'sample_collected')
            _btn(context, 'Mark processing', c.info, onProcess),
          if (order.status == 'processing')
            _btn(context, 'Upload result', c.safe, onUpload),
        ]),
      ]),
    );
  }

  Widget _btn(BuildContext context, String label, Color color, VoidCallback onTap) {
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

class _PriorityChip extends StatelessWidget {
  final String priority;
  const _PriorityChip(this.priority);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Color bg = c.mint, fg = c.mintFg;
    if (priority == 'urgent') { bg = c.warnBg; fg = c.warn; }
    if (priority == 'stat') { bg = c.dangerBg; fg = c.danger; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(priority.toUpperCase(), style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}
