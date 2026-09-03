// Shared definition of the demo identities used by the seeding and
// end-to-end scripts. CNIC is the citizen identity key (P-FR-001/005/019);
// the 16-digit Hayaat card number is issued by the database on sign-up.
//
// Every account is created through the ordinary public sign-up API, so the
// service-role key is never needed. Self-service sign-up can only produce
// `patient` and `doctor` roles -- `demo_seed.sql` promotes the lab worker,
// receptionist and admin afterwards.

export const DEMO_PASSWORD = process.env.DEMO_PASSWORD || 'Hayaat@2026';

export const DEMO_ACCOUNTS = [
  {
    key: 'admin',
    email: 'demo.admin@hayaat.id',
    cnic: '3520100000001',
    full_name: 'Demo Administrator',
    phone: '03001000001',
    gender: 'male',
    date_of_birth: '1982-04-11',
    signupRole: 'patient', // promoted to admin by demo_seed.sql
    finalRole: 'admin',
  },
  {
    key: 'doctor',
    email: 'demo.doctor@hayaat.id',
    cnic: '3520199999991',
    full_name: 'Dr. Sara Ahmed',
    phone: '03009999991',
    gender: 'female',
    date_of_birth: '1986-09-02',
    signupRole: 'doctor',
    finalRole: 'doctor',
    meta: {
      pmdc_number: 'PMDC-45219',
      specialization_primary: 'General Medicine',
      qualification_mbbs: true,
      qualification_fcps: true,
    },
  },
  {
    key: 'lab',
    email: 'demo.lab@hayaat.id',
    cnic: '3520177777771',
    full_name: 'Bilal Hussain',
    phone: '03007777771',
    gender: 'male',
    date_of_birth: '1991-01-19',
    signupRole: 'patient', // promoted to lab_worker by demo_seed.sql
    finalRole: 'lab_worker',
  },
  {
    key: 'reception',
    email: 'demo.reception@hayaat.id',
    cnic: '3520166666661',
    full_name: 'Hina Malik',
    phone: '03006666661',
    gender: 'female',
    date_of_birth: '1994-06-30',
    signupRole: 'patient', // promoted to receptionist by demo_seed.sql
    finalRole: 'receptionist',
  },
  {
    key: 'patient',
    email: 'demo.patient@hayaat.id',
    cnic: '3520112345671',
    full_name: 'Ayesha Khan',
    phone: '03001234571',
    gender: 'female',
    date_of_birth: '1995-03-14',
    signupRole: 'patient',
    finalRole: 'patient',
    meta: { blood_group: 'O+', emergency_phone: '03001234599' },
  },
  {
    key: 'patient2',
    email: 'demo.patient2@hayaat.id',
    cnic: '3520112345672',
    full_name: 'Usman Tariq',
    phone: '03001234572',
    gender: 'male',
    date_of_birth: '1988-11-05',
    signupRole: 'patient',
    finalRole: 'patient',
    meta: { blood_group: 'B+', emergency_phone: '03001234598' },
  },
];

export const byKey = (key) => DEMO_ACCOUNTS.find((a) => a.key === key);

/// Sign-up metadata for an account, in the shape `handle_new_user()` reads.
export const signupMetadata = (a) => ({
  role: a.signupRole,
  cnic: a.cnic,
  full_name: a.full_name,
  phone: a.phone,
  gender: a.gender,
  date_of_birth: a.date_of_birth,
  email: a.email,
  ...(a.meta ?? {}),
});
