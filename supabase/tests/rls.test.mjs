// ============================================================================
// rls.test.mjs — Dynamic live Row Level Security verification.
//
// This suite creates throwaway users and clinical data with the service-role
// key, signs in as real anon/authenticated clients, verifies RLS boundaries, and
// then cleans up. It intentionally does not depend on demo fixtures.
//
// Required env:
//   SUPABASE_URL
//   SUPABASE_PUBLISHABLE_KEY
//   SUPABASE_SERVICE_ROLE_KEY
//
// Optional env:
//   RLS_TEST_PASSWORD (default: RlsTest!12345)
// ============================================================================
import { createClient } from '@supabase/supabase-js';

const URL = process.env.SUPABASE_URL;
const ANON_KEY = process.env.SUPABASE_PUBLISHABLE_KEY;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const PASSWORD = process.env.RLS_TEST_PASSWORD || 'RlsTest!12345';

if (!URL || !ANON_KEY || !SERVICE_KEY) {
  console.log('RLS suite skipped: set SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, and SUPABASE_SERVICE_ROLE_KEY.');
  process.exit(0);
}

const clientOptions = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(URL, SERVICE_KEY, clientOptions);

let pass = 0;
let fail = 0;
const lines = [];
const createdUserIds = [];
const createdIds = {
  clinics: [],
  labs: [],
  appointments: [],
  encounters: [],
  labOrders: [],
  labResults: [],
  medicalDocuments: [],
  auditLogs: [],
};

const stamp = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
const emailFor = (role) => `rls-${role}-${stamp}@hayaat.test`;
// Hayaat card numbers carry a Luhn check digit that `profiles_hayaat_id_format`
// enforces, so a fabricated 16-digit string is rejected. Ask the database to
// mint one instead of inventing it here.
async function newCardNumber() {
  const { data, error } = await admin.rpc('gen_hayaat_id');
  if (error) throw new Error(`gen_hayaat_id: ${error.message}`);
  return data;
}
const isRlsDenied = (error) => !!error && (error.code === '42501' || /row-level security/i.test(error.message || ''));

function ok(name) {
  pass += 1;
  lines.push(`  ✓ ${name}`);
}

function bad(name, detail) {
  fail += 1;
  lines.push(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
}

function check(name, condition, detail) {
  condition ? ok(name) : bad(name, detail);
}

function authedClient() {
  return createClient(URL, ANON_KEY, clientOptions);
}

async function createUser({ role, name, cardNumber, status = 'active', extraProfile = {} }) {
  const email = emailFor(`${role}-${createdUserIds.length}`);
  cardNumber = cardNumber ?? (await newCardNumber());
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: PASSWORD,
    email_confirm: true,
    user_metadata: {
      role,
      full_name: name,
      email,
      card_number: cardNumber,
    },
    app_metadata: { role },
  });
  if (error) throw new Error(`create ${role}: ${error.message}`);
  const id = data.user.id;
  createdUserIds.push(id);

  const profile = {
    id,
    auth_user_id: id,
    full_name: name,
    email,
    // Exactly 11 digits and unique per user: 03 + 7 stamp digits + 2 index
    // digits. Truncating a longer string collided once profiles gained a
    // unique-phone constraint, because the index digits were cut off.
    phone_primary: `03${String(stamp).slice(-7).padStart(7, '0')}${String(createdUserIds.length % 100).padStart(2, '0')}`,
    card_number: cardNumber,
    role,
    status,
    ...extraProfile,
  };
  const { error: profileError } = await admin.from('profiles').upsert(profile, { onConflict: 'id' });
  if (profileError) throw new Error(`upsert profile ${role}: ${profileError.message}`);

  const c = authedClient();
  const { data: signIn, error: signInError } = await c.auth.signInWithPassword({ email, password: PASSWORD });
  if (signInError) throw new Error(`sign in ${role}: ${signInError.message}`);
  return { id, email, role, client: c, sessionUser: signIn.user };
}

async function seed() {
  const { data: clinic, error: clinicError } = await admin
    .from('clinics')
    .insert({ name: `RLS Clinic ${stamp}`, type: 'clinic', phone: '03000000000', address_city: 'Lahore', address_province: 'Punjab', status: 'active' })
    .select('id')
    .single();
  if (clinicError) throw new Error(`create clinic: ${clinicError.message}`);
  createdIds.clinics.push(clinic.id);

  const { data: lab, error: labError } = await admin
    .from('diagnostic_labs')
    .insert({ name: `RLS Lab ${stamp}`, license_number: `LAB-${stamp}`, phone: '03000000001', address_city: 'Lahore', address_province: 'Punjab', status: 'active' })
    .select('id')
    .single();
  if (labError) throw new Error(`create lab: ${labError.message}`);
  createdIds.labs.push(lab.id);

  const patientA = await createUser({ role: 'patient', name: 'RLS Patient A' });
  const patientB = await createUser({ role: 'patient', name: 'RLS Patient B' });
  const doctor = await createUser({ role: 'doctor', name: 'RLS Doctor' });
  const pendingDoctor = await createUser({ role: 'doctor', name: 'RLS Pending Doctor', status: 'pending' });
  const receptionist = await createUser({ role: 'receptionist', name: 'RLS Receptionist' });
  const labWorker = await createUser({ role: 'lab_worker', name: 'RLS Lab Worker' });
  const adminUser = await createUser({ role: 'admin', name: 'RLS Admin' });

  await requireOk(admin.from('patient_profiles').upsert([
    { id: patientA.id, health_card_number: patientA.id },
    { id: patientB.id, health_card_number: patientB.id },
  ], { onConflict: 'id' }), 'upsert patient profiles');
  await requireOk(admin.from('doctor_profiles').upsert([
    { id: doctor.id, clinic_id: clinic.id, specialization_primary: 'General Medicine', qualification_mbbs: true },
    { id: pendingDoctor.id, clinic_id: clinic.id, specialization_primary: 'General Medicine', qualification_mbbs: true },
  ], { onConflict: 'id' }), 'upsert doctor profiles');
  await requireOk(admin.from('receptionist_profiles').upsert({ id: receptionist.id, clinic_id: clinic.id, employee_id: `REC-${stamp}` }, { onConflict: 'id' }), 'upsert receptionist profile');
  await requireOk(admin.from('lab_worker_profiles').upsert({ id: labWorker.id, lab_id: lab.id, employee_id: `LAB-${stamp}` }, { onConflict: 'id' }), 'upsert lab profile');
  await requireOk(admin.from('admin_profiles').upsert({ id: adminUser.id, admin_level: 'super_admin' }, { onConflict: 'id' }), 'upsert admin profile');

  const { data: appt, error: apptError } = await admin.from('appointments').insert({
    patient_id: patientA.id,
    doctor_id: doctor.id,
    clinic_id: clinic.id,
    appointment_date: '2026-07-20',
    appointment_time: '09:30',
    appointment_type: 'in_person',
    status: 'confirmed',
    booked_by_role: 'receptionist',
    booked_by_id: receptionist.id,
  }).select('id').single();
  if (apptError) throw new Error(`create appointment: ${apptError.message}`);
  createdIds.appointments.push(appt.id);

  const { data: encounter, error: encounterError } = await admin.from('encounters').insert({
    patient_id: patientA.id,
    doctor_id: doctor.id,
    appointment_id: appt.id,
    clinic_id: clinic.id,
    encounter_date: '2026-07-20',
    chief_complaint: 'RLS seed complaint',
    assessment: 'RLS seed assessment',
    status: 'finalized',
  }).select('id').single();
  if (encounterError) throw new Error(`create encounter: ${encounterError.message}`);
  createdIds.encounters.push(encounter.id);

  const { data: labOrder, error: labOrderError } = await admin.from('lab_orders').insert({
    encounter_id: encounter.id,
    patient_id: patientA.id,
    ordering_doctor_id: doctor.id,
    lab_id: lab.id,
    test_name: 'CBC',
    priority: 'routine',
    status: 'ordered',
  }).select('id').single();
  if (labOrderError) throw new Error(`create lab order: ${labOrderError.message}`);
  createdIds.labOrders.push(labOrder.id);

  const { data: labResult, error: labResultError } = await admin.from('lab_results').insert({
    lab_order_id: labOrder.id,
    lab_id: lab.id,
    uploaded_by: labWorker.id,
    patient_id: patientA.id,
    result_file_path: `${patientA.id}/rls-result.pdf`,
    result_file_name: 'rls-result.pdf',
    comments: 'RLS seed result',
  }).select('id').single();
  if (labResultError) throw new Error(`create lab result: ${labResultError.message}`);
  createdIds.labResults.push(labResult.id);

  const { data: doc, error: docError } = await admin.from('medical_documents').insert({
    patient_id: patientA.id,
    uploaded_by: labWorker.id,
    doctor_id: doctor.id,
    clinic_id: clinic.id,
    encounter_id: encounter.id,
    specialty: 'General Medicine',
    record_type: 'laboratory',
    title: 'RLS CBC report',
    record_date: '2026-07-20',
    facility_name: `RLS Lab ${stamp}`,
    doctor_name: 'RLS Doctor',
    file_paths: [`${patientA.id}/rls-result.pdf`],
    file_names: ['rls-result.pdf'],
    mime_types: ['application/pdf'],
  }).select('id').single();
  if (docError) throw new Error(`create medical document: ${docError.message}`);
  createdIds.medicalDocuments.push(doc.id);

  const { data: audit, error: auditError } = await admin.from('audit_logs').insert({
    actor_id: adminUser.id,
    actor_role: 'admin',
    action: 'rls_test',
    resource_type: 'profiles',
    resource_id: patientA.id,
    patient_id: patientA.id,
    status: 'success',
  }).select('id').single();
  if (auditError) throw new Error(`create audit log: ${auditError.message}`);
  createdIds.auditLogs.push(audit.id);

  return { clinic, lab, patientA, patientB, doctor, pendingDoctor, receptionist, labWorker, adminUser, appt, encounter, labOrder, labResult, doc };
}

async function requireOk(query, label) {
  const { error } = await query;
  if (error) throw new Error(`${label}: ${error.message}`);
}

async function runChecks(ctx) {
  const anon = authedClient();
  const { data: anonProfiles } = await anon.from('profiles').select('id').limit(5);
  check('anonymous users cannot read profiles', (anonProfiles ?? []).length === 0, `got ${(anonProfiles ?? []).length}`);

  const { data: ownProfile } = await ctx.patientA.client.from('profiles').select('id,card_number').eq('id', ctx.patientA.id);
  check('patient can read own profile', (ownProfile ?? []).length === 1);
  check('patient profile carries a numeric Hayaat card number', /^\d{12,16}$/.test(ownProfile?.[0]?.card_number ?? ''), ownProfile?.[0]?.card_number);

  const { data: otherProfile } = await ctx.patientA.client.from('profiles').select('id').eq('id', ctx.patientB.id);
  check('patient cannot read another patient profile', (otherProfile ?? []).length === 0, `got ${(otherProfile ?? []).length}`);

  const { data: ownEncounter } = await ctx.patientA.client.from('encounters').select('id,patient_id');
  check('patient sees only own encounters', (ownEncounter ?? []).every((r) => r.patient_id === ctx.patientA.id));

  const { error: patientWriteEncounter } = await ctx.patientA.client.from('encounters').insert({
    patient_id: ctx.patientA.id,
    doctor_id: ctx.doctor.id,
    encounter_date: '2026-07-20',
    chief_complaint: 'blocked write',
  });
  check('patient cannot insert encounters', isRlsDenied(patientWriteEncounter), patientWriteEncounter ? `code ${patientWriteEncounter.code}` : 'insert succeeded');

  const { data: doctorEncounter } = await ctx.doctor.client.from('encounters').select('id').eq('patient_id', ctx.patientA.id);
  check('active doctor can read assigned patient encounters', (doctorEncounter ?? []).length >= 1);

  const { data: doctorOtherEncounter } = await ctx.doctor.client.from('encounters').select('id').eq('patient_id', ctx.patientB.id);
  check('doctor cannot read unrelated patient encounters', (doctorOtherEncounter ?? []).length === 0, `got ${(doctorOtherEncounter ?? []).length}`);

  const { data: pendingEncounter } = await ctx.pendingDoctor.client.from('encounters').select('id').eq('patient_id', ctx.patientA.id);
  check('pending doctor is blocked from clinical access', (pendingEncounter ?? []).length === 0, `got ${(pendingEncounter ?? []).length}`);

  const { data: receptionProfile } = await ctx.receptionist.client.from('patient_profiles').select('id').eq('id', ctx.patientA.id);
  check('receptionist can read booked patient demographics', (receptionProfile ?? []).length === 1);

  const { data: receptionClinical } = await ctx.receptionist.client.from('encounters').select('id').eq('patient_id', ctx.patientA.id);
  check('receptionist cannot read clinical encounters', (receptionClinical ?? []).length === 0, `got ${(receptionClinical ?? []).length}`);

  const { data: labOrders } = await ctx.labWorker.client.from('lab_orders').select('id').eq('patient_id', ctx.patientA.id);
  check('lab worker can read lab orders for assigned lab', (labOrders ?? []).length >= 1);

  const { data: labClinical } = await ctx.labWorker.client.from('lab_results').select('id').eq('patient_id', ctx.patientA.id);
  check('lab worker can read lab results for assigned lab', (labClinical ?? []).length >= 1);

  const { data: labOther } = await ctx.labWorker.client.from('lab_orders').select('id').eq('patient_id', ctx.patientB.id);
  check('lab worker cannot read unrelated patient orders', (labOther ?? []).length === 0, `got ${(labOther ?? []).length}`);

  const { data: adminAudit, error: adminAuditError } = await ctx.adminUser.client.from('audit_logs').select('id').eq('id', createdIds.auditLogs[0]);
  check('admin can read audit logs', !adminAuditError && (adminAudit ?? []).length === 1, adminAuditError?.message);

  const { data: patientAudit } = await ctx.patientA.client.from('audit_logs').select('id').eq('id', createdIds.auditLogs[0]);
  check('patient cannot read audit logs', (patientAudit ?? []).length === 0, `got ${(patientAudit ?? []).length}`);

  const { data: patientDocs } = await ctx.patientA.client.from('medical_documents').select('id').eq('id', ctx.doc.id);
  check('patient can read own medical documents', (patientDocs ?? []).length === 1);

  const { data: receptionDocs } = await ctx.receptionist.client.from('medical_documents').select('id').eq('id', ctx.doc.id);
  check('receptionist cannot read clinical documents', (receptionDocs ?? []).length === 0, `got ${(receptionDocs ?? []).length}`);
}

async function cleanup() {
  await deleteIds('medical_documents', createdIds.medicalDocuments);
  await deleteIds('lab_results', createdIds.labResults);
  await deleteIds('lab_orders', createdIds.labOrders);
  await deleteIds('encounters', createdIds.encounters);
  await deleteIds('appointments', createdIds.appointments);
  await deleteIds('audit_logs', createdIds.auditLogs);
  await deleteIds('clinics', createdIds.clinics);
  await deleteIds('diagnostic_labs', createdIds.labs);
  for (const id of createdUserIds.reverse()) {
    await admin.auth.admin.deleteUser(id);
  }
}

async function deleteIds(table, ids) {
  if (!ids.length) return;
  await admin.from(table).delete().in('id', ids);
}

function finish(fatal) {
  if (fatal) console.error('FATAL:', fatal);
  console.log(lines.join('\n'));
  console.log(`\n${pass} passed, ${fail} failed${fatal ? ' (aborted early)' : ''}`);
  process.exit(fail === 0 && !fatal ? 0 : 1);
}

async function main() {
  console.log(`Dynamic RLS suite against ${URL}\n`);
  let ctx;
  try {
    ctx = await seed();
    await runChecks(ctx);
  } finally {
    await cleanup();
  }
  finish();
}

main().catch((error) => finish(error.message));
