import '../models/clinical_models.dart';
import 'api_client.dart';

/// Receptionist-facing API calls (Scope §11.5).
class ReceptionistService {
  final ApiClient _api;
  ReceptionistService(String token) : _api = ApiClient(token);

  Future<List<AppointmentModel>> clinicAppointments({String? date}) async {
    final res = await _api.get('/clinic/appointments${date != null ? '?date=$date' : ''}');
    return (res as List).map((e) => AppointmentModel.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> clinicDoctors() async {
    final res = await _api.get('/clinic/doctors');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> searchPatient(String cnic) async {
    return await _api.get('/patients/search?cnic=$cnic') as Map<String, dynamic>;
  }

  Future<void> bookAppointment({
    required String patientId,
    required String doctorId,
    required String date,
    required String time,
    String type = 'in_person',
    String? notes,
  }) {
    return _api.post('/appointments', {
      'patient_id': patientId,
      'doctor_id': doctorId,
      'appointment_date': date,
      'appointment_time': time,
      'appointment_type': type,
      if (notes != null) 'notes_for_doctor': notes,
    });
  }

  Future<void> checkIn(String appointmentId) => _api.patch('/appointments/$appointmentId/check-in');
  Future<void> cancel(String appointmentId, {String? reason}) =>
      _api.patch('/appointments/$appointmentId/cancel', {if (reason != null) 'reason': reason});
}
