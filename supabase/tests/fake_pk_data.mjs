// Generates a batch of realistic-looking (but entirely fake) Pakistani test
// identities: patients, doctors, lab workers, receptionists and an extra
// admin. Used by seed_fake_pk_data.mjs.
//
// CNICs, phone numbers and emails are synthetic but well-formed (13-digit
// CNIC, 03XXXXXXXXX mobile format) and guaranteed unique within this batch.
// Domain @hayaatfake.id keeps these separate from the official
// demo.*@hayaat.id accounts in demo_accounts.mjs.

export const FAKE_PASSWORD = process.env.FAKE_PASSWORD || 'Hayaat@2026';

const MALE_FIRST = [
  'Ahmed', 'Ali', 'Usman', 'Bilal', 'Hamza', 'Fahad', 'Imran', 'Kashif',
  'Waqas', 'Zeeshan', 'Asad', 'Junaid', 'Faisal', 'Naveed', 'Shahzad',
  'Tariq', 'Rizwan', 'Adeel', 'Saad', 'Hassan', 'Danish', 'Omar', 'Salman',
  'Yasir', 'Arslan',
];
const FEMALE_FIRST = [
  'Ayesha', 'Fatima', 'Sana', 'Hina', 'Mariam', 'Sadia', 'Nadia', 'Iqra',
  'Zainab', 'Amna', 'Rabia', 'Sobia', 'Farah', 'Kiran', 'Bushra', 'Uzma',
  'Saba', 'Nida', 'Mehwish', 'Anum', 'Sidra', 'Warda', 'Komal', 'Aliya',
  'Rukhsana',
];
const LAST = [
  'Khan', 'Ahmed', 'Ali', 'Malik', 'Butt', 'Sheikh', 'Chaudhry', 'Hussain',
  'Raza', 'Iqbal', 'Farooq', 'Qureshi', 'Baig', 'Abbasi', 'Awan', 'Tariq',
  'Javed', 'Siddiqui', 'Mirza', 'Rana', 'Gill', 'Cheema', 'Dar', 'Bhatti',
  'Niazi',
];
const BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
const SPECIALIZATIONS = [
  'General Medicine', 'Cardiology', 'Dermatology', 'Pediatrics',
  'Orthopedics', 'Gynecology', 'ENT', 'Psychiatry', 'Neurology',
  'Endocrinology',
];

// city -> [CNIC 5-digit district prefix, province]
export const CITIES = [
  ['Lahore', '35202', 'Punjab'],
  ['Karachi', '42101', 'Sindh'],
  ['Islamabad', '61101', 'Islamabad Capital Territory'],
  ['Rawalpindi', '37405', 'Punjab'],
  ['Faisalabad', '33100', 'Punjab'],
  ['Multan', '36302', 'Punjab'],
  ['Peshawar', '17301', 'Khyber Pakhtunkhwa'],
  ['Quetta', '54400', 'Balochistan'],
  ['Sialkot', '34101', 'Punjab'],
  ['Gujranwala', '34301', 'Punjab'],
];

function pad(n, len) {
  return String(n).padStart(len, '0');
}

function pick(arr, i) {
  return arr[i % arr.length];
}

function makeCnic(cityIdx, serial) {
  const [, prefix] = CITIES[cityIdx % CITIES.length];
  return `${prefix}${pad(serial, 7)}1`;
}

function makePhone(serial) {
  const operator = pad(21 + (serial % 40), 2); // 03(21-60)
  return `03${operator}${pad(serial, 7)}`;
}

function makeDob(minAge, maxAge, seed) {
  const year = 2026 - (minAge + (seed % (maxAge - minAge + 1)));
  const month = pad(1 + (seed % 12), 2);
  const day = pad(1 + (seed % 28), 2);
  return `${year}-${month}-${day}`;
}

function makePerson(index, genderCycle) {
  const gender = genderCycle % 2 === 0 ? 'male' : 'female';
  const first = gender === 'male' ? pick(MALE_FIRST, index) : pick(FEMALE_FIRST, index);
  const last = pick(LAST, index + 7);
  const fullName = `${first} ${last}`;
  return { first, last, fullName, gender };
}

// ── Patients ────────────────────────────────────────────────────────────────
export const PATIENT_COUNT = 50;
export const FAKE_PATIENTS = Array.from({ length: PATIENT_COUNT }, (_, i) => {
  const p = makePerson(i, i);
  const cityIdx = i % CITIES.length;
  const [city, , province] = CITIES[cityIdx];
  const emergency = makePerson(i + 31, i + 1);
  return {
    key: `patient_fake_${i + 1}`,
    email: `${p.first}.${p.last}${i + 1}@hayaatfake.id`.toLowerCase(),
    cnic: makeCnic(cityIdx, 200000 + i),
    full_name: p.fullName,
    phone: makePhone(200000 + i),
    gender: p.gender,
    date_of_birth: makeDob(5, 80, i * 7 + 3),
    blood_group: pick(BLOOD_GROUPS, i),
    city,
    province,
    emergency_contact_name: emergency.fullName,
    emergency_contact_phone: makePhone(500000 + i),
  };
});

// ── Doctors (self-signup -> pending, promoted/approved by generated SQL) ────
export const DOCTOR_COUNT = 8;
export const FAKE_DOCTORS = Array.from({ length: DOCTOR_COUNT }, (_, i) => {
  const p = makePerson(i + 100, i);
  const cityIdx = i % CITIES.length;
  return {
    key: `doctor_fake_${i + 1}`,
    email: `dr.${p.first}.${p.last}${i + 1}@hayaatfake.id`.toLowerCase(),
    cnic: makeCnic(cityIdx, 300000 + i),
    full_name: `Dr. ${p.fullName}`,
    phone: makePhone(300000 + i),
    gender: p.gender,
    date_of_birth: makeDob(30, 62, i * 11 + 5),
    pmdc_number: `PMDC-${50000 + i}`,
    specialization_primary: pick(SPECIALIZATIONS, i),
    qualification_mbbs: true,
    qualification_fcps: i % 2 === 0,
    years_of_experience: 3 + (i % 20),
    consultation_fee_pkr: 1000 + (i % 6) * 500,
  };
});

// ── Staff created as 'patient' via public signup, promoted by generated SQL ─
export const LAB_WORKER_COUNT = 3;
export const FAKE_LAB_WORKERS = Array.from({ length: LAB_WORKER_COUNT }, (_, i) => {
  const p = makePerson(i + 200, i);
  const cityIdx = i % CITIES.length;
  return {
    key: `labworker_fake_${i + 1}`,
    email: `${p.first}.${p.last}${i + 1}.lab@hayaatfake.id`.toLowerCase(),
    cnic: makeCnic(cityIdx, 400000 + i),
    full_name: p.fullName,
    phone: makePhone(400000 + i),
    gender: p.gender,
    date_of_birth: makeDob(22, 50, i * 13 + 2),
    employee_id: `LAB-FAKE-${pad(i + 1, 3)}`,
    position_title: pick(['Lab Technician', 'Senior Lab Technician', 'Phlebotomist'], i),
  };
});

export const RECEPTIONIST_COUNT = 3;
export const FAKE_RECEPTIONISTS = Array.from({ length: RECEPTIONIST_COUNT }, (_, i) => {
  const p = makePerson(i + 300, i);
  const cityIdx = i % CITIES.length;
  return {
    key: `reception_fake_${i + 1}`,
    email: `${p.first}.${p.last}${i + 1}.front@hayaatfake.id`.toLowerCase(),
    cnic: makeCnic(cityIdx, 450000 + i),
    full_name: p.fullName,
    phone: makePhone(450000 + i),
    gender: p.gender,
    date_of_birth: makeDob(20, 45, i * 17 + 9),
    employee_id: `REC-FAKE-${pad(i + 1, 3)}`,
  };
});

export const FAKE_EXTRA_ADMIN = {
  key: 'admin_fake_1',
  email: 'fake.admin@hayaatfake.id',
  cnic: makeCnic(0, 500000),
  full_name: 'Zara Farooqi',
  phone: makePhone(500999),
  gender: 'female',
  date_of_birth: '1984-02-20',
};

// ── New clinics / labs so staff have somewhere to belong ─────────────────────
export const FAKE_CLINICS = [
  { name: 'Al-Shifa Medical Center', phone: '04236000001', city: 'Lahore', province: 'Punjab', address: '45 Ferozepur Road' },
  { name: 'City Care Clinic', phone: '02135000002', city: 'Karachi', province: 'Sindh', address: '12 Shahrah-e-Faisal' },
  { name: 'Margalla Health Clinic', phone: '05112000003', city: 'Islamabad', province: 'Islamabad Capital Territory', address: 'F-8 Markaz' },
];

export const FAKE_LABS = [
  { name: 'Punjab Diagnostic Lab', license: 'LAB-PB-2201', city: 'Faisalabad', province: 'Punjab', phone: '04136000004' },
  { name: 'Sindh Central Laboratory', license: 'LAB-SD-3305', city: 'Karachi', province: 'Sindh', phone: '02137000005' },
];

export function signupMetadata(role, a) {
  const base = {
    role,
    cnic: a.cnic,
    full_name: a.full_name,
    phone: a.phone,
    gender: a.gender,
    date_of_birth: a.date_of_birth,
    email: a.email,
  };
  if (role === 'patient') base.blood_group = a.blood_group;
  if (role === 'doctor') {
    base.pmdc_number = a.pmdc_number;
    base.specialization_primary = a.specialization_primary;
    base.qualification_mbbs = a.qualification_mbbs;
    base.qualification_fcps = a.qualification_fcps;
  }
  return base;
}
