import '../models/clinical_models.dart';
import 'supabase_client.dart';

/// Doctor-facing data backed by Supabase (Scope §11.3).
class DoctorService {
  DoctorService([String? _]);

  String get _me => currentUid ?? '';
  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<String?> _encPatient(String encId) async {
    final r = await db
        .from('encounters')
        .select('patient_id')
        .eq('id', encId)
        .maybeSingle();
    return r?['patient_id']?.toString();
  }

  // ── Appointments ────────────────────────────────────────────────────────────
  Future<List<AppointmentModel>> appointments({String? date}) async {
    var q = db
        .from('appointments')
        .select('*, patient:profiles!patient_id(id, full_name, card_number)')
        .eq('doctor_id', _me);
    if (date != null) q = q.eq('appointment_date', date);
    final rows = await q as List;
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['patient'] = r['patient'];
      return AppointmentModel.fromJson(m);
    }).toList();
  }

  Future<void> confirmAppointment(String id) async {
    final a = await db
        .from('appointments')
        .update({'status': 'confirmed'})
        .eq('id', id)
        .select()
        .maybeSingle();
    if (a != null) {
      await db.from('notifications').insert({
        'recipient_id': a['patient_id'],
        'type': 'appointment_confirmed',
        'title': 'Appointment confirmed',
        'body': 'Your appointment has been confirmed.',
      });
    }
  }

  Future<void> checkInAppointment(String id) =>
      db.from('appointments').update({'status': 'checked_in'}).eq('id', id);
  Future<void> markNoShow(String id) =>
      db.from('appointments').update({'status': 'no_show'}).eq('id', id);

  // ── Patients ────────────────────────────────────────────────────────────────

  /// P-FR-019 — find a patient from the identifier printed on their card.
  ///
  /// Accepts a 13-digit CNIC (the citizen identity) or a 16-digit Hayaat ID.
  /// The lookup goes through `find_patient_by_identifier`, a SECURITY DEFINER
  /// function: clinical RLS scopes `profiles` to patients the doctor already
  /// has a care relationship with, so a direct select cannot find a walk-in.
  /// The function is staff-only, returns demographics only, and writes its own
  /// audit row for every hit.
  Future<PatientSummary> searchPatient(String identifier) async {
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
    final prof = Map<String, dynamic>.from(rows.first as Map);
    final id = prof['id'].toString();
    final allergies =
        await db.from('allergies').select().eq('patient_id', id) as List;
    final conds =
        await db
                .from('conditions')
                .select()
                .eq('patient_id', id)
                .eq('clinical_status', 'active')
            as List;
    // The lookup RPC already writes the audit row for this access, so the
    // client no longer inserts a second one.
    return PatientSummary.fromJson({
      ...prof,
      'allergies': allergies,
      'active_conditions': conds,
    });
  }

  Future<List<Map<String, dynamic>>> patientTimeline(String patientId) async {
    final rows =
        await db
                .from('encounters')
                .select(
                  '*, conditions(*), medication_requests(*), observations(*), lab_orders(*)',
                )
                .eq('patient_id', patientId)
                .eq('status', 'finalized')
                .order('encounter_date', ascending: false)
            as List;
    final docNames = <String, dynamic>{};
    final ids = rows
        .map((e) => e['doctor_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isNotEmpty) {
      final dn =
          await db.from('profiles').select('id, full_name').inFilter('id', ids)
              as List;
      for (final d in dn) docNames[d['id'].toString()] = d['full_name'];
    }
    return rows.map((e) {
      final m = Map<String, dynamic>.from(e);
      m['medications'] = e['medication_requests'];
      m['doctor_name'] = docNames[e['doctor_id']?.toString()];
      return m;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> patientMedications(
    String patientId,
  ) async {
    final rows =
        await db
                .from('medication_requests')
                .select()
                .eq('patient_id', patientId)
                .eq('status', 'active')
            as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> recordAllergy(
    String patientId,
    String substance, {
    String criticality = 'high',
    String? reaction,
    String severity = 'moderate',
    String? triggerNote,
  }) async {
    await db.from('allergies').insert({
      'patient_id': patientId,
      'recorded_by_id': _me,
      'substance_name': substance,
      'criticality': criticality,
      'severity': severity,
      if (reaction != null) 'reaction_description': reaction,
      if (triggerNote != null) 'trigger_note': triggerNote,
      'clinical_status': 'active',
    });
  }

  // ── Encounters ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createEncounter(
    String patientId, {
    String? chiefComplaint,
    String? specialty,
  }) async {
    final row = await db
        .from('encounters')
        .insert({
          'patient_id': patientId,
          'doctor_id': _me,
          'encounter_date': _today(),
          if (chiefComplaint != null) 'chief_complaint': chiefComplaint,
          if (specialty != null) 'specialty': specialty,
          'status': 'draft',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> updateEncounter(
    String encounterId,
    Map<String, dynamic> patch,
  ) => db.from('encounters').update(patch).eq('id', encounterId);

  Future<Map<String, dynamic>> addCondition(
    String encounterId,
    String display, {
    String? icd10,
  }) async {
    final pid = await _encPatient(encounterId);
    final row = await db
        .from('conditions')
        .insert({
          'encounter_id': encounterId,
          'patient_id': pid,
          'doctor_id': _me,
          'condition_display': display,
          if (icd10 != null) 'icd10_code': icd10,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> addMedication(
    String encounterId,
    String name, {
    num? dosageValue,
    String? dosageUnit,
    String? frequency,
    int? durationDays,
    bool morning = false,
    bool afternoon = false,
    bool evening = false,
    bool night = false,
  }) async {
    final pid = await _encPatient(encounterId);
    final allergies =
        await db
                .from('allergies')
                .select()
                .eq('patient_id', pid ?? '')
                .eq('clinical_status', 'active')
            as List;
    final lower = name.toLowerCase();
    Map? conflict;
    for (final a in allergies) {
      final sub = (a['substance_name'] ?? '').toString().toLowerCase();
      if (sub.isNotEmpty && (lower.contains(sub) || sub.contains(lower))) {
        conflict = a;
        break;
      }
    }
    final med = await db
        .from('medication_requests')
        .insert({
          'encounter_id': encounterId,
          'patient_id': pid,
          'doctor_id': _me,
          'medication_name': name,
          if (dosageValue != null) 'dosage_value': dosageValue,
          if (dosageUnit != null) 'dosage_unit': dosageUnit,
          'route': 'oral',
          if (frequency != null) 'frequency': frequency,
          if (durationDays != null) 'duration_days': durationDays,
          'dose_morning': morning,
          'dose_afternoon': afternoon,
          'dose_evening': evening,
          'dose_night': night,
          'status': 'active',
          'start_date': _today(),
        })
        .select()
        .single();
    return {
      'medication': med,
      'allergy_warning': conflict == null
          ? null
          : 'Patient has a recorded ${conflict['criticality']} allergy to ${conflict['substance_name']}.',
    };
  }

  Future<Map<String, dynamic>> addVital(
    String encounterId,
    String display, {
    num? value,
    String? unit,
  }) async {
    final pid = await _encPatient(encounterId);
    final row = await db
        .from('observations')
        .insert({
          'encounter_id': encounterId,
          'patient_id': pid,
          'authored_by_id': _me,
          'observation_display': display,
          if (value != null) 'value_quantity': value,
          if (unit != null) 'value_unit': unit,
          'observation_date': _today(),
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> labs() async {
    final rows =
        await db
                .from('diagnostic_labs')
                .select('id, name, address_city')
                .eq('status', 'active')
            as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addLabOrder(
    String encounterId,
    String testName,
    String labId, {
    String priority = 'routine',
    String? clinicalIndication,
  }) async {
    final pid = await _encPatient(encounterId);
    final row = await db
        .from('lab_orders')
        .insert({
          'encounter_id': encounterId,
          'patient_id': pid,
          'ordering_doctor_id': _me,
          'lab_id': labId,
          'test_name': testName,
          'priority': priority,
          if (clinicalIndication != null)
            'clinical_indication': clinicalIndication,
          'status': 'ordered',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> finalizeEncounter(String encounterId) async {
    final row = await db
        .from('encounters')
        .update({
          'status': 'finalized',
          'finalized_at': DateTime.now().toIso8601String(),
        })
        .eq('id', encounterId)
        .select()
        .single();
    await db.from('notifications').insert({
      'recipient_id': row['patient_id'],
      'type': 'record_added',
      'title': 'New record added',
      'body': 'A new entry has been added to your health timeline.',
      'resource_id': encounterId,
    });
    return Map<String, dynamic>.from(row);
  }

  // ── Lab review & release ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> labOrdersForReview() async {
    final rows =
        await db
                .from('lab_orders')
                .select(
                  '*, patient:profiles!patient_id(full_name), lab_results(*)',
                )
                .eq('ordering_doctor_id', _me)
                .inFilter('status', ['resulted', 'reviewed'])
            as List;
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      // lab_results.lab_order_id is UNIQUE, so PostgREST returns the result as
      // a single object, not a list. Accept either shape.
      final raw = r['lab_results'];
      m['result'] = raw is Map
          ? raw
          : (raw is List && raw.isNotEmpty)
          ? raw.first
          : null;
      return m;
    }).toList();
  }

  Future<void> reviewLabOrder(String id) => db
      .from('lab_orders')
      .update({
        'status': 'reviewed',
        'reviewed_at': DateTime.now().toIso8601String(),
      })
      .eq('id', id);

  Future<void> releaseLabOrder(String id) async {
    final o = await db
        .from('lab_orders')
        .update({
          'status': 'released_to_patient',
          'released_to_patient_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .maybeSingle();
    if (o != null) {
      await db.from('notifications').insert({
        'recipient_id': o['patient_id'],
        'type': 'lab_result_ready',
        'title': 'Lab result available',
        'body': 'A new lab result has been released to you.',
        'resource_id': id,
      });
    }
  }

  // ── Availability ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> availability() async {
    final rows =
        await db.from('doctor_availability').select().eq('doctor_id', _me)
            as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> addAvailability({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 30,
  }) async {
    if (slotDurationMinutes <= 0) {
      throw Exception('Slot length must be greater than 0 minutes.');
    }
    if (startTime.compareTo(endTime) >= 0) {
      throw Exception('End time must be later than start time.');
    }
    final existing = await db
        .from('doctor_availability')
        .select('id')
        .eq('doctor_id', _me)
        .eq('day_of_week', dayOfWeek)
        .eq('start_time', startTime)
        .eq('end_time', endTime)
        .eq('slot_duration_minutes', slotDurationMinutes)
        .maybeSingle();
    if (existing != null) throw Exception('This weekly slot already exists.');
    await db.from('doctor_availability').insert({
      'doctor_id': _me,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'slot_duration_minutes': slotDurationMinutes,
      'is_active': true,
    });
  }

  Future<void> deleteAvailability(String id) =>
      db.from('doctor_availability').delete().eq('id', id);

  // ── Profile ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> patch) async {
    const baseFields = {'full_name', 'phone_primary', 'email'};
    final base = {
      for (final e in patch.entries)
        if (baseFields.contains(e.key)) e.key: e.value,
    };
    final ext = {
      for (final e in patch.entries)
        if (!baseFields.contains(e.key)) e.key: e.value,
    };
    if (base.isNotEmpty) await db.from('profiles').update(base).eq('id', _me);
    if (ext.isNotEmpty)
      await db.from('doctor_profiles').update(ext).eq('id', _me);
    return (await fetchFullProfile(_me))!;
  }
}
