// ─────────────────────────────────────────────────────────────────────────────
//  Doctor routes  (Scope §11.3)  — all require role: doctor
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { db, findById, where, update, insert, fullProfile } = require('../store');
const { authenticate, requireRole } = require('../middleware');
const { asyncH } = require('../helpers');
const { log } = require('../audit');
const { notify } = require('../notify');

const router = express.Router();
router.use(authenticate, requireRole('doctor'));

const me = (req) => req.auth.profile.id;

function patientSummary(patientId) {
  const base = findById('profiles', patientId);
  if (!base || base.role !== 'patient') return null;
  const ext = findById('patient_profiles', patientId) || {};
  return {
    id: base.id,
    full_name: base.full_name,
    cnic: base.cnic,
    date_of_birth: base.date_of_birth,
    gender: base.gender,
    phone_primary: base.phone_primary,
    blood_group: ext.blood_group,
    known_allergies: ext.known_allergies,
    chronic_conditions_summary: ext.chronic_conditions_summary,
    health_card_number: ext.health_card_number,
    active_conditions: where('conditions', (c) => c.patient_id === patientId && c.clinical_status === 'active'),
    allergies: where('allergies', (a) => a.patient_id === patientId),
  };
}

function encounterDetail(enc) {
  return {
    ...enc,
    doctor_name: (findById('profiles', enc.doctor_id) || {}).full_name,
    conditions: where('conditions', (c) => c.encounter_id === enc.id),
    medications: where('medication_requests', (m) => m.encounter_id === enc.id),
    observations: where('observations', (o) => o.encounter_id === enc.id),
    lab_orders: where('lab_orders', (l) => l.encounter_id === enc.id),
  };
}

// ── Own profile (P-FR-035) ────────────────────────────────────────────────────
router.get('/me', asyncH((req, res) => res.json(fullProfile(me(req)))));
router.patch(
  '/me',
  asyncH((req, res) => {
    const id = me(req);
    const baseFields = ['full_name', 'phone_primary', 'email'];
    const extFields = ['bio', 'consultation_fee_pkr', 'specialization_primary', 'specialization_secondary',
      'years_of_experience', 'qualification_mbbs', 'qualification_md', 'qualification_fcps', 'is_available'];
    const bp = {}; baseFields.forEach((f) => { if (f in req.body) bp[f] = req.body[f]; });
    const ep = {}; extFields.forEach((f) => { if (f in req.body) ep[f] = req.body[f]; });
    if (Object.keys(bp).length) update('profiles', id, bp);
    if (Object.keys(ep).length) update('doctor_profiles', id, ep);
    res.json(fullProfile(id));
  }),
);

// ── GET /labs (active diagnostic labs, for placing lab orders) ─────────────────
router.get('/labs', asyncH((req, res) =>
  res.json(db.diagnostic_labs.filter((l) => l.status === 'active').map((l) => ({ id: l.id, name: l.name, address_city: l.address_city }))),
));

// ── GET /patients/search?cnic= (P-FR-019) ─────────────────────────────────────
router.get(
  '/patients/search',
  asyncH((req, res) => {
    const cnic = String(req.query.cnic || '').trim();
    if (!cnic) return res.status(400).json({ message: 'A CNIC query is required.' });
    const base = db.profiles.find((p) => p.cnic === cnic && p.role === 'patient');
    if (!base) return res.status(404).json({ message: 'No patient found with that CNIC.' });
    // Searching surfaces the patient — log the access (audit precondition for timeline).
    log({ actorId: me(req), actorRole: 'doctor', action: 'read', resourceType: 'patient_profiles', resourceId: base.id, patientId: base.id });
    res.json(patientSummary(base.id));
  }),
);

// ── GET /patients/:id (P-FR-020) ──────────────────────────────────────────────
router.get(
  '/patients/:id',
  asyncH((req, res) => {
    const summary = patientSummary(req.params.id);
    if (!summary) return res.status(404).json({ message: 'Patient not found.' });
    log({ actorId: me(req), actorRole: 'doctor', action: 'read', resourceType: 'patient_profiles', resourceId: req.params.id, patientId: req.params.id });
    res.json(summary);
  }),
);

// ── GET /patients/:id/timeline ────────────────────────────────────────────────
router.get(
  '/patients/:id/timeline',
  asyncH((req, res) => {
    const pid = req.params.id;
    if (!findById('profiles', pid)) return res.status(404).json({ message: 'Patient not found.' });
    const items = where('encounters', (e) => e.patient_id === pid && e.status === 'finalized')
      .map(encounterDetail)
      .sort((a, b) => new Date(b.encounter_date) - new Date(a.encounter_date));
    log({ actorId: me(req), actorRole: 'doctor', action: 'read', resourceType: 'encounters', patientId: pid });
    res.json({ items, total: items.length });
  }),
);

// ── GET /patients/:id/medications (P-FR-033 consolidated) ──────────────────────
router.get('/patients/:id/medications', asyncH((req, res) =>
  res.json(where('medication_requests', (m) => m.patient_id === req.params.id && m.status === 'active')),
));

// ── GET /patients/:id/allergies ───────────────────────────────────────────────
router.get('/patients/:id/allergies', asyncH((req, res) =>
  res.json(where('allergies', (a) => a.patient_id === req.params.id)),
));

// ── POST /patients/:id/allergies (P-FR-032) ───────────────────────────────────
router.post(
  '/patients/:id/allergies',
  asyncH((req, res) => {
    const pid = req.params.id;
    if (!findById('profiles', pid)) return res.status(404).json({ message: 'Patient not found.' });
    const { substance_name, allergy_type, category, criticality, reaction_description } = req.body;
    if (!substance_name) return res.status(400).json({ message: 'substance_name is required.' });
    const allergy = insert('allergies', {
      patient_id: pid,
      recorded_by_id: me(req),
      substance_name,
      allergy_type: allergy_type || 'allergy',
      category: category || 'medication',
      criticality: criticality || 'unable_to_assess',
      reaction_description: reaction_description || null,
      clinical_status: 'active',
    });
    res.status(201).json(allergy);
  }),
);

// ── POST /encounters (P-FR-021 create draft) ──────────────────────────────────
router.post(
  '/encounters',
  asyncH((req, res) => {
    const { patient_id, appointment_id, clinic_id, encounter_type, chief_complaint,
      history_of_present_illness, physical_examination_notes, assessment, plan } = req.body;
    if (!patient_id) return res.status(400).json({ message: 'patient_id is required.' });
    if (!findById('profiles', patient_id)) return res.status(404).json({ message: 'Patient not found.' });

    const enc = insert('encounters', {
      patient_id,
      doctor_id: me(req),
      appointment_id: appointment_id || null,
      clinic_id: clinic_id || (findById('doctor_profiles', me(req)) || {}).clinic_id || null,
      encounter_type: encounter_type || 'outpatient',
      encounter_date: new Date().toISOString().slice(0, 10),
      chief_complaint: chief_complaint || null,
      history_of_present_illness: history_of_present_illness || null,
      physical_examination_notes: physical_examination_notes || null,
      assessment: assessment || null,
      plan: plan || null,
      status: 'draft',
    });
    log({ actorId: me(req), actorRole: 'doctor', action: 'create', resourceType: 'encounters', resourceId: enc.id, patientId: patient_id });
    res.status(201).json(encounterDetail(enc));
  }),
);

// Guard: a draft encounter that belongs to this doctor.
function ownDraft(req, res) {
  const enc = findById('encounters', req.params.id);
  if (!enc || enc.doctor_id !== req.auth.profile.id) { res.status(404).json({ message: 'Encounter not found.' }); return null; }
  if (enc.status === 'finalized') { res.status(409).json({ message: 'Encounter is finalized and cannot be edited.' }); return null; }
  return enc;
}

// ── PATCH /encounters/:id (update draft) ──────────────────────────────────────
router.patch(
  '/encounters/:id',
  asyncH((req, res) => {
    const enc = ownDraft(req, res); if (!enc) return;
    const fields = ['chief_complaint', 'history_of_present_illness', 'physical_examination_notes',
      'assessment', 'plan', 'encounter_type', 'follow_up_required', 'follow_up_date', 'follow_up_notes'];
    const patch = {}; fields.forEach((f) => { if (f in req.body) patch[f] = req.body[f]; });
    update('encounters', enc.id, patch);
    res.json(encounterDetail(findById('encounters', enc.id)));
  }),
);

// ── POST /encounters/:id/conditions (P-FR-022) ────────────────────────────────
router.post(
  '/encounters/:id/conditions',
  asyncH((req, res) => {
    const enc = ownDraft(req, res); if (!enc) return;
    const { condition_display, icd10_code, severity, clinical_status, is_chronic, notes } = req.body;
    if (!condition_display) return res.status(400).json({ message: 'condition_display is required.' });
    const cond = insert('conditions', {
      encounter_id: enc.id,
      patient_id: enc.patient_id,
      doctor_id: me(req),
      condition_display,
      icd10_code: icd10_code || null,
      severity: severity || 'unknown',
      clinical_status: clinical_status || 'active',
      is_chronic: !!is_chronic,
      notes: notes || null,
    });
    res.status(201).json(cond);
  }),
);

// ── POST /encounters/:id/medications (P-FR-023 + P-FR-034 allergy check) ───────
router.post(
  '/encounters/:id/medications',
  asyncH((req, res) => {
    const enc = ownDraft(req, res); if (!enc) return;
    const { medication_name, dosage_value, dosage_unit, route, frequency, duration_days, instructions } = req.body;
    if (!medication_name) return res.status(400).json({ message: 'medication_name is required.' });

    // P-FR-034 — warn if patient is allergic to this medication.
    const allergies = where('allergies', (a) => a.patient_id === enc.patient_id && a.clinical_status === 'active');
    const name = medication_name.toLowerCase();
    const conflict = allergies.find((a) => name.includes(a.substance_name.toLowerCase()) || a.substance_name.toLowerCase().includes(name));

    const med = insert('medication_requests', {
      encounter_id: enc.id,
      patient_id: enc.patient_id,
      doctor_id: me(req),
      medication_name,
      dosage_value: dosage_value ?? null,
      dosage_unit: dosage_unit || null,
      route: route || 'oral',
      frequency: frequency || null,
      duration_days: duration_days ?? null,
      instructions: instructions || null,
      status: 'active',
      start_date: new Date().toISOString().slice(0, 10),
    });
    res.status(201).json({
      medication: med,
      allergy_warning: conflict
        ? `Patient has a recorded ${conflict.criticality} allergy to ${conflict.substance_name}.`
        : null,
    });
  }),
);

// ── POST /encounters/:id/vitals (P-FR-024) ────────────────────────────────────
router.post(
  '/encounters/:id/vitals',
  asyncH((req, res) => {
    const enc = ownDraft(req, res); if (!enc) return;
    const { observation_display, value_quantity, value_unit, reference_range_text } = req.body;
    if (!observation_display) return res.status(400).json({ message: 'observation_display is required.' });
    const obs = insert('observations', {
      encounter_id: enc.id,
      patient_id: enc.patient_id,
      authored_by_id: me(req),
      observation_display,
      value_quantity: value_quantity ?? null,
      value_unit: value_unit || null,
      reference_range_text: reference_range_text || null,
      observation_date: new Date().toISOString().slice(0, 10),
    });
    res.status(201).json(obs);
  }),
);

// ── POST /encounters/:id/lab-orders (P-FR-025) ────────────────────────────────
router.post(
  '/encounters/:id/lab-orders',
  asyncH((req, res) => {
    const enc = ownDraft(req, res); if (!enc) return;
    const { test_name, lab_id, priority, clinical_indication, special_instructions } = req.body;
    if (!test_name || !lab_id) return res.status(400).json({ message: 'test_name and lab_id are required.' });
    if (!findById('diagnostic_labs', lab_id)) return res.status(404).json({ message: 'Lab not found.' });
    const order = insert('lab_orders', {
      encounter_id: enc.id,
      patient_id: enc.patient_id,
      ordering_doctor_id: me(req),
      lab_id,
      test_name,
      priority: priority || 'routine',
      clinical_indication: clinical_indication || null,
      special_instructions: special_instructions || null,
      status: 'ordered',
      ordered_at: new Date().toISOString(),
    });
    res.status(201).json(order);
  }),
);

// ── POST /encounters/:id/finalize (P-FR-026) ──────────────────────────────────
router.post(
  '/encounters/:id/finalize',
  asyncH((req, res) => {
    const enc = ownDraft(req, res); if (!enc) return;
    update('encounters', enc.id, { status: 'finalized', finalized_at: new Date().toISOString() });
    log({ actorId: me(req), actorRole: 'doctor', action: 'status_change', resourceType: 'encounters', resourceId: enc.id, patientId: enc.patient_id });
    notify(enc.patient_id, 'record_added', 'New record added', 'A new entry has been added to your health timeline.', enc.id);
    res.json(encounterDetail(findById('encounters', enc.id)));
  }),
);

// ── GET /doctor/appointments?date= (P-FR-031) ─────────────────────────────────
router.get(
  '/doctor/appointments',
  asyncH((req, res) => {
    const id = me(req);
    let appts = where('appointments', (a) => a.doctor_id === id);
    if (req.query.date) appts = appts.filter((a) => a.appointment_date === req.query.date);
    res.json(appts.map((a) => ({ ...a, patient: patientSummary(a.patient_id) })));
  }),
);

// Appointment status transitions (P-FR-031).
function ownAppt(req, res) {
  const a = findById('appointments', req.params.id);
  if (!a || a.doctor_id !== req.auth.profile.id) { res.status(404).json({ message: 'Appointment not found.' }); return null; }
  return a;
}
router.patch('/appointments/:id/confirm', asyncH((req, res) => {
  const a = ownAppt(req, res); if (!a) return;
  update('appointments', a.id, { status: 'confirmed', confirmed_at: new Date().toISOString() });
  notify(a.patient_id, 'appointment_confirmed', 'Appointment confirmed', 'Your appointment has been confirmed.', a.id);
  res.json(findById('appointments', a.id));
}));
router.patch('/appointments/:id/cancel', asyncH((req, res) => {
  const a = ownAppt(req, res); if (!a) return;
  update('appointments', a.id, { status: 'cancelled_by_doctor', cancellation_reason: req.body.reason || null });
  notify(a.patient_id, 'appointment_cancelled', 'Appointment cancelled', 'Your appointment was cancelled by the doctor.', a.id);
  res.json(findById('appointments', a.id));
}));
router.patch('/appointments/:id/check-in', asyncH((req, res) => {
  const a = ownAppt(req, res); if (!a) return;
  update('appointments', a.id, { status: 'checked_in', checked_in_at: new Date().toISOString() });
  res.json(findById('appointments', a.id));
}));
router.patch('/appointments/:id/no-show', asyncH((req, res) => {
  const a = ownAppt(req, res); if (!a) return;
  update('appointments', a.id, { status: 'no_show' });
  res.json(findById('appointments', a.id));
}));

// ── Lab review / release (P-FR-028/029) ───────────────────────────────────────
router.get('/doctor/lab-orders', asyncH((req, res) => {
  const id = me(req);
  const orders = where('lab_orders', (o) => o.ordering_doctor_id === id && ['resulted', 'reviewed'].includes(o.status))
    .map((o) => ({ ...o, patient: patientSummary(o.patient_id), result: where('lab_results', (r) => r.lab_order_id === o.id)[0] || null }));
  res.json(orders);
}));
router.patch('/lab-orders/:id/review', asyncH((req, res) => {
  const o = findById('lab_orders', req.params.id);
  if (!o || o.ordering_doctor_id !== me(req)) return res.status(404).json({ message: 'Lab order not found.' });
  update('lab_orders', o.id, { status: 'reviewed', reviewed_at: new Date().toISOString() });
  res.json(findById('lab_orders', o.id));
}));
router.patch('/lab-orders/:id/release', asyncH((req, res) => {
  const o = findById('lab_orders', req.params.id);
  if (!o || o.ordering_doctor_id !== me(req)) return res.status(404).json({ message: 'Lab order not found.' });
  update('lab_orders', o.id, { status: 'released_to_patient', released_to_patient_at: new Date().toISOString() });
  log({ actorId: me(req), actorRole: 'doctor', action: 'status_change', resourceType: 'lab_orders', resourceId: o.id, patientId: o.patient_id });
  notify(o.patient_id, 'lab_result_ready', 'Lab result available', 'A new lab result has been released to you.', o.id);
  res.json(findById('lab_orders', o.id));
}));

// ── Availability management (P-FR-030) ────────────────────────────────────────
router.get('/doctor/availability', asyncH((req, res) =>
  res.json(where('doctor_availability', (a) => a.doctor_id === me(req))),
));
router.post('/doctor/availability', asyncH((req, res) => {
  const { clinic_id, day_of_week, start_time, end_time, slot_duration_minutes } = req.body;
  if (day_of_week == null || !start_time || !end_time) {
    return res.status(400).json({ message: 'day_of_week, start_time, and end_time are required.' });
  }
  const slot = insert('doctor_availability', {
    doctor_id: me(req),
    clinic_id: clinic_id || (findById('doctor_profiles', me(req)) || {}).clinic_id || null,
    day_of_week,
    start_time,
    end_time,
    slot_duration_minutes: slot_duration_minutes || 30,
    is_active: true,
  });
  res.status(201).json(slot);
}));
router.delete('/doctor/availability/:id', asyncH((req, res) => {
  const a = findById('doctor_availability', req.params.id);
  if (!a || a.doctor_id !== me(req)) return res.status(404).json({ message: 'Slot not found.' });
  db.doctor_availability = db.doctor_availability.filter((s) => s.id !== a.id);
  res.json({ message: 'Slot removed.' });
}));

module.exports = router;
