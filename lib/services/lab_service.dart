import 'dart:io';

import '../models/clinical_models.dart';
import 'supabase_client.dart';

/// Lab-worker data backed by Supabase (Scope §11.4).
class LabService {
  LabService([String? _]);

  String get _me => currentUid ?? '';
  static const _rank = {'stat': 0, 'urgent': 1, 'routine': 2};

  Future<String?> _myLab() async {
    final r = await db.from('lab_worker_profiles').select('lab_id').eq('id', _me).maybeSingle();
    return r?['lab_id']?.toString();
  }

  String _mask(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Patient';
    final last = parts.length > 1 ? '${parts.last[0]}.' : '';
    return '${parts.first} $last'.trim();
  }

  Future<List<LabOrderModel>> queue() async {
    final lab = await _myLab();
    if (lab == null) return [];
    final rows = await db
        .from('lab_orders')
        .select('*, patient:profiles!patient_id(full_name)')
        .eq('lab_id', lab) as List;
    final list = rows
        .where((r) => !['released_to_patient', 'cancelled'].contains(r['status']))
        .map((r) {
      final m = Map<String, dynamic>.from(r);
      m['patient'] = {'display_name': _mask((r['patient'] as Map?)?['full_name']?.toString() ?? '')};
      return m;
    }).toList()
      ..sort((a, b) {
        final pr = (_rank[a['priority']] ?? 9).compareTo(_rank[b['priority']] ?? 9);
        return pr != 0 ? pr : (a['ordered_at'] ?? '').toString().compareTo((b['ordered_at'] ?? '').toString());
      });
    return list.map((e) => LabOrderModel.fromJson(e)).toList();
  }

  Future<void> markCollected(String orderId) => db
      .from('lab_orders')
      .update({'status': 'sample_collected', 'sample_collected_at': DateTime.now().toIso8601String()})
      .eq('id', orderId);

  Future<void> markProcessing(String orderId) =>
      db.from('lab_orders').update({'status': 'processing'}).eq('id', orderId);

  Future<void> uploadResult(
    String orderId, {
    String? fileName,
    String? comments,
    List<Map<String, dynamic>>? structuredResults,
    String? fileUrl,
  }) async {
    final order = await db.from('lab_orders').select().eq('id', orderId).single();
    await db.from('lab_results').insert({
      'lab_order_id': orderId,
      'lab_id': order['lab_id'],
      'uploaded_by': _me,
      'patient_id': order['patient_id'],
      if (fileName != null) 'result_file_name': fileName,
      if (fileUrl != null) 'result_file_url': fileUrl,
      if (comments != null) 'comments': comments,
      if (structuredResults != null) 'structured_results': structuredResults,
    });
    await db
        .from('lab_orders')
        .update({'status': 'resulted', 'resulted_at': DateTime.now().toIso8601String()})
        .eq('id', orderId);
    await db.from('notifications').insert({
      'recipient_id': order['ordering_doctor_id'],
      'type': 'lab_result_uploaded',
      'title': 'Lab result uploaded',
      'body': 'A lab result is ready for your review.',
      'resource_id': orderId,
    });
  }

  /// Upload an actual result file to Supabase Storage, then record it.
  Future<void> uploadResultFile(
    String orderId,
    String filePath, {
    String? comments,
    List<Map<String, dynamic>>? structuredResults,
  }) async {
    final file = File(filePath);
    final name = filePath.split(Platform.pathSeparator).last;
    // Look up the owning patient so the file is stored under "<patient>/<order>/…"
    // — the lab-results bucket is private and RLS scopes reads to owner + staff.
    final order = await db.from('lab_orders').select('patient_id').eq('id', orderId).single();
    final objectPath = '${order['patient_id']}/$orderId/${DateTime.now().millisecondsSinceEpoch}_$name';
    await db.storage.from('lab-results').upload(objectPath, file);
    // Private bucket → signed URL (valid 1 year) instead of a public URL.
    final url = await db.storage.from('lab-results').createSignedUrl(objectPath, 60 * 60 * 24 * 365);
    await uploadResult(orderId, fileName: name, fileUrl: url, comments: comments, structuredResults: structuredResults);
  }
}
