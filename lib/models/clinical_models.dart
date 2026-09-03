// Lightweight models for the doctor / lab / receptionist clinical workflow.

String _s(dynamic v) => v?.toString() ?? '';
String formatHayaatId(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 16) return value;
  return [
    digits.substring(0, 4),
    digits.substring(4, 8),
    digits.substring(8, 12),
    digits.substring(12, 16),
  ].join(' ');
}

class PatientSummary {
  final String id;
  final String fullName;
  final String cardNumber;
  final String? gender;
  final String? dateOfBirth;
  final String? bloodGroup;
  /// 13-digit CNIC — the citizen identity the doctor searches by (P-FR-019).
  final String? cnic;
  final List<Map<String, dynamic>> allergies;
  final List<Map<String, dynamic>> activeConditions;

  PatientSummary({
    required this.id,
    required this.fullName,
    required this.cardNumber,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    this.cnic,
    this.allergies = const [],
    this.activeConditions = const [],
  });

  factory PatientSummary.fromJson(Map<String, dynamic> j) => PatientSummary(
    id: _s(j['id']),
    fullName: _s(j['full_name']),
    cardNumber: _s(j['card_number']),
    gender: j['gender'] as String?,
    dateOfBirth: j['date_of_birth'] as String?,
    bloodGroup: j['blood_group'] as String?,
    cnic: j['cnic'] as String?,
    allergies: ((j['allergies'] as List?) ?? []).cast<Map<String, dynamic>>(),
    activeConditions: ((j['active_conditions'] as List?) ?? [])
        .cast<Map<String, dynamic>>(),
  );
}

class AppointmentModel {
  final String id;
  final String status;
  final String date;
  final String time;
  final String type;
  final String? notesForDoctor;
  final String? doctorName;
  final String? clinicName;
  final Map<String, dynamic>? patient;

  AppointmentModel({
    required this.id,
    required this.status,
    required this.date,
    required this.time,
    required this.type,
    this.notesForDoctor,
    this.doctorName,
    this.clinicName,
    this.patient,
  });

  String get patientName =>
      patient?['full_name']?.toString() ??
      patient?['display_name']?.toString() ??
      '—';

  factory AppointmentModel.fromJson(Map<String, dynamic> j) => AppointmentModel(
    id: _s(j['id']),
    status: _s(j['status']),
    date: _s(j['appointment_date']),
    time: _s(j['appointment_time']),
    type: _s(j['appointment_type']),
    notesForDoctor: j['notes_for_doctor'] as String?,
    doctorName: j['doctor_name'] as String?,
    clinicName: j['clinic_name'] as String?,
    patient: (j['patient'] as Map?)?.cast<String, dynamic>(),
  );
}

class LabOrderModel {
  final String id;
  final String testName;
  final String priority;
  final String status;
  final String? clinicalIndication;
  final String? specialInstructions;
  final String patientDisplay;

  LabOrderModel({
    required this.id,
    required this.testName,
    required this.priority,
    required this.status,
    this.clinicalIndication,
    this.specialInstructions,
    required this.patientDisplay,
  });

  factory LabOrderModel.fromJson(Map<String, dynamic> j) => LabOrderModel(
    id: _s(j['id']),
    testName: _s(j['test_name']),
    priority: _s(j['priority']),
    status: _s(j['status']),
    clinicalIndication: j['clinical_indication'] as String?,
    specialInstructions: j['special_instructions'] as String?,
    patientDisplay:
        (j['patient'] as Map?)?['display_name']?.toString() ?? 'Patient',
  );
}
