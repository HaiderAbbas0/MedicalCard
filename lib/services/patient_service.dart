import '../models/clinical_models.dart';
import 'api_client.dart';

/// Patient-facing API calls for the newer features (doctor search, booking,
/// appointments, allergies) layered on top of the existing patient screens.
class PatientService {
  final ApiClient _api;
  PatientService(String token) : _api = ApiClient(token);

  Future<List<Map<String, dynamic>>> searchDoctors(String query) async {
    final res = await _api.get('/doctors?q=${Uri.encodeQueryComponent(query)}');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> doctorAvailability(String doctorId) async {
    final res = await _api.get('/doctors/$doctorId/availability');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<AppointmentModel>> myAppointments() async {
    final res = await _api.get('/me/appointments');
    return (res as List).map((e) => AppointmentModel.fromJson(e)).toList();
  }

  Future<void> bookAppointment({
    required String doctorId,
    String? clinicId,
    required String date,
    required String time,
    String type = 'in_person',
    String? notes,
  }) =>
      _api.post('/appointments', {
        'doctor_id': doctorId,
        if (clinicId != null) 'clinic_id': clinicId,
        'appointment_date': date,
        'appointment_time': time,
        'appointment_type': type,
        if (notes != null) 'notes_for_doctor': notes,
      });

  Future<void> cancelAppointment(String id, {String? reason}) =>
      _api.patch('/appointments/$id/cancel', {if (reason != null) 'reason': reason});

  Future<List<Map<String, dynamic>>> myAllergies() async {
    final res = await _api.get('/me/allergies');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final res = await _api.get('/me/notifications');
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Fetch the patient's own full profile (base + extended).
  Future<Map<String, dynamic>> profile() async {
    return await _api.get('/me') as Map<String, dynamic>;
  }

  /// Update demographics (P-FR-018). Returns the updated profile.
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> patch) async {
    return await _api.patch('/me', patch) as Map<String, dynamic>;
  }
}
