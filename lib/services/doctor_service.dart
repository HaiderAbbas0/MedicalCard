import '../models/clinical_models.dart';
import 'api_client.dart';

/// Doctor-facing API calls (Scope §11.3).
class DoctorService {
  final ApiClient _api;
  DoctorService(String token) : _api = ApiClient(token);

  Future<List<AppointmentModel>> appointments({String? date}) async {
    final res = await _api.get('/doctor/appointments${date != null ? '?date=$date' : ''}');
    return (res as List).map((e) => AppointmentModel.fromJson(e)).toList();
  }

  Future<PatientSummary> searchPatient(String cnic) async {
    final res = await _api.get('/patients/search?cnic=$cnic');
    return PatientSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> patientTimeline(String patientId) async {
    final res = await _api.get('/patients/$patientId/timeline');
    return ((res['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  /// Consolidated active medications across all encounters (P-FR-033).
  Future<List<Map<String, dynamic>>> patientMedications(String patientId) async {
    final res = await _api.get('/patients/$patientId/medications');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createEncounter(String patientId, {String? chiefComplaint}) async {
    final res = await _api.post('/encounters', {
      'patient_id': patientId,
      if (chiefComplaint != null) 'chief_complaint': chiefComplaint,
    });
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addCondition(String encounterId, String display, {String? icd10}) async {
    return await _api.post('/encounters/$encounterId/conditions', {
      'condition_display': display,
      if (icd10 != null) 'icd10_code': icd10,
    }) as Map<String, dynamic>;
  }

  /// Returns the created medication and an `allergy_warning` (nullable).
  Future<Map<String, dynamic>> addMedication(
    String encounterId,
    String name, {
    num? dosageValue,
    String? dosageUnit,
    String? frequency,
  }) async {
    return await _api.post('/encounters/$encounterId/medications', {
      'medication_name': name,
      if (dosageValue != null) 'dosage_value': dosageValue,
      if (dosageUnit != null) 'dosage_unit': dosageUnit,
      if (frequency != null) 'frequency': frequency,
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addVital(String encounterId, String display, {num? value, String? unit}) async {
    return await _api.post('/encounters/$encounterId/vitals', {
      'observation_display': display,
      if (value != null) 'value_quantity': value,
      if (unit != null) 'value_unit': unit,
    }) as Map<String, dynamic>;
  }

  /// Patch draft encounter fields (e.g. follow-up date) before finalizing.
  Future<void> updateEncounter(String encounterId, Map<String, dynamic> patch) =>
      _api.patch('/encounters/$encounterId', patch);

  Future<Map<String, dynamic>> finalizeEncounter(String encounterId) async {
    return await _api.post('/encounters/$encounterId/finalize') as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> labs() async {
    final res = await _api.get('/labs');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addLabOrder(
    String encounterId,
    String testName,
    String labId, {
    String priority = 'routine',
    String? clinicalIndication,
  }) async {
    return await _api.post('/encounters/$encounterId/lab-orders', {
      'test_name': testName,
      'lab_id': labId,
      'priority': priority,
      if (clinicalIndication != null) 'clinical_indication': clinicalIndication,
    }) as Map<String, dynamic>;
  }

  // ── Lab review & release (P-FR-028/029) ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> labOrdersForReview() async {
    final res = await _api.get('/doctor/lab-orders');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> reviewLabOrder(String orderId) => _api.patch('/lab-orders/$orderId/review');
  Future<void> releaseLabOrder(String orderId) => _api.patch('/lab-orders/$orderId/release');

  // ── Availability management (P-FR-030) ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> availability() async {
    final res = await _api.get('/doctor/availability');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> addAvailability({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 30,
  }) =>
      _api.post('/doctor/availability', {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'slot_duration_minutes': slotDurationMinutes,
      });

  Future<void> deleteAvailability(String id) => _api.delete('/doctor/availability/$id');

  // ── Record allergy (P-FR-032) ───────────────────────────────────────────────
  Future<void> recordAllergy(
    String patientId,
    String substance, {
    String criticality = 'high',
    String? reaction,
  }) =>
      _api.post('/patients/$patientId/allergies', {
        'substance_name': substance,
        'criticality': criticality,
        if (reaction != null) 'reaction_description': reaction,
      });

  // ── Update own profile (P-FR-035) ───────────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> patch) async =>
      await _api.patch('/me', patch) as Map<String, dynamic>;

  Future<void> confirmAppointment(String id) => _api.patch('/appointments/$id/confirm');
  Future<void> checkInAppointment(String id) => _api.patch('/appointments/$id/check-in');
  Future<void> markNoShow(String id) => _api.patch('/appointments/$id/no-show');
}
