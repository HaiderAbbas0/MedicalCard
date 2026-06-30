import 'package:flutter/material.dart';
import '../models/record_models.dart';
import '../models/clinical_models.dart';
import '../services/record_service.dart';
import '../services/patient_service.dart';

/// Loads and exposes all of the patient's live data (visits, prescriptions,
/// reports, allergies, appointments) and the derived stats the dashboard shows.
class RecordController extends ChangeNotifier {
  final RecordService _service;

  List<VisitModel> _visits = [];
  List<PrescriptionModel> _prescriptions = [];
  List<ReportModel> _reports = [];
  List<Map<String, dynamic>> _allergies = [];
  List<AppointmentModel> _appointments = [];

  bool _isLoading = false;
  bool _loaded = false;
  String? _errorMessage;
  String? _token;
  bool get loaded => _loaded;

  // Raw collections
  List<VisitModel> get visits => _visits;
  List<PrescriptionModel> get prescriptions => _prescriptions;
  List<ReportModel> get reports => _reports;
  List<Map<String, dynamic>> get allergies => _allergies;
  List<AppointmentModel> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Derived dashboard stats ─────────────────────────────────────────────────
  List<PrescriptionModel> get activePrescriptions => _prescriptions.where((p) => p.active).toList();
  int get activeMedsCount => activePrescriptions.length;
  int get allergyCount => _allergies.length;
  int get recentVisitsCount => _visits.length;

  /// Earliest upcoming appointment (today or later, not cancelled/no-show).
  AppointmentModel? get nextAppointment {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final upcoming = _appointments
        .where((a) =>
            a.date.compareTo(today) >= 0 &&
            !a.status.startsWith('cancelled') &&
            a.status != 'no_show' &&
            a.status != 'completed')
        .toList()
      ..sort((a, b) => ('${a.date} ${a.time}').compareTo('${b.date} ${b.time}'));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  RecordController({RecordService? service}) : _service = service ?? RecordService();

  /// Re-loads using the last token (for pull-to-refresh / retry).
  Future<void> refresh() => loadRecords(_token ?? '');

  /// Loads everything the patient app needs in parallel.
  Future<void> loadRecords(String token) async {
    _token = token;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final patientApi = PatientService(token);
    try {
      final results = await Future.wait([
        _service.fetchVisits(token),
        _service.fetchPrescriptions(token),
        _service.fetchReports(token),
        patientApi.myAllergies().catchError((_) => <Map<String, dynamic>>[]),
        patientApi.myAppointments().catchError((_) => <AppointmentModel>[]),
      ]);

      _visits = results[0] as List<VisitModel>;
      _prescriptions = results[1] as List<PrescriptionModel>;
      _reports = results[2] as List<ReportModel>;
      _allergies = results[3] as List<Map<String, dynamic>>;
      _appointments = results[4] as List<AppointmentModel>;
    } catch (e) {
      _errorMessage = 'Failed to load medical records: $e';
    } finally {
      _isLoading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  void clear() {
    _visits = [];
    _prescriptions = [];
    _reports = [];
    _allergies = [];
    _appointments = [];
    _loaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
