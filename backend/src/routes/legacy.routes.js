// ─────────────────────────────────────────────────────────────────────────────
//  Legacy compatibility routes
//
//  Maps the original patient-demo endpoints onto the new data model so older
//  builds of the patient app keep working during the migration. New clients
//  should use the /me/* endpoints in patient.routes.js instead.
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { findById, where } = require('../store');
const { authenticate, requireRole } = require('../middleware');
const { asyncH } = require('../helpers');

const router = express.Router();

// Patient-only legacy reads.
router.use('/patient', authenticate, requireRole('patient'));

const me = (req) => req.auth.profile.id;

// GET /patient/visits — encounters mapped to the old "visit" shape.
router.get('/patient/visits', asyncH((req, res) => {
  const visits = where('encounters', (e) => e.patient_id === me(req) && e.status === 'finalized')
    .sort((a, b) => new Date(b.encounter_date) - new Date(a.encounter_date))
    .map((e) => {
      const doctor = findById('profiles', e.doctor_id) || {};
      const dp = findById('doctor_profiles', e.doctor_id) || {};
      const clinic = e.clinic_id ? findById('clinics', e.clinic_id) : null;
      const conds = where('conditions', (c) => c.encounter_id === e.id);
      const meds = where('medication_requests', (m) => m.encounter_id === e.id);
      return {
        id: e.id,
        dx: conds[0] ? conds[0].condition_display : (e.assessment || 'Consultation'),
        doctor: doctor.full_name,
        specialty: dp.specialization_primary || 'General',
        hospital: clinic ? clinic.name : '',
        dateLabel: e.encounter_date,
        time: '',
        symptoms: e.chief_complaint || '',
        diagnosis: conds.map((c) => `${c.condition_display}${c.icd10_code ? ` (${c.icd10_code})` : ''}`).join(', '),
        diagnosisNote: e.assessment || '',
        meds: meds.map((m) => ({
          name: m.medication_name,
          strength: `${m.dosage_value ?? ''} ${m.dosage_unit ?? ''}`.trim(),
          freq: m.frequency || '',
          dur: m.duration_days ? `${m.duration_days} days` : 'Ongoing',
        })),
        followUp: e.follow_up_date || '',
        advice: e.plan || '',
      };
    });
  res.json(visits);
}));

// GET /patient/prescriptions
router.get('/patient/prescriptions', asyncH((req, res) => {
  const rx = where('medication_requests', (m) => m.patient_id === me(req)).map((m) => ({
    id: m.id,
    name: m.medication_name,
    strength: `${m.dosage_value ?? ''} ${m.dosage_unit ?? ''}`.trim(),
    freq: m.frequency || '',
    dur: m.duration_days ? `${m.duration_days} days` : 'Ongoing',
    by: (findById('profiles', m.doctor_id) || {}).full_name,
    date: m.start_date || '',
    active: m.status === 'active',
  }));
  res.json(rx);
}));

// GET /patient/reports
router.get('/patient/reports', asyncH((req, res) => {
  const reports = where('lab_orders', (o) => o.patient_id === me(req)).map((o) => ({
    id: o.id,
    name: o.test_name,
    lab: (findById('diagnostic_labs', o.lab_id) || {}).name,
    date: (o.ordered_at || '').slice(0, 10),
    status: o.status === 'released_to_patient' ? 'ready' : o.status,
  }));
  res.json(reports);
}));

// GET /patient/conversations — messaging is a production feature; return a stub.
router.get('/patient/conversations', asyncH((_req, res) => {
  res.json([
    {
      doctorId: 'care', initials: 'SC', name: 'Sehat Care Team',
      last: 'Welcome to the CNIC Health Card 👋', time: 'Now', unread: 0, online: false,
      messages: [{ text: 'Welcome 👋 Secure messaging is coming soon.', fromMe: false, time: 'Now' }],
    },
  ]);
}));

// POST /patient/chat/send — echo back.
router.post('/patient/chat/send', asyncH((req, res) => {
  const now = new Date();
  res.status(201).json({
    text: req.body.message || '',
    fromMe: true,
    time: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`,
  });
}));

module.exports = router;
