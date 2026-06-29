// ─────────────────────────────────────────────────────────────────────────────
//  Demo seed data
//
//  Pre-loads sample clinics, labs, one account per role, and a full clinical
//  history for the demo patient so every role has something to show in a live
//  demo (Scope §16 — "Demo data seed script").
//
//  Shared password for ALL demo accounts: password123
// ─────────────────────────────────────────────────────────────────────────────

const { db, now } = require('./store');

const PW = 'password123';
const ts = now();

// Stable IDs so the apps can reference known records.
const ID = {
  // clinics / labs
  clinicShifa: 'clinic-shifa-0001',
  clinicAku: 'clinic-aku-0002',
  labShifa: 'lab-shifa-0001',
  labPending: 'lab-chughtai-0002',
  // profiles
  patientAyesha: 'prof-patient-ayesha',
  patientBilal: 'prof-patient-bilal',
  doctorImran: 'prof-doctor-imran',
  doctorSanaPending: 'prof-doctor-sana',
  labWorkerZafar: 'prof-lab-zafar',
  receptionistHina: 'prof-recept-hina',
  adminSuper: 'prof-admin-super',
  // clinical
  apptUpcoming: 'appt-0001',
  encounterHtn: 'enc-htn-0001',
  labOrderLipid: 'laborder-0001',
};

function seed() {
  // ── Clinics ────────────────────────────────────────────────────────────────
  db.clinics.push(
    {
      id: ID.clinicShifa,
      name: 'Shifa International Hospital',
      type: 'hospital',
      phone: '+92 51 8464646',
      address_street: 'Sector H-8/4, Pitras Bukhari Road',
      address_city: 'Islamabad',
      address_province: 'Islamabad',
      status: 'active',
      created_at: ts,
    },
    {
      id: ID.clinicAku,
      name: 'Aga Khan University Hospital',
      type: 'teaching_hospital',
      phone: '+92 21 111911911',
      address_street: 'Stadium Road',
      address_city: 'Karachi',
      address_province: 'Sindh',
      status: 'active',
      created_at: ts,
    },
  );

  // ── Diagnostic labs ──────────────────────────────────────────────────────────
  db.diagnostic_labs.push(
    {
      id: ID.labShifa,
      name: 'Shifa Diagnostic Lab',
      license_number: 'LAB-ISB-2021-0098',
      phone: '+92 51 8464600',
      address_city: 'Islamabad',
      address_province: 'Islamabad',
      status: 'active',
      created_at: ts,
    },
    {
      id: ID.labPending,
      name: 'Chughtai Lab — G9 Branch',
      license_number: 'LAB-ISB-2024-0457',
      phone: '+92 51 111456789',
      address_city: 'Islamabad',
      address_province: 'Islamabad',
      status: 'pending', // awaiting admin approval (admin demo)
      created_at: ts,
    },
  );

  // ── Helper to add a base profile + its role-extended profile ─────────────────
  const addProfile = (base, extTable, ext) => {
    db.profiles.push({ created_at: ts, updated_at: ts, status: 'active', ...base });
    if (extTable) db[extTable].push({ id: base.id, created_at: ts, updated_at: ts, ...ext });
  };

  // ── Patients ─────────────────────────────────────────────────────────────────
  addProfile(
    {
      id: ID.patientAyesha,
      auth_user_id: 'auth-ayesha',
      cnic: '3520112345671',
      full_name: 'Ayesha Khan',
      date_of_birth: '1958-03-14',
      gender: 'female',
      phone_primary: '+92 310 1234567',
      email: 'ayesha@example.com',
      role: 'patient',
      password: PW,
    },
    'patient_profiles',
    {
      blood_group: 'B+',
      height_cm: 162,
      weight_kg: 68,
      address_street: 'House 12, Street 5, F-7/2',
      address_city: 'Islamabad',
      address_province: 'Islamabad',
      emergency_contact_name: 'Imran Khan',
      emergency_contact_phone: '+92 300 7654321',
      health_card_number: 'HC-2024-00001234',
      known_allergies: 'Penicillin (rash)',
      chronic_conditions_summary: 'Hypertension, Type 2 Diabetes',
    },
  );

  addProfile(
    {
      id: ID.patientBilal,
      auth_user_id: 'auth-bilal',
      cnic: '3520155555552',
      full_name: 'Bilal Ahmed',
      date_of_birth: '1990-07-22',
      gender: 'male',
      phone_primary: '+92 321 9876543',
      email: 'bilal@example.com',
      role: 'patient',
      password: PW,
    },
    'patient_profiles',
    {
      blood_group: 'O+',
      address_city: 'Islamabad',
      address_province: 'Islamabad',
      health_card_number: 'HC-2024-00005678',
    },
  );

  // ── Doctors ──────────────────────────────────────────────────────────────────
  addProfile(
    {
      id: ID.doctorImran,
      auth_user_id: 'auth-imran',
      cnic: '3520199999991',
      full_name: 'Dr. Imran Yousuf',
      date_of_birth: '1975-01-10',
      gender: 'male',
      phone_primary: '+92 333 1112223',
      email: 'imran@example.com',
      role: 'doctor',
      password: PW,
    },
    'doctor_profiles',
    {
      pmdc_number: 'PMDC-12345-C',
      specialization_primary: 'Cardiology',
      qualification_mbbs: true,
      qualification_fcps: true,
      years_of_experience: 18,
      consultation_fee_pkr: 3000,
      bio: 'Consultant Cardiologist with 18 years of clinical experience.',
      is_available: true,
      clinic_id: ID.clinicShifa,
      approved_at: ts,
      approved_by: ID.adminSuper,
    },
  );

  // Pending doctor application (for the admin approval queue demo).
  db.profiles.push({
    id: ID.doctorSanaPending,
    auth_user_id: 'auth-sana',
    cnic: '3520188888882',
    full_name: 'Dr. Sana Tariq',
    date_of_birth: '1985-09-05',
    gender: 'female',
    phone_primary: '+92 345 6667778',
    email: 'sana@example.com',
    role: 'doctor',
    password: PW,
    status: 'pending',
    created_at: ts,
    updated_at: ts,
  });
  db.doctor_profiles.push({
    id: ID.doctorSanaPending,
    pmdc_number: 'PMDC-67890-E',
    specialization_primary: 'Endocrinology',
    qualification_mbbs: true,
    qualification_md: true,
    years_of_experience: 9,
    consultation_fee_pkr: 2500,
    bio: 'Endocrinologist focused on diabetes care.',
    is_available: true,
    clinic_id: ID.clinicAku,
    created_at: ts,
    updated_at: ts,
  });

  // ── Lab worker ───────────────────────────────────────────────────────────────
  addProfile(
    {
      id: ID.labWorkerZafar,
      auth_user_id: 'auth-zafar',
      cnic: '3520177777771',
      full_name: 'Zafar Iqbal',
      date_of_birth: '1992-04-18',
      gender: 'male',
      phone_primary: '+92 301 2223334',
      email: 'zafar@example.com',
      role: 'lab_worker',
      password: PW,
    },
    'lab_worker_profiles',
    {
      lab_id: ID.labShifa,
      employee_id: 'EMP-LAB-014',
      position_title: 'Senior Lab Technician',
      approved_at: ts,
    },
  );

  // ── Receptionist ─────────────────────────────────────────────────────────────
  addProfile(
    {
      id: ID.receptionistHina,
      auth_user_id: 'auth-hina',
      cnic: '3520166666661',
      full_name: 'Hina Saleem',
      date_of_birth: '1995-11-30',
      gender: 'female',
      phone_primary: '+92 311 4445556',
      email: 'hina@example.com',
      role: 'receptionist',
      password: PW,
    },
    'receptionist_profiles',
    {
      clinic_id: ID.clinicShifa,
      employee_id: 'EMP-REC-007',
      approved_at: ts,
    },
  );

  // ── Admin (super) ────────────────────────────────────────────────────────────
  addProfile(
    {
      id: ID.adminSuper,
      auth_user_id: 'auth-admin',
      cnic: '3520100000001',
      full_name: 'System Administrator',
      date_of_birth: '1980-01-01',
      gender: 'other',
      phone_primary: '+92 300 0000000',
      email: 'admin@example.com',
      role: 'admin',
      password: PW,
    },
    'admin_profiles',
    {
      admin_level: 'super_admin',
      can_approve_doctors: true,
      can_approve_labs: true,
      can_suspend_accounts: true,
    },
  );

  // ── Doctor availability (Dr. Imran @ Shifa, Mon & Wed) ───────────────────────
  [1, 3].forEach((dow) => {
    db.doctor_availability.push({
      id: `avail-imran-${dow}`,
      doctor_id: ID.doctorImran,
      clinic_id: ID.clinicShifa,
      day_of_week: dow, // 1=Mon, 3=Wed
      start_time: '09:00',
      end_time: '13:00',
      slot_duration_minutes: 30,
      is_active: true,
      created_at: ts,
    });
  });

  // ── Upcoming appointment (Ayesha → Dr. Imran, confirmed) ─────────────────────
  db.appointments.push({
    id: ID.apptUpcoming,
    patient_id: ID.patientAyesha,
    doctor_id: ID.doctorImran,
    clinic_id: ID.clinicShifa,
    appointment_date: '2026-07-06',
    appointment_time: '09:30',
    appointment_type: 'follow_up',
    status: 'confirmed',
    booked_by_role: 'patient',
    booked_by_id: ID.patientAyesha,
    notes_for_doctor: 'Routine BP review.',
    created_at: ts,
    updated_at: ts,
  });

  // ── Finalized encounter (Hypertension review) ────────────────────────────────
  db.encounters.push({
    id: ID.encounterHtn,
    patient_id: ID.patientAyesha,
    doctor_id: ID.doctorImran,
    clinic_id: ID.clinicShifa,
    appointment_id: null,
    encounter_type: 'outpatient',
    encounter_date: '2026-06-18',
    chief_complaint: 'Occasional headaches, mild dizziness in mornings.',
    history_of_present_illness: 'Known hypertensive on Amlodipine. BP 148/94 on arrival.',
    physical_examination_notes: 'Cardiovascular exam unremarkable. No edema.',
    assessment: 'Essential hypertension, reasonably controlled.',
    plan: 'Continue current regimen. Reduce salt. 30-min daily walk.',
    follow_up_required: true,
    follow_up_date: '2026-07-06',
    status: 'finalized',
    finalized_at: ts,
    created_at: ts,
    updated_at: ts,
  });

  db.conditions.push({
    id: 'cond-htn-0001',
    encounter_id: ID.encounterHtn,
    patient_id: ID.patientAyesha,
    doctor_id: ID.doctorImran,
    icd10_code: 'I10',
    condition_display: 'Essential (primary) hypertension',
    severity: 'moderate',
    clinical_status: 'active',
    is_chronic: true,
    created_at: ts,
  });

  db.medication_requests.push(
    {
      id: 'med-amlo-0001',
      encounter_id: ID.encounterHtn,
      patient_id: ID.patientAyesha,
      doctor_id: ID.doctorImran,
      medication_name: 'Amlodipine',
      dosage_value: 5,
      dosage_unit: 'mg',
      route: 'oral',
      frequency: 'once_daily',
      duration_days: 30,
      instructions: 'Take in the morning.',
      status: 'active',
      start_date: '2026-06-18',
      created_at: ts,
    },
    {
      id: 'med-metf-0001',
      encounter_id: ID.encounterHtn,
      patient_id: ID.patientAyesha,
      doctor_id: ID.doctorImran,
      medication_name: 'Metformin',
      dosage_value: 500,
      dosage_unit: 'mg',
      route: 'oral',
      frequency: 'twice_daily',
      instructions: 'Take with food.',
      status: 'active',
      start_date: '2026-06-18',
      created_at: ts,
    },
  );

  db.observations.push(
    {
      id: 'obs-bp-0001',
      encounter_id: ID.encounterHtn,
      patient_id: ID.patientAyesha,
      authored_by_id: ID.doctorImran,
      observation_display: 'Blood Pressure Systolic',
      value_quantity: 148,
      value_unit: 'mmHg',
      reference_range_text: '90-120 mmHg',
      observation_date: '2026-06-18',
      created_at: ts,
    },
    {
      id: 'obs-pulse-0001',
      encounter_id: ID.encounterHtn,
      patient_id: ID.patientAyesha,
      authored_by_id: ID.doctorImran,
      observation_display: 'Pulse Rate',
      value_quantity: 78,
      value_unit: 'bpm',
      reference_range_text: '60-100 bpm',
      observation_date: '2026-06-18',
      created_at: ts,
    },
  );

  db.allergies.push({
    id: 'allergy-pcn-0001',
    patient_id: ID.patientAyesha,
    recorded_by_id: ID.doctorImran,
    encounter_id: ID.encounterHtn,
    substance_name: 'Penicillin',
    allergy_type: 'allergy',
    category: 'medication',
    criticality: 'high',
    reaction_description: 'Skin rash and itching.',
    clinical_status: 'active',
    created_at: ts,
  });

  // ── Lab order + released result ──────────────────────────────────────────────
  db.lab_orders.push({
    id: ID.labOrderLipid,
    encounter_id: ID.encounterHtn,
    patient_id: ID.patientAyesha,
    ordering_doctor_id: ID.doctorImran,
    lab_id: ID.labShifa,
    test_name: 'Lipid Profile',
    priority: 'routine',
    clinical_indication: 'Hypertension management — assess cardiovascular risk.',
    status: 'released_to_patient',
    ordered_at: ts,
    sample_collected_at: ts,
    resulted_at: ts,
    reviewed_at: ts,
    released_to_patient_at: ts,
  });

  db.lab_results.push({
    id: 'labresult-0001',
    lab_order_id: ID.labOrderLipid,
    lab_id: ID.labShifa,
    uploaded_by: ID.labWorkerZafar,
    patient_id: ID.patientAyesha,
    result_file_url: 'https://example.com/demo/lipid-profile.pdf',
    result_file_name: 'lipid-profile.pdf',
    structured_results: [
      { name: 'Total Cholesterol', value: '190', unit: 'mg/dL' },
      { name: 'HDL', value: '55', unit: 'mg/dL' },
      { name: 'LDL', value: '110', unit: 'mg/dL' },
      { name: 'Triglycerides', value: '140', unit: 'mg/dL' },
    ],
    comments: 'Results within acceptable range.',
    created_at: ts,
  });

  // ── A welcome notification for the patient ──────────────────────────────────
  db.notifications.push({
    id: 'notif-welcome-0001',
    recipient_id: ID.patientAyesha,
    type: 'lab_result_ready',
    title: 'Lab result available',
    body: 'A new lab result has been released to you.',
    is_read: false,
    resource_id: ID.labOrderLipid,
    created_at: ts,
  });

  console.log(
    `[seed] Loaded: ${db.profiles.length} profiles, ${db.clinics.length} clinics, ` +
      `${db.diagnostic_labs.length} labs, ${db.encounters.length} encounters, ` +
      `${db.lab_orders.length} lab orders.`,
  );
}

module.exports = { seed, ID };
