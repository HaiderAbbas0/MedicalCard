import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patient/models/record_models.dart';
import 'package:patient/services/report_pdf_service.dart';

void main() {
  // Built-in fonts only: no network fetch of Google fonts inside tests.
  final service = ReportPdfService(fontLoader: () async => null);
  const patient = PdfPatientInfo(
    name: 'Ayesha Hussain',
    hayaatId: '1234567890123456',
    cnic: '3630202000251',
    dob: '1995-03-14',
    gender: 'female',
    bloodGroup: 'O+',
    phone: '03460500025',
  );

  bool isPdf(List<int> bytes) =>
      bytes.length > 500 && ascii.decode(bytes.sublist(0, 4)) == '%PDF';

  test('file names are safe and dated', () {
    expect(
      ReportPdfService.fileName('Doctor prescription', DateTime(2026, 9, 4)),
      'hayaat_doctor_prescription_2026-09-04.pdf',
    );
    expect(
      ReportPdfService.fileName('   ', DateTime(2026, 1, 1)),
      'hayaat_document_2026-01-01.pdf',
    );
  });

  test('builds a visit summary PDF', () async {
    final visit = VisitModel(
      id: 'v1',
      dx: 'Essential hypertension',
      doctor: 'Dr. Sadia Baig',
      specialty: 'General Medicine',
      hospital: 'Al-Shifa Medical Center',
      dateLabel: '2026-09-01',
      time: '10:30',
      symptoms: 'Morning headaches and dizziness.',
      diagnosis: 'Essential (primary) hypertension (I10)',
      diagnosisNote: 'Controlled.',
      meds: [
        MedModel(name: 'Amlodipine', strength: '5 mg', freq: 'once daily', dur: '30 days'),
        MedModel(name: 'Metformin', strength: '500 mg', freq: 'twice daily', dur: 'Ongoing'),
      ],
      followUp: '2026-09-15',
      advice: 'Reduce salt. Walk 30 minutes daily.',
    );
    final bytes = await service.buildVisitPdf(visit, patient);
    expect(isPdf(bytes), isTrue);
  });

  test('builds a full health record PDF', () async {
    final bytes = await service.buildHealthRecordPdf(
      patient: patient,
      visits: [
        VisitModel(
          id: 'v1',
          dx: 'Consultation',
          doctor: 'Dr. Usman Iqbal',
          specialty: 'Dermatology',
          hospital: 'Margalla Health Clinic',
          dateLabel: '2026-08-20',
          time: '',
          symptoms: '',
          diagnosis: '',
          diagnosisNote: '',
          meds: const [],
          followUp: '',
          advice: '',
        ),
      ],
      prescriptions: [
        PrescriptionModel(
          id: 'p1',
          name: 'Amlodipine',
          strength: '5 mg',
          freq: 'once daily',
          dur: '30 days',
          by: 'Dr. Sadia Baig',
          date: '2026-09-01',
          active: true,
        ),
        PrescriptionModel(
          id: 'p2',
          name: 'Old medicine',
          strength: '',
          freq: '',
          dur: '',
          by: '',
          date: '2025-01-01',
          active: false,
        ),
      ],
      reports: [
        ReportModel(
          id: 'r1',
          name: 'Lipid Profile',
          lab: 'Punjab Diagnostic Lab',
          date: '2026-08-30',
          status: 'ready',
        ),
      ],
      allergies: [
        {
          'substance_name': 'Penicillin',
          'category': 'medication',
          'criticality': 'high',
          'reaction_description': 'Urticaria',
          'clinical_status': 'active',
        },
      ],
    );
    expect(isPdf(bytes), isTrue);
  });

  test('builds an empty health record PDF without throwing', () async {
    final bytes = await service.buildHealthRecordPdf(
      patient: const PdfPatientInfo(name: ''),
      visits: const [],
      prescriptions: const [],
      reports: const [],
      allergies: const [],
    );
    expect(isPdf(bytes), isTrue);
  });

  test('renders a prescription record', () async {
    final record = MedicalRecordModel(
      id: 'prescription-e1',
      source: MedicalRecordSource.prescription,
      type: MedicalRecordType.prescription,
      specialtyId: 'general-medicine',
      title: 'Prescription',
      date: DateTime(2026, 9, 1),
      facility: 'Al-Shifa Medical Center',
      doctor: 'Dr. Sadia Baig',
      summary: 'Take with food.',
      details: {
        'medications': [
          {
            'name': 'Amlodipine',
            'strength': '5 mg',
            'route': 'oral',
            'frequency': 'once daily',
            'duration': '30 days',
            'instructions': 'Morning.',
          },
        ],
        'signatureName': 'Dr. Sadia Baig',
        'signatureCredentials': 'MBBS, FCPS',
        'signatureFooter': 'PMDC-50005',
      },
    );
    final bytes = await service.buildRecordPdf(record, patient);
    expect(isPdf(bytes), isTrue);
  });

  test('renders a consultation record with nested detail tables', () async {
    final record = MedicalRecordModel(
      id: 'consultation-e1',
      source: MedicalRecordSource.encounter,
      type: MedicalRecordType.consultation,
      specialtyId: 'general-medicine',
      title: 'Essential hypertension',
      date: DateTime(2026, 9, 1),
      doctor: 'Dr. Sadia Baig',
      summary: 'Headaches.',
      details: {
        'Chief complaint': 'Headaches.',
        'History': '',
        'Plan': 'Continue regimen.',
        'Diagnoses': [
          {'name': 'Essential hypertension', 'code': 'I10', 'severity': 'moderate'},
        ],
      },
    );
    final bytes = await service.buildRecordPdf(record, patient);
    expect(isPdf(bytes), isTrue);
  });
}
