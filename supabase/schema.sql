-- ============================================================================
--  HayaatID — CNIC Health Card System · Supabase schema
--
--  Run this ONCE in your Supabase project:  Dashboard → SQL Editor → New query
--  → paste this whole file → Run. Safe to re-run (drops & recreates).
--
--  Creates: all prototype tables, an auth trigger that builds a profile on
--  signup, Row-Level-Security policies, a storage bucket for lab-result files,
--  and demo accounts + clinical data. All demo passwords: password123
--  Login uses CNIC + password (auth email is <cnic>@hayaat.id internally).
-- ============================================================================

-- ── Extensions ──────────────────────────────────────────────────────────────
create extension if not exists pgcrypto;

-- ── Clean slate (idempotent) ────────────────────────────────────────────────
drop table if exists public.audit_logs cascade;
drop table if exists public.notifications cascade;
drop table if exists public.lab_results cascade;
drop table if exists public.lab_orders cascade;
drop table if exists public.allergies cascade;
drop table if exists public.observations cascade;
drop table if exists public.medication_requests cascade;
drop table if exists public.conditions cascade;
drop table if exists public.encounters cascade;
drop table if exists public.appointments cascade;
drop table if exists public.doctor_availability cascade;
drop table if exists public.admin_profiles cascade;
drop table if exists public.receptionist_profiles cascade;
drop table if exists public.lab_worker_profiles cascade;
drop table if exists public.doctor_profiles cascade;
drop table if exists public.patient_profiles cascade;
drop table if exists public.diagnostic_labs cascade;
drop table if exists public.clinics cascade;
drop table if exists public.profiles cascade;

-- ── Core: profiles (1:1 with auth.users) ────────────────────────────────────
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  auth_user_id uuid,
  cnic varchar(13) unique,
  full_name varchar(255) not null default '',
  date_of_birth date,
  gender varchar(10),
  phone_primary varchar(20) default '',
  email varchar(255),
  role varchar(20) not null default 'patient',
  status varchar(20) not null default 'active',
  status_reason text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.clinics (
  id uuid primary key default gen_random_uuid(),
  name varchar(255) not null,
  type varchar(50) default 'clinic',
  phone varchar(20),
  address_street text,
  address_city varchar(100),
  address_province varchar(50),
  status varchar(20) default 'active',
  created_at timestamptz default now()
);

create table public.diagnostic_labs (
  id uuid primary key default gen_random_uuid(),
  name varchar(255) not null,
  license_number varchar(100),
  phone varchar(20),
  address_city varchar(100),
  address_province varchar(50),
  status varchar(20) default 'pending',
  created_at timestamptz default now()
);

create table public.patient_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  blood_group varchar(5),
  height_cm numeric(5,2),
  weight_kg numeric(5,2),
  address_street text,
  address_city varchar(100),
  address_province varchar(50),
  emergency_contact_name varchar(255),
  emergency_contact_phone varchar(20),
  health_card_number varchar(50),
  known_allergies text,
  chronic_conditions_summary text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.doctor_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  pmdc_number varchar(50),
  specialization_primary varchar(100),
  specialization_secondary varchar(100),
  qualification_mbbs boolean default false,
  qualification_md boolean default false,
  qualification_fcps boolean default false,
  years_of_experience smallint,
  consultation_fee_pkr numeric(10,2),
  bio text,
  is_available boolean default true,
  clinic_id uuid references public.clinics(id),
  approved_at timestamptz,
  approved_by uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.lab_worker_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  lab_id uuid references public.diagnostic_labs(id),
  employee_id varchar(50),
  position_title varchar(100),
  approved_at timestamptz,
  created_at timestamptz default now()
);

create table public.receptionist_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  clinic_id uuid references public.clinics(id),
  employee_id varchar(50),
  approved_at timestamptz,
  created_at timestamptz default now()
);

create table public.admin_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  admin_level varchar(20) default 'support_admin',
  can_approve_doctors boolean default true,
  can_approve_labs boolean default true,
  can_suspend_accounts boolean default true,
  created_at timestamptz default now()
);

-- ── Scheduling ──────────────────────────────────────────────────────────────
create table public.doctor_availability (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.profiles(id) on delete cascade,
  clinic_id uuid references public.clinics(id),
  day_of_week smallint,
  start_time time,
  end_time time,
  slot_duration_minutes smallint default 30,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.profiles(id) on delete cascade,
  doctor_id uuid references public.profiles(id),
  clinic_id uuid references public.clinics(id),
  appointment_date date not null,
  appointment_time time not null,
  appointment_type varchar(20) default 'in_person',
  status varchar(30) default 'pending',
  booked_by_role varchar(20),
  booked_by_id uuid,
  notes_for_doctor text,
  cancellation_reason text,
  encounter_id uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── Clinical ────────────────────────────────────────────────────────────────
create table public.encounters (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.profiles(id) on delete cascade,
  doctor_id uuid references public.profiles(id),
  appointment_id uuid,
  clinic_id uuid references public.clinics(id),
  encounter_type varchar(50) default 'outpatient',
  encounter_date date not null default current_date,
  chief_complaint text,
  history_of_present_illness text,
  physical_examination_notes text,
  assessment text,
  plan text,
  follow_up_required boolean default false,
  follow_up_date date,
  follow_up_notes text,
  status varchar(20) default 'draft',
  finalized_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.conditions (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid references public.encounters(id) on delete cascade,
  patient_id uuid references public.profiles(id),
  doctor_id uuid references public.profiles(id),
  icd10_code varchar(10),
  condition_display varchar(500) not null,
  severity varchar(20),
  clinical_status varchar(20) default 'active',
  is_chronic boolean default false,
  notes text,
  created_at timestamptz default now()
);

create table public.medication_requests (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid references public.encounters(id) on delete cascade,
  patient_id uuid references public.profiles(id),
  doctor_id uuid references public.profiles(id),
  medication_name varchar(255) not null,
  medication_brand varchar(255),
  dosage_value numeric(8,3),
  dosage_unit varchar(20),
  route varchar(50),
  frequency varchar(50),
  duration_days smallint,
  instructions text,
  status varchar(30) default 'active',
  start_date date,
  end_date date,
  created_at timestamptz default now()
);

create table public.observations (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid references public.encounters(id) on delete cascade,
  patient_id uuid references public.profiles(id),
  authored_by_id uuid references public.profiles(id),
  observation_display varchar(255),
  value_quantity numeric(12,4),
  value_unit varchar(50),
  reference_range_text varchar(255),
  observation_date date not null default current_date,
  created_at timestamptz default now()
);

create table public.allergies (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.profiles(id) on delete cascade,
  recorded_by_id uuid references public.profiles(id),
  encounter_id uuid,
  substance_name varchar(255) not null,
  allergy_type varchar(20) default 'allergy',
  category varchar(20) default 'medication',
  criticality varchar(20) default 'unable_to_assess',
  reaction_description text,
  clinical_status varchar(20) default 'active',
  created_at timestamptz default now()
);

-- ── Lab workflow ────────────────────────────────────────────────────────────
create table public.lab_orders (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid references public.encounters(id) on delete cascade,
  patient_id uuid references public.profiles(id),
  ordering_doctor_id uuid references public.profiles(id),
  lab_id uuid references public.diagnostic_labs(id),
  test_name varchar(255) not null,
  priority varchar(20) default 'routine',
  clinical_indication text,
  special_instructions text,
  status varchar(30) default 'ordered',
  ordered_at timestamptz default now(),
  sample_collected_at timestamptz,
  resulted_at timestamptz,
  reviewed_at timestamptz,
  released_to_patient_at timestamptz
);

create table public.lab_results (
  id uuid primary key default gen_random_uuid(),
  lab_order_id uuid unique references public.lab_orders(id) on delete cascade,
  lab_id uuid references public.diagnostic_labs(id),
  uploaded_by uuid references public.profiles(id),
  patient_id uuid references public.profiles(id),
  result_file_url text,
  result_file_name varchar(255),
  structured_results jsonb,
  comments text,
  created_at timestamptz default now()
);

-- ── Cross-cutting ───────────────────────────────────────────────────────────
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references public.profiles(id) on delete cascade,
  type varchar(50),
  title varchar(100),
  body text,
  is_read boolean default false,
  resource_id uuid,
  created_at timestamptz default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  actor_role varchar(20),
  action varchar(50),
  resource_type varchar(50),
  resource_id uuid,
  patient_id uuid,
  status varchar(20) default 'success',
  timestamp timestamptz not null default now()
);

-- ── Helpers (SECURITY DEFINER so RLS policies can read the caller's role) ────
create or replace function public.my_role()
  returns text language sql security definer stable set search_path = public as
$$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.is_staff()
  returns boolean language sql security definer stable set search_path = public as
$$ select coalesce((select role from public.profiles where id = auth.uid())
     in ('doctor','lab_worker','receptionist','admin'), false) $$;

-- ── Auth trigger: create profile + role-extended row on signup ──────────────
create or replace function public.handle_new_user()
  returns trigger language plpgsql security definer set search_path = public as
$$
declare
  r text := coalesce(new.raw_user_meta_data->>'role', 'patient');
  m jsonb := new.raw_user_meta_data;
begin
  insert into public.profiles (id, auth_user_id, cnic, full_name, date_of_birth, gender, phone_primary, email, role, status)
  values (
    new.id, new.id,
    m->>'cnic',
    coalesce(m->>'full_name', ''),
    nullif(m->>'date_of_birth','')::date,
    m->>'gender',
    coalesce(m->>'phone', ''),
    nullif(m->>'email',''),
    r,
    case when r = 'doctor' then 'pending' else 'active' end
  );

  if r = 'patient' then
    insert into public.patient_profiles (id, blood_group, health_card_number)
    values (new.id, m->>'blood_group', 'HC-' || upper(substr(replace(new.id::text,'-',''),1,10)));
  elsif r = 'doctor' then
    insert into public.doctor_profiles (id, pmdc_number, specialization_primary, qualification_mbbs, qualification_fcps, clinic_id)
    values (new.id, m->>'pmdc_number', coalesce(m->>'specialization_primary','General Medicine'),
            coalesce((m->>'qualification_mbbs')::boolean, true),
            coalesce((m->>'qualification_fcps')::boolean, false),
            nullif(m->>'clinic_id','')::uuid);
  elsif r = 'lab_worker' then
    insert into public.lab_worker_profiles (id, lab_id) values (new.id, nullif(m->>'lab_id','')::uuid);
  elsif r = 'receptionist' then
    insert into public.receptionist_profiles (id, clinic_id) values (new.id, nullif(m->>'clinic_id','')::uuid);
  elsif r = 'admin' then
    insert into public.admin_profiles (id, admin_level) values (new.id, coalesce(m->>'admin_level','support_admin'));
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── Row Level Security ──────────────────────────────────────────────────────
do $$ declare t text; begin
  foreach t in array array[
    'profiles','clinics','diagnostic_labs','patient_profiles','doctor_profiles',
    'lab_worker_profiles','receptionist_profiles','admin_profiles','doctor_availability',
    'appointments','encounters','conditions','medication_requests','observations',
    'allergies','lab_orders','lab_results','notifications','audit_logs'
  ] loop execute format('alter table public.%I enable row level security;', t); end loop;
end $$;

-- Profiles + extended + reference data: readable by any authenticated user.
create policy p_profiles_sel on public.profiles for select to authenticated using (true);
create policy p_profiles_upd on public.profiles for update to authenticated using (id = auth.uid() or is_staff());
create policy p_pp_sel on public.patient_profiles for select to authenticated using (true);
create policy p_pp_upd on public.patient_profiles for update to authenticated using (id = auth.uid() or is_staff());
create policy p_dp_sel on public.doctor_profiles for select to authenticated using (true);
create policy p_dp_upd on public.doctor_profiles for update to authenticated using (id = auth.uid() or is_staff());
create policy p_lwp_sel on public.lab_worker_profiles for select to authenticated using (true);
create policy p_rp_sel on public.receptionist_profiles for select to authenticated using (true);
create policy p_ap_sel on public.admin_profiles for select to authenticated using (true);

create policy p_clinics_all on public.clinics for all to authenticated using (true) with check (true);
create policy p_labs_all on public.diagnostic_labs for all to authenticated using (true) with check (true);
create policy p_avail_sel on public.doctor_availability for select to authenticated using (true);
create policy p_avail_write on public.doctor_availability for all to authenticated using (is_staff()) with check (is_staff());

-- Appointments: patient sees own; staff see all; either may create.
create policy p_appt_sel on public.appointments for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_appt_ins on public.appointments for insert to authenticated with check (true);
create policy p_appt_upd on public.appointments for update to authenticated using (patient_id = auth.uid() or is_staff());

-- Clinical data: patient reads own; staff read/write.
create policy p_enc_sel on public.encounters for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_enc_write on public.encounters for all to authenticated using (is_staff()) with check (is_staff());
create policy p_cond_sel on public.conditions for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_cond_write on public.conditions for all to authenticated using (is_staff()) with check (is_staff());
create policy p_med_sel on public.medication_requests for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_med_write on public.medication_requests for all to authenticated using (is_staff()) with check (is_staff());
create policy p_obs_sel on public.observations for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_obs_write on public.observations for all to authenticated using (is_staff()) with check (is_staff());
create policy p_alg_sel on public.allergies for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_alg_write on public.allergies for all to authenticated using (is_staff()) with check (is_staff());
create policy p_lo_sel on public.lab_orders for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_lo_write on public.lab_orders for all to authenticated using (is_staff()) with check (is_staff());
create policy p_lr_sel on public.lab_results for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_lr_write on public.lab_results for all to authenticated using (is_staff()) with check (is_staff());

-- Notifications: recipient reads/updates own; anyone authenticated may create.
create policy p_notif_sel on public.notifications for select to authenticated using (recipient_id = auth.uid());
create policy p_notif_ins on public.notifications for insert to authenticated with check (true);
create policy p_notif_upd on public.notifications for update to authenticated using (recipient_id = auth.uid());

-- Audit: anyone authenticated may append; only admins read.
create policy p_audit_ins on public.audit_logs for insert to authenticated with check (true);
create policy p_audit_sel on public.audit_logs for select to authenticated using (my_role() = 'admin');

-- ── Storage bucket for lab-result files ─────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('lab-results', 'lab-results', true)
on conflict (id) do nothing;

create policy p_storage_read on storage.objects for select to authenticated using (bucket_id = 'lab-results');
create policy p_storage_write on storage.objects for insert to authenticated with check (bucket_id = 'lab-results');

-- ============================================================================
--  DEMO SEED  (fixed UUIDs so clinical data can reference accounts)
--  All passwords: password123 · login with the CNIC shown.
-- ============================================================================
do $$
declare
  ayesha uuid := '00000000-0000-0000-0000-0000000000a1';
  bilal  uuid := '00000000-0000-0000-0000-0000000000a2';
  imran  uuid := '00000000-0000-0000-0000-0000000000d1';
  sana   uuid := '00000000-0000-0000-0000-0000000000d2';
  zafar  uuid := '00000000-0000-0000-0000-0000000000c1';
  hina   uuid := '00000000-0000-0000-0000-0000000000e1';
  admin  uuid := '00000000-0000-0000-0000-0000000000f1';
  clinic_shifa uuid := '00000000-0000-0000-0000-0000000c1111';
  clinic_aku   uuid := '00000000-0000-0000-0000-0000000c2222';
  lab_shifa    uuid := '00000000-0000-0000-0000-00000000abc1';
  lab_pending  uuid := '00000000-0000-0000-0000-00000000abc2';
  enc1 uuid := '00000000-0000-0000-0000-0000000e1111';
  ord1 uuid := '00000000-0000-0000-0000-00000000a0d1';
begin
  -- Reference data
  insert into public.clinics (id, name, type, phone, address_city, address_province, status) values
    (clinic_shifa, 'Shifa International Hospital', 'hospital', '+92 51 8464646', 'Islamabad', 'Islamabad', 'active'),
    (clinic_aku,   'Aga Khan University Hospital', 'teaching_hospital', '+92 21 111911911', 'Karachi', 'Sindh', 'active');
  insert into public.diagnostic_labs (id, name, license_number, phone, address_city, address_province, status) values
    (lab_shifa,   'Shifa Diagnostic Lab', 'LAB-ISB-2021-0098', '+92 51 8464600', 'Islamabad', 'Islamabad', 'active'),
    (lab_pending, 'Chughtai Lab — G9 Branch', 'LAB-ISB-2024-0457', '+92 51 111456789', 'Islamabad', 'Islamabad', 'pending');

  -- Auth users (trigger creates the matching profile + extended row)
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values
   ('00000000-0000-0000-0000-000000000000', ayesha, 'authenticated','authenticated','3520112345671@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','patient','cnic','3520112345671','full_name','Ayesha Khan','phone','+92 310 1234567','email','ayesha@example.com','date_of_birth','1958-03-14','gender','female','blood_group','B+'), now(), now()),
   ('00000000-0000-0000-0000-000000000000', bilal, 'authenticated','authenticated','3520155555552@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','patient','cnic','3520155555552','full_name','Bilal Ahmed','phone','+92 321 9876543','gender','male','blood_group','O+'), now(), now()),
   ('00000000-0000-0000-0000-000000000000', imran, 'authenticated','authenticated','3520199999991@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','doctor','cnic','3520199999991','full_name','Dr. Imran Yousuf','phone','+92 333 1112223','specialization_primary','Cardiology','pmdc_number','PMDC-12345-C','qualification_mbbs',true,'qualification_fcps',true), now(), now()),
   ('00000000-0000-0000-0000-000000000000', sana, 'authenticated','authenticated','3520188888882@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','doctor','cnic','3520188888882','full_name','Dr. Sana Tariq','phone','+92 345 6667778','specialization_primary','Endocrinology','pmdc_number','PMDC-67890-E','qualification_mbbs',true), now(), now()),
   ('00000000-0000-0000-0000-000000000000', zafar, 'authenticated','authenticated','3520177777771@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','lab_worker','cnic','3520177777771','full_name','Zafar Iqbal','phone','+92 301 2223334'), now(), now()),
   ('00000000-0000-0000-0000-000000000000', hina, 'authenticated','authenticated','3520166666661@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','receptionist','cnic','3520166666661','full_name','Hina Saleem','phone','+92 311 4445556'), now(), now()),
   ('00000000-0000-0000-0000-000000000000', admin, 'authenticated','authenticated','3520100000001@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','admin','cnic','3520100000001','full_name','System Administrator','admin_level','super_admin'), now(), now());

  -- Identities (so email/password auth resolves cleanly)
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  select u.id, u.id, u.id::text,
         jsonb_build_object('sub', u.id::text, 'email', u.email),
         'email', now(), now(), now()
  from auth.users u
  where u.id in (ayesha,bilal,imran,sana,zafar,hina,admin);

  -- GoTrue can't read NULL token columns on login — set them to '' for seeds.
  update auth.users set
    confirmation_token = '', recovery_token = '', email_change = '',
    email_change_token_new = '', email_change_token_current = '',
    phone_change = '', phone_change_token = '', reauthentication_token = ''
  where id in (ayesha,bilal,imran,sana,zafar,hina,admin);

  -- Link staff to clinics/labs + approve the active doctor
  update public.patient_profiles set blood_group='B+', height_cm=162, weight_kg=68,
    address_city='Islamabad', address_province='Islamabad',
    emergency_contact_name='Imran Khan', emergency_contact_phone='+92 300 7654321',
    known_allergies='Penicillin (rash)', chronic_conditions_summary='Hypertension, Type 2 Diabetes'
    where id = ayesha;
  update public.doctor_profiles set clinic_id=clinic_shifa, consultation_fee_pkr=3000, years_of_experience=18,
    bio='Consultant Cardiologist with 18 years of experience.', approved_at=now() where id=imran;
  update public.profiles set status='active' where id=imran;
  update public.doctor_profiles set clinic_id=clinic_aku, consultation_fee_pkr=2500, years_of_experience=9 where id=sana;
  update public.lab_worker_profiles set lab_id=lab_shifa, position_title='Senior Lab Technician', approved_at=now() where id=zafar;
  update public.receptionist_profiles set clinic_id=clinic_shifa, approved_at=now() where id=hina;

  -- Availability
  insert into public.doctor_availability (doctor_id, clinic_id, day_of_week, start_time, end_time, slot_duration_minutes)
  values (imran, clinic_shifa, 1, '09:00', '13:00', 30), (imran, clinic_shifa, 3, '09:00', '13:00', 30);

  -- Upcoming appointment
  insert into public.appointments (patient_id, doctor_id, clinic_id, appointment_date, appointment_time, appointment_type, status, booked_by_role, booked_by_id, notes_for_doctor)
  values (ayesha, imran, clinic_shifa, current_date + 7, '09:30', 'follow_up', 'confirmed', 'patient', ayesha, 'Routine BP review.');

  -- A finalized encounter with conditions / meds / vitals / allergy / lab
  insert into public.encounters (id, patient_id, doctor_id, clinic_id, encounter_type, encounter_date, chief_complaint, assessment, plan, follow_up_required, follow_up_date, status, finalized_at)
  values (enc1, ayesha, imran, clinic_shifa, 'outpatient', current_date - 14,
    'Occasional headaches, mild dizziness in mornings.', 'Essential hypertension, controlled.',
    'Continue regimen. Reduce salt. 30-min daily walk.', true, current_date + 7, 'finalized', now());
  insert into public.conditions (encounter_id, patient_id, doctor_id, icd10_code, condition_display, severity, clinical_status, is_chronic)
  values (enc1, ayesha, imran, 'I10', 'Essential (primary) hypertension', 'moderate', 'active', true);
  insert into public.medication_requests (encounter_id, patient_id, doctor_id, medication_name, dosage_value, dosage_unit, route, frequency, duration_days, instructions, status, start_date)
  values (enc1, ayesha, imran, 'Amlodipine', 5, 'mg', 'oral', 'once_daily', 30, 'Take in the morning.', 'active', current_date - 14),
         (enc1, ayesha, imran, 'Metformin', 500, 'mg', 'oral', 'twice_daily', null, 'Take with food.', 'active', current_date - 14);
  insert into public.observations (encounter_id, patient_id, authored_by_id, observation_display, value_quantity, value_unit, reference_range_text, observation_date)
  values (enc1, ayesha, imran, 'Blood Pressure Systolic', 148, 'mmHg', '90-120 mmHg', current_date - 14),
         (enc1, ayesha, imran, 'Pulse Rate', 78, 'bpm', '60-100 bpm', current_date - 14);
  insert into public.allergies (patient_id, recorded_by_id, encounter_id, substance_name, allergy_type, category, criticality, reaction_description, clinical_status)
  values (ayesha, imran, enc1, 'Penicillin', 'allergy', 'medication', 'high', 'Skin rash and itching.', 'active');

  insert into public.lab_orders (id, encounter_id, patient_id, ordering_doctor_id, lab_id, test_name, priority, clinical_indication, status, ordered_at, sample_collected_at, resulted_at, reviewed_at, released_to_patient_at)
  values (ord1, enc1, ayesha, imran, lab_shifa, 'Lipid Profile', 'routine', 'Cardiovascular risk assessment.', 'released_to_patient', now(), now(), now(), now(), now());
  insert into public.lab_results (lab_order_id, lab_id, uploaded_by, patient_id, result_file_name, structured_results, comments)
  values (ord1, lab_shifa, zafar, ayesha, 'lipid-profile.pdf',
    '[{"name":"Total Cholesterol","value":"190","unit":"mg/dL"},{"name":"HDL","value":"55","unit":"mg/dL"},{"name":"LDL","value":"110","unit":"mg/dL"}]'::jsonb,
    'Results within acceptable range.');

  insert into public.notifications (recipient_id, type, title, body, resource_id)
  values (ayesha, 'lab_result_ready', 'Lab result available', 'A new lab result has been released to you.', ord1);
end $$;
