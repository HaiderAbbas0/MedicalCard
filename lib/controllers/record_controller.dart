import 'package:flutter/material.dart';
import '../models/record_models.dart';
import '../services/record_service.dart';

class RecordController extends ChangeNotifier {
  final RecordService _service;

  List<VisitModel> _visits = [];
  List<PrescriptionModel> _prescriptions = [];
  List<ReportModel> _reports = [];

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<VisitModel> get visits => _visits;
  List<PrescriptionModel> get prescriptions => _prescriptions;
  List<ReportModel> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RecordController({RecordService? service}) : _service = service ?? RecordService();

  /// Loads all medical records for the user.
  Future<void> loadRecords(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.fetchVisits(token),
        _service.fetchPrescriptions(token),
        _service.fetchReports(token),
      ]);

      _visits = results[0] as List<VisitModel>;
      _prescriptions = results[1] as List<PrescriptionModel>;
      _reports = results[2] as List<ReportModel>;
    } catch (e) {
      _errorMessage = 'Failed to load medical records: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears stored records on logout.
  void clear() {
    _visits = [];
    _prescriptions = [];
    _reports = [];
    _errorMessage = null;
    notifyListeners();
  }
}
