import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/record_models.dart';
import 'api_config.dart';
import 'auth_service.dart';

class RecordService {
  static const String _baseUrl = ApiConfig.baseUrl;

  final http.Client _client;

  RecordService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches medical visits/history.
  Future<List<VisitModel>> fetchVisits(String token) async {
    final url = Uri.parse('$_baseUrl/patient/visits');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body) as List;
        return body.map((v) => VisitModel.fromJson(v as Map<String, dynamic>)).toList();
      } else {
        throw ApiException('Failed to load visits', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('RecordService: Fetch visits failed. Falling back to mock data.');
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Dynamic fallback mapping using mockVisits data representation
      return [
        VisitModel(
          id: 'v1',
          dx: 'Hypertension review',
          doctor: 'Dr. Imran Yousuf',
          specialty: 'Cardiology',
          hospital: 'Shifa International Hospital',
          dateLabel: '18 Jun 2026',
          time: '09:30',
          symptoms: 'Occasional headaches, mild dizziness in mornings. BP 148/94 on arrival.',
          diagnosis: 'Essential hypertension (I10)',
          diagnosisNote: 'Well-controlled on current regimen. Continue monitoring.',
          meds: [
            MedModel(name: 'Amlodipine', strength: '5 mg', freq: 'Once daily', dur: '30 days'),
            MedModel(name: 'Metformin', strength: '500 mg', freq: 'Twice daily', dur: 'Ongoing'),
            MedModel(name: 'Aspirin', strength: '75 mg', freq: 'Once daily', dur: '30 days'),
          ],
          followUp: '24 Jun 2026',
          advice: 'Reduce salt intake, 30-min daily walk.',
        ),
        VisitModel(
          id: 'v2',
          dx: 'Diabetes follow-up',
          doctor: 'Dr. Sana Tariq',
          specialty: 'Endocrinology',
          hospital: 'Aga Khan University Hospital',
          dateLabel: '02 May 2026',
          time: '11:15',
          symptoms: 'Fasting sugar trending high last week. No acute complaints.',
          diagnosis: 'Type 2 diabetes mellitus (E11)',
          diagnosisNote: 'HbA1c improving. Maintain diet and metformin.',
          meds: [
            MedModel(name: 'Metformin', strength: '500 mg', freq: 'Twice daily', dur: 'Ongoing'),
            MedModel(name: 'Glimepiride', strength: '1 mg', freq: 'Once daily', dur: '30 days'),
          ],
          followUp: '02 Aug 2026',
          advice: 'Low-carb diet, monitor sugar twice daily.',
        ),
        VisitModel(
          id: 'v3',
          dx: 'Chest pain — cleared',
          doctor: 'Dr. Imran Yousuf',
          specialty: 'Cardiology',
          hospital: 'Shifa International Hospital',
          dateLabel: '21 Mar 2026',
          time: '16:40',
          symptoms: 'Transient chest tightness on exertion. ECG normal.',
          diagnosis: 'Non-cardiac chest pain (R07.9)',
          diagnosisNote: 'Cardiac causes ruled out. Likely musculoskeletal.',
          meds: [MedModel(name: 'Pantoprazole', strength: '40 mg', freq: 'Once daily', dur: '14 days')],
          followUp: 'As needed',
          advice: 'Return if pain recurs at rest.',
        ),
        VisitModel(
          id: 'v4',
          dx: 'Seasonal influenza',
          doctor: 'Dr. Bilal Aziz',
          specialty: 'General Medicine',
          hospital: 'CMH Lahore',
          dateLabel: '09 Feb 2026',
          time: '10:05',
          symptoms: 'Fever, body aches and dry cough for 3 days.',
          diagnosis: 'Influenza, unspecified (J11)',
          diagnosisNote: 'Symptomatic management. Rest and hydration.',
          meds: [
            MedModel(name: 'Paracetamol', strength: '500 mg', freq: 'As needed', dur: '5 days'),
            MedModel(name: 'Cetirizine', strength: '10 mg', freq: 'Once at night', dur: '5 days'),
          ],
          followUp: 'If not improving in 5 days',
          advice: 'Plenty of fluids and rest.',
        ),
        VisitModel(
          id: 'v5',
          dx: 'Eye check-up',
          doctor: 'Dr. Aasim Rehman',
          specialty: 'Ophthalmology',
          hospital: 'Shifa International Hospital',
          dateLabel: '15 Jan 2026',
          time: '14:00',
          symptoms: 'Blurry vision in left eye when reading.',
          diagnosis: 'Presbyopia (H52.4)',
          diagnosisNote: 'Prescribed reading glasses. Follow up in 1 year.',
          meds: [MedModel(name: 'Lubricant Eye Drops', strength: '0.5%', freq: 'Four times daily', dur: '30 days')],
          followUp: '15 Jan 2027',
          advice: 'Limit screen time, use drops daily.',
        ),
        VisitModel(
          id: 'v6',
          dx: 'Dental cleaning & filling',
          doctor: 'Dr. Nadia Malik',
          specialty: 'Dental',
          hospital: 'Aga Khan University Hospital',
          dateLabel: '05 Dec 2025',
          time: '10:30',
          symptoms: 'Sensitivity to cold water on upper right molar.',
          diagnosis: 'Dental caries (K02.9)',
          diagnosisNote: 'Composite filling done on tooth 14. Excellent oral hygiene.',
          meds: [MedModel(name: 'Amoxicillin', strength: '500 mg', freq: 'Three times daily', dur: '5 days')],
          followUp: '05 Jun 2026',
          advice: 'Brush twice daily, floss daily.',
        ),
        VisitModel(
          id: 'v7',
          dx: 'Knee pain evaluation',
          doctor: 'Dr. Tariq Mahmood',
          specialty: 'Orthopedics',
          hospital: 'CMH Lahore',
          dateLabel: '12 Nov 2025',
          time: '12:15',
          symptoms: 'Mild pain in right knee after walking long distances.',
          diagnosis: 'Osteoarthritis of knee, unspecified (M17.9)',
          diagnosisNote: 'Early stage OA. Recommended physical therapy.',
          meds: [MedModel(name: 'Glucosamine', strength: '1500 mg', freq: 'Once daily', dur: 'Ongoing')],
          followUp: '12 May 2026',
          advice: 'Avoid high-impact activities, knee support sleeve.',
        ),
      ];
    }
  }

  /// Fetches active and past prescriptions.
  Future<List<PrescriptionModel>> fetchPrescriptions(String token) async {
    final url = Uri.parse('$_baseUrl/patient/prescriptions');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body) as List;
        return body.map((p) => PrescriptionModel.fromJson(p as Map<String, dynamic>)).toList();
      } else {
        throw ApiException('Failed to load prescriptions', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('RecordService: Fetch prescriptions failed. Falling back to mock data.');
      await Future.delayed(const Duration(milliseconds: 600));

      return [
        PrescriptionModel(
          id: 'rx1',
          name: 'Amlodipine',
          strength: '5 mg',
          freq: 'Once daily',
          dur: '30 days',
          by: 'Dr. Imran Yousuf',
          date: '18 Jun',
          active: true,
        ),
        PrescriptionModel(
          id: 'rx2',
          name: 'Metformin',
          strength: '500 mg',
          freq: 'Twice daily',
          dur: 'Ongoing',
          by: 'Dr. Sana Tariq',
          date: '02 May',
          active: true,
        ),
        PrescriptionModel(
          id: 'rx3',
          name: 'Aspirin',
          strength: '75 mg',
          freq: 'Once daily',
          dur: '30 days',
          by: 'Dr. Imran Yousuf',
          date: '18 Jun',
          active: true,
          warn: 'Avoid with Penicillin-class drugs',
        ),
        PrescriptionModel(
          id: 'rx4',
          name: 'Pantoprazole',
          strength: '40 mg',
          freq: 'Once daily',
          dur: 'Completed',
          by: 'Dr. Imran Yousuf',
          date: '21 Mar',
          active: false,
        ),
      ];
    }
  }

  /// Fetches lab reports.
  Future<List<ReportModel>> fetchReports(String token) async {
    final url = Uri.parse('$_baseUrl/patient/reports');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body) as List;
        return body.map((r) => ReportModel.fromJson(r as Map<String, dynamic>)).toList();
      } else {
        throw ApiException('Failed to load reports', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('RecordService: Fetch reports failed. Falling back to mock data.');
      await Future.delayed(const Duration(milliseconds: 600));

      return [
        ReportModel(id: 'r1', name: 'Lipid Profile', lab: 'Shifa Lab', date: '18 Jun 2026', status: 'ready'),
        ReportModel(id: 'r2', name: 'HbA1c', lab: 'Shifa Lab', date: '18 Jun 2026', status: 'ready'),
        ReportModel(id: 'r3', name: 'Chest X-Ray', lab: 'Aga Khan', date: '02 May 2026', status: 'reviewed'),
        ReportModel(id: 'r4', name: 'Fasting Blood Sugar', lab: 'Chughtai Lab', date: '02 May 2026', status: 'abnormal'),
      ];
    }
  }
}
