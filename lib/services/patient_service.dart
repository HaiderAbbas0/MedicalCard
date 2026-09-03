import '../models/clinical_models.dart';
import 'supabase_client.dart';

/// Patient-facing data (doctor search, booking, appointments, allergies,
/// notifications, profile) backed by Supabase.
class PatientService {
  PatientService([String? _]);

  Future<List<Map<String, dynamic>>> searchDoctors(String query) async {
    final rows = await db
        .from('doctor_profiles')
        .select('*, profiles!id(id, full_name, status), clinics(id, name)') as List;
    final q = query.trim().toLowerCase();
    final result = <Map<String, dynamic>>[];
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      if (p == null || p['status'] != 'active') continue;
      final name = (p['full_name'] ?? '').toString();
      final spec = (r['specialization_primary'] ?? '').toString();
      if (q.isNotEmpty && !name.toLowerCase().contains(q) && !spec.toLowerCase().contains(q)) continue;
      final clinic = r['clinics'] as Map?;
      result.add({
        'id': p['id'],
        'full_name': name,
        'specialization_primary': spec,
        'consultation_fee_pkr': r['consultation_fee_pkr'],
        'years_of_experience': r['years_of_experience'],
        'bio': r['bio'],
        'clinic': clinic == null ? null : {'id': clinic['id'], 'name': clinic['name']},
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> doctorAvailability(String doctorId) async {
    final rows = await db
        .from('doctor_availability')
        .select()
        .eq('doctor_id', doctorId)
        .eq('is_active', true) as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> availableAppointmentSlots({
    required String doctorId,
    required String date,
  }) async {
    final rows = await db.rpc('available_appointment_slots', params: {
      'p_doctor': doctorId,
      'p_date': date,
    }) as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<AppointmentModel>> myAppointments() async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows = await db
        .from('appointments')
        .select('*, doctor:profiles!doctor_id(full_name), clinic:clinics(name)')
        .eq('patient_id', uid) as List;
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['doctor_name'] = (r['doctor'] as Map?)?['full_name'];
      m['clinic_name'] = (r['clinic'] as Map?)?['name'];
      return AppointmentModel.fromJson(m);
    }).toList();
  }

  Future<void> bookAppointment({
    required String doctorId,
    String? clinicId,
    required String date,
    required String time,
    String type = 'in_person',
    String? notes,
  }) async {
    await db.rpc('request_patient_appointment', params: {
      'p_doctor': doctorId,
      'p_date': date,
      'p_time': time,
      'p_clinic': clinicId,
      'p_type': type,
      'p_notes': notes,
    });
    // The doctor is notified by the `trg_notify_doctor_appt` DB trigger
    // (see supabase/security.sql) — clients can no longer write notifications
    // for another user.
  }

  Future<void> cancelAppointment(String id, {String? reason}) async {
    await db.from('appointments').update({
      'status': 'cancelled_by_patient',
      if (reason != null) 'cancellation_reason': reason,
    }).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> myAllergies() async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows = await db.from('allergies').select().eq('patient_id', uid) as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows = await db
        .from('notifications')
        .select()
        .eq('recipient_id', uid)
        .order('created_at', ascending: false) as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<int> unreadNotificationCount() async {
    final uid = currentUid;
    if (uid == null) return 0;
    final rows = await db
        .from('notifications')
        .select('id')
        .eq('recipient_id', uid)
        .eq('is_read', false) as List;
    return rows.length;
  }

  Future<void> markNotificationRead(String id) async {
    await db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead() async {
    final uid = currentUid;
    if (uid == null) return;
    await db.from('notifications').update({'is_read': true}).eq('recipient_id', uid).eq('is_read', false);
  }

  Future<Map<String, dynamic>> profile() async {
    return (await fetchFullProfile(currentUid!))!;
  }

  // ── Medication adherence ────────────────────────────────────────────────────
  Future<void> logDose(String medicationId, String doseLabel, String status) async {
    await db.from('medication_logs').insert({
      'medication_id': medicationId,
      'patient_id': currentUid,
      'dose_label': doseLabel,
      'status': status, // taken | skipped
    });
  }

  /// Today's adherence entries, keyed by '<medId>|<doseLabel>' → status.
  Future<Map<String, String>> todaysDoseLog() async {
    final uid = currentUid;
    if (uid == null) return {};
    final start = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db
        .from('medication_logs')
        .select()
        .eq('patient_id', uid)
        .gte('logged_at', '${start}T00:00:00') as List;
    return {for (final r in rows) '${r['medication_id']}|${r['dose_label']}': r['status'].toString()};
  }

  Future<List<Map<String, dynamic>>> doseHistory() async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows = await db
        .from('medication_logs')
        .select('*, medication:medication_requests(medication_name)')
        .eq('patient_id', uid)
        .order('logged_at', ascending: false)
        .limit(50) as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> patch) async {
    final uid = currentUid!;
    const baseFields = {'full_name', 'phone_primary', 'email'};
    const extFields = {
      'blood_group', 'height_cm', 'weight_kg', 'address_street', 'address_city',
      'address_province', 'emergency_contact_name', 'emergency_contact_phone',
    };
    final base = {for (final e in patch.entries) if (baseFields.contains(e.key)) e.key: e.value};
    final ext = {for (final e in patch.entries) if (extFields.contains(e.key)) e.key: e.value};
    if (base.isNotEmpty) await db.from('profiles').update(base).eq('id', uid);
    if (ext.isNotEmpty) await db.from('patient_profiles').update(ext).eq('id', uid);
    return (await fetchFullProfile(uid))!;
  }
}
