// Unified Demo Data Sync across all portals: Doctor, Patient, Lab, Receptionist, Admin.
//
// Usage: node supabase/tests/seed_live_sync_data.mjs

import { createClient } from '@supabase/supabase-js';
import { byKey, DEMO_PASSWORD } from './demo_accounts.mjs';

const URL = process.env.SUPABASE_URL || 'https://iikwdtiqvxxatrzahuzo.supabase.co';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

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

async function signIn(key) {
  const account = byKey(key);
  const c = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await c.auth.signInWithPassword({
    email: account.email,
    password: DEMO_PASSWORD,
  });
  if (error) {
    console.error(`Sign in as ${key} failed:`, error.message);
    process.exit(1);
  }
  return { id: data.user.id, email: account.email, c };
}

async function main() {
  console.log('Connecting and synchronizing shared demo data across all modules...');
  const [admin, doctor, labWorker, receptionist, patient] = await Promise.all([
    signIn('admin'),
    signIn('doctor'),
    signIn('lab'),
    signIn('reception'),
    signIn('patient'),
  ]);

  // 1. Get Clinic & Lab
  const { data: clinics } = await admin.c.from('clinics').select('id, name').limit(5);
  const clinic = clinics?.find((c) => c.name === 'Hayaat Family Clinic') || clinics?.[0];
  const { data: labs } = await admin.c.from('diagnostic_labs').select('id, name').limit(5);
  const lab = labs?.find((l) => l.name === 'Hayaat Diagnostics') || labs?.[0];

  if (!clinic || !lab) {
    console.error('Clinic or Lab not found. Make sure supabase/demo_seed.sql has been run.');
    process.exit(1);
  }

  // 2. Fetch patient demographics
  const { data: patientProfile } = await patient.c
    .from('profiles')
    .select('full_name, cnic, card_number')
    .eq('id', patient.id)
    .single();

  console.log(`Demo Patient: ${patientProfile?.full_name} (Hayaat ID: ${patientProfile?.card_number})`);
  console.log(`Demo Clinic: ${clinic.name} | Demo Lab: ${lab.name}`);

  // 3. Ensure Today's Appointment
  const today = new Date().toISOString().slice(0, 10);
  const { data: existingAppts } = await doctor.c
    .from('appointments')
    .select('id, appointment_date, appointment_time, status')
    .eq('patient_id', patient.id)
    .eq('appointment_date', today);

  if (!existingAppts || existingAppts.length === 0) {
    console.log(`Creating today's appointment (${today} at 10:00 AM)...`);
    const { error: apptErr } = await receptionist.c.from('appointments').insert({
      patient_id: patient.id,
      doctor_id: doctor.id,
      clinic_id: clinic.id,
      appointment_date: today,
      appointment_time: '10:00:00',
      appointment_type: 'in_person',
      status: 'confirmed',
      booked_by_role: 'receptionist',
      booked_by_id: receptionist.id,
      notes_for_doctor: 'Follow-up for chronic fatigue and routine blood panel review.',
    });
    if (apptErr) console.warn('Appointment creation error:', apptErr.message);
    else console.log('✓ Created confirmed appointment for today');
  } else {
    console.log(`✓ Appointment for today already exists (${existingAppts[0].appointment_time})`);
  }

  // Also an upcoming appointment in 3 days
  const futureDate = new Date(Date.now() + 3 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const { data: upcomingAppts } = await doctor.c
    .from('appointments')
    .select('id')
    .eq('patient_id', patient.id)
    .eq('appointment_date', futureDate);

  if (!upcomingAppts || upcomingAppts.length === 0) {
    await patient.c.from('appointments').insert({
      patient_id: patient.id,
      doctor_id: doctor.id,
      clinic_id: clinic.id,
      appointment_date: futureDate,
      appointment_time: '11:30:00',
      appointment_type: 'in_person',
      status: 'confirmed',
      booked_by_role: 'patient',
      booked_by_id: patient.id,
      notes_for_doctor: 'Routine follow-up consultation.',
    });
    console.log(`✓ Created upcoming appointment for ${futureDate}`);
  }

  // 4. Ensure Encounter + Prescriptions + Vitals
  const { data: existingEnc } = await doctor.c
    .from('encounters')
    .select('id, status')
    .eq('patient_id', patient.id)
    .eq('doctor_id', doctor.id)
    .eq('chief_complaint', 'Demo encounter - fatigue and routine screening')
    .maybeSingle();

  let encounterId = existingEnc?.id;
  if (!encounterId) {
    console.log('Creating clinical encounter with prescriptions and observations...');
    const { data: enc, error: encErr } = await doctor.c.from('encounters').insert({
      patient_id: patient.id,
      doctor_id: doctor.id,
      clinic_id: clinic.id,
      encounter_date: today,
      chief_complaint: 'Demo encounter - fatigue and routine screening',
      history_of_present_illness: 'Three weeks of tiredness and reduced exercise tolerance. No fever, no weight loss.',
      physical_examination_notes: 'Conjunctival pallor. Chest clear. BP 128/84, pulse 82 regular.',
      assessment: 'Probable iron-deficiency anaemia; screen for diabetes and dyslipidaemia.',
      plan: 'CBC, HbA1c and lipid profile today. Review with results.',
      specialty: 'General Medicine',
      status: 'finalized',
      finalized_at: new Date().toISOString(),
      prescription_signature_name: 'Dr. Sara Ahmed',
      prescription_signature_credentials: 'MBBS, FCPS',
      prescription_signature_footer: 'PMDC-45219',
    }).select('id').single();

    if (encErr) {
      console.warn('Encounter creation error:', encErr.message);
    } else {
      encounterId = enc.id;
      await doctor.c.from('conditions').insert({
        encounter_id: encounterId, patient_id: patient.id, doctor_id: doctor.id,
        condition_display: 'Fatigue & Anaemia', icd10_code: 'R53.83', severity: 'mild',
        clinical_status: 'active', notes: 'Under investigation.',
      });
      await doctor.c.from('observations').insert([
        { encounter_id: encounterId, patient_id: patient.id, authored_by_id: doctor.id,
          observation_display: 'Blood Pressure Systolic', value_quantity: 128, value_unit: 'mmHg',
          observation_date: today },
        { encounter_id: encounterId, patient_id: patient.id, authored_by_id: doctor.id,
          observation_display: 'Pulse Rate', value_quantity: 82, value_unit: 'bpm',
          observation_date: today },
      ]);
      await doctor.c.from('medication_requests').insert({
        encounter_id: encounterId, patient_id: patient.id, doctor_id: doctor.id,
        medication_name: 'Ferrous sulfate', dosage_value: 200, dosage_unit: 'mg',
        route: 'oral', frequency: 'twice_daily', duration_days: 30, status: 'active',
        start_date: today, instructions: 'Take after food. Expect darker stools.',
        dose_morning: true, dose_night: true,
      });
      console.log('✓ Created finalized clinical encounter with prescriptions and observations');
    }
  } else {
    console.log('✓ Clinical encounter and prescriptions already present');
  }

  // 5. Ensure 3 Lab Reports (CBC, HbA1c, Lipid Profile)
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

  for (const t of TESTS) {
    const { data: existingOrders } = await labWorker.c
      .from('lab_orders')
      .select('id, status, lab_results(id)')
      .eq('patient_id', patient.id)
      .eq('test_name', t.name)
      .neq('status', 'cancelled');

    const hasValidResult = existingOrders?.some((o) => o.status === 'released_to_patient' && (Array.isArray(o.lab_results) ? o.lab_results.length > 0 : !!o.lab_results));

    if (!hasValidResult) {
      console.log(`Seeding lab report for ${t.name}...`);
      const { data: order, error: oErr } = await doctor.c.from('lab_orders').insert({
        encounter_id: encounterId || null,
        patient_id: patient.id,
        ordering_doctor_id: doctor.id,
        lab_id: lab.id,
        test_name: t.name,
        priority: t.priority,
        clinical_indication: t.indication,
        status: 'released_to_patient',
        ordered_at: new Date().toISOString(),
        sample_collected_at: new Date().toISOString(),
        resulted_at: new Date().toISOString(),
        released_to_patient_at: new Date().toISOString(),
      }).select('id').single();

      if (oErr) {
        console.warn(`Order error for ${t.name}:`, oErr.message);
        continue;
      }

      const fileName = `${t.name.replace(/\s+/g, '-').toLowerCase()}.pdf`;
      const path = `${patient.id}/${order.id}/${Date.now()}_${fileName}`;
      const pdf = demoPdf(`Hayaat Diagnostics - ${t.name}`, [
        `Patient: ${patientProfile?.full_name ?? 'Demo Patient'}`,
        `CNIC: ${patientProfile?.cnic ?? '3520112345671'}`,
        `Hayaat ID: ${patientProfile?.card_number ?? ''}`,
        `Reported: ${today}`,
        '',
        ...t.results.map((r) => `${r.name}: ${r.value} ${r.unit}   (reference ${r.reference})`),
        '',
        t.comments,
      ]);

      const { error: upErr } = await labWorker.c.storage.from('lab-results').upload(path, pdf, {
        contentType: 'application/pdf',
        upsert: true,
      });
      if (upErr) console.warn(`PDF upload error for ${t.name}:`, upErr.message);

      await labWorker.c.from('lab_results').insert({
        lab_order_id: order.id,
        lab_id: lab.id,
        uploaded_by: labWorker.id,
        patient_id: patient.id,
        result_file_name: fileName,
        result_file_path: path,
        structured_results: t.results,
        comments: t.comments,
      });

      await doctor.c.from('notifications').insert({
        recipient_id: patient.id,
        type: 'lab_result_ready',
        title: 'Lab report released',
        body: `Your lab result for ${t.name} is now available.`,
        resource_id: order.id,
      });
      console.log(`✓ Uploaded and released ${t.name} report`);
    } else {
      console.log(`✓ ${t.name} report already released and visible to patient`);
    }
  }

  // 6. Ensure Penicillin Allergy
  const { data: allergies } = await doctor.c
    .from('allergies')
    .select('id')
    .eq('patient_id', patient.id)
    .ilike('substance_name', 'penicillin');

  if (!allergies || allergies.length === 0) {
    await doctor.c.from('allergies').insert({
      patient_id: patient.id,
      recorded_by_id: doctor.id,
      substance_name: 'Penicillin',
      allergy_type: 'allergy',
      category: 'medication',
      criticality: 'high',
      severity: 'severe',
      reaction_description: 'Urticaria and facial swelling within an hour.',
      clinical_status: 'active',
    });
    console.log('✓ Recorded Penicillin allergy on patient');
  }

  console.log('\n======================================================');
  console.log('ALL MODULES ARE FULLY SYNCHRONIZED WITH SHARED DATA:');
  console.log('  • Receptionist Portal: Sees today\'s clinic schedule & check-in');
  console.log('  • Doctor Portal: Sees today\'s appointments, encounter & reports');
  console.log('  • Lab Worker Portal: Sees order queue, can add direct reports & cancel send');
  console.log('  • Patient Portal: Sees next appointment, timeline, prescriptions & 3 lab reports');
  console.log('  • Admin Portal: Sees active users, clinic, and lab stats');
  console.log('======================================================\n');
}

main().catch((err) => {
  console.error('Sync failed:', err);
  process.exit(1);
});
