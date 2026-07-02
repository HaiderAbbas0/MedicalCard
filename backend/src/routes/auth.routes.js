// ─────────────────────────────────────────────────────────────────────────────
//  Authentication routes  (Scope §11.1)
//
//  POST /auth/register          Register a new patient
//  POST /auth/register/doctor   Register a doctor (created PENDING)
//  POST /auth/login             Login with CNIC / email / phone + password
//  POST /auth/logout            Invalidate session (audit only for prototype)
//  POST /auth/refresh           Issue a fresh access token
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { db, insert, findProfileByLogin, fullProfile } = require('../store');
const { isValidCnic, authResponse, asyncH } = require('../helpers');
const { authenticate } = require('../middleware');
const { verify } = require('../token');
const { log } = require('../audit');
const { notify } = require('../notify');

const router = express.Router();

const MAX_FAILED = 5; // P-FR-006
const LOCK_MINUTES = 30;

// ── Register patient (P-FR-001) ───────────────────────────────────────────────
router.post(
  '/register',
  asyncH((req, res) => {
    const {
      cnic,
      full_name,
      name, // backward-compat alias
      date_of_birth,
      dob, // alias
      gender,
      phone_primary,
      phone, // alias
      email,
      password,
      blood_group,
    } = req.body;

    const fullName = full_name || name;
    const phoneNum = phone_primary || phone;
    const dateOfBirth = date_of_birth || dob;

    if (!cnic || !fullName || !password) {
      return res
        .status(400)
        .json({ message: 'CNIC, full name, and password are required.' });
    }
    if (!isValidCnic(cnic)) {
      return res.status(400).json({ message: 'CNIC must be exactly 13 digits with no dashes.' });
    }
    // P-FR-005 — one CNIC, one account of any role.
    if (db.profiles.some((p) => p.cnic === String(cnic).trim())) {
      return res.status(409).json({ message: 'An account with this CNIC already exists.' });
    }

    const profile = insert('profiles', {
      auth_user_id: `auth-${Date.now()}`,
      cnic: String(cnic).trim(),
      full_name: fullName,
      date_of_birth: dateOfBirth || null,
      gender: gender || 'other',
      phone_primary: phoneNum || '',
      email: email || null,
      role: 'patient',
      status: 'active', // patients are active immediately
      password,
      failed_login_attempts: 0,
      locked_until: null,
    });

    insert('patient_profiles', {
      id: profile.id,
      blood_group: blood_group || null,
      health_card_number: `HC-${new Date().getFullYear()}-${String(db.patient_profiles.length + 1).padStart(8, '0')}`,
    });

    log({ actorId: profile.id, actorRole: 'patient', action: 'create', resourceType: 'profiles', resourceId: profile.id });
    res.status(201).json(authResponse(profile));
  }),
);

// ── Register doctor (P-FR-002 — created PENDING) ──────────────────────────────
router.post(
  '/register/doctor',
  asyncH((req, res) => {
    const {
      cnic,
      full_name,
      name,
      date_of_birth,
      dob,
      gender,
      phone_primary,
      phone,
      email,
      password,
      pmdc_number,
      specialization_primary,
      clinic_id,
      qualification_mbbs,
      qualification_md,
      qualification_fcps,
      years_of_experience,
      consultation_fee_pkr,
    } = req.body;

    const fullName = full_name || name;
    if (!cnic || !fullName || !password || !pmdc_number || !specialization_primary) {
      return res.status(400).json({
        message: 'CNIC, full name, password, PMDC number, and primary specialization are required.',
      });
    }
    if (!isValidCnic(cnic)) {
      return res.status(400).json({ message: 'CNIC must be exactly 13 digits with no dashes.' });
    }
    if (db.profiles.some((p) => p.cnic === String(cnic).trim())) {
      return res.status(409).json({ message: 'An account with this CNIC already exists.' });
    }

    const profile = insert('profiles', {
      auth_user_id: `auth-${Date.now()}`,
      cnic: String(cnic).trim(),
      full_name: fullName,
      date_of_birth: date_of_birth || dob || null,
      gender: gender || 'other',
      phone_primary: phone_primary || phone || '',
      email: email || null,
      role: 'doctor',
      status: 'pending', // P-FR-003 — cannot log in until approved
      password,
      failed_login_attempts: 0,
      locked_until: null,
    });

    insert('doctor_profiles', {
      id: profile.id,
      pmdc_number,
      specialization_primary,
      clinic_id: clinic_id || null,
      qualification_mbbs: !!qualification_mbbs,
      qualification_md: !!qualification_md,
      qualification_fcps: !!qualification_fcps,
      years_of_experience: years_of_experience || null,
      consultation_fee_pkr: consultation_fee_pkr || null,
      is_available: true,
    });

    log({ actorId: profile.id, actorRole: 'doctor', action: 'create', resourceType: 'profiles', resourceId: profile.id });

    // P-FR-051 — notify all admins of the new application.
    db.profiles
      .filter((p) => p.role === 'admin')
      .forEach((a) =>
        notify(a.id, 'doctor_application', 'New doctor application', 'A doctor has submitted a registration for review.', profile.id),
      );

    res.status(201).json({
      message: 'Application submitted. An administrator will review your account before you can log in.',
      profile: fullProfile(profile.id),
    });
  }),
);

// ── Login (P-FR-006 lockout) ──────────────────────────────────────────────────
router.post(
  '/login',
  asyncH((req, res) => {
    const { identifier, cnic, email, password } = req.body;
    const login = identifier || cnic || email;
    if (!login || !password) {
      return res.status(400).json({ message: 'Login (CNIC / email / phone) and password are required.' });
    }

    const profile = findProfileByLogin(login);
    if (!profile) {
      log({ action: 'login', status: 'failure', resourceType: 'profiles' });
      return res.status(401).json({ message: 'Invalid credentials.' });
    }

    // Lockout check.
    if (profile.locked_until && new Date(profile.locked_until) > new Date()) {
      return res.status(423).json({
        message: `Account locked after too many attempts. Try again after ${LOCK_MINUTES} minutes.`,
      });
    }

    if (profile.password !== password) {
      profile.failed_login_attempts = (profile.failed_login_attempts || 0) + 1;
      if (profile.failed_login_attempts >= MAX_FAILED) {
        profile.locked_until = new Date(Date.now() + LOCK_MINUTES * 60000).toISOString();
      }
      log({ actorId: profile.id, actorRole: profile.role, action: 'login', status: 'failure' });
      return res.status(401).json({ message: 'Invalid credentials.' });
    }

    // Status gates (Scope §9.2).
    if (profile.status === 'pending') {
      return res.status(403).json({ message: 'Your account is pending approval by an administrator.' });
    }
    if (profile.status === 'suspended') {
      return res.status(403).json({ message: 'This account has been suspended. Contact an administrator.' });
    }
    if (profile.status === 'rejected') {
      return res.status(403).json({ message: 'This registration was rejected. Contact an administrator.' });
    }

    // Success — reset counters.
    profile.failed_login_attempts = 0;
    profile.locked_until = null;
    log({ actorId: profile.id, actorRole: profile.role, action: 'login', status: 'success' });
    res.json(authResponse(profile));
  }),
);

// ── Logout ────────────────────────────────────────────────────────────────────
router.post(
  '/logout',
  authenticate,
  asyncH((req, res) => {
    log({ actorId: req.auth.profile.id, actorRole: req.auth.role, action: 'logout' });
    res.json({ message: 'Logged out.' });
  }),
);

// ── Refresh ───────────────────────────────────────────────────────────────────
router.post(
  '/refresh',
  asyncH((req, res) => {
    const { token } = req.body;
    const payload = verify(token);
    if (!payload) return res.status(401).json({ message: 'Invalid token.' });
    const profile = db.profiles.find((p) => p.id === payload.sub);
    if (!profile || profile.status !== 'active') {
      return res.status(401).json({ message: 'Cannot refresh — account not active.' });
    }
    res.json(authResponse(profile));
  }),
);

module.exports = router;
