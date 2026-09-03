import '../models/clinical_models.dart';
import 'supabase_client.dart';

/// Receptionist data backed by Supabase (Scope §11.5). Demographic + scheduling
/// only — no clinical records.
class ReceptionistService {
  ReceptionistService([String? _]);

  String get _me => currentUid ?? '';

  Future<String?> _myClinic() async {
    final r = await db
        .from('receptionist_profiles')
        .select('clinic_id')
        .eq('id', _me)
        .maybeSingle();
    return r?['clinic_id']?.toString();
  }

  Future<List<AppointmentModel>> clinicAppointments({String? date}) async {
    final clinic = await _myClinic();
    if (clinic == null) return [];
    var q = db
        .from('appointments')
        .select(
          '*, patient:profiles!patient_id(id, full_name, card_number, phone_primary), doctor:profiles!doctor_id(full_name)',
        )
        .eq('clinic_id', clinic);
    if (date != null) q = q.eq('appointment_date', date);
    final rows = await q as List;
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['patient'] = r['patient'];
      m['doctor_name'] = (r['doctor'] as Map?)?['full_name'];
      return AppointmentModel.fromJson(m);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> clinicDoctors() async {
    final clinic = await _myClinic();
    if (clinic == null) return [];
    final rows =
        await db
                .from('doctor_profiles')
                .select(
                  'id, specialization_primary, profiles!id(full_name, status)',
                )
                .eq('clinic_id', clinic)
            as List;
    return rows
        .where((r) => (r['profiles'] as Map?)?['status'] == 'active')
        .map(
          (r) => {
            'id': r['id'],
            'full_name': (r['profiles'] as Map?)?['full_name'] ?? '',
            'specialization_primary': r['specialization_primary'] ?? '',
          },
        )
        .toList();
  }

  /// Find a patient at the front desk by 13-digit CNIC or 16-digit Hayaat ID.
  /// Uses the same staff-only lookup RPC as the doctor so a receptionist can
  /// serve a walk-in without being granted a blanket read over `profiles`.
  Future<Map<String, dynamic>> searchPatient(String identifier) async {
    final digits = identifier.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13 && digits.length != 16) {
      throw Exception('Enter a 13-digit CNIC or a 16-digit Hayaat ID.');
    }
    final rows =
        await db.rpc(
              'find_patient_by_identifier',
              params: {'p_identifier': digits},
            )
            as List;
    if (rows.isEmpty) {
      throw Exception(
        digits.length == 13
            ? 'No patient is registered with that CNIC.'
            : 'No patient found with that Hayaat ID.',
      );
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<void> bookAppointment({
    required String patientId,
    required String doctorId,
    required String date,
    required String time,
    String type = 'in_person',
    String? notes,
  }) async {
    final clinic = await _myClinic();
    await db.from('appointments').insert({
      'patient_id': patientId,
      'doctor_id': doctorId,
      'clinic_id': clinic,
      'appointment_date': date,
      'appointment_time': time,
      'appointment_type': type,
      'status': 'pending',
      'booked_by_role': 'receptionist',
      'booked_by_id': _me,
      if (notes != null) 'notes_for_doctor': notes,
    });
    await db.from('notifications').insert([
      {
        'recipient_id': doctorId,
        'type': 'appointment_booked',
        'title': 'New appointment request',
        'body': 'A receptionist booked an appointment.',
      },
      {
        'recipient_id': patientId,
        'type': 'appointment_booked',
        'title': 'Appointment booked',
        'body': 'An appointment has been booked for you.',
      },
    ]);
  }

  Future<void> checkIn(String appointmentId) => db
      .from('appointments')
      .update({'status': 'checked_in'})
      .eq('id', appointmentId);

  Future<void> cancel(String appointmentId, {String? reason}) => db
      .from('appointments')
      .update({
        'status': 'cancelled_by_patient',
        if (reason != null) 'cancellation_reason': reason,
      })
      .eq('id', appointmentId);
}
