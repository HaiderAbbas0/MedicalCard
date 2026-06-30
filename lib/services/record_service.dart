import '../models/record_models.dart';
import 'supabase_client.dart';

/// Patient medical records, read from Supabase and mapped to the UI models.
class RecordService {
  RecordService([String? _]); // token ignored — Supabase client is authenticated

  String _str(dynamic v) => v?.toString() ?? '';

  /// Build an id→value map for a column on a table (e.g. profiles.full_name).
  Future<Map<String, dynamic>> _lookup(String table, List<String> ids, String col) async {
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return {};
    final rows = await db.from(table).select('id, $col').inFilter('id', unique);
    return {for (final r in rows as List) r['id'].toString(): r[col]};
  }

  Future<List<VisitModel>> fetchVisits(String token) async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows = await db
        .from('encounters')
        .select('*, conditions(*), medication_requests(*)')
        .eq('patient_id', uid)
        .eq('status', 'finalized')
        .order('encounter_date', ascending: false) as List;

    final doctorIds = rows.map((e) => _str(e['doctor_id'])).toList();
    final clinicIds = rows.map((e) => _str(e['clinic_id'])).toList();
    final docNames = await _lookup('profiles', doctorIds, 'full_name');
    final docSpec = await _lookup('doctor_profiles', doctorIds, 'specialization_primary');
    final clinicNames = await _lookup('clinics', clinicIds, 'name');

    return rows.map((e) {
      final conds = (e['conditions'] as List? ?? []);
      final meds = (e['medication_requests'] as List? ?? []);
      final dx = conds.isNotEmpty ? _str(conds.first['condition_display']) : _str(e['assessment']);
      // Specialty: explicit encounter specialty, else the doctor's primary.
      var specialty = _str(e['specialty']);
      if (specialty.isEmpty) specialty = _str(docSpec[_str(e['doctor_id'])]);
      if (specialty.isEmpty) specialty = 'General Medicine';
      return VisitModel(
        id: _str(e['id']),
        dx: dx.isEmpty ? 'Consultation' : dx,
        doctor: _str(docNames[_str(e['doctor_id'])]),
        specialty: specialty,
        hospital: _str(clinicNames[_str(e['clinic_id'])]),
        dateLabel: _str(e['encounter_date']),
        time: '',
        symptoms: _str(e['chief_complaint']),
        diagnosis: conds
            .map((c) => '${_str(c['condition_display'])}${c['icd10_code'] != null ? ' (${c['icd10_code']})' : ''}')
            .join(', '),
        diagnosisNote: _str(e['assessment']),
        meds: meds.map<MedModel>((m) {
          final strength = '${m['dosage_value'] ?? ''} ${m['dosage_unit'] ?? ''}'.trim();
          return MedModel(
            name: _str(m['medication_name']),
            strength: strength,
            freq: _str(m['frequency']).replaceAll('_', ' '),
            dur: m['duration_days'] != null ? '${m['duration_days']} days' : 'Ongoing',
          );
        }).toList(),
        followUp: _str(e['follow_up_date']),
        advice: _str(e['plan']),
      );
    }).toList();
  }

  Future<List<PrescriptionModel>> fetchPrescriptions(String token) async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows = await db
        .from('medication_requests')
        .select()
        .eq('patient_id', uid)
        .order('created_at', ascending: false) as List;
    final docNames = await _lookup('profiles', rows.map((m) => _str(m['doctor_id'])).toList(), 'full_name');
    return rows.map((m) {
      return PrescriptionModel(
        id: _str(m['id']),
        name: _str(m['medication_name']),
        strength: '${m['dosage_value'] ?? ''} ${m['dosage_unit'] ?? ''}'.trim(),
        freq: _str(m['frequency']).replaceAll('_', ' '),
        dur: m['duration_days'] != null ? '${m['duration_days']} days' : 'Ongoing',
        by: _str(docNames[_str(m['doctor_id'])]),
        date: _str(m['start_date']),
        active: _str(m['status']) == 'active',
        morning: m['dose_morning'] == true,
        afternoon: m['dose_afternoon'] == true,
        evening: m['dose_evening'] == true,
        night: m['dose_night'] == true,
        durationDays: m['duration_days'] as int?,
      );
    }).toList();
  }

  Future<List<ReportModel>> fetchReports(String token) async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows = await db
        .from('lab_orders')
        .select('*, encounters(specialty)')
        .eq('patient_id', uid)
        .order('ordered_at', ascending: false) as List;
    final labNames = await _lookup('diagnostic_labs', rows.map((o) => _str(o['lab_id'])).toList(), 'name');
    return rows.map((o) {
      final status = _str(o['status']);
      var spec = _str((o['encounters'] as Map?)?['specialty']);
      if (spec.isEmpty) spec = 'Laboratory';
      return ReportModel(
        id: _str(o['id']),
        name: _str(o['test_name']),
        lab: _str(labNames[_str(o['lab_id'])]),
        date: _str(o['ordered_at']).split('T').first,
        status: status == 'released_to_patient' ? 'ready' : status,
        specialty: spec,
      );
    }).toList();
  }
}
