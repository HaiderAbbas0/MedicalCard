// ─────────────────────────────────────────────────────────────────────────────
//  Receptionist routes  (Scope §11.5)  — all require role: receptionist
//
//  Boundary (P-FR-044): no clinical record access — only demographic and
//  appointment data, scoped to the receptionist's own clinic.
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { db, findById, where, update, insert } = require('../store');
const { authenticate, requireRole } = require('../middleware');
const { asyncH } = require('../helpers');
const { log } = require('../audit');
const { notify } = require('../notify');

const router = express.Router();
router.use(authenticate, requireRole('receptionist'));

const myClinicId = (req) => (findById('receptionist_profiles', req.auth.profile.id) || {}).clinic_id;

function demographic(patientId) {
  const p = findById('profiles', patientId);
  if (!p) return null;
  return { id: p.id, full_name: p.full_name, cnic: p.cnic, phone_primary: p.phone_primary };
}

// ── GET /clinic/appointments (P-FR-040 / UC-R003) ─────────────────────────────
router.get(
  '/clinic/appointments',
  asyncH((req, res) => {
    const clinicId = myClinicId(req);
    let appts = where('appointments', (a) => a.clinic_id === clinicId);
    if (req.query.date) appts = appts.filter((a) => a.appointment_date === req.query.date);
    res.json(appts.map((a) => ({
      ...a,
      patient: demographic(a.patient_id),
      doctor_name: (findById('profiles', a.doctor_id) || {}).full_name,
    })));
  }),
);

// ── GET /patients/search?cnic= (demographic + appt info only) ─────────────────
router.get(
  '/patients/search',
  asyncH((req, res) => {
    const cnic = String(req.query.cnic || '').trim();
    if (!cnic) return res.status(400).json({ message: 'A CNIC query is required.' });
    const p = db.profiles.find((x) => x.cnic === cnic && x.role === 'patient');
    if (!p) return res.status(404).json({ message: 'No patient found with that CNIC.' });
    res.json(demographic(p.id));
  }),
);

// ── POST /appointments (P-FR-041 book for walk-in) ────────────────────────────
router.post(
  '/appointments',
  asyncH((req, res) => {
    const clinicId = myClinicId(req);
    const { patient_id, doctor_id, appointment_date, appointment_time, appointment_type, notes_for_doctor } = req.body;
    if (!patient_id || !doctor_id || !appointment_date || !appointment_time) {
      return res.status(400).json({ message: 'patient_id, doctor_id, appointment_date, and appointment_time are required.' });
    }
    const clash = where('appointments', (a) =>
      a.doctor_id === doctor_id && a.appointment_date === appointment_date && a.appointment_time === appointment_time &&
      !['cancelled_by_patient', 'cancelled_by_doctor', 'no_show'].includes(a.status));
    if (clash.length) return res.status(409).json({ message: 'That time slot is no longer available.' });

    const appt = insert('appointments', {
      patient_id, doctor_id, clinic_id: clinicId,
      appointment_date, appointment_time,
      appointment_type: appointment_type || 'in_person',
      status: 'pending',
      booked_by_role: 'receptionist',
      booked_by_id: req.auth.profile.id,
      notes_for_doctor: notes_for_doctor || null,
    });
    notify(doctor_id, 'appointment_booked', 'New appointment request', 'A receptionist booked an appointment.', appt.id);
    notify(patient_id, 'appointment_booked', 'Appointment booked', 'An appointment has been booked for you.', appt.id);
    log({ actorId: req.auth.profile.id, actorRole: 'receptionist', action: 'create', resourceType: 'appointments', resourceId: appt.id });
    res.status(201).json(appt);
  }),
);

// Guard: appointment in this receptionist's clinic.
function clinicAppt(req, res) {
  const a = findById('appointments', req.params.id);
  if (!a || a.clinic_id !== myClinicId(req)) { res.status(404).json({ message: 'Appointment not found.' }); return null; }
  return a;
}

// ── PATCH /appointments/:id/cancel (P-FR-042) ─────────────────────────────────
router.patch('/appointments/:id/cancel', asyncH((req, res) => {
  const a = clinicAppt(req, res); if (!a) return;
  update('appointments', a.id, { status: 'cancelled_by_patient', cancellation_reason: req.body.reason || null });
  notify(a.patient_id, 'appointment_cancelled', 'Appointment cancelled', 'Your appointment has been cancelled.', a.id);
  notify(a.doctor_id, 'appointment_cancelled', 'Appointment cancelled', 'An appointment was cancelled.', a.id);
  res.json(findById('appointments', a.id));
}));

// ── PATCH /appointments/:id/check-in (P-FR-043 / UC-R002) ─────────────────────
router.patch('/appointments/:id/check-in', asyncH((req, res) => {
  const a = clinicAppt(req, res); if (!a) return;
  update('appointments', a.id, { status: 'checked_in', checked_in_at: new Date().toISOString() });
  res.json(findById('appointments', a.id));
}));

// ── GET /clinic/doctors (for booking dropdown) ────────────────────────────────
router.get('/clinic/doctors', asyncH((req, res) => {
  const clinicId = myClinicId(req);
  const doctors = db.doctor_profiles
    .filter((dp) => dp.clinic_id === clinicId)
    .map((dp) => {
      const base = findById('profiles', dp.id);
      return base && base.status === 'active'
        ? { id: base.id, full_name: base.full_name, specialization_primary: dp.specialization_primary }
        : null;
    })
    .filter(Boolean);
  res.json(doctors);
}));

module.exports = router;
