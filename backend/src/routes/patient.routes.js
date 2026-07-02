// ─────────────────────────────────────────────────────────────────────────────
//  Patient routes  (Scope §11.2)  — all require role: patient
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { db, findById, where, update, insert, fullProfile } = require('../store');
const { authenticate, requireRole } = require('../middleware');
const { asyncH } = require('../helpers');
const { log } = require('../audit');
const { notify } = require('../notify');

const router = express.Router();
router.use(authenticate, requireRole('patient'));

const me = (req) => req.auth.profile.id;

// Assemble a full encounter object with nested clinical data.
function encounterDetail(enc) {
  const doctor = findById('profiles', enc.doctor_id);
  const clinic = enc.clinic_id ? findById('clinics', enc.clinic_id) : null;
  return {
    ...enc,
    doctor_name: doctor ? doctor.full_name : 'Unknown',
    clinic_name: clinic ? clinic.name : null,
    conditions: where('conditions', (c) => c.encounter_id === enc.id),
    medications: where('medication_requests', (m) => m.encounter_id === enc.id),
    observations: where('observations', (o) => o.encounter_id === enc.id),
    lab_orders: where('lab_orders', (l) => l.encounter_id === enc.id),
  };
}

// ── GET /me ───────────────────────────────────────────────────────────────────
router.get('/me', asyncH((req, res) => res.json(fullProfile(me(req)))));

// ── PATCH /me (P-FR-018) ──────────────────────────────────────────────────────
router.patch(
  '/me',
  asyncH((req, res) => {
    const id = me(req);
    const baseFields = ['full_name', 'phone_primary', 'email'];
    const extFields = [
      'blood_group', 'height_cm', 'weight_kg', 'address_street', 'address_city',
      'address_province', 'emergency_contact_name', 'emergency_contact_phone',
    ];
    const basePatch = {};
    baseFields.forEach((f) => { if (f in req.body) basePatch[f] = req.body[f]; });
    const extPatch = {};
    extFields.forEach((f) => { if (f in req.body) extPatch[f] = req.body[f]; });

    if (Object.keys(basePatch).length) update('profiles', id, basePatch);
    if (Object.keys(extPatch).length) update('patient_profiles', id, extPatch);

    log({ actorId: id, actorRole: 'patient', action: 'update', resourceType: 'patient_profiles', resourceId: id });
    res.json(fullProfile(id));
  }),
);

// ── GET /me/timeline (P-FR-007/008) ───────────────────────────────────────────
router.get(
  '/me/timeline',
  asyncH((req, res) => {
    const id = me(req);
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const pageSize = Math.min(50, parseInt(req.query.pageSize, 10) || 20);

    let encounters = where('encounters', (e) => e.patient_id === id && e.status === 'finalized')
      .map(encounterDetail)
      .sort((a, b) => new Date(b.encounter_date) - new Date(a.encounter_date));

    // Optional date-range filter.
    const { from, to } = req.query;
    if (from) encounters = encounters.filter((e) => e.encounter_date >= from);
    if (to) encounters = encounters.filter((e) => e.encounter_date <= to);

    const total = encounters.length;
    const items = encounters.slice((page - 1) * pageSize, page * pageSize);
    res.json({ page, pageSize, total, items });
  }),
);

// ── GET /me/timeline/:encounterId ─────────────────────────────────────────────
router.get(
  '/me/encounters/:id',
  asyncH((req, res) => {
    const enc = findById('encounters', req.params.id);
    if (!enc || enc.patient_id !== me(req)) return res.status(404).json({ message: 'Encounter not found.' });
    res.json(encounterDetail(enc));
  }),
);

// ── GET /me/medications (P-FR-010) ────────────────────────────────────────────
router.get(
  '/me/medications',
  asyncH((req, res) => {
    const id = me(req);
    const meds = where('medication_requests', (m) => m.patient_id === id && m.status === 'active')
      .map((m) => ({ ...m, doctor_name: (findById('profiles', m.doctor_id) || {}).full_name }));
    res.json(meds);
  }),
);

// ── GET /me/labs (P-FR-011) ───────────────────────────────────────────────────
router.get(
  '/me/labs',
  asyncH((req, res) => {
    const id = me(req);
    const orders = where('lab_orders', (o) => o.patient_id === id).map((o) => {
      const result = where('lab_results', (r) => r.lab_order_id === o.id)[0] || null;
      const lab = findById('diagnostic_labs', o.lab_id);
      return {
        ...o,
        lab_name: lab ? lab.name : null,
        // Patient only sees the result once it's been released to them (P-FR-011).
        result: o.status === 'released_to_patient' ? result : null,
      };
    });
    res.json(orders);
  }),
);

// ── GET /me/allergies (P-FR-017) ──────────────────────────────────────────────
router.get('/me/allergies', asyncH((req, res) => res.json(where('allergies', (a) => a.patient_id === me(req)))));

// ── GET /me/notifications ─────────────────────────────────────────────────────
router.get('/me/notifications', asyncH((req, res) =>
  res.json(where('notifications', (n) => n.recipient_id === me(req)).sort((a, b) => new Date(b.created_at) - new Date(a.created_at))),
));

// ── GET /me/appointments (P-FR-015) ───────────────────────────────────────────
router.get(
  '/me/appointments',
  asyncH((req, res) => {
    const id = me(req);
    const appts = where('appointments', (a) => a.patient_id === id).map((a) => ({
      ...a,
      doctor_name: (findById('profiles', a.doctor_id) || {}).full_name,
      clinic_name: (findById('clinics', a.clinic_id) || {}).name,
    }));
    res.json(appts);
  }),
);

// ── GET /doctors  (P-FR-012 search) ───────────────────────────────────────────
router.get(
  '/doctors',
  asyncH((req, res) => {
    const q = String(req.query.q || '').toLowerCase();
    const results = db.doctor_profiles
      .map((dp) => {
        const base = findById('profiles', dp.id);
        return base && base.status === 'active' ? { base, dp } : null;
      })
      .filter(Boolean)
      .filter(({ base, dp }) =>
        !q ||
        base.full_name.toLowerCase().includes(q) ||
        (dp.specialization_primary || '').toLowerCase().includes(q),
      )
      .map(({ base, dp }) => ({
        id: base.id,
        full_name: base.full_name,
        specialization_primary: dp.specialization_primary,
        consultation_fee_pkr: dp.consultation_fee_pkr,
        years_of_experience: dp.years_of_experience,
        bio: dp.bio,
        clinic: dp.clinic_id ? findById('clinics', dp.clinic_id) : null,
      }));
    res.json(results);
  }),
);

// ── GET /doctors/:id ──────────────────────────────────────────────────────────
router.get(
  '/doctors/:id',
  asyncH((req, res) => {
    const base = findById('profiles', req.params.id);
    const dp = findById('doctor_profiles', req.params.id);
    if (!base || !dp || base.role !== 'doctor') return res.status(404).json({ message: 'Doctor not found.' });
    res.json({ ...fullProfile(base.id) });
  }),
);

// ── GET /doctors/:id/availability (P-FR-013) ──────────────────────────────────
router.get(
  '/doctors/:id/availability',
  asyncH((req, res) => {
    const slots = where('doctor_availability', (a) => a.doctor_id === req.params.id && a.is_active);
    res.json(slots);
  }),
);

// ── POST /appointments  (P-FR-013 book) ───────────────────────────────────────
router.post(
  '/appointments',
  asyncH((req, res) => {
    const id = me(req);
    const { doctor_id, clinic_id, appointment_date, appointment_time, appointment_type, notes_for_doctor } = req.body;
    if (!doctor_id || !appointment_date || !appointment_time) {
      return res.status(400).json({ message: 'doctor_id, appointment_date, and appointment_time are required.' });
    }

    // P-FR-053 — prevent double-booking a doctor for the same slot.
    const clash = where('appointments', (a) =>
      a.doctor_id === doctor_id &&
      a.appointment_date === appointment_date &&
      a.appointment_time === appointment_time &&
      !['cancelled_by_patient', 'cancelled_by_doctor', 'no_show'].includes(a.status),
    );
    if (clash.length) return res.status(409).json({ message: 'That time slot is no longer available.' });

    const appt = insert('appointments', {
      patient_id: id,
      doctor_id,
      clinic_id: clinic_id || (findById('doctor_profiles', doctor_id) || {}).clinic_id || null,
      appointment_date,
      appointment_time,
      appointment_type: appointment_type || 'in_person',
      status: 'pending',
      booked_by_role: 'patient',
      booked_by_id: id,
      notes_for_doctor: notes_for_doctor || null,
    });

    notify(doctor_id, 'appointment_booked', 'New appointment request', 'A patient has requested an appointment.', appt.id);
    log({ actorId: id, actorRole: 'patient', action: 'create', resourceType: 'appointments', resourceId: appt.id });
    res.status(201).json(appt);
  }),
);

// ── PATCH /appointments/:id/cancel  (P-FR-014) ────────────────────────────────
router.patch(
  '/appointments/:id/cancel',
  asyncH((req, res) => {
    const appt = findById('appointments', req.params.id);
    if (!appt || appt.patient_id !== me(req)) return res.status(404).json({ message: 'Appointment not found.' });
    update('appointments', appt.id, { status: 'cancelled_by_patient', cancellation_reason: req.body.reason || null });
    notify(appt.doctor_id, 'appointment_cancelled', 'Appointment cancelled', 'A patient cancelled their appointment.', appt.id);
    log({ actorId: me(req), actorRole: 'patient', action: 'update', resourceType: 'appointments', resourceId: appt.id });
    res.json(findById('appointments', appt.id));
  }),
);

module.exports = router;
