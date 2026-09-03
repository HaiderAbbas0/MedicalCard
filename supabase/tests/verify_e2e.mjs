// End-to-end integration check: Admin -> Database -> Lab -> Doctor -> Patient.
//
//   node supabase/tests/verify_e2e.mjs            check, creating demo data if absent
//   node supabase/tests/verify_e2e.mjs --force    always create a fresh encounter + reports
//
// Every step runs through the same anon-key + RLS path the real apps use --
// there is no service-role shortcut, so a pass here means the policies, the
// RPCs and the client queries genuinely agree with each other.
//
// Prerequisites:
//   1. supabase/cnic_identity.sql  and supabase/product_hardening.sql applied
//   2. node supabase/tests/seed_demo_accounts.mjs
//   3. supabase/demo_seed.sql applied

import { createClient } from '@supabase/supabase-js';
import { byKey, DEMO_PASSWORD } from './demo_accounts.mjs';

const URL = process.env.SUPABASE_URL || 'https://iikwdtiqvxxatrzahuzo.supabase.co';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';
const FORCE = process.argv.includes('--force');

const TESTS = [
  { name: 'Complete Blood Count', priority: 'routine', indication: 'Fatigue and pallor for three weeks.',
    results: [
      { name: 'Haemoglobin', value: '11.2', unit: 'g/dL', reference: '12.0 - 15.5' },
      { name: 'WBC', value: '7.4', unit: 'x10^9/L', reference: '4.0 - 11.0' },
      { name: 'Platelets', value: '264', unit: 'x10^9/L', reference: '150 - 400' },
    ],
    comments: 'Mild normocytic anaemia. Correlate clinically; consider iron studies.' },
  { name: 'HbA1c', priority: 'urgent', indication: 'Screening for diabetes; strong family history.',
    results: [{ name: 'HbA1c', value: '6.4', unit: '%', reference: '< 5.7' }],
    comments: 'Result in the pre-diabetic range. Repeat in three months.' },
  { name: 'Lipid Profile', priority: 'routine', indication: 'Cardiovascular risk assessment.',
    results: [
      { name: 'Total cholesterol', value: '212', unit: 'mg/dL', reference: '< 200' },
      { name: 'LDL', value: '141', unit: 'mg/dL', reference: '< 100' },
      { name: 'HDL', value: '46', unit: 'mg/dL', reference: '> 40' },
      { name: 'Triglycerides', value: '158', unit: 'mg/dL', reference: '< 150' },
    ],
    comments: 'Borderline dyslipidaemia. Lifestyle advice given.' },
];

// ── tiny test harness ──────────────────────────────────────────────────────
let passed = 0;
let failed = 0;
const failures = [];

function check(label, condition, detail) {
  if (condition) {
    passed += 1;
    console.log(`  PASS  ${label}`);
  } else {
    failed += 1;
    failures.push(label);
    console.log(`  FAIL  ${label}${detail ? `  -- ${detail}` : ''}`);
  }
}
function section(title) {
  console.log(`\n${title}\n${'-'.repeat(title.length)}`);
}
/** PostgREST embeds a one-to-one relation as an object and one-to-many as an
 *  array. `lab_results.lab_order_id` is UNIQUE, so a lab result arrives as an
 *  object. Accept either shape rather than assuming one. */
function embeddedResult(value) {
  if (!value) return null;
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

function fatal(message) {
  console.error(`\nSTOPPED: ${message}`);
  process.exit(1);
}

async function signIn(key) {
  const account = byKey(key);
  const c = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await c.auth.signInWithPassword({
    email: account.email,
    password: DEMO_PASSWORD,
  });
  if (error) fatal(`cannot sign in as ${key} (${account.email}): ${error.message}. Did you run seed_demo_accounts.mjs and demo_seed.sql?`);
  return { c, id: data.user.id, account };
}

/// A minimal but genuinely valid one-page PDF, so the stored lab report opens
/// in a viewer instead of being an unreadable placeholder blob.
function demoPdf(title, lines) {
  const text = [`BT /F1 16 Tf 60 760 Td (${title}) Tj ET`]
    .concat(lines.map((l, i) => `BT /F1 11 Tf 60 ${720 - i * 18} Td (${l.replace(/[()\\]/g, ' ')}) Tj ET`))
    .join('\n');
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    `<< /Length ${text.length} >>\nstream\n${text}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let pdf = '%PDF-1.4\n';
  const offsets = [];
  objects.forEach((body, i) => {
    offsets.push(pdf.length);
    pdf += `${i + 1} 0 obj\n${body}\nendobj\n`;
  });
  const xref = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  offsets.forEach((o) => { pdf += `${String(o).padStart(10, '0')} 00000 n \n`; });
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return new Blob([pdf], { type: 'application/pdf' });
}

// ═══════════════════════════════════════════════════════════════════════════
console.log(`Integration check against ${URL}`);
console.log(`Chain: Admin -> Database -> Lab -> Doctor -> Patient\n`);

// ── 1. ADMIN ───────────────────────────────────────────────────────────────
section('1. Admin module');
const admin = await signIn('admin');

const { data: adminRole } = await admin.c.rpc('my_role');
check('admin account resolves to the admin role', adminRole === 'admin', `got ${adminRole}`);

const { data: clinics } = await admin.c.from('clinics').select('id, name, status');
const clinic = (clinics ?? []).find((x) => x.name === 'Hayaat Family Clinic');
check('admin sees the demo clinic', !!clinic, 'run supabase/demo_seed.sql');

const { data: labs } = await admin.c.from('diagnostic_labs').select('id, name, status');
const lab = (labs ?? []).find((x) => x.name === 'Hayaat Diagnostics');
check('admin sees the demo diagnostic lab', !!lab, 'run supabase/demo_seed.sql');

const { data: staff } = await admin.c
  .from('profiles')
  .select('id, full_name, role, status, cnic, card_number')
  .in('role', ['doctor', 'lab_worker', 'receptionist', 'patient']);
const roles = new Set((staff ?? []).map((s) => s.role));
check('admin can read every role from the user directory',
  ['doctor', 'lab_worker', 'receptionist', 'patient'].every((r) => roles.has(r)),
  `saw ${[...roles].join(', ') || 'nothing'}`);

const approvedDoctor = (staff ?? []).find((s) => s.role === 'doctor' && s.status === 'active');
check('demo doctor is approved and active', !!approvedDoctor);

const { data: auditReadable } = await admin.c.from('audit_logs').select('id').limit(1);
check('admin can read the audit log', Array.isArray(auditReadable));

if (!clinic || !lab) fatal('demo clinic/lab missing -- apply supabase/demo_seed.sql first');

// ── 2. DATABASE / CNIC identity ────────────────────────────────────────────
section('2. Database - CNIC identity (P-FR-001 / 005 / 019)');

const patientAccount = byKey('patient');
const withCnic = (staff ?? []).filter((s) => s.cnic);
check('profiles.cnic exists and is populated for demo users',
  withCnic.length >= 4, `${withCnic.length} of ${(staff ?? []).length} rows carry a CNIC`);

const demoPatientRow = (staff ?? []).find((s) => s.cnic === patientAccount.cnic);
check('demo patient carries the expected CNIC', !!demoPatientRow, patientAccount.cnic);
check('every CNIC in the directory is 13 digits',
  withCnic.every((s) => /^[0-9]{13}$/.test(s.cnic)));
check('CNICs are unique across roles',
  new Set(withCnic.map((s) => s.cnic)).size === withCnic.length);
check('Hayaat card numbers are still issued alongside the CNIC',
  (staff ?? []).every((s) => !s.card_number || /^[0-9]{16}$/.test(s.card_number)));

// P-FR-001: the CNIC is a login identifier.
const { data: emailByCnic } = await admin.c.rpc('login_email', { p_id: patientAccount.cnic });
check('login_email() resolves an account from its CNIC',
  emailByCnic === patientAccount.email, `got ${emailByCnic}`);

// P-FR-005: the same CNIC cannot be registered twice.
const dupClient = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
const { error: dupError } = await dupClient.auth.signUp({
  email: `dup.${Date.now()}@hayaat.id`,
  password: DEMO_PASSWORD,
  options: { data: { role: 'patient', cnic: patientAccount.cnic, full_name: 'Duplicate CNIC', phone: '03000000000' } },
});
check('a second sign-up with an existing CNIC is rejected (P-FR-005)',
  !!dupError, dupError ? '' : 'the duplicate sign-up SUCCEEDED');

// ── 3. DOCTOR: find patient by CNIC, create the encounter and lab orders ────
section('3. Doctor module - lookup by CNIC and ordering');
const doctor = await signIn('doctor');

const { data: found, error: findError } = await doctor.c
  .rpc('find_patient_by_identifier', { p_identifier: patientAccount.cnic });
const patientRow = Array.isArray(found) ? found[0] : found;
check('doctor finds the patient by CNIC (P-FR-019)',
  !!patientRow && patientRow.cnic === patientAccount.cnic,
  findError?.message ?? 'no row returned');
if (!patientRow) fatal('CNIC lookup returned nothing -- apply supabase/cnic_identity.sql');

check('CNIC lookup returns the same Hayaat card number the patient holds',
  patientRow.card_number === demoPatientRow?.card_number);
check('CNIC lookup returns demographics needed at the counter',
  !!patientRow.full_name && !!patientRow.blood_group);

const { data: alsoByCard } = await doctor.c
  .rpc('find_patient_by_identifier', { p_identifier: patientRow.card_number });
check('the same lookup still accepts a 16-digit Hayaat ID',
  (Array.isArray(alsoByCard) ? alsoByCard[0] : alsoByCard)?.id === patientRow.id);

const patientId = patientRow.id;

// Reuse the demo encounter unless --force was passed.
let encounterId = null;
if (!FORCE) {
  const { data: existing } = await doctor.c
    .from('encounters')
    .select('id, lab_orders(id)')
    .eq('patient_id', patientId)
    .eq('doctor_id', doctor.id)
    .eq('chief_complaint', 'Demo encounter - fatigue and routine screening')
    .limit(1);
  if (existing?.length && existing[0].lab_orders?.length) encounterId = existing[0].id;
}

let createdFresh = false;
if (!encounterId) {
  createdFresh = true;
  const { data: enc, error: encError } = await doctor.c.from('encounters').insert({
    patient_id: patientId,
    doctor_id: doctor.id,
    clinic_id: clinic.id,
    encounter_date: new Date().toISOString().slice(0, 10),
    chief_complaint: 'Demo encounter - fatigue and routine screening',
    history_of_present_illness: 'Three weeks of tiredness and reduced exercise tolerance. No fever, no weight loss.',
    physical_examination_notes: 'Conjunctival pallor. Chest clear. BP 128/84, pulse 82 regular.',
    assessment: 'Probable iron-deficiency anaemia; screen for diabetes and dyslipidaemia.',
    plan: 'CBC, HbA1c and lipid profile today. Review with results.',
    specialty: 'General Medicine',
    status: 'draft',
  }).select().single();
  if (encError) fatal(`doctor could not create an encounter: ${encError.message}`);
  encounterId = enc.id;

  await doctor.c.from('conditions').insert({
    encounter_id: encounterId, patient_id: patientId, doctor_id: doctor.id,
    condition_display: 'Fatigue', icd10_code: 'R53.83', severity: 'mild',
    clinical_status: 'active', notes: 'Under investigation.',
  });
  await doctor.c.from('observations').insert([
    { encounter_id: encounterId, patient_id: patientId, authored_by_id: doctor.id,
      observation_display: 'Blood Pressure Systolic', value_quantity: 128, value_unit: 'mmHg',
      observation_date: new Date().toISOString().slice(0, 10) },
    { encounter_id: encounterId, patient_id: patientId, authored_by_id: doctor.id,
      observation_display: 'Pulse Rate', value_quantity: 82, value_unit: 'bpm',
      observation_date: new Date().toISOString().slice(0, 10) },
  ]);
  await doctor.c.from('medication_requests').insert({
    encounter_id: encounterId, patient_id: patientId, doctor_id: doctor.id,
    medication_name: 'Ferrous sulfate', dosage_value: 200, dosage_unit: 'mg',
    route: 'oral', frequency: 'twice_daily', duration_days: 30, status: 'active',
    start_date: new Date().toISOString().slice(0, 10),
    instructions: 'Take after food. Expect darker stools.',
    dose_morning: true, dose_night: true,
  });

  const { error: orderError } = await doctor.c.from('lab_orders').insert(
    TESTS.map((t) => ({
      encounter_id: encounterId, patient_id: patientId, ordering_doctor_id: doctor.id,
      lab_id: lab.id, test_name: t.name, priority: t.priority,
      clinical_indication: t.indication, status: 'ordered',
    })),
  );
  if (orderError) fatal(`doctor could not order labs: ${orderError.message}`);

  await doctor.c.from('encounters')
    .update({ status: 'finalized', finalized_at: new Date().toISOString(),
              prescription_signature_name: 'Dr. Sara Ahmed',
              prescription_signature_credentials: 'MBBS, FCPS',
              prescription_signature_footer: 'PMDC-45219' })
    .eq('id', encounterId);
}

check(createdFresh ? 'doctor created a finalized encounter with three lab orders'
                   : 'demo encounter and lab orders already present', !!encounterId);

const { data: myOrders } = await doctor.c
  .from('lab_orders').select('id, test_name, status').eq('encounter_id', encounterId);
check('three demo lab orders exist on the encounter',
  (myOrders ?? []).length === TESTS.length, `found ${(myOrders ?? []).length}`);

// ── 4. LAB ─────────────────────────────────────────────────────────────────
section('4. Lab module - queue, sample tracking, result upload');
const labWorker = await signIn('lab');

const { data: labRole } = await labWorker.c.rpc('my_role');
check('lab account resolves to the lab_worker role', labRole === 'lab_worker', `got ${labRole}`);

const { data: queue, error: queueError } = await labWorker.c
  .from('lab_orders')
  .select('*, patient:profiles!patient_id(full_name)')
  .eq('lab_id', lab.id);
check('lab worker sees orders addressed to their lab',
  (queue ?? []).length > 0, queueError?.message);

const mine = (queue ?? []).filter((o) => o.encounter_id === encounterId);
check('this encounter\'s orders reached the lab queue (Doctor -> Lab sync)',
  mine.length === TESTS.length, `found ${mine.length}`);

const { data: leakCheck } = await labWorker.c.from('encounters').select('id').limit(1);
check('lab worker cannot browse clinical encounters',
  (leakCheck ?? []).length === 0, `saw ${(leakCheck ?? []).length} encounter rows`);

let uploaded = 0;
for (const order of mine) {
  const spec = TESTS.find((t) => t.name === order.test_name);
  if (!spec) continue;

  const { data: already } = await labWorker.c
    .from('lab_results').select('id, result_file_path').eq('lab_order_id', order.id).maybeSingle();
  if (already) { uploaded += 1; continue; }

  await labWorker.c.from('lab_orders')
    .update({ status: 'sample_collected', sample_collected_at: new Date().toISOString() })
    .eq('id', order.id);
  await labWorker.c.from('lab_orders').update({ status: 'processing' }).eq('id', order.id);

  const fileName = `${spec.name.replace(/\s+/g, '-').toLowerCase()}.pdf`;
  const path = `${patientId}/${order.id}/${Date.now()}_${fileName}`;
  const pdf = demoPdf(`Hayaat Diagnostics - ${spec.name}`, [
    `Patient: ${patientRow.full_name}`,
    `CNIC: ${patientRow.cnic}`,
    `Hayaat ID: ${patientRow.card_number}`,
    `Reported: ${new Date().toISOString().slice(0, 10)}`,
    '',
    ...spec.results.map((r) => `${r.name}: ${r.value} ${r.unit}   (reference ${r.reference})`),
    '',
    spec.comments,
  ]);
  const { error: upErr } = await labWorker.c.storage.from('lab-results')
    .upload(path, pdf, { contentType: 'application/pdf', upsert: true });
  if (upErr) { check(`upload result file for ${spec.name}`, false, upErr.message); continue; }

  const { error: insErr } = await labWorker.c.from('lab_results').insert({
    lab_order_id: order.id, lab_id: order.lab_id, uploaded_by: labWorker.id,
    patient_id: order.patient_id, result_file_name: fileName, result_file_path: path,
    structured_results: spec.results, comments: spec.comments,
  });
  if (insErr) { check(`store result metadata for ${spec.name}`, false, insErr.message); continue; }

  await labWorker.c.from('lab_orders')
    .update({ status: 'resulted', resulted_at: new Date().toISOString() }).eq('id', order.id);
  await labWorker.c.from('notifications').insert({
    recipient_id: order.ordering_doctor_id, type: 'lab_result_uploaded',
    title: 'Lab result uploaded', body: 'A lab result is ready for your review.',
    resource_id: order.id,
  });
  uploaded += 1;
}
check('lab worker uploaded a report file and metadata for every order',
  uploaded === TESTS.length, `${uploaded} of ${TESTS.length}`);

// ── 5. DOCTOR review and release ───────────────────────────────────────────
section('5. Doctor module - review and release to patient');

const { data: forReview } = await doctor.c
  .from('lab_orders')
  .select('*, lab_results(*)')
  .eq('ordering_doctor_id', doctor.id)
  .eq('encounter_id', encounterId)
  .in('status', ['resulted', 'reviewed', 'released_to_patient']);
check('uploaded results appear in the doctor review queue (Lab -> Doctor sync)',
  (forReview ?? []).length === TESTS.length, `found ${(forReview ?? []).length}`);
check('each result carries structured values the doctor can read',
  (forReview ?? []).length > 0 && (forReview ?? []).every((o) => {
    const values = embeddedResult(o.lab_results)?.structured_results;
    return Array.isArray(values) && values.length > 0;
  }));

for (const order of forReview ?? []) {
  if (order.status === 'resulted') {
    await doctor.c.from('lab_orders')
      .update({ status: 'reviewed', reviewed_at: new Date().toISOString() }).eq('id', order.id);
  }
  if (order.status !== 'released_to_patient') {
    await doctor.c.from('lab_orders')
      .update({ status: 'released_to_patient', released_to_patient_at: new Date().toISOString() })
      .eq('id', order.id);
    await doctor.c.from('notifications').insert({
      recipient_id: order.patient_id, type: 'lab_result_ready',
      title: 'Lab result available', body: 'A new lab result has been released to you.',
      resource_id: order.id,
    });
  }
}
const { data: released } = await doctor.c.from('lab_orders')
  .select('id, status').eq('encounter_id', encounterId).eq('status', 'released_to_patient');
check('doctor released every report to the patient',
  (released ?? []).length === TESTS.length, `${(released ?? []).length} released`);

// ── 6. PATIENT ─────────────────────────────────────────────────────────────
section('6. Patient module - report visibility');
const patient = await signIn('patient');

check('patient signs in and is the CNIC holder the doctor looked up',
  patient.id === patientId);

// The patient reports screen: lib/services/record_service.dart fetchReports()
const { data: patientOrders, error: poError } = await patient.c
  .from('lab_orders').select('*, encounters(specialty)')
  .eq('patient_id', patient.id).order('ordered_at', { ascending: false });
check('patient can list their own lab orders', !Array.isArray(patientOrders) === false, poError?.message);

const readyForPatient = (patientOrders ?? []).filter((o) => o.status === 'released_to_patient');
check('released reports are visible to the patient (Doctor -> Patient sync)',
  readyForPatient.length >= TESTS.length, `${readyForPatient.length} visible`);
check('every demo test appears by name on the patient side',
  TESTS.every((t) => readyForPatient.some((o) => o.test_name === t.name)));

// The record library: record_service.dart fetchRecords() joins lab_results.
const { data: patientRecords } = await patient.c
  .from('lab_orders').select('*, lab_results(*), encounters(specialty, clinic_id)')
  .eq('patient_id', patient.id).eq('status', 'released_to_patient');
const withFile = (patientRecords ?? []).filter((r) => embeddedResult(r.lab_results)?.result_file_path);
check('patient sees the stored report file path for each result',
  withFile.length >= TESTS.length, `${withFile.length} of ${(patientRecords ?? []).length}`);

const firstPath = embeddedResult(withFile[0]?.lab_results)?.result_file_path;
const { data: signed, error: signError } = firstPath
  ? await patient.c.storage.from('lab-results').createSignedUrl(firstPath, 60)
  : { data: null, error: { message: 'no stored report file to sign' } };
check('patient can open the report file through a signed URL',
  !!signed?.signedUrl, signError?.message);

if (signed?.signedUrl) {
  const res = await fetch(signed.signedUrl);
  const body = await res.text();
  check('the signed URL serves a real PDF document',
    res.ok && body.startsWith('%PDF'), `status ${res.status}`);
}

const { data: notifs } = await patient.c.from('notifications')
  .select('id, type').eq('recipient_id', patient.id).eq('type', 'lab_result_ready');
check('patient was notified that a result was released (P-FR-016)',
  (notifs ?? []).length > 0, `${(notifs ?? []).length} notifications`);

const { data: timeline } = await patient.c.from('encounters')
  .select('*, conditions(*), medication_requests(*), observations(*), lab_orders(*)')
  .eq('patient_id', patient.id).eq('status', 'finalized');
check('the finalized encounter shows on the patient timeline (P-FR-007)',
  (timeline ?? []).some((e) => e.id === encounterId));
check('the prescription written in that encounter reaches the patient (P-FR-010)',
  (timeline ?? []).some((e) => (e.medication_requests ?? [])
    .some((m) => m.medication_name === 'Ferrous sulfate')));

// One patient, one Hayaat number. request_card() used to mint a fresh number
// on every card issue and never touched patient_profiles, so the three copies
// drifted apart.
const { data: ownProfile } = await patient.c
  .from('profiles').select('card_number').eq('id', patient.id).maybeSingle();
const { data: ownPatient } = await patient.c
  .from('patient_profiles').select('health_card_number').eq('id', patient.id).maybeSingle();
const { data: ownCard } = await patient.c
  .from('cards').select('card_number').eq('profile_id', patient.id).maybeSingle();
check('patient_profiles carries the same Hayaat number as the profile',
  !!ownProfile?.card_number && ownPatient?.health_card_number === ownProfile.card_number,
  `profile ${ownProfile?.card_number} vs patient_profiles ${ownPatient?.health_card_number}`);
check('the issued card carries the same Hayaat number as the profile',
  !ownCard || ownCard.card_number === ownProfile?.card_number,
  `profile ${ownProfile?.card_number} vs card ${ownCard?.card_number}`);

// Isolation: the second patient must see none of this.
const other = await signIn('patient2');
const { data: otherOrders } = await other.c.from('lab_orders').select('id').eq('patient_id', patientId);
check('a different patient cannot read these lab orders',
  (otherOrders ?? []).length === 0, `leaked ${(otherOrders ?? []).length} rows`);
const { data: otherResults } = await other.c.from('lab_results').select('id').eq('patient_id', patientId);
check('a different patient cannot read these lab results',
  (otherResults ?? []).length === 0, `leaked ${(otherResults ?? []).length} rows`);

// ── 7. RECEPTIONIST ────────────────────────────────────────────────────────
section('7. Receptionist module - demographics only');
const reception = await signIn('reception');

const { data: recRole } = await reception.c.rpc('my_role');
check('reception account resolves to the receptionist role', recRole === 'receptionist', `got ${recRole}`);

const { data: recLookup } = await reception.c
  .rpc('find_patient_by_identifier', { p_identifier: patientAccount.cnic });
check('receptionist can find the patient by CNIC for booking',
  (Array.isArray(recLookup) ? recLookup[0] : recLookup)?.id === patientId);

const { data: recClinical } = await reception.c.from('lab_results').select('id').limit(1);
check('receptionist cannot read clinical lab results',
  (recClinical ?? []).length === 0, `saw ${(recClinical ?? []).length} rows`);

// ── summary ────────────────────────────────────────────────────────────────
console.log(`\n${'='.repeat(60)}`);
console.log(`${passed} passed, ${failed} failed`);
if (failed) {
  console.log('\nFailures:');
  failures.forEach((f) => console.log(`  - ${f}`));
  process.exitCode = 1;
} else {
  console.log('\nAdmin -> Database -> Lab -> Doctor -> Patient is synchronized.');
  console.log(`Demo reports: ${TESTS.map((t) => t.name).join(', ')}`);
  console.log(`Patient CNIC ${patientAccount.cnic} / Hayaat ID ${patientRow.card_number}`);
}
