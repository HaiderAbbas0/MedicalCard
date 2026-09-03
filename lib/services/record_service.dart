import '../models/record_models.dart';
import '../models/medical_specialty.dart';
import 'supabase_client.dart';

/// Patient medical records, read from Supabase and mapped to the UI models.
class RecordService {
  RecordService([
    String? _,
  ]); // token ignored — Supabase client is authenticated

  String _str(dynamic v) => v?.toString() ?? '';

  /// Build an id→value map for a column on a table (e.g. profiles.full_name).
  Future<Map<String, dynamic>> _lookup(
    String table,
    List<String> ids,
    String col,
  ) async {
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return {};
    final rows = await db.from(table).select('id, $col').inFilter('id', unique);
    return {for (final r in rows as List) r['id'].toString(): r[col]};
  }

  Future<List<VisitModel>> fetchVisits(String token) async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows =
        await db
                .from('encounters')
                .select('*, conditions(*), medication_requests(*)')
                .eq('patient_id', uid)
                .eq('status', 'finalized')
                .order('encounter_date', ascending: false)
            as List;

    final doctorIds = rows.map((e) => _str(e['doctor_id'])).toList();
    final clinicIds = rows.map((e) => _str(e['clinic_id'])).toList();
    final docNames = await _lookup('profiles', doctorIds, 'full_name');
    final docSpec = await _lookup(
      'doctor_profiles',
      doctorIds,
      'specialization_primary',
    );
    final clinicNames = await _lookup('clinics', clinicIds, 'name');

    return rows.map((e) {
      final conds = (e['conditions'] as List? ?? []);
      final meds = (e['medication_requests'] as List? ?? []);
      final dx = conds.isNotEmpty
          ? _str(conds.first['condition_display'])
          : _str(e['assessment']);
      // Specialty: explicit encounter specialty, else the doctor's primary.
      var specialty = _str(e['specialty']);
      if (specialty.isEmpty) specialty = _str(docSpec[_str(e['doctor_id'])]);
      if (specialty.isEmpty) specialty = 'General Medicine';
      return VisitModel(
        id: _str(e['id']),
        dx: dx.isEmpty ? 'Consultation' : dx,
        doctor: _str(docNames[_str(e['doctor_id'])]),
        specialty: specialty,
        hospital: _str(clinicNames[_str(e['clinic_id'])]),
        dateLabel: _str(e['encounter_date']),
        time: '',
        symptoms: _str(e['chief_complaint']),
        diagnosis: conds
            .map(
              (c) =>
                  '${_str(c['condition_display'])}${c['icd10_code'] != null ? ' (${c['icd10_code']})' : ''}',
            )
            .join(', '),
        diagnosisNote: _str(e['assessment']),
        meds: meds.map<MedModel>((m) {
          final strength =
              '${m['dosage_value'] ?? ''} ${m['dosage_unit'] ?? ''}'.trim();
          return MedModel(
            name: _str(m['medication_name']),
            strength: strength,
            freq: _str(m['frequency']).replaceAll('_', ' '),
            dur: m['duration_days'] != null
                ? '${m['duration_days']} days'
                : 'Ongoing',
          );
        }).toList(),
        followUp: _str(e['follow_up_date']),
        advice: _str(e['plan']),
      );
    }).toList();
  }

  Future<List<PrescriptionModel>> fetchPrescriptions(String token) async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows =
        await db
                .from('medication_requests')
                .select(
                  '*, encounters(prescription_signature_name, prescription_signature_credentials, prescription_signature_footer)',
                )
                .eq('patient_id', uid)
                .order('created_at', ascending: false)
            as List;
    final docNames = await _lookup(
      'profiles',
      rows.map((m) => _str(m['doctor_id'])).toList(),
      'full_name',
    );
    return rows.map((m) {
      final encounter = m['encounters'] as Map?;
      return PrescriptionModel(
        id: _str(m['id']),
        name: _str(m['medication_name']),
        strength: '${m['dosage_value'] ?? ''} ${m['dosage_unit'] ?? ''}'.trim(),
        freq: _str(m['frequency']).replaceAll('_', ' '),
        dur: m['duration_days'] != null
            ? '${m['duration_days']} days'
            : 'Ongoing',
        by: _str(docNames[_str(m['doctor_id'])]),
        date: _str(m['start_date']),
        active: _str(m['status']) == 'active',
        morning: m['dose_morning'] == true,
        afternoon: m['dose_afternoon'] == true,
        evening: m['dose_evening'] == true,
        night: m['dose_night'] == true,
        durationDays: m['duration_days'] as int?,
        route: _str(m['route']),
        instructions: _str(m['instructions']),
        signatureName: _str(encounter?['prescription_signature_name']),
        signatureCredentials: _str(
          encounter?['prescription_signature_credentials'],
        ),
        signatureFooter: _str(encounter?['prescription_signature_footer']),
      );
    }).toList();
  }

  Future<List<ReportModel>> fetchReports(String token) async {
    final uid = currentUid;
    if (uid == null) return [];
    final rows =
        await db
                .from('lab_orders')
                .select('*, encounters(specialty)')
                .eq('patient_id', uid)
                .order('ordered_at', ascending: false)
            as List;
    final labNames = await _lookup(
      'diagnostic_labs',
      rows.map((o) => _str(o['lab_id'])).toList(),
      'name',
    );
    return rows.map((o) {
      final status = _str(o['status']);
      var spec = _str((o['encounters'] as Map?)?['specialty']);
      if (spec.isEmpty) spec = 'Laboratory';
      return ReportModel(
        id: _str(o['id']),
        name: _str(o['test_name']),
        lab: _str(labNames[_str(o['lab_id'])]),
        date: _str(o['ordered_at']).split('T').first,
        status: status == 'released_to_patient' ? 'ready' : status,
        specialty: spec,
      );
    }).toList();
  }

  DateTime _date(dynamic value) =>
      DateTime.tryParse(_str(value)) ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool _isImaging(String value) => RegExp(
    r'\b(x[ -]?ray|ct|mri|ultrasound|sonography|mammogram|mammography|ecg|echo|angiography|pet scan)\b',
    caseSensitive: false,
  ).hasMatch(value);

  Future<List<String>> _signedFiles(String bucket, dynamic paths) async {
    final values = (paths as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    return Future.wait(
      values.map((path) => db.storage.from(bucket).createSignedUrl(path, 3600)),
    );
  }

  /// A normalized, specialty-aware index across every patient-owned clinical
  /// source. Empty specialties never reach the UI because groups are derived
  /// exclusively from this list.
  Future<List<MedicalRecordModel>> fetchMedicalRecords(String token) async {
    final uid = currentUid;
    if (uid == null) return [];
    final records = <MedicalRecordModel>[];

    final encounters =
        await db
                .from('encounters')
                .select(
                  '*, conditions(*), medication_requests(*), observations(*)',
                )
                .eq('patient_id', uid)
                .eq('status', 'finalized')
            as List;
    final doctorIds = encounters.map((row) => _str(row['doctor_id'])).toList();
    final clinicIds = encounters.map((row) => _str(row['clinic_id'])).toList();
    final doctorNames = await _lookup('profiles', doctorIds, 'full_name');
    final doctorSpecialties = await _lookup(
      'doctor_profiles',
      doctorIds,
      'specialization_primary',
    );
    final clinicNames = await _lookup('clinics', clinicIds, 'name');

    for (final raw in encounters) {
      final row = raw as Map<String, dynamic>;
      final encounterId = _str(row['id']);
      final doctorId = _str(row['doctor_id']);
      final clinicId = _str(row['clinic_id']);
      final specialty = MedicalSpecialties.resolve(
        _str(row['specialty']).isNotEmpty
            ? _str(row['specialty'])
            : _str(doctorSpecialties[doctorId]),
      );
      final conditions = (row['conditions'] as List? ?? const []);
      final medications = (row['medication_requests'] as List? ?? const []);
      final observations = (row['observations'] as List? ?? const []);
      final encounterDate = _date(row['encounter_date']);
      final doctor = _str(doctorNames[doctorId]);
      final facility = _str(clinicNames[clinicId]);
      final assessment = _str(row['assessment']);
      final title = conditions.isNotEmpty
          ? _str((conditions.first as Map)['condition_display'])
          : assessment.isNotEmpty
          ? assessment
          : 'Consultation';

      records.add(
        MedicalRecordModel(
          id: 'consultation-$encounterId',
          source: MedicalRecordSource.encounter,
          type: MedicalRecordType.consultation,
          specialtyId: specialty.id,
          title: title,
          date: encounterDate,
          facility: facility,
          doctor: doctor,
          summary: _str(row['chief_complaint']),
          details: {
            'Chief complaint': _str(row['chief_complaint']),
            'History': _str(row['history_of_present_illness']),
            'Examination': _str(row['physical_examination_notes']),
            'Assessment': assessment,
            'Plan': _str(row['plan']),
            'Follow-up': _str(row['follow_up_notes']),
            'Diagnoses': conditions
                .map(
                  (item) => {
                    'name': _str((item as Map)['condition_display']),
                    'code': _str(item['icd10_code']),
                    'severity': _str(item['severity']),
                  },
                )
                .toList(),
          },
        ),
      );

      if (medications.isNotEmpty) {
        records.add(
          MedicalRecordModel(
            id: 'prescription-$encounterId',
            source: MedicalRecordSource.prescription,
            type: MedicalRecordType.prescription,
            specialtyId: specialty.id,
            title: medications.length == 1
                ? _str((medications.first as Map)['medication_name'])
                : 'Prescription · ${medications.length} medicines',
            date: encounterDate,
            facility: facility,
            doctor: doctor,
            summary: _str(row['plan']),
            details: {
              'medications': medications.map((item) {
                final med = item as Map;
                return {
                  'name': _str(med['medication_name']),
                  'strength':
                      '${med['dosage_value'] ?? ''} ${med['dosage_unit'] ?? ''}'
                          .trim(),
                  'route': _str(med['route']),
                  'frequency': _str(med['frequency']).replaceAll('_', ' '),
                  'duration': med['duration_days'] == null
                      ? ''
                      : '${med['duration_days']} days',
                  'instructions': _str(med['instructions']),
                };
              }).toList(),
              'signatureName': _str(row['prescription_signature_name']),
              'signatureCredentials': _str(
                row['prescription_signature_credentials'],
              ),
              'signatureFooter': _str(row['prescription_signature_footer']),
            },
          ),
        );
      }

      if (observations.isNotEmpty) {
        records.add(
          MedicalRecordModel(
            id: 'vitals-$encounterId',
            source: MedicalRecordSource.clinical,
            type: MedicalRecordType.vitalSigns,
            specialtyId: specialty.id,
            title: 'Vital signs & observations',
            date: encounterDate,
            facility: facility,
            doctor: doctor,
            details: {
              'observations': observations.map((item) {
                final observation = item as Map;
                return {
                  'name': _str(observation['observation_display']),
                  'value':
                      '${observation['value_quantity'] ?? ''} ${observation['value_unit'] ?? ''}'
                          .trim(),
                  'range': _str(observation['reference_range_text']),
                };
              }).toList(),
            },
          ),
        );
      }

      for (final item in conditions.where(
        (item) => (item as Map)['is_chronic'] == true,
      )) {
        final condition = item as Map;
        records.add(
          MedicalRecordModel(
            id: 'chronic-${_str(condition['id'])}',
            source: MedicalRecordSource.clinical,
            type: MedicalRecordType.chronicDisease,
            specialtyId: specialty.id,
            title: _str(condition['condition_display']),
            date: _date(condition['created_at']),
            facility: facility,
            doctor: doctor,
            summary: _str(condition['notes']),
            details: {
              'ICD-10 code': _str(condition['icd10_code']),
              'Severity': _str(condition['severity']),
              'Status': _str(condition['clinical_status']),
            },
          ),
        );
      }
    }

    final orders =
        await db
                .from('lab_orders')
                .select('*, lab_results(*), encounters(specialty, clinic_id)')
                .eq('patient_id', uid)
                .eq('status', 'released_to_patient')
            as List;
    final labNames = await _lookup(
      'diagnostic_labs',
      orders.map((row) => _str(row['lab_id'])).toList(),
      'name',
    );
    final orderingDoctors = await _lookup(
      'profiles',
      orders.map((row) => _str(row['ordering_doctor_id'])).toList(),
      'full_name',
    );
    for (final raw in orders) {
      final row = raw as Map<String, dynamic>;
      final resultValue = row['lab_results'];
      final result = resultValue is Map
          ? resultValue
          : resultValue is List && resultValue.isNotEmpty
          ? resultValue.first as Map
          : null;
      final encounter = row['encounters'] as Map?;
      final testName = _str(row['test_name']);
      final imaging = _isImaging(testName);
      final rawSpecialty = _str(encounter?['specialty']);
      final specialty = rawSpecialty.isEmpty
          ? MedicalSpecialties.byId(imaging ? 'radiology' : 'pathology')
          : MedicalSpecialties.resolve(rawSpecialty);
      var files = <String>[];
      final objectPath = _str(result?['result_file_path']);
      if (objectPath.isNotEmpty) {
        files = await _signedFiles('lab-results', [objectPath]);
      } else if (_str(result?['result_file_url']).isNotEmpty) {
        files = [_str(result?['result_file_url'])];
      }
      final fileName = _str(result?['result_file_name']);
      records.add(
        MedicalRecordModel(
          id: 'lab-${_str(row['id'])}',
          source: MedicalRecordSource.lab,
          type: imaging
              ? MedicalRecordType.imaging
              : MedicalRecordType.laboratory,
          specialtyId: specialty.id,
          title: testName,
          date: _date(row['resulted_at'] ?? row['ordered_at']),
          facility: _str(labNames[_str(row['lab_id'])]),
          doctor: _str(orderingDoctors[_str(row['ordering_doctor_id'])]),
          summary: _str(result?['comments']),
          fileUrls: files,
          fileNames: fileName.isEmpty ? const [] : [fileName],
          mimeTypes: fileName.isEmpty ? const [] : [_mimeFromName(fileName)],
          details: {
            'Clinical indication': _str(row['clinical_indication']),
            'Comments': _str(result?['comments']),
            'results': result?['structured_results'] ?? const [],
          },
        ),
      );
    }

    final allergies =
        await db.from('allergies').select('*').eq('patient_id', uid) as List;
    final allergyAuthors = await _lookup(
      'profiles',
      allergies.map((row) => _str(row['recorded_by_id'])).toList(),
      'full_name',
    );
    for (final raw in allergies) {
      final row = raw as Map<String, dynamic>;
      records.add(
        MedicalRecordModel(
          id: 'allergy-${_str(row['id'])}',
          source: MedicalRecordSource.clinical,
          type: MedicalRecordType.allergy,
          specialtyId: 'allergy-immunology',
          title: _str(row['substance_name']),
          date: _date(row['created_at']),
          doctor: _str(allergyAuthors[_str(row['recorded_by_id'])]),
          summary: _str(row['reaction_description']),
          details: {
            'Category': _str(row['category']),
            'Criticality': _str(row['criticality']),
            'Reaction': _str(row['reaction_description']),
            'Status': _str(row['clinical_status']),
          },
        ),
      );
    }

    // Optional original-document source. This catch keeps older databases
    // operational until patient_records.sql is applied.
    try {
      final uploads =
          await db.from('medical_documents').select('*').eq('patient_id', uid)
              as List;
      final uploadDoctors = await _lookup(
        'profiles',
        uploads.map((row) => _str(row['doctor_id'])).toList(),
        'full_name',
      );
      final uploadClinics = await _lookup(
        'clinics',
        uploads.map((row) => _str(row['clinic_id'])).toList(),
        'name',
      );
      for (final raw in uploads) {
        final row = raw as Map<String, dynamic>;
        final files = await _signedFiles(
          'medical-documents',
          row['file_paths'],
        );
        records.add(
          MedicalRecordModel(
            id: 'upload-${_str(row['id'])}',
            source: MedicalRecordSource.upload,
            type: MedicalRecordType.fromDatabase(_str(row['record_type'])),
            specialtyId: MedicalSpecialties.resolve(_str(row['specialty'])).id,
            title: _str(row['title']).isEmpty
                ? 'Medical document'
                : _str(row['title']),
            date: _date(row['record_date']),
            facility: _str(row['facility_name']).isNotEmpty
                ? _str(row['facility_name'])
                : _str(uploadClinics[_str(row['clinic_id'])]),
            doctor: _str(row['doctor_name']).isNotEmpty
                ? _str(row['doctor_name'])
                : _str(uploadDoctors[_str(row['doctor_id'])]),
            summary: _str(row['notes']),
            fileUrls: files,
            fileNames: (row['file_names'] as List? ?? const [])
                .map((item) => item.toString())
                .toList(),
            mimeTypes: (row['mime_types'] as List? ?? const [])
                .map((item) => item.toString())
                .toList(),
            details: Map<String, dynamic>.from(
              row['extracted_metadata'] as Map? ?? const {},
            ),
          ),
        );
      }
    } catch (_) {
      // Migration not installed yet; native clinical records remain available.
    }

    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  String _mimeFromName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.dcm')) return 'application/dicom';
    return 'image/jpeg';
  }
}
