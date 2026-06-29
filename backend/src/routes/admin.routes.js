// ─────────────────────────────────────────────────────────────────────────────
//  Admin routes  (Scope §11.6)  — all require role: admin
//  These power the React web admin portal.
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { db, findById, where, update, insert, fullProfile } = require('../store');
const { authenticate, requireRole } = require('../middleware');
const { isValidCnic, asyncH } = require('../helpers');
const { log } = require('../audit');
const { notify } = require('../notify');

const router = express.Router();
router.use(authenticate, requireRole('admin'));

const me = (req) => req.auth.profile.id;

function doctorApplicationView(base) {
  const dp = findById('doctor_profiles', base.id) || {};
  return {
    id: base.id,
    full_name: base.full_name,
    cnic: base.cnic,
    email: base.email,
    phone_primary: base.phone_primary,
    status: base.status,
    created_at: base.created_at,
    pmdc_number: dp.pmdc_number,
    specialization_primary: dp.specialization_primary,
    qualification_mbbs: dp.qualification_mbbs,
    qualification_md: dp.qualification_md,
    qualification_fcps: dp.qualification_fcps,
    years_of_experience: dp.years_of_experience,
    clinic: dp.clinic_id ? findById('clinics', dp.clinic_id) : null,
  };
}

// ── Doctor applications (P-FR-045/046) ────────────────────────────────────────
router.get('/admin/applications/doctors', asyncH((req, res) => {
  const status = req.query.status || 'pending';
  res.json(db.profiles.filter((p) => p.role === 'doctor' && p.status === status).map(doctorApplicationView));
}));

router.get('/admin/applications/doctors/:id', asyncH((req, res) => {
  const base = findById('profiles', req.params.id);
  if (!base || base.role !== 'doctor') return res.status(404).json({ message: 'Application not found.' });
  res.json(doctorApplicationView(base));
}));

router.post('/admin/applications/doctors/:id/approve', asyncH((req, res) => {
  const base = findById('profiles', req.params.id);
  if (!base || base.role !== 'doctor') return res.status(404).json({ message: 'Application not found.' });
  update('profiles', base.id, { status: 'active', status_reason: 'Approved by admin' });
  update('doctor_profiles', base.id, { approved_at: new Date().toISOString(), approved_by: me(req) });
  log({ actorId: me(req), actorRole: 'admin', action: 'status_change', resourceType: 'profiles', resourceId: base.id });
  notify(base.id, 'doctor_approved', 'Account approved', 'Your doctor account has been approved. You can now log in.', base.id);
  res.json(doctorApplicationView(base));
}));

router.post('/admin/applications/doctors/:id/reject', asyncH((req, res) => {
  const base = findById('profiles', req.params.id);
  if (!base || base.role !== 'doctor') return res.status(404).json({ message: 'Application not found.' });
  const { reason } = req.body;
  if (!reason) return res.status(400).json({ message: 'A rejection reason is required.' }); // P-FR-046
  update('profiles', base.id, { status: 'rejected', status_reason: reason });
  log({ actorId: me(req), actorRole: 'admin', action: 'status_change', resourceType: 'profiles', resourceId: base.id });
  notify(base.id, 'doctor_rejected', 'Application rejected', 'Your doctor registration was not approved.', base.id);
  res.json(doctorApplicationView(base));
}));

// ── Lab applications (P-FR-047) ───────────────────────────────────────────────
router.get('/admin/applications/labs', asyncH((req, res) => {
  const status = req.query.status || 'pending';
  res.json(db.diagnostic_labs.filter((l) => l.status === status));
}));
router.post('/admin/applications/labs/:id/approve', asyncH((req, res) => {
  const lab = findById('diagnostic_labs', req.params.id);
  if (!lab) return res.status(404).json({ message: 'Lab not found.' });
  update('diagnostic_labs', lab.id, { status: 'active' });
  log({ actorId: me(req), actorRole: 'admin', action: 'status_change', resourceType: 'diagnostic_labs', resourceId: lab.id });
  res.json(findById('diagnostic_labs', lab.id));
}));
router.post('/admin/applications/labs/:id/reject', asyncH((req, res) => {
  const lab = findById('diagnostic_labs', req.params.id);
  if (!lab) return res.status(404).json({ message: 'Lab not found.' });
  if (!req.body.reason) return res.status(400).json({ message: 'A rejection reason is required.' });
  update('diagnostic_labs', lab.id, { status: 'suspended' });
  res.json(findById('diagnostic_labs', lab.id));
}));

// ── Users (P-FR-048 suspend/reactivate) ───────────────────────────────────────
router.get('/admin/users', asyncH((req, res) => {
  const { role, status, q } = req.query;
  let users = [...db.profiles];
  if (role) users = users.filter((u) => u.role === role);
  if (status) users = users.filter((u) => u.status === status);
  if (q) {
    const term = String(q).toLowerCase();
    users = users.filter((u) => u.full_name.toLowerCase().includes(term) || u.cnic.includes(term));
  }
  res.json(users.map((u) => fullProfile(u.id)));
}));

router.post('/admin/users/:id/suspend', asyncH((req, res) => {
  const u = findById('profiles', req.params.id);
  if (!u) return res.status(404).json({ message: 'User not found.' });
  if (u.role === 'admin') return res.status(403).json({ message: 'Admin accounts cannot be suspended here.' });
  if (!req.body.reason) return res.status(400).json({ message: 'A suspension reason is required.' });
  update('profiles', u.id, { status: 'suspended', status_reason: req.body.reason, status_changed_by: me(req) });
  log({ actorId: me(req), actorRole: 'admin', action: 'status_change', resourceType: 'profiles', resourceId: u.id });
  res.json(fullProfile(u.id));
}));

router.post('/admin/users/:id/reactivate', asyncH((req, res) => {
  const u = findById('profiles', req.params.id);
  if (!u) return res.status(404).json({ message: 'User not found.' });
  update('profiles', u.id, { status: 'active', status_reason: req.body.reason || 'Reactivated by admin', status_changed_by: me(req) });
  log({ actorId: me(req), actorRole: 'admin', action: 'status_change', resourceType: 'profiles', resourceId: u.id });
  res.json(fullProfile(u.id));
}));

// ── Clinics (P-FR-049) ────────────────────────────────────────────────────────
router.get('/admin/clinics', asyncH((req, res) => res.json(db.clinics)));
router.post('/admin/clinics', asyncH((req, res) => {
  const { name, type, phone, address_street, address_city, address_province } = req.body;
  if (!name) return res.status(400).json({ message: 'Clinic name is required.' });
  const clinic = insert('clinics', {
    name, type: type || 'clinic', phone: phone || null,
    address_street: address_street || null, address_city: address_city || null,
    address_province: address_province || null, status: 'active',
  });
  log({ actorId: me(req), actorRole: 'admin', action: 'create', resourceType: 'clinics', resourceId: clinic.id });
  res.status(201).json(clinic);
}));
router.patch('/admin/clinics/:id', asyncH((req, res) => {
  const c = findById('clinics', req.params.id);
  if (!c) return res.status(404).json({ message: 'Clinic not found.' });
  const fields = ['name', 'type', 'phone', 'address_street', 'address_city', 'address_province', 'status'];
  const patch = {}; fields.forEach((f) => { if (f in req.body) patch[f] = req.body[f]; });
  update('clinics', c.id, patch);
  res.json(findById('clinics', c.id));
}));

router.get('/admin/labs', asyncH((req, res) => res.json(db.diagnostic_labs)));

// ── Create staff accounts (P-FR-004 / UC-A003) ────────────────────────────────
function createStaff(role, extTable, extBuilder) {
  return asyncH((req, res) => {
    const { cnic, full_name, name, phone_primary, phone, email, password } = req.body;
    const fullName = full_name || name;
    if (!cnic || !fullName || !password) return res.status(400).json({ message: 'CNIC, full name, and password are required.' });
    if (!isValidCnic(cnic)) return res.status(400).json({ message: 'CNIC must be exactly 13 digits.' });
    if (db.profiles.some((p) => p.cnic === String(cnic).trim())) return res.status(409).json({ message: 'CNIC already registered.' });

    const extError = extBuilder.validate(req.body);
    if (extError) return res.status(400).json({ message: extError });

    const profile = insert('profiles', {
      auth_user_id: `auth-${Date.now()}`,
      cnic: String(cnic).trim(), full_name: fullName,
      phone_primary: phone_primary || phone || '', email: email || null,
      role, status: 'active', password, failed_login_attempts: 0, locked_until: null,
    });
    insert(extTable, { id: profile.id, ...extBuilder.build(req.body), approved_at: new Date().toISOString(), approved_by: me(req) });
    log({ actorId: me(req), actorRole: 'admin', action: 'create', resourceType: 'profiles', resourceId: profile.id });
    res.status(201).json(fullProfile(profile.id));
  });
}

router.post('/admin/users/receptionist', createStaff('receptionist', 'receptionist_profiles', {
  validate: (b) => (b.clinic_id && findById('clinics', b.clinic_id) ? null : 'A valid clinic_id is required.'),
  build: (b) => ({ clinic_id: b.clinic_id, employee_id: b.employee_id || null }),
}));

router.post('/admin/users/lab-worker', createStaff('lab_worker', 'lab_worker_profiles', {
  validate: (b) => (b.lab_id && findById('diagnostic_labs', b.lab_id) ? null : 'A valid lab_id is required.'),
  build: (b) => ({ lab_id: b.lab_id, employee_id: b.employee_id || null, position_title: b.position_title || null }),
}));

// ── Create admin (P-FR-050 — super_admin only) ────────────────────────────────
router.post('/admin/users/admin', asyncH((req, res) => {
  const actor = findById('admin_profiles', me(req));
  if (!actor || actor.admin_level !== 'super_admin') {
    return res.status(403).json({ message: 'Only a super admin can create admin accounts.' });
  }
  const { cnic, full_name, name, phone_primary, phone, email, password, admin_level } = req.body;
  const fullName = full_name || name;
  if (!cnic || !fullName || !password) return res.status(400).json({ message: 'CNIC, full name, and password are required.' });
  if (!isValidCnic(cnic)) return res.status(400).json({ message: 'CNIC must be exactly 13 digits.' });
  if (db.profiles.some((p) => p.cnic === String(cnic).trim())) return res.status(409).json({ message: 'CNIC already registered.' });

  const profile = insert('profiles', {
    auth_user_id: `auth-${Date.now()}`,
    cnic: String(cnic).trim(), full_name: fullName,
    phone_primary: phone_primary || phone || '', email: email || null,
    role: 'admin', status: 'active', password, failed_login_attempts: 0, locked_until: null,
  });
  insert('admin_profiles', {
    id: profile.id,
    admin_level: admin_level === 'super_admin' ? 'super_admin' : 'support_admin',
    can_approve_doctors: true,
    can_approve_labs: true,
    can_suspend_accounts: true,
  });
  log({ actorId: me(req), actorRole: 'admin', action: 'create', resourceType: 'profiles', resourceId: profile.id });
  res.status(201).json(fullProfile(profile.id));
}));

// ── Dashboard (P-FR-052) ──────────────────────────────────────────────────────
router.get('/admin/dashboard', asyncH((req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  res.json({
    total_patients: db.profiles.filter((p) => p.role === 'patient').length,
    approved_doctors: db.profiles.filter((p) => p.role === 'doctor' && p.status === 'active').length,
    pending_doctor_applications: db.profiles.filter((p) => p.role === 'doctor' && p.status === 'pending').length,
    pending_lab_applications: db.diagnostic_labs.filter((l) => l.status === 'pending').length,
    appointments_today: db.appointments.filter((a) => a.appointment_date === today).length,
    pending_lab_orders: db.lab_orders.filter((o) => !['released_to_patient', 'cancelled'].includes(o.status)).length,
    total_clinics: db.clinics.length,
    total_labs: db.diagnostic_labs.length,
  });
}));

// ── Audit logs (admin only) ───────────────────────────────────────────────────
router.get('/admin/audit-logs', asyncH((req, res) => {
  const limit = Math.min(500, parseInt(req.query.limit, 10) || 100);
  const logs = [...db.audit_logs].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp)).slice(0, limit)
    .map((l) => ({ ...l, actor_name: l.actor_id ? (findById('profiles', l.actor_id) || {}).full_name : 'System' }));
  res.json(logs);
}));

module.exports = router;
