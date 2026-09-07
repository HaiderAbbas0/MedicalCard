// Fills in realistic clinical history for a handful of the fake Pakistani
// test accounts (see fake_pk_data.mjs / seed_fake_pk_data.mjs), so the app
// isn't empty when testing features: finalized encounters, prescriptions,
// vitals, lab orders + released results, allergies, chat messages, and
// appointments (one past/completed, one upcoming/confirmed).
//
// Every write goes through the ordinary public API as the real app does --
// signed in as the doctor / lab worker / patient in question -- so it is
// bound by the same RLS policies as a real user (same approach as
// verify_e2e.mjs). No service-role key involved.
//
//   node supabase/tests/seed_clinical_data.mjs
//
// Prerequisites: seed_fake_pk_data.mjs has run AND its generated
// fake_pk_data_promote.generated.sql has been applied (doctors approved,
// clinics/labs created).

import { createClient } from '@supabase/supabase-js';
import {
  FAKE_PASSWORD, FAKE_PATIENTS, FAKE_DOCTORS, FAKE_LAB_WORKERS,
  FAKE_CLINICS, FAKE_LABS,
} from './fake_pk_data.mjs';

const URL = process.env.SUPABASE_URL || 'https://iikwdtiqvxxatrzahuzo.supabase.co';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

// How many of the 50 fake patients get a full clinical history.
const TREAT_COUNT = 10;

function client() {
  return createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
}

async function signIn(email) {
  const c = client();
  const { data, error } = await c.auth.signInWithPassword({ email, password: FAKE_PASSWORD });
  if (error) throw new Error(`sign-in failed for ${email}: ${error.message}`);
  return { c, id: data.user.id, email };
}

function isoDate(d) { return d.toISOString().slice(0, 10); }
function daysFromNow(n) { const d = new Date(); d.setDate(d.getDate() + n); return d; }

/// Adds `minutes` to an 'HH:MM' string, returning 'HH:MM'.
function addMinutes(hhmm, minutes) {
  const [h, m] = hhmm.split(':').map(Number);
  const total = h * 60 + m + minutes;
  return `${String(Math.floor(total / 60) % 24).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
}

/// Next date on/after `from` that falls on `dayOfWeek` (0=Sun..6=Sat).
function nextWeekday(from, dayOfWeek) {
  const d = new Date(from);
  const delta = (dayOfWeek - d.getDay() + 7) % 7 || 7;
  d.setDate(d.getDate() + delta);
  return d;
}

/// A minimal but genuinely valid one-page PDF (same trick as verify_e2e.mjs)
/// so stored lab reports open in a real PDF viewer.
function demoPdf(title, lines) {
  const text = [`BT /F1 16 Tf 60 760 Td (${title}) Tj ET`]
    .concat(lines.map((l, i) => `BT /F1 11 Tf 60 ${720 - i * 18} Td (${String(l).replace(/[()\\]/g, ' ')}) Tj ET`))
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
  objects.forEach((body, i) => { offsets.push(pdf.length); pdf += `${i + 1} 0 obj\n${body}\nendobj\n`; });
  const xref = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  offsets.forEach((o) => { pdf += `${String(o).padStart(10, '0')} 00000 n \n`; });
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return new Blob([pdf], { type: 'application/pdf' });
}

// ── Clinical vignettes, one per doctor specialty (FAKE_DOCTORS order) ───────
const VIGNETTES = [
  { // General Medicine
    complaint: 'Fatigue and low-grade fever for four days.',
    history: 'No cough, no rash. Reduced appetite. No sick contacts reported.',
    exam: 'Temp 38.0C, throat mildly injected, chest clear, no lymphadenopathy.',
    assessment: 'Viral upper respiratory infection.',
    plan: 'Supportive care, fluids, rest. Review in a week if not improving.',
    condition: { display: 'Viral upper respiratory infection', icd10: 'J06.9', severity: 'mild' },
    med: { name: 'Paracetamol', value: 500, unit: 'mg', freq: 'three_times_daily', days: 5, instructions: 'Take after meals for fever.' },
    vitals: [{ name: 'Body Temperature', value: 38.0, unit: 'C' }, { name: 'Blood Pressure Systolic', value: 118, unit: 'mmHg' }],
    lab: { name: 'Complete Blood Count', priority: 'routine', indication: 'Fever with fatigue.',
      results: [{ name: 'Haemoglobin', value: '13.2', unit: 'g/dL', reference: '12.0 - 15.5' }, { name: 'WBC', value: '9.8', unit: 'x10^9/L', reference: '4.0 - 11.0' }],
      comments: 'Mild leukocytosis consistent with a viral illness.' },
  },
  { // Cardiology
    complaint: 'Occasional chest tightness on exertion for two weeks.',
    history: 'No radiation to arm/jaw. Resolves with rest. Family history of heart disease.',
    exam: 'BP 138/88, pulse 88 regular, heart sounds normal, no murmurs.',
    assessment: 'Atypical chest pain - rule out coronary artery disease.',
    plan: 'Lipid profile, lifestyle counselling, follow-up in two weeks.',
    condition: { display: 'Atypical chest pain', icd10: 'R07.89', severity: 'moderate' },
    med: { name: 'Aspirin', value: 75, unit: 'mg', freq: 'once_daily', days: 30, instructions: 'Take with food, once daily in the morning.' },
    vitals: [{ name: 'Blood Pressure Systolic', value: 138, unit: 'mmHg' }, { name: 'Pulse Rate', value: 88, unit: 'bpm' }],
    lab: { name: 'Lipid Profile', priority: 'routine', indication: 'Cardiovascular risk assessment.',
      results: [{ name: 'Total Cholesterol', value: '212', unit: 'mg/dL', reference: '< 200' }, { name: 'LDL', value: '141', unit: 'mg/dL', reference: '< 100' }],
      comments: 'Borderline dyslipidaemia; lifestyle advice given.' },
  },
  { // Dermatology
    complaint: 'Itchy red rash on both forearms for a week.',
    history: 'Started after using a new detergent. No fever. No known drug allergy.',
    exam: 'Erythematous, mildly scaly patches on flexor forearms, no vesicles.',
    assessment: 'Contact dermatitis.',
    plan: 'Antihistamine, avoid the suspected irritant, review in two weeks if not resolved.',
    condition: { display: 'Contact dermatitis', icd10: 'L23.9', severity: 'mild' },
    med: { name: 'Cetirizine', value: 10, unit: 'mg', freq: 'once_daily', days: 10, instructions: 'Take at night; may cause drowsiness.' },
    vitals: [{ name: 'Blood Pressure Systolic', value: 116, unit: 'mmHg' }],
    lab: { name: 'Complete Blood Count', priority: 'routine', indication: 'Baseline before treatment.',
      results: [{ name: 'Eosinophils', value: '6', unit: '%', reference: '1 - 4' }],
      comments: 'Mild eosinophilia, consistent with an allergic process.' },
  },
  { // Pediatrics
    complaint: 'Recurrent dry cough, worse at night, for three weeks.',
    history: 'No fever. Symptoms worse with exercise. No prior diagnosis of asthma.',
    exam: 'Chest clear at rest, mild expiratory wheeze on forced exhalation. SpO2 98%.',
    assessment: 'Suspected mild intermittent asthma.',
    plan: 'Trial of bronchodilator, avoid triggers, review in one month.',
    condition: { display: 'Asthma, mild intermittent', icd10: 'J45.20', severity: 'mild' },
    med: { name: 'Salbutamol inhaler', value: 100, unit: 'mcg', freq: 'as_needed', days: null, instructions: 'Two puffs as needed for wheeze or breathlessness.' },
    vitals: [{ name: 'Oxygen Saturation', value: 98, unit: '%' }, { name: 'Pulse Rate', value: 92, unit: 'bpm' }],
    lab: { name: 'Complete Blood Count', priority: 'routine', indication: 'Evaluate for allergic component.',
      results: [{ name: 'Eosinophils', value: '5', unit: '%', reference: '1 - 4' }],
      comments: 'Mildly raised, supportive of an atopic picture.' },
  },
  { // Orthopedics
    complaint: 'Lower back pain radiating to the left leg for two weeks.',
    history: 'Started after lifting a heavy object. Worse on bending, better lying flat.',
    exam: 'Reduced lumbar flexion, positive straight-leg raise on the left at 50 degrees.',
    assessment: 'Lumbar radiculopathy, likely disc-related.',
    plan: 'NSAID, physiotherapy referral, review in two weeks; imaging if not improving.',
    condition: { display: 'Lumbar radiculopathy', icd10: 'M54.16', severity: 'moderate' },
    med: { name: 'Ibuprofen', value: 400, unit: 'mg', freq: 'twice_daily', days: 7, instructions: 'Take with food to reduce stomach upset.' },
    vitals: [{ name: 'Blood Pressure Systolic', value: 124, unit: 'mmHg' }],
    lab: { name: 'ESR', priority: 'routine', indication: 'Rule out an inflammatory cause of back pain.',
      results: [{ name: 'ESR', value: '14', unit: 'mm/hr', reference: '0 - 20' }],
      comments: 'Within normal limits; mechanical cause more likely.' },
  },
  { // Gynecology
    complaint: 'Irregular menstrual cycles for the past three months.',
    history: 'Cycles 40-55 days apart. No significant weight change. Not currently pregnant.',
    exam: 'Abdomen soft, non-tender. Vitals stable.',
    assessment: 'Oligomenorrhea, likely hormonal - investigate thyroid and prolactin.',
    plan: 'TSH and hormone panel, follow-up with results.',
    condition: { display: 'Oligomenorrhea', icd10: 'N91.4', severity: 'mild' },
    med: { name: 'Folic acid', value: 5, unit: 'mg', freq: 'once_daily', days: null, instructions: 'Once daily, ongoing.' },
    vitals: [{ name: 'Blood Pressure Systolic', value: 112, unit: 'mmHg' }],
    lab: { name: 'TSH', priority: 'routine', indication: 'Rule out thyroid dysfunction as a cause of irregular cycles.',
      results: [{ name: 'TSH', value: '3.1', unit: 'mIU/L', reference: '0.4 - 4.0' }],
      comments: 'Within normal range.' },
  },
  { // ENT
    complaint: 'Sore throat and pain on swallowing for three days.',
    history: 'Fever since yesterday. No cough. No difficulty breathing.',
    exam: 'Throat erythematous with tonsillar exudate. Temp 38.3C. Tender anterior cervical nodes.',
    assessment: 'Acute pharyngitis, likely bacterial.',
    plan: 'Antibiotics, salt-water gargles, review if not improving in 3 days.',
    condition: { display: 'Acute pharyngitis', icd10: 'J02.9', severity: 'moderate' },
    med: { name: 'Amoxicillin', value: 500, unit: 'mg', freq: 'three_times_daily', days: 7, instructions: 'Complete the full course even if symptoms improve.' },
    vitals: [{ name: 'Body Temperature', value: 38.3, unit: 'C' }],
    lab: { name: 'Throat Culture', priority: 'routine', indication: 'Confirm bacterial cause and guide antibiotic choice.',
      results: [{ name: 'Culture', value: 'Streptococcus pyogenes', unit: '', reference: 'No growth expected' }],
      comments: 'Group A Streptococcus isolated; continue current antibiotic.' },
  },
  { // Psychiatry
    complaint: 'Persistent low mood and poor sleep for about a month.',
    history: 'Reduced interest in usual activities. No suicidal ideation. No prior psychiatric history.',
    exam: 'Alert, oriented, mood low, affect congruent. No psychotic features.',
    assessment: 'Mild depressive episode.',
    plan: 'Start SSRI, psychoeducation, review in four weeks, safety-net advice given.',
    condition: { display: 'Mild depressive episode', icd10: 'F32.0', severity: 'mild' },
    med: { name: 'Sertraline', value: 50, unit: 'mg', freq: 'once_daily', days: null, instructions: 'Once daily in the morning, ongoing. Effects may take 2-4 weeks.' },
    vitals: [{ name: 'Blood Pressure Systolic', value: 118, unit: 'mmHg' }],
    lab: { name: 'TSH', priority: 'routine', indication: 'Rule out an organic (thyroid) cause of mood symptoms.',
      results: [{ name: 'TSH', value: '2.4', unit: 'mIU/L', reference: '0.4 - 4.0' }],
      comments: 'Normal; supports a primary mood disorder.' },
  },
];

// Allergy for a few of the treated patients, keyed by their index within
// `plans` (0-based, matches FAKE_PATIENTS.slice(0, TREAT_COUNT) order).
const ALLERGY_FOR = {
  0: { substance: 'Penicillin', criticality: 'high', severity: 'severe', reaction: 'Urticaria and facial swelling within an hour.' },
  2: { substance: 'Sulfa drugs', criticality: 'medium', severity: 'moderate', reaction: 'Skin rash.' },
  5: { substance: 'Latex', criticality: 'low', severity: 'mild', reaction: 'Mild contact irritation.' },
};

// ── Resolve clinics/labs (any authenticated session can read these) ────────
async function loadReference() {
  const anyDoc = await signIn(FAKE_DOCTORS[0].email);
  const { data: clinics } = await anyDoc.c.from('clinics').select('id, name');
  const { data: labs } = await anyDoc.c.from('diagnostic_labs').select('id, name');
  const clinicByName = Object.fromEntries((clinics ?? []).map((c) => [c.name, c.id]));
  const labByName = Object.fromEntries((labs ?? []).map((l) => [l.name, l.id]));
  await anyDoc.c.auth.signOut();
  return { clinicByName, labByName };
}

let ok = 0, fail = 0;
function report(label, err) {
  if (err) { fail += 1; console.log(`FAIL  ${label}: ${err.message ?? err}`); }
  else { ok += 1; console.log(`ok    ${label}`); }
}

async function main() {
  console.log(`Seeding clinical data against ${URL}\n`);
  const { clinicByName, labByName } = await loadReference();

  const treated = FAKE_PATIENTS.slice(0, TREAT_COUNT);
  const slotForDoctor = new Map(); // doctorIndex -> next free 30-min slot offset
  const plans = treated.map((patient, i) => {
    const doctorIndex = i % FAKE_DOCTORS.length;
    const doctor = FAKE_DOCTORS[doctorIndex];
    const clinicName = FAKE_CLINICS[doctorIndex % FAKE_CLINICS.length].name;
    const labName = FAKE_LABS[i % FAKE_LABS.length].name;
    const slotOffset = slotForDoctor.get(doctorIndex) ?? 0;
    slotForDoctor.set(doctorIndex, slotOffset + 1);
    return {
      patient, doctor, doctorIndex, slotOffset,
      clinicId: clinicByName[clinicName], labId: labByName[labName],
      vignette: VIGNETTES[doctorIndex % VIGNETTES.length],
    };
  });

  // ── Pass A: per doctor — weekly availability + encounters/labs for their patients ──
  const byDoctor = new Map();
  for (const p of plans) {
    if (!byDoctor.has(p.doctor.email)) byDoctor.set(p.doctor.email, []);
    byDoctor.get(p.doctor.email).push(p);
  }

  for (const [doctorEmail, group] of byDoctor) {
    let doc;
    try { doc = await signIn(doctorEmail); } catch (e) { report(`sign in ${doctorEmail}`, e); continue; }
    for (const p of group) p.doctorId = doc.id;

    // Weekly availability, Mon-Fri 09:00-13:00 (ignore "already exists" errors).
    const clinicId = group[0].clinicId;
    for (let dow = 1; dow <= 5; dow++) {
      const { error } = await doc.c.from('doctor_availability').insert({
        doctor_id: doc.id, clinic_id: clinicId, day_of_week: dow,
        start_time: '09:00', end_time: '13:00', slot_duration_minutes: 30, is_active: true,
      });
      if (error && !/duplicate|unique/i.test(error.message)) report(`availability for ${doctorEmail} (day ${dow})`, error);
    }
    report(`weekly availability for ${doctorEmail}`, null);

    for (const p of group) {
      const v = p.vignette;
      const today = isoDate(new Date());

      const { data: prof, error: lookErr } = await doc.c.rpc('find_patient_by_identifier', { p_identifier: p.patient.cnic });
      const patientRow = Array.isArray(prof) ? prof[0] : prof;
      if (lookErr || !patientRow) { report(`find patient ${p.patient.full_name} by CNIC`, lookErr ?? new Error('not found')); continue; }
      p.patientId = patientRow.id;

      const { data: enc, error: encErr } = await doc.c.from('encounters').insert({
        patient_id: p.patientId, doctor_id: doc.id, clinic_id: p.clinicId,
        encounter_date: today, chief_complaint: v.complaint,
        history_of_present_illness: v.history, physical_examination_notes: v.exam,
        assessment: v.assessment, plan: v.plan, specialty: p.doctor.specialization_primary,
        status: 'draft',
      }).select().single();
      if (encErr) { report(`encounter for ${p.patient.full_name}`, encErr); continue; }
      p.encounterId = enc.id;

      await doc.c.from('conditions').insert({
        encounter_id: enc.id, patient_id: p.patientId, doctor_id: doc.id,
        condition_display: v.condition.display, icd10_code: v.condition.icd10,
        severity: v.condition.severity, clinical_status: 'active',
      });
      await doc.c.from('observations').insert(
        v.vitals.map((vt) => ({
          encounter_id: enc.id, patient_id: p.patientId, authored_by_id: doc.id,
          observation_display: vt.name, value_quantity: vt.value, value_unit: vt.unit,
          observation_date: today,
        })),
      );
      await doc.c.from('medication_requests').insert({
        encounter_id: enc.id, patient_id: p.patientId, doctor_id: doc.id,
        medication_name: v.med.name, dosage_value: v.med.value, dosage_unit: v.med.unit,
        route: 'oral', frequency: v.med.freq, duration_days: v.med.days,
        status: 'active', start_date: today, instructions: v.med.instructions,
        dose_morning: true, dose_night: v.med.freq !== 'once_daily' && v.med.freq !== 'as_needed',
      });
      const { data: order, error: orderErr } = await doc.c.from('lab_orders').insert({
        encounter_id: enc.id, patient_id: p.patientId, ordering_doctor_id: doc.id,
        lab_id: p.labId, test_name: v.lab.name, priority: v.lab.priority,
        clinical_indication: v.lab.indication, status: 'ordered',
      }).select().single();
      if (orderErr) { report(`lab order for ${p.patient.full_name}`, orderErr); continue; }
      p.labOrderId = order.id;

      await doc.c.from('encounters').update({
        status: 'finalized', finalized_at: new Date().toISOString(),
        prescription_signature_name: p.doctor.full_name,
        prescription_signature_credentials: p.doctor.qualification_fcps ? 'MBBS, FCPS' : 'MBBS',
        prescription_signature_footer: p.doctor.pmdc_number,
      }).eq('id', enc.id);

      report(`encounter + prescription + lab order for ${p.patient.full_name} (${p.doctor.specialization_primary})`, null);
    }

    // Allergies keyed by the patient's index within `plans`.
    for (let idx = 0; idx < plans.length; idx++) {
      const p = plans[idx];
      if (p.doctor.email !== doctorEmail || !p.patientId) continue;
      const a = ALLERGY_FOR[idx];
      if (!a) continue;
      const { error } = await doc.c.from('allergies').insert({
        patient_id: p.patientId, recorded_by_id: doc.id, substance_name: a.substance,
        allergy_type: 'allergy', category: 'medication', criticality: a.criticality,
        severity: a.severity, reaction_description: a.reaction, clinical_status: 'active',
      });
      report(`allergy record for ${p.patient.full_name}`, error);
    }

    await doc.c.auth.signOut();
  }

  // ── Pass B: per lab — upload results for every order addressed to that lab ──
  const byLabWorkerEmail = {};
  FAKE_LAB_WORKERS.forEach((w, idx) => {
    const labName = FAKE_LABS[idx % FAKE_LABS.length].name;
    if (!byLabWorkerEmail[labName]) byLabWorkerEmail[labName] = w.email;
  });
  const labIdsNeeded = [...new Set(plans.map((p) => p.labId))];
  for (const labId of labIdsNeeded) {
    const labName = Object.entries(labByName).find(([, id]) => id === labId)?.[0];
    const workerEmail = byLabWorkerEmail[labName];
    if (!workerEmail) continue;
    let lw;
    try { lw = await signIn(workerEmail); } catch (e) { report(`sign in ${workerEmail}`, e); continue; }

    const { data: orders, error } = await lw.c.from('lab_orders').select('*').eq('lab_id', labId).eq('status', 'ordered');
    if (error) { report(`load lab queue for ${labName}`, error); await lw.c.auth.signOut(); continue; }

    for (const order of orders ?? []) {
      const p = plans.find((x) => x.labOrderId === order.id);
      const spec = p?.vignette.lab;
      if (!spec) continue;
      await lw.c.from('lab_orders').update({ status: 'sample_collected', sample_collected_at: new Date().toISOString() }).eq('id', order.id);
      await lw.c.from('lab_orders').update({ status: 'processing' }).eq('id', order.id);

      const fileName = `${spec.name.replace(/\s+/g, '-').toLowerCase()}.pdf`;
      const path = `${order.patient_id}/${order.id}/${Date.now()}_${fileName}`;
      const pdf = demoPdf(`HayaatID Diagnostics - ${spec.name}`, [
        `Patient: ${p.patient.full_name}`, `CNIC: ${p.patient.cnic}`, `Reported: ${isoDate(new Date())}`, '',
        ...spec.results.map((r) => `${r.name}: ${r.value} ${r.unit} (reference ${r.reference})`), '', spec.comments,
      ]);
      const { error: upErr } = await lw.c.storage.from('lab-results').upload(path, pdf, { contentType: 'application/pdf', upsert: true });
      if (upErr) { report(`upload result file for ${p.patient.full_name}`, upErr); continue; }

      const { error: insErr } = await lw.c.from('lab_results').insert({
        lab_order_id: order.id, lab_id: order.lab_id, uploaded_by: lw.id, patient_id: order.patient_id,
        result_file_name: fileName, result_file_path: path, structured_results: spec.results, comments: spec.comments,
      });
      if (insErr) { report(`store result for ${p.patient.full_name}`, insErr); continue; }

      await lw.c.from('lab_orders').update({ status: 'resulted', resulted_at: new Date().toISOString() }).eq('id', order.id);
      report(`lab result uploaded for ${p.patient.full_name} (${spec.name})`, null);
    }
    await lw.c.auth.signOut();
  }

  // ── Pass C: per doctor — review + release results ────────────────────────────
  for (const [doctorEmail, group] of byDoctor) {
    let doc;
    try { doc = await signIn(doctorEmail); } catch (e) { report(`sign in ${doctorEmail}`, e); continue; }
    for (const p of group) {
      if (!p.labOrderId) continue;
      const { data: order } = await doc.c.from('lab_orders').select('status, patient_id').eq('id', p.labOrderId).maybeSingle();
      if (!order || order.status !== 'resulted') continue;
      await doc.c.from('lab_orders').update({ status: 'reviewed', reviewed_at: new Date().toISOString() }).eq('id', p.labOrderId);
      await doc.c.from('lab_orders').update({ status: 'released_to_patient', released_to_patient_at: new Date().toISOString() }).eq('id', p.labOrderId);
      await doc.c.from('notifications').insert({
        recipient_id: order.patient_id, type: 'lab_result_ready',
        title: 'Lab result available', body: 'A new lab result has been released to you.', resource_id: p.labOrderId,
      });
      report(`released lab result to ${p.patient.full_name}`, null);
    }
    await doc.c.auth.signOut();
  }

  // ── Pass D: appointments (one past/completed, one upcoming/confirmed) ────────
  for (const p of plans) {
    if (!p.patientId || !p.doctorId) continue;
    let pat;
    try { pat = await signIn(p.patient.email); } catch (e) { report(`sign in ${p.patient.email}`, e); continue; }

    const past = daysFromNow(-10);
    const { error: e1 } = await pat.c.from('appointments').insert({
      patient_id: pat.id, doctor_id: p.doctorId, clinic_id: p.clinicId,
      appointment_date: isoDate(past), appointment_time: addMinutes('10:00', p.slotOffset * 30), appointment_type: 'in_person',
      status: 'completed', booked_by_role: 'patient', booked_by_id: pat.id,
      notes_for_doctor: p.vignette.complaint,
    });
    report(`past appointment for ${p.patient.full_name}`, e1);

    const future = nextWeekday(daysFromNow(3), 2); // next Tuesday, at least a few days out
    const { error: e2 } = await pat.c.from('appointments').insert({
      patient_id: pat.id, doctor_id: p.doctorId, clinic_id: p.clinicId,
      appointment_date: isoDate(future), appointment_time: addMinutes('09:30', p.slotOffset * 30), appointment_type: 'in_person',
      status: 'confirmed', booked_by_role: 'patient', booked_by_id: pat.id,
      notes_for_doctor: 'Follow-up visit.',
    });
    report(`upcoming appointment for ${p.patient.full_name}`, e2);
    await pat.c.auth.signOut();
  }

  // ── Pass E: a short chat thread for the first treated patient + their doctor ──
  const lead = plans[0];
  if (lead?.patientId && lead?.doctorId) {
    const pat = await signIn(lead.patient.email);
    const { data: convoId, error: startErr } = await pat.c.rpc('start_conversation', {
      p_patient: pat.id, p_doctor: lead.doctorId,
    });
    if (startErr) {
      report('start conversation', startErr);
      await pat.c.auth.signOut();
    } else {
      await pat.c.from('messages').insert({ conversation_id: convoId, sender_id: pat.id, body: 'Hi doctor, I still have a mild fever since yesterday, should I be worried?' });
      await pat.c.auth.signOut();

      const doc = await signIn(lead.doctor.email);
      await doc.c.from('messages').insert({ conversation_id: convoId, sender_id: doc.id, body: 'Keep taking the paracetamol and fluids. If the fever crosses 39C or lasts more than 2 more days, come in for a review.' });
      await doc.c.auth.signOut();

      const pat2 = await signIn(lead.patient.email);
      await pat2.c.from('messages').insert({ conversation_id: convoId, sender_id: pat2.id, body: 'Understood, thank you!' });
      await pat2.c.auth.signOut();
      report(`chat thread between ${lead.patient.full_name} and ${lead.doctor.full_name}`, null);
    }
  }

  console.log(`\n${ok} ok, ${fail} failed`);
  if (fail) process.exitCode = 1;
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
