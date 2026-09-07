-- ============================================================================
--  HayaatID Health Platform · Supabase schema
--
--  Run this ONCE in your Supabase project:  Dashboard → SQL Editor → New query
--  → paste this whole file → Run. Safe to re-run (drops & recreates).
--
--  Creates: all prototype tables, an auth trigger that builds a profile on
--  signup, Row-Level-Security policies, a storage bucket for lab-result files,
--  The optional legacy development seed at the end is disabled by default.
--  Login uses Hayaat ID, email, phone, or staff Employee ID.
-- ============================================================================

-- ── Extensions ──────────────────────────────────────────────────────────────
create extension if not exists pgcrypto;

-- ── Clean slate (idempotent) ────────────────────────────────────────────────
-- Add-on tables are listed here too because this file is often rerun after
-- later migrations have already been applied. Dropping only `profiles cascade`
-- removes their FK constraints, not the tables themselves.
drop table if exists public.messages cascade;
drop table if exists public.conversations cascade;
drop table if exists public.consent_preferences cascade;
drop table if exists public.consents cascade;
drop table if exists public.deletion_requests cascade;
drop table if exists public.medication_logs cascade;
drop table if exists public.cards cascade;
drop table if exists public.medical_documents cascade;
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
  full_name varchar(255) not null default '',
  date_of_birth date,
  gender varchar(10),
  phone_primary varchar(20) default '',
  email varchar(255),
  card_number text unique,
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
  result_file_path text,
  result_file_name varchar(255),
  structured_results jsonb,
  comments text,
  created_at timestamptz default now()
);

create table public.medical_documents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  uploaded_by uuid references public.profiles(id),
  doctor_id uuid references public.profiles(id),
  clinic_id uuid references public.clinics(id),
  encounter_id uuid references public.encounters(id) on delete set null,
  specialty text not null default 'General Medicine',
  record_type text not null default 'other' check (record_type in (
    'prescription', 'laboratory', 'imaging', 'medical_certificate',
    'discharge_summary', 'procedure_note', 'vaccination', 'referral',
    'consultation', 'clinical_note', 'vital_signs', 'diagnosis',
    'medication_history', 'allergy', 'chronic_disease', 'follow_up', 'other'
  )),
  title text not null,
  record_date date not null default current_date,
  facility_name text,
  doctor_name text,
  notes text,
  file_paths text[] not null default '{}',
  file_names text[] not null default '{}',
  mime_types text[] not null default '{}',
  extracted_metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint medical_documents_file_metadata_lengths check (
    cardinality(file_names) in (0, cardinality(file_paths)) and
    cardinality(mime_types) in (0, cardinality(file_paths))
  )
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

create unique index doctor_availability_unique_slot
  on public.doctor_availability
  (doctor_id, day_of_week, start_time, end_time, slot_duration_minutes);

create unique index appointments_unique_doctor_time
  on public.appointments (doctor_id, appointment_date, appointment_time)
  where status not in ('cancelled_by_patient', 'cancelled_by_clinic', 'no_show');

-- ── Helpers (SECURITY DEFINER so RLS policies can read the caller's role) ────
create or replace function public.my_role()
  returns text language sql security definer stable set search_path = public as
$$ select role from public.profiles where id = auth.uid() and status = 'active' $$;

create or replace function public.is_staff()
  returns boolean language sql security definer stable set search_path = public as
$$ select coalesce((select role from public.profiles where id = auth.uid() and status = 'active')
     in ('doctor','lab_worker','receptionist','admin'), false) $$;

create or replace function public.is_admin()
  returns boolean language sql security definer stable set search_path = public as
$$ select coalesce((select role from public.profiles where id = auth.uid() and status = 'active') = 'admin', false) $$;

create or replace function public.gen_card_number(p_role text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  prefix text := case lower(coalesce(p_role,'patient'))
    when 'doctor' then '2'
    when 'receptionist' then '3'
    when 'lab_worker' then '4'
    when 'admin' then '9'
    else '1'
  end;
  candidate text;
begin
  loop
    candidate := prefix || lpad(floor(random() * 1000000000000000)::bigint::text, 15, '0');
    exit when not exists (select 1 from public.profiles where card_number = candidate);
  end loop;
  return candidate;
end;
$$;

create or replace function public.staff_can_access_patient(p_patient uuid)
  returns boolean language sql security definer stable set search_path = public as
$$
  select case
    when auth.uid() = p_patient then true
    when public.is_admin() then true
    when (select role from public.profiles where id = auth.uid() and status = 'active') = 'doctor' then exists (
      select 1 from public.appointments a
      where a.patient_id = p_patient and a.doctor_id = auth.uid()
        and a.status not in ('cancelled_by_patient','cancelled_by_clinic')
      union all
      select 1 from public.encounters e
      where e.patient_id = p_patient and e.doctor_id = auth.uid()
    )
    when (select role from public.profiles where id = auth.uid() and status = 'active') = 'receptionist' then exists (
      select 1
      from public.receptionist_profiles rp
      join public.appointments a on a.clinic_id = rp.clinic_id
      where rp.id = auth.uid()
        and a.patient_id = p_patient
        and a.status not in ('cancelled_by_patient','cancelled_by_clinic')
    )
    when (select role from public.profiles where id = auth.uid() and status = 'active') = 'lab_worker' then exists (
      select 1
      from public.lab_worker_profiles lwp
      join public.lab_orders lo on lo.lab_id = lwp.lab_id
      where lwp.id = auth.uid() and lo.patient_id = p_patient
    )
    else false
  end
$$;

create or replace function public.clinical_staff_can_access_patient(p_patient uuid)
  returns boolean language sql security definer stable set search_path = public as
$$
  select case
    when auth.uid() = p_patient then true
    when public.my_role() = 'admin' then true
    when public.my_role() = 'doctor' then exists (
      select 1 from public.appointments a
      where a.patient_id = p_patient
        and a.doctor_id = auth.uid()
        and a.status not in ('cancelled_by_patient','cancelled_by_clinic')
      union all
      select 1 from public.encounters e
      where e.patient_id = p_patient and e.doctor_id = auth.uid()
    )
    when public.my_role() = 'lab_worker' then exists (
      select 1
      from public.lab_worker_profiles lwp
      join public.lab_orders lo on lo.lab_id = lwp.lab_id
      where lwp.id = auth.uid() and lo.patient_id = p_patient
    )
    else false
  end
$$;

-- ── Auth trigger: create profile + role-extended row on signup ──────────────
create or replace function public.available_appointment_slots(p_doctor uuid, p_date date)
returns table (
  availability_id uuid,
  clinic_id uuid,
  slot_time time,
  slot_label text,
  slot_duration_minutes smallint
)
language sql
security definer
stable
set search_path = public
as $$
  select
    a.id as availability_id,
    a.clinic_id,
    gs.slot_at::time as slot_time,
    to_char(gs.slot_at, 'HH24:MI') as slot_label,
    a.slot_duration_minutes
  from public.doctor_availability a
  join public.profiles p on p.id = a.doctor_id and p.role = 'doctor' and p.status = 'active'
  cross join lateral generate_series(
    p_date::timestamp + a.start_time,
    p_date::timestamp + a.end_time - ((a.slot_duration_minutes || ' minutes')::interval),
    (a.slot_duration_minutes || ' minutes')::interval
  ) as gs(slot_at)
  where a.doctor_id = p_doctor
    and a.is_active = true
    and a.slot_duration_minutes > 0
    and a.start_time < a.end_time
    and a.day_of_week = extract(dow from p_date)::int
    and p_date >= current_date
    and (p_date > current_date or gs.slot_at > now() + interval '2 hours')
    and not exists (
      select 1
      from public.appointments ap
      where ap.doctor_id = p_doctor
        and ap.appointment_date = p_date
        and ap.appointment_time = gs.slot_at::time
        and ap.status not in ('cancelled_by_patient', 'cancelled_by_clinic', 'no_show')
    )
  order by gs.slot_at
$$;
grant execute on function public.available_appointment_slots(uuid,date) to authenticated;

create or replace function public.request_patient_appointment(
  p_doctor uuid,
  p_date date,
  p_time time,
  p_clinic uuid default null,
  p_type text default 'in_person',
  p_notes text default null
)
returns public.appointments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_patient uuid := auth.uid();
  v_slot record;
  v_row public.appointments;
begin
  if v_patient is null or public.my_role() <> 'patient' then
    raise exception 'Only patients can request appointments';
  end if;

  select * into v_slot
  from public.available_appointment_slots(p_doctor, p_date)
  where slot_time = p_time
    and (p_clinic is null or clinic_id = p_clinic)
  limit 1;

  if not found then
    raise exception 'This appointment slot is no longer available';
  end if;

  insert into public.appointments (
    patient_id, doctor_id, clinic_id, appointment_date, appointment_time,
    appointment_type, status, booked_by_role, booked_by_id, notes_for_doctor
  )
  values (
    v_patient, p_doctor, coalesce(p_clinic, v_slot.clinic_id), p_date, p_time,
    coalesce(nullif(p_type, ''), 'in_person'), 'pending', 'patient', v_patient, nullif(p_notes, '')
  )
  returning * into v_row;

  return v_row;
end;
$$;
grant execute on function public.request_patient_appointment(uuid,date,time,uuid,text,text) to authenticated;

create or replace function public.book_clinic_appointment(
  p_patient uuid,
  p_doctor uuid,
  p_date date,
  p_time time,
  p_type text default 'in_person',
  p_notes text default null
)
returns public.appointments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_clinic uuid;
  v_row public.appointments;
begin
  if v_actor is null then
    raise exception 'Not authenticated';
  end if;

  if public.my_role() = 'admin' then
    select clinic_id into v_clinic
    from public.available_appointment_slots(p_doctor, p_date)
    where slot_time = p_time
    limit 1;
  else
    select rp.clinic_id into v_clinic
    from public.receptionist_profiles rp
    where rp.id = v_actor;
  end if;

  if v_clinic is null then
    raise exception 'No clinic is available for this booking';
  end if;

  if public.my_role() not in ('receptionist', 'admin') then
    raise exception 'Only receptionists or admins can book clinic appointments';
  end if;

  if not exists (
    select 1
    from public.available_appointment_slots(p_doctor, p_date)
    where slot_time = p_time and clinic_id = v_clinic
  ) then
    raise exception 'This appointment slot is no longer available';
  end if;

  insert into public.appointments (
    patient_id, doctor_id, clinic_id, appointment_date, appointment_time,
    appointment_type, status, booked_by_role, booked_by_id, notes_for_doctor
  )
  values (
    p_patient, p_doctor, v_clinic, p_date, p_time,
    coalesce(nullif(p_type, ''), 'in_person'), 'pending', public.my_role(), v_actor, nullif(p_notes, '')
  )
  returning * into v_row;

  return v_row;
end;
$$;
grant execute on function public.book_clinic_appointment(uuid,uuid,date,time,text,text) to authenticated;

create or replace function public.handle_new_user()
  returns trigger language plpgsql security definer set search_path = public as
$$
declare
  r text := coalesce(new.raw_user_meta_data->>'role', 'patient');
  m jsonb := new.raw_user_meta_data;
  cnum text := coalesce(nullif(regexp_replace(coalesce(new.raw_user_meta_data->>'card_number', ''), '\s', '', 'g'), ''), public.gen_card_number(r));
begin
  insert into public.profiles (id, auth_user_id, full_name, date_of_birth, gender, phone_primary, email, card_number, role, status)
  values (
    new.id, new.id,
    coalesce(m->>'full_name', ''),
    nullif(m->>'date_of_birth','')::date,
    m->>'gender',
    coalesce(m->>'phone', ''),
    nullif(m->>'email',''),
    cnum,
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

-- Profiles + extended data: directory rows stay discoverable; PHI is scoped.
create policy p_profiles_sel on public.profiles for select to authenticated
  using (id = auth.uid() or is_staff() or role in ('doctor','lab_worker','receptionist'));
create policy p_profiles_upd on public.profiles for update to authenticated
  using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());
create policy p_pp_sel on public.patient_profiles for select to authenticated
  using (id = auth.uid() or staff_can_access_patient(id));
create policy p_pp_upd on public.patient_profiles for update to authenticated
  using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());
create policy p_dp_sel on public.doctor_profiles for select to authenticated using (true);
create policy p_dp_upd on public.doctor_profiles for update to authenticated
  using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());
create policy p_lwp_sel on public.lab_worker_profiles for select to authenticated using (id = auth.uid() or is_staff());
create policy p_rp_sel on public.receptionist_profiles for select to authenticated using (id = auth.uid() or is_staff());
create policy p_ap_sel on public.admin_profiles for select to authenticated using (id = auth.uid() or is_staff());

create policy p_clinics_sel on public.clinics for select to authenticated using (true);
create policy p_clinics_write on public.clinics for all to authenticated using (is_admin()) with check (is_admin());
create policy p_labs_sel on public.diagnostic_labs for select to authenticated using (true);
create policy p_labs_write on public.diagnostic_labs for all to authenticated using (is_admin()) with check (is_admin());
create policy p_avail_sel on public.doctor_availability for select to authenticated using (true);
create policy p_avail_write on public.doctor_availability for all to authenticated
  using (doctor_id = auth.uid() or is_admin()) with check (doctor_id = auth.uid() or is_admin());

-- Appointments: patient, assigned doctor, clinic receptionist, or admin.
create policy p_appt_sel on public.appointments for select to authenticated
  using (patient_id = auth.uid() or doctor_id = auth.uid() or is_admin() or exists (
    select 1 from public.receptionist_profiles rp where rp.id = auth.uid() and rp.clinic_id = appointments.clinic_id
  ));
create policy p_appt_ins on public.appointments for insert to authenticated
  with check (patient_id = auth.uid() or doctor_id = auth.uid() or is_admin() or exists (
    select 1 from public.receptionist_profiles rp where rp.id = auth.uid() and rp.clinic_id = appointments.clinic_id
  ));
create policy p_appt_upd on public.appointments for update to authenticated
  using (patient_id = auth.uid() or doctor_id = auth.uid() or is_admin() or exists (
    select 1 from public.receptionist_profiles rp where rp.id = auth.uid() and rp.clinic_id = appointments.clinic_id
  ))
  with check (patient_id = auth.uid() or doctor_id = auth.uid() or is_admin() or exists (
    select 1 from public.receptionist_profiles rp where rp.id = auth.uid() and rp.clinic_id = appointments.clinic_id
  ));

-- Clinical data: patient reads own; staff access is care-relationship based.
create policy p_enc_sel on public.encounters for select to authenticated using (patient_id = auth.uid() or clinical_staff_can_access_patient(patient_id));
create policy p_enc_write on public.encounters for all to authenticated using (doctor_id = auth.uid() or is_admin()) with check (doctor_id = auth.uid() or is_admin());
create policy p_cond_sel on public.conditions for select to authenticated using (patient_id = auth.uid() or clinical_staff_can_access_patient(patient_id));
create policy p_cond_write on public.conditions for all to authenticated using (doctor_id = auth.uid() or is_admin()) with check (doctor_id = auth.uid() or is_admin());
create policy p_med_sel on public.medication_requests for select to authenticated using (patient_id = auth.uid() or clinical_staff_can_access_patient(patient_id));
create policy p_med_write on public.medication_requests for all to authenticated using (doctor_id = auth.uid() or is_admin()) with check (doctor_id = auth.uid() or is_admin());
create policy p_obs_sel on public.observations for select to authenticated using (patient_id = auth.uid() or clinical_staff_can_access_patient(patient_id));
create policy p_obs_write on public.observations for all to authenticated using (authored_by_id = auth.uid() or is_admin()) with check (authored_by_id = auth.uid() or is_admin());
create policy p_alg_sel on public.allergies for select to authenticated using (patient_id = auth.uid() or clinical_staff_can_access_patient(patient_id));
create policy p_alg_write on public.allergies for all to authenticated using (recorded_by_id = auth.uid() or is_admin()) with check (recorded_by_id = auth.uid() or is_admin());
create policy p_lo_sel on public.lab_orders for select to authenticated using (patient_id = auth.uid() or clinical_staff_can_access_patient(patient_id));
create policy p_lo_write on public.lab_orders for all to authenticated
  using (ordering_doctor_id = auth.uid() or is_admin() or exists (
    select 1 from public.lab_worker_profiles lwp where lwp.id = auth.uid() and lwp.lab_id = lab_orders.lab_id
  ))
  with check (ordering_doctor_id = auth.uid() or is_admin() or exists (
    select 1 from public.lab_worker_profiles lwp where lwp.id = auth.uid() and lwp.lab_id = lab_orders.lab_id
  ));
create policy p_lr_sel on public.lab_results for select to authenticated using (patient_id = auth.uid() or clinical_staff_can_access_patient(patient_id));
create policy p_lr_write on public.lab_results for all to authenticated
  using (is_admin() or exists (
    select 1 from public.lab_worker_profiles lwp where lwp.id = auth.uid() and lwp.lab_id = lab_results.lab_id
  ))
  with check (is_admin() or exists (
    select 1 from public.lab_worker_profiles lwp where lwp.id = auth.uid() and lwp.lab_id = lab_results.lab_id
  ));

-- Notifications: recipient reads/updates own; anyone authenticated may create.
create policy p_notif_sel on public.notifications for select to authenticated using (recipient_id = auth.uid());
create policy p_notif_ins on public.notifications for insert to authenticated with check (is_staff() or recipient_id = auth.uid());
create policy p_notif_upd on public.notifications for update to authenticated using (recipient_id = auth.uid());

-- Audit: anyone authenticated may append; only admins read.
create policy p_audit_ins on public.audit_logs for insert to authenticated with check (true);
create policy p_audit_sel on public.audit_logs for select to authenticated using (my_role() = 'admin');

-- ── Storage bucket for lab-result files ─────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('lab-results', 'lab-results', false)
on conflict (id) do update set public = false;

drop policy if exists p_storage_read on storage.objects;
drop policy if exists p_storage_write on storage.objects;
create policy p_storage_read on storage.objects for select to authenticated using (
  bucket_id = 'lab-results'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.clinical_staff_can_access_patient((storage.foldername(name))[1]::uuid)
  )
);
create policy p_storage_write on storage.objects for insert to authenticated with check (bucket_id = 'lab-results');

-- ============================================================================
--  OPTIONAL DEVELOPMENT SEED (disabled by default).
--  To enable deliberately for an isolated throwaway project, run
--  `set app.seed_demo = 'on';` in the same SQL session before this block.
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
  if coalesce(current_setting('app.seed_demo', true), 'off') <> 'on' then
    return;
  end if;
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
     jsonb_build_object('role','patient','full_name','Ayesha Khan','phone','+92 310 1234567','email','ayesha@example.com','date_of_birth','1958-03-14','gender','female','blood_group','B+'), now(), now()),
   ('00000000-0000-0000-0000-000000000000', bilal, 'authenticated','authenticated','3520155555552@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','patient','full_name','Bilal Ahmed','phone','+92 321 9876543','gender','male','blood_group','O+'), now(), now()),
   ('00000000-0000-0000-0000-000000000000', imran, 'authenticated','authenticated','3520199999991@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','doctor','full_name','Dr. Imran Yousuf','phone','+92 333 1112223','specialization_primary','Cardiology','pmdc_number','PMDC-12345-C','qualification_mbbs',true,'qualification_fcps',true), now(), now()),
   ('00000000-0000-0000-0000-000000000000', sana, 'authenticated','authenticated','3520188888882@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','doctor','full_name','Dr. Sana Tariq','phone','+92 345 6667778','specialization_primary','Endocrinology','pmdc_number','PMDC-67890-E','qualification_mbbs',true), now(), now()),
   ('00000000-0000-0000-0000-000000000000', zafar, 'authenticated','authenticated','3520177777771@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','lab_worker','full_name','Zafar Iqbal','phone','+92 301 2223334'), now(), now()),
   ('00000000-0000-0000-0000-000000000000', hina, 'authenticated','authenticated','3520166666661@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','receptionist','full_name','Hina Saleem','phone','+92 311 4445556'), now(), now()),
   ('00000000-0000-0000-0000-000000000000', admin, 'authenticated','authenticated','3520100000001@hayaat.id', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}',
     jsonb_build_object('role','admin','full_name','System Administrator','admin_level','super_admin'), now(), now());

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
-- ============================================================================
--  HayaatID — Card issuance (run AFTER schema.sql, once, in the SQL Editor)
--
--  Adds: 16-digit numeric Hayaat IDs, a cards table, request RPCs,
--  RLS, and a private storage bucket for card photos. Safe to re-run.
-- ============================================================================

-- Card number on the profile (also a DB lookup key).
alter table public.profiles add column if not exists card_number text unique;

create or replace function public.hayaat_luhn_check_digit(p_first_15 text)
returns text language plpgsql immutable strict as $$
declare total integer := 0; digit integer; i integer;
begin
  if p_first_15 !~ '^[0-9]{15}$' then
    raise exception 'Hayaat ID base must contain exactly 15 digits';
  end if;
  for i in 1..15 loop
    digit := substr(p_first_15, i, 1)::integer;
    if mod(i, 2) = 1 then
      digit := digit * 2;
      if digit > 9 then digit := digit - 9; end if;
    end if;
    total := total + digit;
  end loop;
  return ((10 - mod(total, 10)) % 10)::text;
end;
$$;

create or replace function public.gen_card_number(p_role text)
returns text language plpgsql security definer set search_path = public as $$
declare base text; candidate text;
begin
  loop
    base := lpad(floor(random() * 1000000000000000)::bigint::text, 15, '0');
    candidate := base || public.hayaat_luhn_check_digit(base);
    exit when not exists (select 1 from public.profiles where card_number = candidate);
  end loop;
  return candidate;
end;
$$;

-- Cards table (one card per person).
create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete cascade,
  card_number text unique not null,
  role varchar(20) not null,
  name_en varchar(255),
  name_ur varchar(255),
  date_of_birth date,
  blood_group varchar(5),
  city varchar(100),
  photo_url text,
  status varchar(30) default 'virtual',          -- virtual | physical_requested | delivered
  delivery_address text,
  delivery_phone varchar(20),
  delivery_fee_pkr numeric(10,2) default 250,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.cards enable row level security;
drop policy if exists p_cards_sel on public.cards;
drop policy if exists p_cards_upd on public.cards;
create policy p_cards_sel on public.cards for select to authenticated using (profile_id = auth.uid() or is_staff());
create policy p_cards_upd on public.cards for update to authenticated using (profile_id = auth.uid());

-- Issue or update the caller's card (atomic; assigns the next number on first issue).
drop function if exists public.request_card(text, date, text, text, text);
drop function if exists public.request_card(text, text, date, text, text, text);

create function public.request_card(
  p_name_en text default null,
  p_name_ur text default null,
  p_dob date default null,
  p_blood_group text default null,
  p_city text default null,
  p_photo_url text default null)
  returns public.cards language plpgsql security definer set search_path = public as
$fn$
declare
  v_role text;
  v_name text;
  v_num text;
  v_card public.cards;
begin
  select role, full_name, card_number into v_role, v_name, v_num
    from public.profiles where id = auth.uid();
  if v_role is null then raise exception 'Profile not found.'; end if;

  -- Reuse the number issued at sign-up. Only mint one if the account somehow
  -- has none (rows created before card numbers existed).
  if v_num is null or v_num !~ '^[0-9]{16}$' then
    v_num := public.gen_hayaat_id();
  end if;

  select * into v_card from public.cards where profile_id = auth.uid();
  if v_card.id is null then
    insert into public.cards
      (profile_id, card_number, role, name_en, name_ur, date_of_birth,
       blood_group, city, photo_url, status)
    values
      (auth.uid(), v_num, v_role, coalesce(nullif(p_name_en, ''), v_name),
       p_name_ur, p_dob, p_blood_group, p_city, p_photo_url, 'virtual')
    returning * into v_card;
  else
    update public.cards set
      card_number   = v_num,
      name_en       = coalesce(nullif(p_name_en, ''), name_en),
      name_ur       = p_name_ur,
      date_of_birth = p_dob,
      blood_group   = p_blood_group,
      city          = p_city,
      photo_url     = coalesce(p_photo_url, photo_url),
      updated_at    = now()
    where profile_id = auth.uid()
    returning * into v_card;
  end if;

  -- Keep all three copies of the number, and the demographics, in step.
  update public.profiles
     set card_number   = v_num,
         date_of_birth = coalesce(date_of_birth, p_dob)
   where id = auth.uid();

  update public.patient_profiles
     set blood_group        = coalesce(p_blood_group, blood_group),
         address_city       = coalesce(p_city, address_city),
         health_card_number = v_num
   where id = auth.uid();

  return v_card;
end;
$fn$;

revoke all on function public.request_card(text, text, date, text, text, text) from public;
grant execute on function public.request_card(text, text, date, text, text, text) to authenticated;

create or replace function public.request_physical_card(p_address text, p_phone text)
  returns public.cards language plpgsql security definer set search_path = public as
$$
declare v_card public.cards;
begin
  update public.cards set status = 'physical_requested', delivery_address = p_address,
    delivery_phone = p_phone, updated_at = now()
  where profile_id = auth.uid() returning * into v_card;
  if v_card.id is null then raise exception 'Issue a virtual card first.'; end if;
  return v_card;
end;
$$;

-- Private bucket for card photos. Clients store the object path on the card
-- row and use signed URLs when displaying it.
insert into storage.buckets (id, name, public) values ('card-photos', 'card-photos', false)
on conflict (id) do update set public = false;
drop policy if exists p_cardphoto_read on storage.objects;
drop policy if exists p_cardphoto_write on storage.objects;
create policy p_cardphoto_read on storage.objects for select to authenticated
  using (
    bucket_id = 'card-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or is_staff())
  );
create policy p_cardphoto_write on storage.objects for insert to authenticated
  with check (bucket_id = 'card-photos' and (storage.foldername(name))[1] = auth.uid()::text);
-- ============================================================================
--  HayaatID — Revision migration (run once after schema.sql + cards.sql)
--
--  Adds: card_number assigned at SIGNUP (so it's the login id), backfill for
--  existing users, a login_email() lookup RPC, medicine-schedule columns +
--  adherence log, encounter specialty, richer allergy fields, and the demo
--  login token fix. Safe to re-run.
-- ============================================================================

-- ── New columns ──────────────────────────────────────────────────────────────
alter table public.encounters        add column if not exists specialty text;
alter table public.medication_requests add column if not exists dose_morning   boolean default false;
alter table public.medication_requests add column if not exists dose_afternoon boolean default false;
alter table public.medication_requests add column if not exists dose_evening   boolean default false;
alter table public.medication_requests add column if not exists dose_night     boolean default false;
alter table public.allergies          add column if not exists severity text;       -- mild | moderate | severe
alter table public.allergies          add column if not exists trigger_note text;

-- ── Medication adherence log (Taken / Skipped) ──────────────────────────────
create table if not exists public.medication_logs (
  id uuid primary key default gen_random_uuid(),
  medication_id uuid references public.medication_requests(id) on delete cascade,
  patient_id uuid references public.profiles(id) on delete cascade,
  dose_label text,                 -- morning | afternoon | evening | night
  status text default 'taken',     -- taken | skipped
  logged_at timestamptz default now()
);
alter table public.medication_logs enable row level security;
drop policy if exists p_medlog_sel on public.medication_logs;
drop policy if exists p_medlog_ins on public.medication_logs;
create policy p_medlog_sel on public.medication_logs for select to authenticated using (patient_id = auth.uid() or is_staff());
create policy p_medlog_ins on public.medication_logs for insert to authenticated with check (patient_id = auth.uid());

-- ── Card number is assigned at signup; rebuild the trigger ──────────────────
create or replace function public.handle_new_user()
  returns trigger language plpgsql security definer set search_path = public as
$$
declare
  r text := coalesce(new.raw_user_meta_data->>'role', 'patient');
  m jsonb := new.raw_user_meta_data;
  cnum text := public.gen_card_number(coalesce(new.raw_user_meta_data->>'role','patient'));
begin
  insert into public.profiles (id, auth_user_id, full_name, date_of_birth, gender, phone_primary, email, role, status, card_number)
  values (new.id, new.id, coalesce(m->>'full_name',''), nullif(m->>'date_of_birth','')::date,
          m->>'gender', coalesce(m->>'phone',''), nullif(m->>'email',''), r,
          case when r='doctor' then 'pending' else 'active' end, cnum);

  if r = 'patient' then
    insert into public.patient_profiles (id, blood_group, health_card_number, emergency_contact_phone)
    values (new.id, m->>'blood_group', cnum, m->>'emergency_phone');
  elsif r = 'doctor' then
    insert into public.doctor_profiles (id, pmdc_number, specialization_primary, qualification_mbbs, qualification_fcps, clinic_id)
    values (new.id, m->>'pmdc_number', coalesce(m->>'specialization_primary','General Medicine'),
            coalesce((m->>'qualification_mbbs')::boolean, true), coalesce((m->>'qualification_fcps')::boolean, false),
            nullif(m->>'clinic_id','')::uuid);
  elsif r = 'lab_worker' then
    insert into public.lab_worker_profiles (id, lab_id) values (new.id, nullif(m->>'lab_id','')::uuid);
  elsif r = 'receptionist' then
    insert into public.receptionist_profiles (id, clinic_id, employee_id) values (new.id, nullif(m->>'clinic_id','')::uuid, m->>'employee_id');
  elsif r = 'admin' then
    insert into public.admin_profiles (id, admin_level) values (new.id, coalesce(m->>'admin_level','support_admin'));
  end if;
  return new;
end;
$$;

-- ── Backfill card numbers for existing accounts ─────────────────────────────
do $$ declare rec record; begin
  for rec in select id, role from public.profiles where card_number is null order by created_at loop
    update public.profiles set card_number = public.gen_card_number(rec.role) where id = rec.id;
  end loop;
end $$;

-- ── Login by Hayaat ID / phone / email → auth email ─────────────────────────
create or replace function public.login_email(p_id text)
  returns text language sql security definer set search_path = public as
$$
  select u.email from auth.users u
  join public.profiles p on p.id = u.id
  where p.card_number = regexp_replace(p_id, '\s', '', 'g')
     or p.phone_primary = regexp_replace(p_id, '\D', '', 'g')
     or lower(p.email) = lower(trim(p_id))
  limit 1
$$;
grant execute on function public.login_email(text) to anon, authenticated;

-- ── Card request now accepts an English "Name on Card" (+ auto Urdu) ────────
drop function if exists public.request_card(text, date, text, text, text);
drop function if exists public.request_card(text, text, date, text, text, text);
create or replace function public.request_card(
  p_name_en text, p_name_ur text, p_dob date, p_blood_group text, p_city text, p_photo_url text)
  returns public.cards language plpgsql security definer set search_path = public as
$$
declare v_role text; v_name text; v_num text; v_card public.cards;
begin
  select role, full_name into v_role, v_name from public.profiles where id = auth.uid();
  if v_role is null then raise exception 'Profile not found.'; end if;

  select * into v_card from public.cards where profile_id = auth.uid();
  if v_card.id is null then
    v_num := public.gen_card_number(v_role);
    insert into public.cards (profile_id, card_number, role, name_en, name_ur, date_of_birth, blood_group, city, photo_url, status)
      values (auth.uid(), v_num, v_role, coalesce(nullif(p_name_en,''), v_name), p_name_ur, p_dob, p_blood_group, p_city, p_photo_url, 'virtual')
      returning * into v_card;
    update public.profiles set card_number = coalesce(card_number, v_num), date_of_birth = coalesce(date_of_birth, p_dob) where id = auth.uid();
  else
    update public.cards set
      name_en = coalesce(nullif(p_name_en,''), name_en), name_ur = p_name_ur, date_of_birth = p_dob,
      blood_group = p_blood_group, city = p_city, photo_url = coalesce(p_photo_url, photo_url), updated_at = now()
    where profile_id = auth.uid() returning * into v_card;
  end if;

  update public.patient_profiles set blood_group = p_blood_group, address_city = p_city where id = auth.uid();
  return v_card;
end;
$$;

-- ── Repair demo accounts' login (NULL token columns) ────────────────────────
update auth.users set
  confirmation_token = coalesce(confirmation_token, ''),
  recovery_token = coalesce(recovery_token, ''),
  email_change = coalesce(email_change, ''),
  email_change_token_new = coalesce(email_change_token_new, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  phone_change = coalesce(phone_change, ''),
  phone_change_token = coalesce(phone_change_token, ''),
  reauthentication_token = coalesce(reauthentication_token, '')
where email like '%@hayaat.id';
-- ════════════════════════════════════════════════════════════════════════════
--  HayaatID — Security hardening migration
--  Run AFTER schema.sql + cards.sql + revision.sql, in the Supabase SQL Editor.
--  Idempotent: safe to re-run. Fixes the audit findings:
--    1. Patient demographics were world-readable (profiles/patient_profiles).
--    2. Staff-internal profiles were world-readable.
--    3. Any user could create/modify clinics & diagnostic labs.
--    4. Any user could forge audit logs / spam appointments & notifications.
--    5. Lab-result files were in a PUBLIC bucket (PHI leak).
--    6. Self-signup trusted a client-supplied role (admin escalation).
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Profiles: protect PATIENT demographics; keep providers discoverable ───
-- Patient rows: only the owner or staff. Provider rows (doctor/lab/reception)
-- stay readable so patients can see "Dr. X", clinic staff names, etc.
-- Admin rows: only self or staff.
create table if not exists public.audit_logs (
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

drop policy if exists p_profiles_sel on public.profiles;
create policy p_profiles_sel on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or is_staff()
    or role in ('doctor', 'lab_worker', 'receptionist')
  );

-- ── 2. Extended profiles ─────────────────────────────────────────────────────
-- patient_profiles hold blood group + emergency contacts → owner or staff only.
drop policy if exists p_pp_sel on public.patient_profiles;
create policy p_pp_sel on public.patient_profiles for select to authenticated
  using (id = auth.uid() or is_staff());

-- doctor_profiles are a provider directory (specialization, fee, bio) → keep
-- readable to any authenticated user (needed for doctor search).
drop policy if exists p_dp_sel on public.doctor_profiles;
create policy p_dp_sel on public.doctor_profiles for select to authenticated
  using (true);

-- Staff-internal extended profiles → owner or staff only.
drop policy if exists p_lwp_sel on public.lab_worker_profiles;
create policy p_lwp_sel on public.lab_worker_profiles for select to authenticated
  using (id = auth.uid() or is_staff());

drop policy if exists p_rp_sel on public.receptionist_profiles;
create policy p_rp_sel on public.receptionist_profiles for select to authenticated
  using (id = auth.uid() or is_staff());

drop policy if exists p_ap_sel on public.admin_profiles;
create policy p_ap_sel on public.admin_profiles for select to authenticated
  using (id = auth.uid() or is_staff());

-- ── 3. Clinics & diagnostic labs: public directory, admin-only writes ─────────
drop policy if exists p_clinics_all on public.clinics;
drop policy if exists p_clinics_sel on public.clinics;
drop policy if exists p_clinics_write on public.clinics;
create policy p_clinics_sel   on public.clinics for select to authenticated using (true);
create policy p_clinics_write on public.clinics for all    to authenticated
  using (my_role() = 'admin') with check (my_role() = 'admin');

drop policy if exists p_labs_all on public.diagnostic_labs;
drop policy if exists p_labs_sel on public.diagnostic_labs;
drop policy if exists p_labs_write on public.diagnostic_labs;
create policy p_labs_sel   on public.diagnostic_labs for select to authenticated using (true);
create policy p_labs_write on public.diagnostic_labs for all    to authenticated
  using (my_role() = 'admin') with check (my_role() = 'admin');

-- ── 4. Appointments: patients may only book for themselves; staff for anyone ──
drop policy if exists p_appt_ins on public.appointments;
create policy p_appt_ins on public.appointments for insert to authenticated
  with check (patient_id = auth.uid() or is_staff());

-- ── 5. Notifications: only staff (or self) may insert directly ────────────────
-- The one patient→doctor case (booking) is handled by a trigger below so the
-- client no longer needs to insert a notification for another user.
drop policy if exists p_notif_ins on public.notifications;
create policy p_notif_ins on public.notifications for insert to authenticated
  with check (is_staff() or recipient_id = auth.uid());

create or replace function public.notify_doctor_on_appointment()
  returns trigger language plpgsql security definer set search_path = public as
$$
begin
  if new.doctor_id is not null then
    insert into public.notifications (recipient_id, type, title, body, resource_id)
    values (new.doctor_id, 'appointment_booked', 'New appointment request',
            'A patient has requested an appointment.', new.id);
  end if;
  return new;
end;
$$;
drop trigger if exists trg_notify_doctor_appt on public.appointments;
create trigger trg_notify_doctor_appt
  after insert on public.appointments
  for each row execute function public.notify_doctor_on_appointment();

-- ── 6. Audit logs: you can only log actions as yourself (no framing others) ───
drop policy if exists p_audit_ins on public.audit_logs;
create policy p_audit_ins on public.audit_logs for insert to authenticated
  with check (actor_id = auth.uid());

-- ── 7. Lab-result files: PRIVATE bucket, owner/staff reads, staff writes ──────
-- Files are now stored under "<patient_id>/<order_id>/<file>" and served via
-- signed URLs (see lib/services/lab_service.dart + web-staff/src/api/lab.ts).
update storage.buckets set public = false where id = 'lab-results';

drop policy if exists p_storage_read  on storage.objects;
drop policy if exists p_storage_write on storage.objects;
drop policy if exists p_labresults_read  on storage.objects;
drop policy if exists p_labresults_write on storage.objects;
create policy p_labresults_read on storage.objects for select to authenticated
  using (
    bucket_id = 'lab-results'
    and (is_staff() or (storage.foldername(name))[1] = auth.uid()::text)
  );
create policy p_labresults_write on storage.objects for insert to authenticated
  with check (bucket_id = 'lab-results' and is_staff());

-- ── 8. Stop self-signup role escalation ──────────────────────────────────────
-- Roles other than patient/doctor may ONLY be set via app_metadata, which only
-- the service role (the admin-create-user Edge Function) can write. A client
-- self-signup that tries role=admin/lab_worker/receptionist is clamped to patient.
create or replace function public.handle_new_user()
  returns trigger language plpgsql security definer set search_path = public as
$$
declare
  m  jsonb := new.raw_user_meta_data;
  am jsonb := new.raw_app_meta_data;
  r  text;
  cnum text;
begin
  r := coalesce(am->>'role', m->>'role', 'patient');
  -- Client-supplied (user_metadata) roles are restricted; only the service role
  -- may set a privileged role via app_metadata.
  if (am->>'role') is null and r not in ('patient', 'doctor') then
    r := 'patient';
  end if;
  cnum := public.gen_card_number(r);

  insert into public.profiles (id, auth_user_id, full_name, date_of_birth, gender, phone_primary, email, role, status, card_number)
  values (new.id, new.id, coalesce(m->>'full_name',''), nullif(m->>'date_of_birth','')::date,
          m->>'gender', coalesce(m->>'phone',''), nullif(m->>'email',''), r,
          case when r='doctor' then 'pending' else 'active' end, cnum);

  if r = 'patient' then
    insert into public.patient_profiles (id, blood_group, health_card_number, emergency_contact_phone)
    values (new.id, m->>'blood_group', cnum, m->>'emergency_phone');
  elsif r = 'doctor' then
    insert into public.doctor_profiles (id, pmdc_number, specialization_primary, qualification_mbbs, qualification_fcps, clinic_id)
    values (new.id, m->>'pmdc_number', coalesce(m->>'specialization_primary','General Medicine'),
            coalesce((m->>'qualification_mbbs')::boolean, true), coalesce((m->>'qualification_fcps')::boolean, false),
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

-- ── Note (accepted risk): login_email(p_id) must stay callable by anon so the
-- login-by-Unique-ID flow can resolve an email before authentication. This
-- allows ID enumeration; mitigate in production with Supabase Auth rate limits
-- / a captcha on the login screen rather than removing the RPC.
-- ============================================================================
-- chat.sql — Real patient <-> doctor messaging (replaces the demo Node chat stub)
-- Run AFTER security.sql. Idempotent.
--
-- Model: one conversation per (patient, doctor) pair; many messages per
-- conversation. RLS restricts every row to the two participants ONLY (a
-- conversation is PHI-adjacent, so we do NOT expose it to all staff/admins).
-- Realtime is enabled on `messages` so both clients receive replies live.
--
-- ============================================================================

create table if not exists public.conversations (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references public.profiles(id) on delete cascade,
  doctor_id       uuid not null references public.profiles(id) on delete cascade,
  last_message    text,
  last_message_at timestamptz,
  created_at      timestamptz not null default now(),
  unique (patient_id, doctor_id)
);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid not null references public.profiles(id) on delete cascade,
  body            text not null check (length(btrim(body)) > 0),
  created_at      timestamptz not null default now(),
  read_at         timestamptz
);

alter table public.conversations
  add column if not exists last_message text,
  add column if not exists last_message_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

alter table public.messages
  add column if not exists read_at timestamptz;

create index if not exists idx_messages_convo_time on public.messages (conversation_id, created_at);
create index if not exists idx_conversations_patient on public.conversations (patient_id);
create index if not exists idx_conversations_doctor on public.conversations (doctor_id);

-- Keep the conversation's denormalized "last message" preview current, and stamp
-- the conversation row so both list views can sort by recency. Runs as definer
-- so clients never need UPDATE rights on conversations.
create or replace function public.touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
     set last_message = left(new.body, 140),
         last_message_at = new.created_at
   where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists trg_touch_conversation on public.messages;
create trigger trg_touch_conversation
  after insert on public.messages
  for each row execute function public.touch_conversation();

-- Get-or-create the conversation between a patient and a doctor. Guarded so the
-- caller must be one of the two participants; avoids INSERT/RLS races on the
-- unique (patient_id, doctor_id) pair. Returns the conversation id.
create or replace function public.start_conversation(p_patient uuid, p_doctor uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or auth.uid() not in (p_patient, p_doctor) then
    raise exception 'not a participant';
  end if;
  -- the non-patient side must actually be a doctor
  if not exists (select 1 from public.profiles where id = p_doctor and role = 'doctor') then
    raise exception 'target is not a doctor';
  end if;

  insert into public.conversations (patient_id, doctor_id)
  values (p_patient, p_doctor)
  on conflict (patient_id, doctor_id) do nothing;

  select id into v_id from public.conversations
   where patient_id = p_patient and doctor_id = p_doctor;
  return v_id;
end;
$$;

revoke all on function public.start_conversation(uuid, uuid) from public;
grant execute on function public.start_conversation(uuid, uuid) to authenticated;

-- --------------------------------------------------------------------------
-- RLS: participants only
-- --------------------------------------------------------------------------
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists p_conv_sel on public.conversations;
create policy p_conv_sel on public.conversations for select to authenticated
  using (patient_id = auth.uid() or doctor_id = auth.uid());

drop policy if exists p_conv_ins on public.conversations;
create policy p_conv_ins on public.conversations for insert to authenticated
  with check (patient_id = auth.uid() or doctor_id = auth.uid());

drop policy if exists p_msg_sel on public.messages;
create policy p_msg_sel on public.messages for select to authenticated
  using (exists (
    select 1 from public.conversations c
     where c.id = conversation_id
       and (c.patient_id = auth.uid() or c.doctor_id = auth.uid())
  ));

drop policy if exists p_msg_ins on public.messages;
create policy p_msg_ins on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations c
       where c.id = conversation_id
         and (c.patient_id = auth.uid() or c.doctor_id = auth.uid())
    )
  );

-- Recipient marks messages read (read_at). A participant may only update rows in
-- their own conversations; they cannot alter the body (enforced by app + this
-- narrow policy which is only used for the read_at stamp).
drop policy if exists p_msg_upd on public.messages;
create policy p_msg_upd on public.messages for update to authenticated
  using (exists (
    select 1 from public.conversations c
     where c.id = conversation_id
       and (c.patient_id = auth.uid() or c.doctor_id = auth.uid())
  ));

-- --------------------------------------------------------------------------
-- Realtime: stream new messages to both clients
-- --------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations'
  ) then
    alter publication supabase_realtime add table public.conversations;
  end if;
end $$;
-- ============================================================================
-- security_hardening.sql — Phase 5 incremental RLS/security fixes.
-- Run AFTER security.sql (and any time; idempotent). Complements it.
--
-- Fixes three findings from the security audit:
--   1. Suspended / pending staff still passed is_staff() → they could still read
--      PHI at the data layer even though the app blocks their login. Now
--      is_staff() also requires status = 'active', so suspension/pending is
--      enforced by RLS itself.
--   2. The card-photos bucket allowed ANY authenticated user to write to ANY
--      path. Now writes are limited to the owner's own folder (<uid>/...) or staff.
--   3. audit_logs hardened as append-only: UPDATE/DELETE are revoked outright
--      (in addition to being denied by the absence of any RLS policy for them).
-- ============================================================================

-- 1. Active-status gate on staff access ------------------------------------
create or replace function public.is_staff()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid()
       and role in ('doctor', 'lab_worker', 'receptionist', 'admin')
       and status = 'active'
  );
$$;

-- 2. card-photos: writes only to your own folder (or staff) ------------------
-- Uploads use the path `<auth.uid()>/<timestamp>.png` (see card_service.dart /
-- web card upload), so the first path segment is the owner's id.
drop policy if exists p_cardphoto_write on storage.objects;
create policy p_cardphoto_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'card-photos'
    and (public.is_staff() or (storage.foldername(name))[1] = auth.uid()::text)
  );

-- Needed so the client's `upsert: true` (overwrite own photo) still works.
drop policy if exists p_cardphoto_upd on storage.objects;
create policy p_cardphoto_upd on storage.objects for update to authenticated
  using (
    bucket_id = 'card-photos'
    and (public.is_staff() or (storage.foldername(name))[1] = auth.uid()::text)
  )
  with check (
    bucket_id = 'card-photos'
    and (public.is_staff() or (storage.foldername(name))[1] = auth.uid()::text)
  );

-- 3. audit_logs: append-only (no client updates/deletes, ever) ---------------
revoke update, delete on public.audit_logs from authenticated;
revoke update, delete on public.audit_logs from anon;

-- 4. audit_logs: server-stamped context (IP / device / role / time) ----------
-- Records who/where/when from the SERVER's view so a client cannot spoof its
-- role, backdate an entry, or omit its origin. actor_id integrity is already
-- guaranteed by the INSERT policy (actor_id = auth.uid()); this adds the rest.
alter table public.audit_logs add column if not exists ip         text;
alter table public.audit_logs add column if not exists user_agent text;
alter table public.audit_logs add column if not exists reason     text;

create or replace function public.stamp_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  hdrs json;
begin
  begin
    hdrs := current_setting('request.headers', true)::json;
  exception when others then
    hdrs := null;  -- not a PostgREST request (e.g. SQL editor) — leave blank
  end;

  -- Trust the JWT for the actor's role, never the client-supplied value.
  if auth.uid() is not null then
    new.actor_role := (select role from public.profiles where id = auth.uid());
  end if;

  -- Server clock — clients cannot backdate.
  new."timestamp" := now();

  if hdrs is not null then
    new.ip := nullif(split_part(coalesce(hdrs->>'x-forwarded-for', ''), ',', 1), '');
    new.user_agent := left(nullif(coalesce(hdrs->>'user-agent', ''), ''), 300);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_stamp_audit on public.audit_logs;
create trigger trg_stamp_audit
  before insert on public.audit_logs
  for each row execute function public.stamp_audit();
-- ============================================================================
-- compliance.sql — Phase 8: consent storage, account-deletion requests, and a
-- self-service data export. Run AFTER security_hardening.sql. Idempotent.
--
--   * consents          — immutable record of a user accepting a document version
--   * deletion_requests — user-initiated "delete my account/data" workflow
--   * export_my_data()  — returns everything the CALLER's account holds, as JSON
-- ============================================================================

-- 1. Consent storage --------------------------------------------------------
create table if not exists public.consents (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  document    text not null,               -- 'privacy_policy' | 'terms' | 'data_processing'
  version     text not null,               -- e.g. '2026-07-04'
  accepted_at timestamptz not null default now(),
  ip          text,
  user_agent  text
);
create index if not exists idx_consents_user on public.consents (user_id);

-- Stamp server-observed context; clients can't spoof IP/device or backdate.
create or replace function public.stamp_consent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare hdrs json;
begin
  begin hdrs := current_setting('request.headers', true)::json;
  exception when others then hdrs := null; end;
  new.accepted_at := now();
  if hdrs is not null then
    new.ip := nullif(split_part(coalesce(hdrs->>'x-forwarded-for', ''), ',', 1), '');
    new.user_agent := left(nullif(coalesce(hdrs->>'user-agent', ''), ''), 300);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_consent on public.consents;
create trigger trg_stamp_consent before insert on public.consents
  for each row execute function public.stamp_consent();

alter table public.consents enable row level security;

drop policy if exists p_consents_sel on public.consents;
create policy p_consents_sel on public.consents for select to authenticated
  using (user_id = auth.uid() or public.is_staff());

drop policy if exists p_consents_ins on public.consents;
create policy p_consents_ins on public.consents for insert to authenticated
  with check (user_id = auth.uid());

-- Append-only: consents are a legal record, never edited or deleted by clients.
revoke update, delete on public.consents from authenticated;
revoke update, delete on public.consents from anon;

-- 2. Account-deletion requests ---------------------------------------------
create table if not exists public.deletion_requests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  reason       text,
  status       text not null default 'pending',   -- pending | processing | completed | rejected | failed
  note         text,                               -- admin note
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_by uuid references public.profiles(id)
);
create index if not exists idx_deletion_requests_status on public.deletion_requests (status, requested_at);

alter table public.deletion_requests enable row level security;

-- A user sees and creates only their own request; admins see and process all.
drop policy if exists p_delreq_sel on public.deletion_requests;
create policy p_delreq_sel on public.deletion_requests for select to authenticated
  using (user_id = auth.uid() or public.my_role() = 'admin');

drop policy if exists p_delreq_ins on public.deletion_requests;
create policy p_delreq_ins on public.deletion_requests for insert to authenticated
  with check (user_id = auth.uid());

-- Only admins may update status / add a note (fulfil or reject the request).
drop policy if exists p_delreq_upd on public.deletion_requests;
create policy p_delreq_upd on public.deletion_requests for update to authenticated
  using (public.my_role() = 'admin')
  with check (public.my_role() = 'admin');

-- 3. Self-service data export ----------------------------------------------
-- Returns ALL data belonging to the calling user as one JSON document. Scoped
-- strictly to auth.uid(), so SECURITY DEFINER is safe (it never reads anyone
-- else's rows). Powers the "Download my data" feature (data portability).
create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  return jsonb_build_object(
    'exported_at', now(),
    'profile',         (select to_jsonb(p)  from public.profiles p          where p.id = uid),
    'patient_profile', (select to_jsonb(pp) from public.patient_profiles pp where pp.id = uid),
    'card',            (select to_jsonb(c)  from public.cards c             where c.profile_id = uid),
    'appointments', (select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb) from public.appointments a         where a.patient_id = uid),
    'encounters',   (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb) from public.encounters e           where e.patient_id = uid),
    'conditions',   (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from public.conditions x           where x.patient_id = uid),
    'medications',  (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb) from public.medication_requests m  where m.patient_id = uid),
    'observations', (select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb) from public.observations o         where o.patient_id = uid),
    'allergies',    (select coalesce(jsonb_agg(to_jsonb(al)), '[]'::jsonb) from public.allergies al          where al.patient_id = uid),
    'lab_orders',   (select coalesce(jsonb_agg(to_jsonb(lo)), '[]'::jsonb) from public.lab_orders lo         where lo.patient_id = uid),
    'lab_results',  (select coalesce(jsonb_agg(to_jsonb(lr)), '[]'::jsonb) from public.lab_results lr        where lr.patient_id = uid),
    'notifications',(select coalesce(jsonb_agg(to_jsonb(n)), '[]'::jsonb) from public.notifications n        where n.recipient_id = uid),
    'consents',     (select coalesce(jsonb_agg(to_jsonb(cs)), '[]'::jsonb) from public.consents cs           where cs.user_id = uid)
  );
end;
$$;

revoke all on function public.export_my_data() from public;
grant execute on function public.export_my_data() to authenticated;
-- ============================================================================
-- card_workflow.sql — Phase 7: card delivery workflow + admin notifications.
-- Run AFTER cards.sql and security_hardening.sql. Idempotent.
--
--   * Admins are notified in-app when a patient APPLIES for a card, and again
--     when a patient requests PHYSICAL delivery.
--   * Admins may update cards (to mark a physical card delivered).
-- ============================================================================

-- Let admins act on cards (mark delivered, etc.). The existing owner policy
-- (profile_id = auth.uid()) stays; RLS allows a row if EITHER policy passes.
drop policy if exists p_cards_upd_admin on public.cards;
create policy p_cards_upd_admin on public.cards for update to authenticated
  using (public.my_role() = 'admin')
  with check (public.my_role() = 'admin');

-- Fan a notification out to every active admin. SECURITY DEFINER so the trigger
-- can write notifications addressed to other users.
create or replace function public.notify_admins(p_type text, p_title text, p_body text, p_resource uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare a uuid;
begin
  for a in select id from public.profiles where role = 'admin' and status = 'active' loop
    insert into public.notifications (recipient_id, type, title, body, resource_id)
    values (a, p_type, p_title, p_body, p_resource);
  end loop;
end;
$$;

-- New card application → notify admins.
create or replace function public.tg_card_insert_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare nm text;
begin
  select full_name into nm from public.profiles where id = new.profile_id;
  perform public.notify_admins(
    'card_request',
    'New card application',
    coalesce(nm, 'A patient') || ' applied for a health card (' || coalesce(new.card_number, '') || ').',
    new.profile_id);
  return new;
end;
$$;

drop trigger if exists trg_card_insert_notify on public.cards;
create trigger trg_card_insert_notify after insert on public.cards
  for each row execute function public.tg_card_insert_notify();

-- Physical delivery requested → notify admins (only on the transition).
create or replace function public.tg_card_physical_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare nm text;
begin
  if new.status = 'physical_requested'
     and coalesce(old.status, '') is distinct from 'physical_requested' then
    select full_name into nm from public.profiles where id = new.profile_id;
    perform public.notify_admins(
      'card_delivery',
      'Physical card delivery requested',
      coalesce(nm, 'A patient') || ' requested physical delivery of card ' || coalesce(new.card_number, '') || '.',
      new.profile_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_card_physical_notify on public.cards;
create trigger trg_card_physical_notify after update on public.cards
  for each row execute function public.tg_card_physical_notify();
-- ============================================================================
-- perf_indexes.sql — Phase-3 performance: indexes on the foreign-key / filter
-- columns that RLS policies and app queries actually use. Without these, every
-- "my records" / "this patient's records" / "this lab's queue" query is a full
-- table scan. Run any time; idempotent (create index if not exists).
-- ============================================================================

-- Appointments — patient view, doctor day view, clinic schedule.
create index if not exists idx_appointments_patient       on public.appointments (patient_id);
create index if not exists idx_appointments_doctor_date    on public.appointments (doctor_id, appointment_date);
create index if not exists idx_appointments_clinic_date    on public.appointments (clinic_id, appointment_date);

-- Encounters — patient timeline, doctor's encounters.
create index if not exists idx_encounters_patient          on public.encounters (patient_id);
create index if not exists idx_encounters_doctor           on public.encounters (doctor_id);
create index if not exists idx_encounters_appointment      on public.encounters (appointment_id);

-- Clinical children — joined by encounter, filtered by patient.
create index if not exists idx_conditions_encounter        on public.conditions (encounter_id);
create index if not exists idx_conditions_patient          on public.conditions (patient_id);
create index if not exists idx_medreq_encounter            on public.medication_requests (encounter_id);
create index if not exists idx_medreq_patient_status       on public.medication_requests (patient_id, status);
create index if not exists idx_observations_encounter      on public.observations (encounter_id);
create index if not exists idx_observations_patient        on public.observations (patient_id);
create index if not exists idx_allergies_patient           on public.allergies (patient_id);

-- Lab workflow — patient results, lab queue (by lab + status), doctor review.
create index if not exists idx_lab_orders_patient          on public.lab_orders (patient_id);
create index if not exists idx_lab_orders_lab_status       on public.lab_orders (lab_id, status);
create index if not exists idx_lab_orders_encounter        on public.lab_orders (encounter_id);
create index if not exists idx_lab_orders_doctor           on public.lab_orders (ordering_doctor_id);
create index if not exists idx_lab_results_patient         on public.lab_results (patient_id);

-- Doctor availability — by doctor, by clinic.
create index if not exists idx_availability_doctor         on public.doctor_availability (doctor_id);
create index if not exists idx_availability_clinic         on public.doctor_availability (clinic_id);

-- Notifications — the recipient's unread-first list (bell + patient notifications).
create index if not exists idx_notifications_recipient     on public.notifications (recipient_id, is_read, created_at desc);

-- Audit log — admin review (recent first) and per-actor / per-patient lookups.
create index if not exists idx_audit_timestamp             on public.audit_logs ("timestamp" desc);
create index if not exists idx_audit_actor                 on public.audit_logs (actor_id);
create index if not exists idx_audit_patient               on public.audit_logs (patient_id);

-- Profiles — admin user list filters + signup phone lookup.
create index if not exists idx_profiles_role_status        on public.profiles (role, status);
create index if not exists idx_profiles_phone              on public.profiles (phone_primary);

-- Role-extended profiles — clinic / lab scoping.
create index if not exists idx_doctor_profiles_clinic      on public.doctor_profiles (clinic_id);
create index if not exists idx_lab_worker_profiles_lab     on public.lab_worker_profiles (lab_id);
create index if not exists idx_receptionist_profiles_clinic on public.receptionist_profiles (clinic_id);

-- Medication adherence logs.
create index if not exists idx_medication_logs_patient     on public.medication_logs (patient_id);
create index if not exists idx_medication_logs_medication  on public.medication_logs (medication_id);
-- Product hardening migration. Run after the existing Supabase migrations.
-- Safe to re-run.

-- ---------------------------------------------------------------------------
-- Role and care-team helpers
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists card_number text unique;

create or replace function public.gen_card_number(p_role text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  prefix text := case lower(coalesce(p_role,'patient'))
    when 'doctor' then '2'
    when 'receptionist' then '3'
    when 'lab_worker' then '4'
    when 'admin' then '9'
    else '1'
  end;
  candidate text;
begin
  loop
    candidate := prefix || lpad(floor(random() * 1000000000000000)::bigint::text, 15, '0');
    exit when not exists (select 1 from public.profiles where card_number = candidate);
  end loop;
  return candidate;
end;
$$;

update public.profiles
set card_number = public.gen_card_number(role)
where card_number is null;

create or replace function public.my_role()
  returns text language sql security definer stable set search_path = public as
$$ select role from public.profiles where id = auth.uid() and status = 'active' $$;

create or replace function public.is_staff()
  returns boolean language sql security definer stable set search_path = public as
$$
  select coalesce((select role from public.profiles where id = auth.uid() and status = 'active')
    in ('doctor','lab_worker','receptionist','admin'), false)
$$;

create or replace function public.is_admin()
  returns boolean language sql security definer stable set search_path = public as
$$ select coalesce(public.my_role() = 'admin', false) $$;

create or replace function public.staff_can_access_patient(p_patient uuid)
  returns boolean language sql security definer stable set search_path = public as
$$
  select case
    when auth.uid() = p_patient then true
    when public.my_role() = 'admin' then true
    when public.my_role() = 'doctor' then exists (
      select 1 from public.appointments a
      where a.patient_id = p_patient
        and a.doctor_id = auth.uid()
        and a.status not in ('cancelled_by_patient','cancelled_by_clinic')
      union all
      select 1 from public.encounters e
      where e.patient_id = p_patient and e.doctor_id = auth.uid()
    )
    when public.my_role() = 'receptionist' then exists (
      select 1
      from public.receptionist_profiles rp
      join public.appointments a on a.clinic_id = rp.clinic_id
      where rp.id = auth.uid()
        and a.patient_id = p_patient
        and a.status not in ('cancelled_by_patient','cancelled_by_clinic')
    )
    when public.my_role() = 'lab_worker' then exists (
      select 1
      from public.lab_worker_profiles lwp
      join public.lab_orders lo on lo.lab_id = lwp.lab_id
      where lwp.id = auth.uid() and lo.patient_id = p_patient
    )
    else false
  end
$$;

create or replace function public.clinical_staff_can_access_patient(p_patient uuid)
  returns boolean language sql security definer stable set search_path = public as
$$
  select case
    when auth.uid() = p_patient then true
    when public.my_role() = 'admin' then true
    when public.my_role() = 'doctor' then exists (
      select 1 from public.appointments a
      where a.patient_id = p_patient
        and a.doctor_id = auth.uid()
        and a.status not in ('cancelled_by_patient','cancelled_by_clinic')
      union all
      select 1 from public.encounters e
      where e.patient_id = p_patient and e.doctor_id = auth.uid()
    )
    when public.my_role() = 'lab_worker' then exists (
      select 1
      from public.lab_worker_profiles lwp
      join public.lab_orders lo on lo.lab_id = lwp.lab_id
      where lwp.id = auth.uid() and lo.patient_id = p_patient
    )
    else false
  end
$$;

-- Availability must describe a real, non-duplicated weekly window.
delete from public.doctor_availability a
using public.doctor_availability b
where a.id > b.id
  and a.doctor_id = b.doctor_id
  and a.day_of_week = b.day_of_week
  and a.start_time = b.start_time
  and a.end_time = b.end_time
  and a.slot_duration_minutes = b.slot_duration_minutes;

delete from public.doctor_availability
where slot_duration_minutes <= 0 or start_time >= end_time;

alter table public.doctor_availability
  drop constraint if exists doctor_availability_valid_day,
  drop constraint if exists doctor_availability_valid_window,
  drop constraint if exists doctor_availability_positive_duration;

alter table public.doctor_availability
  add constraint doctor_availability_valid_day check (day_of_week between 0 and 6),
  add constraint doctor_availability_valid_window check (start_time < end_time),
  add constraint doctor_availability_positive_duration check (slot_duration_minutes > 0);

create unique index if not exists doctor_availability_unique_slot
  on public.doctor_availability
  (doctor_id, day_of_week, start_time, end_time, slot_duration_minutes);

-- A doctor controls the professional footer used on every prescription.
alter table public.doctor_profiles
  add column if not exists prescription_signature_name varchar(255),
  add column if not exists prescription_signature_credentials varchar(255),
  add column if not exists prescription_signature_footer varchar(500);

-- Snapshot the footer when an encounter is finalized so historical
-- prescriptions do not change when a profile is edited later.
alter table public.encounters
  add column if not exists prescription_signature_name varchar(255),
  add column if not exists prescription_signature_credentials varchar(255),
  add column if not exists prescription_signature_footer varchar(500);

alter table public.medication_requests
  drop constraint if exists medication_requests_positive_duration;
alter table public.medication_requests
  add constraint medication_requests_positive_duration
  check (duration_days is null or duration_days > 0);

-- Prevent double-booking the same clinician. Cancelled appointments no longer
-- reserve the time.
create unique index if not exists appointments_unique_doctor_time
  on public.appointments (doctor_id, appointment_date, appointment_time)
  where status not in ('cancelled_by_patient', 'cancelled_by_clinic', 'no_show');

create or replace function public.available_appointment_slots(p_doctor uuid, p_date date)
returns table (
  availability_id uuid,
  clinic_id uuid,
  slot_time time,
  slot_label text,
  slot_duration_minutes smallint
)
language sql
security definer
stable
set search_path = public
as $$
  select
    a.id as availability_id,
    a.clinic_id,
    gs.slot_at::time as slot_time,
    to_char(gs.slot_at, 'HH24:MI') as slot_label,
    a.slot_duration_minutes
  from public.doctor_availability a
  join public.profiles p on p.id = a.doctor_id and p.role = 'doctor' and p.status = 'active'
  cross join lateral generate_series(
    p_date::timestamp + a.start_time,
    p_date::timestamp + a.end_time - ((a.slot_duration_minutes || ' minutes')::interval),
    (a.slot_duration_minutes || ' minutes')::interval
  ) as gs(slot_at)
  where a.doctor_id = p_doctor
    and a.is_active = true
    and a.slot_duration_minutes > 0
    and a.start_time < a.end_time
    and a.day_of_week = extract(dow from p_date)::int
    and p_date >= current_date
    and (
      p_date > current_date
      or gs.slot_at > now() + interval '2 hours'
    )
    and not exists (
      select 1
      from public.appointments ap
      where ap.doctor_id = p_doctor
        and ap.appointment_date = p_date
        and ap.appointment_time = gs.slot_at::time
        and ap.status not in ('cancelled_by_patient', 'cancelled_by_clinic', 'no_show')
    )
  order by gs.slot_at
$$;
grant execute on function public.available_appointment_slots(uuid,date) to authenticated;

create or replace function public.request_patient_appointment(
  p_doctor uuid,
  p_date date,
  p_time time,
  p_clinic uuid default null,
  p_type text default 'in_person',
  p_notes text default null
)
returns public.appointments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_patient uuid := auth.uid();
  v_slot record;
  v_row public.appointments;
begin
  if v_patient is null or public.my_role() <> 'patient' then
    raise exception 'Only patients can request appointments';
  end if;

  select *
  into v_slot
  from public.available_appointment_slots(p_doctor, p_date)
  where slot_time = p_time
    and (p_clinic is null or clinic_id = p_clinic)
  limit 1;

  if not found then
    raise exception 'This appointment slot is no longer available';
  end if;

  insert into public.appointments (
    patient_id, doctor_id, clinic_id, appointment_date, appointment_time,
    appointment_type, status, booked_by_role, booked_by_id, notes_for_doctor
  )
  values (
    v_patient, p_doctor, coalesce(p_clinic, v_slot.clinic_id), p_date, p_time,
    coalesce(nullif(p_type, ''), 'in_person'), 'pending', 'patient', v_patient, nullif(p_notes, '')
  )
  returning * into v_row;

  return v_row;
end;
$$;
grant execute on function public.request_patient_appointment(uuid,date,time,uuid,text,text) to authenticated;

create or replace function public.book_clinic_appointment(
  p_patient uuid,
  p_doctor uuid,
  p_date date,
  p_time time,
  p_type text default 'in_person',
  p_notes text default null
)
returns public.appointments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_clinic uuid;
  v_row public.appointments;
begin
  if v_actor is null then
    raise exception 'Not authenticated';
  end if;

  if public.my_role() = 'admin' then
    select clinic_id into v_clinic
    from public.available_appointment_slots(p_doctor, p_date)
    where slot_time = p_time
    limit 1;
  else
    select rp.clinic_id into v_clinic
    from public.receptionist_profiles rp
    where rp.id = v_actor;
  end if;

  if v_clinic is null then
    raise exception 'No clinic is available for this booking';
  end if;

  if public.my_role() not in ('receptionist', 'admin') then
    raise exception 'Only receptionists or admins can book clinic appointments';
  end if;

  if not exists (
    select 1
    from public.available_appointment_slots(p_doctor, p_date)
    where slot_time = p_time and clinic_id = v_clinic
  ) then
    raise exception 'This appointment slot is no longer available';
  end if;

  insert into public.appointments (
    patient_id, doctor_id, clinic_id, appointment_date, appointment_time,
    appointment_type, status, booked_by_role, booked_by_id, notes_for_doctor
  )
  values (
    p_patient, p_doctor, v_clinic, p_date, p_time,
    coalesce(nullif(p_type, ''), 'in_person'), 'pending', public.my_role(), v_actor, nullif(p_notes, '')
  )
  returning * into v_row;

  return v_row;
end;
$$;
grant execute on function public.book_clinic_appointment(uuid,uuid,date,time,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- Tighten RLS from broad "any staff" to owner / care relationship / admin.
-- ---------------------------------------------------------------------------
drop policy if exists p_profiles_upd on public.profiles;
create policy p_profiles_upd on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

drop policy if exists p_pp_sel on public.patient_profiles;
create policy p_pp_sel on public.patient_profiles for select to authenticated
  using (id = auth.uid() or public.staff_can_access_patient(id));
drop policy if exists p_pp_upd on public.patient_profiles;
create policy p_pp_upd on public.patient_profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

drop policy if exists p_dp_upd on public.doctor_profiles;
create policy p_dp_upd on public.doctor_profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

drop policy if exists p_avail_write on public.doctor_availability;
create policy p_avail_write on public.doctor_availability for all to authenticated
  using (doctor_id = auth.uid() or public.is_admin())
  with check (doctor_id = auth.uid() or public.is_admin());

drop policy if exists p_appt_sel on public.appointments;
create policy p_appt_sel on public.appointments for select to authenticated
  using (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.receptionist_profiles rp
      where rp.id = auth.uid() and rp.clinic_id = appointments.clinic_id
    )
  );
drop policy if exists p_appt_ins on public.appointments;
create policy p_appt_ins on public.appointments for insert to authenticated
  with check (
    patient_id = auth.uid()
    or public.is_admin()
    or doctor_id = auth.uid()
    or exists (
      select 1 from public.receptionist_profiles rp
      where rp.id = auth.uid() and rp.clinic_id = appointments.clinic_id
    )
  );
drop policy if exists p_appt_upd on public.appointments;
create policy p_appt_upd on public.appointments for update to authenticated
  using (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.receptionist_profiles rp
      where rp.id = auth.uid() and rp.clinic_id = appointments.clinic_id
    )
  )
  with check (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.receptionist_profiles rp
      where rp.id = auth.uid() and rp.clinic_id = appointments.clinic_id
    )
  );

drop policy if exists p_enc_sel on public.encounters;
create policy p_enc_sel on public.encounters for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_enc_write on public.encounters;
create policy p_enc_write on public.encounters for all to authenticated
  using (doctor_id = auth.uid() or public.is_admin())
  with check (doctor_id = auth.uid() or public.is_admin());

drop policy if exists p_cond_sel on public.conditions;
create policy p_cond_sel on public.conditions for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_cond_write on public.conditions;
create policy p_cond_write on public.conditions for all to authenticated
  using (doctor_id = auth.uid() or public.is_admin())
  with check (doctor_id = auth.uid() or public.is_admin());

drop policy if exists p_med_sel on public.medication_requests;
create policy p_med_sel on public.medication_requests for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_med_write on public.medication_requests;
create policy p_med_write on public.medication_requests for all to authenticated
  using (doctor_id = auth.uid() or public.is_admin())
  with check (doctor_id = auth.uid() or public.is_admin());

drop policy if exists p_obs_sel on public.observations;
create policy p_obs_sel on public.observations for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_obs_write on public.observations;
create policy p_obs_write on public.observations for all to authenticated
  using (authored_by_id = auth.uid() or public.is_admin())
  with check (authored_by_id = auth.uid() or public.is_admin());

drop policy if exists p_alg_sel on public.allergies;
create policy p_alg_sel on public.allergies for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_alg_write on public.allergies;
create policy p_alg_write on public.allergies for all to authenticated
  using (recorded_by_id = auth.uid() or public.is_admin())
  with check (recorded_by_id = auth.uid() or public.is_admin());

drop policy if exists p_lo_sel on public.lab_orders;
create policy p_lo_sel on public.lab_orders for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_lo_write on public.lab_orders;
create policy p_lo_write on public.lab_orders for all to authenticated
  using (
    ordering_doctor_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid() and lwp.lab_id = lab_orders.lab_id
    )
  )
  with check (
    ordering_doctor_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid() and lwp.lab_id = lab_orders.lab_id
    )
  );

drop policy if exists p_lr_sel on public.lab_results;
create policy p_lr_sel on public.lab_results for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_lr_write on public.lab_results;
create policy p_lr_write on public.lab_results for all to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid() and lwp.lab_id = lab_results.lab_id
    )
  )
  with check (
    public.is_admin()
    or exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid() and lwp.lab_id = lab_results.lab_id
    )
  );

-- Contact email is a supported patient login identifier.
create or replace function public.login_email(p_id text)
  returns text language sql security definer set search_path = public as
$$
  select u.email from auth.users u
  join public.profiles p on p.id = u.id
  where p.card_number = regexp_replace(p_id, '\s', '', 'g')
     or p.phone_primary = p_id
     or lower(p.email) = lower(p_id)
  limit 1
$$;
grant execute on function public.login_email(text) to anon, authenticated;

create unique index if not exists profiles_unique_phone
  on public.profiles (phone_primary)
  where phone_primary is not null and phone_primary <> '';

create table if not exists public.audit_logs (
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

-- ---------------------------------------------------------------------------
-- Private storage buckets and object access.
-- ---------------------------------------------------------------------------
update storage.buckets set public = false where id in ('lab-results', 'card-photos', 'medical-documents');

insert into storage.buckets (id, name, public)
values ('medical-documents', 'medical-documents', false)
on conflict (id) do update set public = false;

drop policy if exists p_cardphoto_read on storage.objects;
drop policy if exists p_cardphoto_write on storage.objects;
drop policy if exists p_cardphoto_update on storage.objects;
create policy p_cardphoto_read on storage.objects for select to authenticated
  using (
    bucket_id = 'card-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.staff_can_access_patient((storage.foldername(name))[1]::uuid))
  );
create policy p_cardphoto_write on storage.objects for insert to authenticated
  with check (bucket_id = 'card-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy p_cardphoto_update on storage.objects for update to authenticated
  using (bucket_id = 'card-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'card-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists p_labresults_read on storage.objects;
drop policy if exists p_labresults_write on storage.objects;
create policy p_labresults_read on storage.objects for select to authenticated
  using (
    bucket_id = 'lab-results'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.clinical_staff_can_access_patient((storage.foldername(name))[1]::uuid))
  );
create policy p_labresults_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'lab-results'
    and exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid()
    )
  );

drop policy if exists p_medicaldocs_read on storage.objects;
drop policy if exists p_medicaldocs_write on storage.objects;
create policy p_medicaldocs_read on storage.objects for select to authenticated
  using (
    bucket_id = 'medical-documents'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.clinical_staff_can_access_patient((storage.foldername(name))[1]::uuid))
  );
create policy p_medicaldocs_write on storage.objects for insert to authenticated
  with check (bucket_id = 'medical-documents' and public.is_staff());

drop policy if exists "patient reads own medical documents" on public.medical_documents;
drop policy if exists "patient or staff uploads medical documents" on public.medical_documents;
drop policy if exists "document uploader maintains metadata" on public.medical_documents;
drop policy if exists p_medical_documents_sel on public.medical_documents;
drop policy if exists p_medical_documents_ins on public.medical_documents;
drop policy if exists p_medical_documents_upd on public.medical_documents;
create policy p_medical_documents_sel on public.medical_documents for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id) or uploaded_by = auth.uid());
create policy p_medical_documents_ins on public.medical_documents for insert to authenticated
  with check (
    patient_id = auth.uid()
    or public.is_admin()
    or (public.my_role() = 'doctor' and doctor_id = auth.uid() and uploaded_by = auth.uid())
    or (
      public.my_role() = 'lab_worker'
      and uploaded_by = auth.uid()
      and exists (
        select 1 from public.lab_worker_profiles lwp
        join public.lab_orders lo on lo.lab_id = lwp.lab_id
        where lwp.id = auth.uid() and lo.patient_id = medical_documents.patient_id
      )
    )
  );
create policy p_medical_documents_upd on public.medical_documents for update to authenticated
  using (patient_id = auth.uid() or uploaded_by = auth.uid() or public.is_admin())
  with check (patient_id = auth.uid() or uploaded_by = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- Current consent preferences, plus complete export.
-- ---------------------------------------------------------------------------
create table if not exists public.consent_preferences (
  user_id uuid not null references public.profiles(id) on delete cascade,
  key text not null check (key in ('share_history','emergency_access','research','notifications')),
  enabled boolean not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id),
  primary key (user_id, key)
);

alter table public.consent_preferences enable row level security;
drop policy if exists p_consent_prefs_sel on public.consent_preferences;
create policy p_consent_prefs_sel on public.consent_preferences for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists p_consent_prefs_write on public.consent_preferences;
create policy p_consent_prefs_write on public.consent_preferences for all to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

create or replace function public.set_consent_preference(p_key text, p_enabled boolean)
returns public.consent_preferences
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.consent_preferences;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_key not in ('share_history','emergency_access','research','notifications') then
    raise exception 'invalid consent preference';
  end if;

  insert into public.consent_preferences (user_id, key, enabled, updated_at, updated_by)
  values (auth.uid(), p_key, p_enabled, now(), auth.uid())
  on conflict (user_id, key) do update
    set enabled = excluded.enabled,
        updated_at = now(),
        updated_by = auth.uid()
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.set_consent_preference(text, boolean) from public;
grant execute on function public.set_consent_preference(text, boolean) to authenticated;

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  return jsonb_build_object(
    'exported_at', now(),
    'profile',         (select to_jsonb(p)  from public.profiles p          where p.id = uid),
    'patient_profile', (select to_jsonb(pp) from public.patient_profiles pp where pp.id = uid),
    'card',            (select to_jsonb(c)  from public.cards c             where c.profile_id = uid),
    'appointments',    (select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb) from public.appointments a where a.patient_id = uid),
    'encounters',      (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb) from public.encounters e where e.patient_id = uid),
    'conditions',      (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from public.conditions x where x.patient_id = uid),
    'medications',     (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb) from public.medication_requests m where m.patient_id = uid),
    'observations',    (select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb) from public.observations o where o.patient_id = uid),
    'allergies',       (select coalesce(jsonb_agg(to_jsonb(al)), '[]'::jsonb) from public.allergies al where al.patient_id = uid),
    'lab_orders',      (select coalesce(jsonb_agg(to_jsonb(lo)), '[]'::jsonb) from public.lab_orders lo where lo.patient_id = uid),
    'lab_results',     (select coalesce(jsonb_agg(to_jsonb(lr)), '[]'::jsonb) from public.lab_results lr where lr.patient_id = uid),
    'medical_documents',(select coalesce(jsonb_agg(to_jsonb(md)), '[]'::jsonb) from public.medical_documents md where md.patient_id = uid),
    'conversations',   (select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) from public.conversations c where c.patient_id = uid or c.doctor_id = uid),
    'messages',        (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
                         from public.messages m
                         where exists (
                           select 1 from public.conversations c
                           where c.id = m.conversation_id and (c.patient_id = uid or c.doctor_id = uid)
                         )),
    'notifications',   (select coalesce(jsonb_agg(to_jsonb(n)), '[]'::jsonb) from public.notifications n where n.recipient_id = uid),
    'consents',        (select coalesce(jsonb_agg(to_jsonb(cs)), '[]'::jsonb) from public.consents cs where cs.user_id = uid),
    'consent_preferences', (select coalesce(jsonb_agg(to_jsonb(cp)), '[]'::jsonb) from public.consent_preferences cp where cp.user_id = uid),
    'audit_logs',      (select coalesce(jsonb_agg(to_jsonb(al)), '[]'::jsonb) from public.audit_logs al where al.actor_id = uid or al.patient_id = uid)
  );
end;
$$;

revoke all on function public.export_my_data() from public;
grant execute on function public.export_my_data() to authenticated;

-- ---------------------------------------------------------------------------
-- Deletion fulfillment RPC for admins. The Edge Function uses the same order
-- before removing storage objects and the auth user.
-- ---------------------------------------------------------------------------
create or replace function public.admin_mark_deletion_request(
  p_request_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only';
  end if;
  if p_status not in ('pending','processing','completed','rejected','failed') then
    raise exception 'invalid deletion status';
  end if;

  update public.deletion_requests
     set status = p_status,
         note = nullif(btrim(coalesce(p_note, '')), ''),
         processed_at = case when p_status in ('completed','rejected','failed') then now() else processed_at end,
         processed_by = case when p_status in ('completed','rejected','failed') then auth.uid() else processed_by end
   where id = p_request_id;
end;
$$;

revoke all on function public.admin_mark_deletion_request(uuid, text, text) from public;
grant execute on function public.admin_mark_deletion_request(uuid, text, text) to authenticated;

alter table public.deletion_requests
  alter column user_id drop not null;
alter table public.deletion_requests
  drop constraint if exists deletion_requests_user_id_fkey;
alter table public.deletion_requests
  add constraint deletion_requests_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;
-- Removes the fixed legacy demo identities and every row that directly
-- references them. Run in the Supabase SQL editor with an owner/service role.
-- Safe to re-run.

do $$
declare
  demo_ids uuid[] := array[
    '00000000-0000-0000-0000-0000000000a1'::uuid,
    '00000000-0000-0000-0000-0000000000a2'::uuid,
    '00000000-0000-0000-0000-0000000000d1'::uuid,
    '00000000-0000-0000-0000-0000000000d2'::uuid,
    '00000000-0000-0000-0000-0000000000c1'::uuid,
    '00000000-0000-0000-0000-0000000000e1'::uuid,
    '00000000-0000-0000-0000-0000000000f1'::uuid
  ];
  fk record;
  demo_lab_ids uuid[] := array[
    '00000000-0000-0000-0000-00000000abc1'::uuid,
    '00000000-0000-0000-0000-00000000abc2'::uuid
  ];
  demo_clinic_ids uuid[] := array[
    '00000000-0000-0000-0000-0000000c1111'::uuid,
    '00000000-0000-0000-0000-0000000c2222'::uuid
  ];
begin
  -- Delete rows from every table with a single-column FK to profiles. This
  -- includes conditions.patient_id/doctor_id, medication requests, encounters,
  -- appointments, chat, notifications, audit records, and role extensions.
  for fk in
    select n.nspname as schema_name,
           c.relname as table_name,
           a.attname as column_name
      from pg_constraint con
      join pg_class c on c.oid = con.conrelid
      join pg_namespace n on n.oid = c.relnamespace
      join pg_attribute a on a.attrelid = con.conrelid
                         and a.attnum = con.conkey[1]
     where con.contype = 'f'
       and con.confrelid = 'public.profiles'::regclass
       and array_length(con.conkey, 1) = 1
       and not (n.nspname = 'public' and c.relname = 'profiles')
  loop
    execute format('delete from %I.%I where %I = any ($1)',
                   fk.schema_name, fk.table_name, fk.column_name)
      using demo_ids;
  end loop;

  -- profiles.id cascades from auth.users once all non-cascading clinical FKs
  -- have been cleared.
  delete from auth.users where id = any (demo_ids);

  -- Preserve any real staff accounts that were temporarily attached to seeded
  -- facilities, but remove clinical/demo rows owned by those facilities.
  update public.lab_worker_profiles set lab_id = null
   where lab_id = any (demo_lab_ids);
  update public.doctor_profiles set clinic_id = null
   where clinic_id = any (demo_clinic_ids);
  update public.receptionist_profiles set clinic_id = null
   where clinic_id = any (demo_clinic_ids);

  delete from public.lab_results where lab_id = any (demo_lab_ids);
  delete from public.lab_orders where lab_id = any (demo_lab_ids);
  delete from public.doctor_availability where clinic_id = any (demo_clinic_ids);
  delete from public.appointments where clinic_id = any (demo_clinic_ids);
  delete from public.encounters where clinic_id = any (demo_clinic_ids);

  delete from public.diagnostic_labs where id = any (demo_lab_ids);
  delete from public.clinics where id = any (demo_clinic_ids);
end $$;
-- Replaces CNIC identity with one 16-digit numeric Hayaat ID.
-- Run after product_hardening.sql. Safe to re-run.

create or replace function public.hayaat_luhn_check_digit(p_first_15 text)
returns text
language plpgsql
immutable
strict
as $$
declare
  total integer := 0;
  digit integer;
  i integer;
begin
  if p_first_15 !~ '^[0-9]{15}$' then
    raise exception 'Hayaat ID base must contain exactly 15 digits';
  end if;
  for i in 1..15 loop
    digit := substr(p_first_15, i, 1)::integer;
    if mod(i, 2) = 1 then
      digit := digit * 2;
      if digit > 9 then digit := digit - 9; end if;
    end if;
    total := total + digit;
  end loop;
  return ((10 - mod(total, 10)) % 10)::text;
end;
$$;

create or replace function public.gen_hayaat_id()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  base text;
  candidate text;
begin
  loop
    base := lpad(floor(random() * 1000000000000000)::bigint::text, 15, '0');
    candidate := base || public.hayaat_luhn_check_digit(base);
    exit when not exists (select 1 from public.profiles where card_number = candidate)
              and not exists (select 1 from public.cards where card_number = candidate);
  end loop;
  return candidate;
end;
$$;

-- Keep the existing function signature so older card/signup functions call the
-- new generator without retaining role prefixes or sequential numbers.
create or replace function public.gen_card_number(p_role text)
returns text
language sql
security definer
set search_path = public
as $$ select public.gen_hayaat_id() $$;

-- Replace every old prefixed/sequential identifier with a numeric Hayaat ID.
do $$
declare
  rec record;
  new_id text;
begin
  for rec in
    select id from public.profiles
     where card_number is null
        or card_number !~ '^[0-9]{16}$'
        or right(card_number, 1) <> public.hayaat_luhn_check_digit(left(card_number, 15))
  loop
    new_id := public.gen_hayaat_id();
    update public.profiles set card_number = new_id where id = rec.id;
    update public.patient_profiles set health_card_number = new_id where id = rec.id;
    update public.cards set card_number = new_id where profile_id = rec.id;
  end loop;
end $$;

alter table public.profiles
  drop constraint if exists profiles_hayaat_id_format;
alter table public.profiles
  add constraint profiles_hayaat_id_format
  check (
    card_number ~ '^[0-9]{16}$'
    and right(card_number, 1) = public.hayaat_luhn_check_digit(left(card_number, 15))
  );

-- Login accepts Hayaat ID, email, phone, or staff employee ID. CNIC is not a
-- lookup key anywhere in this function.
create or replace function public.login_email(p_id text)
returns text
language sql
security definer
set search_path = public
as $$
  select u.email
    from auth.users u
    join public.profiles p on p.id = u.id
    left join public.receptionist_profiles rp on rp.id = p.id
    left join public.lab_worker_profiles lp on lp.id = p.id
   where p.card_number = regexp_replace(p_id, '\s', '', 'g')
      or p.phone_primary = regexp_replace(p_id, '\D', '', 'g')
      or lower(p.email) = lower(trim(p_id))
      or lower(rp.employee_id) = lower(trim(p_id))
      or lower(lp.employee_id) = lower(trim(p_id))
   limit 1
$$;
grant execute on function public.login_email(text) to anon, authenticated;

-- Stop storing or exposing CNIC after all dependent functions above have been
-- replaced. User metadata in Supabase Auth is also cleaned.
update auth.users
   set raw_user_meta_data = raw_user_meta_data - 'cnic'
 where raw_user_meta_data ? 'cnic';

alter table public.profiles drop column if exists cnic;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  m jsonb := new.raw_user_meta_data;
  am jsonb := new.raw_app_meta_data;
  r text;
  hayat_id text;
begin
  r := coalesce(am->>'role', m->>'role', 'patient');
  if (am->>'role') is null and r not in ('patient', 'doctor') then
    r := 'patient';
  end if;
  hayat_id := public.gen_hayaat_id();

  insert into public.profiles
    (id, auth_user_id, full_name, date_of_birth, gender, phone_primary,
     email, role, status, card_number)
  values
    (new.id, new.id, coalesce(m->>'full_name', ''),
     nullif(m->>'date_of_birth', '')::date, m->>'gender',
     coalesce(m->>'phone', ''), nullif(m->>'email', ''), r,
     case when r = 'doctor' then 'pending' else 'active' end, hayat_id);

  if r = 'patient' then
    insert into public.patient_profiles
      (id, blood_group, health_card_number, emergency_contact_phone)
    values (new.id, m->>'blood_group', hayat_id, m->>'emergency_phone');
  elsif r = 'doctor' then
    insert into public.doctor_profiles
      (id, pmdc_number, specialization_primary, qualification_mbbs,
       qualification_fcps, clinic_id)
    values
      (new.id, m->>'pmdc_number',
       coalesce(m->>'specialization_primary', 'General Medicine'),
       coalesce((m->>'qualification_mbbs')::boolean, true),
       coalesce((m->>'qualification_fcps')::boolean, false),
       nullif(m->>'clinic_id', '')::uuid);
  elsif r = 'lab_worker' then
    insert into public.lab_worker_profiles (id, lab_id, employee_id)
    values (new.id, nullif(m->>'lab_id', '')::uuid, m->>'employee_id');
  elsif r = 'receptionist' then
    insert into public.receptionist_profiles (id, clinic_id, employee_id)
    values (new.id, nullif(m->>'clinic_id', '')::uuid, m->>'employee_id');
  elsif r = 'admin' then
    insert into public.admin_profiles (id, admin_level)
    values (new.id, coalesce(m->>'admin_level', 'support_admin'));
  end if;
  return new;
end;
$$;
-- Specialty-first patient record library and durable original-document storage.
-- Run after hayaat_id_only.sql. Safe to re-run.

alter table public.lab_results
  add column if not exists result_file_path text;

create table if not exists public.medical_documents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  uploaded_by uuid references public.profiles(id),
  doctor_id uuid references public.profiles(id),
  clinic_id uuid references public.clinics(id),
  encounter_id uuid references public.encounters(id) on delete set null,
  specialty text not null default 'General Medicine',
  record_type text not null default 'other' check (record_type in (
    'prescription', 'laboratory', 'imaging', 'medical_certificate',
    'discharge_summary', 'procedure_note', 'vaccination', 'referral',
    'consultation', 'clinical_note', 'vital_signs', 'diagnosis',
    'medication_history', 'allergy', 'chronic_disease', 'follow_up', 'other'
  )),
  title text not null,
  record_date date not null default current_date,
  facility_name text,
  doctor_name text,
  notes text,
  file_paths text[] not null default '{}',
  file_names text[] not null default '{}',
  mime_types text[] not null default '{}',
  extracted_metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint medical_documents_file_metadata_lengths check (
    cardinality(file_names) in (0, cardinality(file_paths)) and
    cardinality(mime_types) in (0, cardinality(file_paths))
  )
);

create index if not exists medical_documents_patient_specialty_date_idx
  on public.medical_documents(patient_id, specialty, record_date desc);
create index if not exists medical_documents_encounter_idx
  on public.medical_documents(encounter_id) where encounter_id is not null;

alter table public.medical_documents enable row level security;

drop policy if exists "patient reads own medical documents" on public.medical_documents;
create policy "patient reads own medical documents"
  on public.medical_documents for select
  using (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or uploaded_by = auth.uid()
    or public.my_role() = 'admin'
  );

drop policy if exists "patient or staff uploads medical documents" on public.medical_documents;
create policy "patient or staff uploads medical documents"
  on public.medical_documents for insert
  with check (
    patient_id = auth.uid()
    or (
      public.my_role() in ('doctor', 'lab_worker', 'admin')
      and uploaded_by = auth.uid()
    )
  );

drop policy if exists "document uploader maintains metadata" on public.medical_documents;
create policy "document uploader maintains metadata"
  on public.medical_documents for update
  using (
    patient_id = auth.uid()
    or (public.my_role() in ('doctor', 'lab_worker', 'admin') and uploaded_by = auth.uid())
  )
  with check (
    patient_id = auth.uid()
    or (public.my_role() in ('doctor', 'lab_worker', 'admin') and uploaded_by = auth.uid())
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'medical-documents',
  'medical-documents',
  false,
  52428800,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'application/dicom']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "medical document owner or staff reads files" on storage.objects;
create policy "medical document owner or staff reads files"
  on storage.objects for select
  using (
    bucket_id = 'medical-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
          from public.medical_documents document
         where name = any (document.file_paths)
           and (
             document.doctor_id = auth.uid()
             or document.uploaded_by = auth.uid()
             or public.my_role() = 'admin'
           )
      )
    )
  );

drop policy if exists "medical document owner or staff uploads files" on storage.objects;
create policy "medical document owner or staff uploads files"
  on storage.objects for insert
  with check (
    bucket_id = 'medical-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.my_role() in ('doctor', 'lab_worker', 'admin')
    )
  );

grant select, insert, update on public.medical_documents to authenticated;
-- ===========================================================================
-- CNIC identity restoration.
--
-- The prototype scope document (docs/ibbi docs/CNIC_Health_Card_PROTOTYPE_Scope.pdf)
-- makes the 13-digit CNIC the citizen's identity:
--   P-FR-001  register as a patient with a valid 13-digit CNIC
--   P-FR-002  doctors submit PMDC number + CNIC at registration
--   P-FR-005  the same CNIC cannot be registered twice, for any role
--   P-FR-019  a doctor finds a patient by entering their CNIC number
--
-- A previous migration (hayaat_id_only.sql) dropped profiles.cnic and made the
-- 16-digit Hayaat card number the only lookup key. This file puts CNIC back as
-- the identity key WITHOUT removing the Hayaat card number, which stays the
-- number printed on the physical/virtual health card.
--
-- Run after: hayaat_id_only.sql and product_hardening.sql. Safe to re-run.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. profiles.cnic
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists cnic varchar(13);

-- Format check: exactly 13 digits, no dashes. NULL is tolerated so that rows
-- created while CNIC was dropped keep working; every new sign-up supplies one.
alter table public.profiles drop constraint if exists profiles_cnic_format;
alter table public.profiles
  add constraint profiles_cnic_format
  check (cnic is null or cnic ~ '^[0-9]{13}$');

-- P-FR-005: one CNIC, one account, across every role.
create unique index if not exists profiles_cnic_unique
  on public.profiles (cnic) where cnic is not null;

comment on column public.profiles.cnic is
  '13-digit Pakistan CNIC, no dashes. Citizen identity key (P-FR-001/005/019). profiles.card_number stays the 16-digit Hayaat health-card number.';

-- ---------------------------------------------------------------------------
-- 2. Sign-up trigger stores the CNIC supplied in auth metadata.
--    Role is still trusted only from raw_app_meta_data (service-role) and
--    clamped to patient/doctor for self-service sign-up -- unchanged.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  m jsonb := new.raw_user_meta_data;
  am jsonb := new.raw_app_meta_data;
  r text;
  hayat_id text;
  v_cnic text;
begin
  r := coalesce(am->>'role', m->>'role', 'patient');
  if (am->>'role') is null and r not in ('patient', 'doctor') then
    r := 'patient';
  end if;
  hayat_id := public.gen_hayaat_id();

  -- Normalise the CNIC: strip dashes/spaces, keep only a well-formed 13-digit
  -- value. A malformed value is rejected outright rather than silently dropped,
  -- so the client cannot create an account with an unusable identity.
  v_cnic := nullif(regexp_replace(coalesce(m->>'cnic', ''), '\D', '', 'g'), '');
  if v_cnic is not null and v_cnic !~ '^[0-9]{13}$' then
    raise exception 'CNIC must be exactly 13 digits.';
  end if;
  if v_cnic is not null and exists (select 1 from public.profiles where cnic = v_cnic) then
    raise exception 'This CNIC is already registered.';
  end if;

  insert into public.profiles
    (id, auth_user_id, cnic, full_name, date_of_birth, gender, phone_primary,
     email, role, status, card_number)
  values
    (new.id, new.id, v_cnic, coalesce(m->>'full_name', ''),
     nullif(m->>'date_of_birth', '')::date, m->>'gender',
     coalesce(m->>'phone', ''), nullif(m->>'email', ''), r,
     case when r = 'doctor' then 'pending' else 'active' end, hayat_id);

  if r = 'patient' then
    insert into public.patient_profiles
      (id, blood_group, health_card_number, emergency_contact_phone)
    values (new.id, m->>'blood_group', hayat_id, m->>'emergency_phone');
  elsif r = 'doctor' then
    insert into public.doctor_profiles
      (id, pmdc_number, specialization_primary, qualification_mbbs,
       qualification_fcps, clinic_id)
    values
      (new.id, m->>'pmdc_number',
       coalesce(m->>'specialization_primary', 'General Medicine'),
       coalesce((m->>'qualification_mbbs')::boolean, true),
       coalesce((m->>'qualification_fcps')::boolean, false),
       nullif(m->>'clinic_id', '')::uuid);
  elsif r = 'lab_worker' then
    insert into public.lab_worker_profiles (id, lab_id, employee_id)
    values (new.id, nullif(m->>'lab_id', '')::uuid, m->>'employee_id');
  elsif r = 'receptionist' then
    insert into public.receptionist_profiles (id, clinic_id, employee_id)
    values (new.id, nullif(m->>'clinic_id', '')::uuid, m->>'employee_id');
  elsif r = 'admin' then
    insert into public.admin_profiles (id, admin_level)
    values (new.id, coalesce(m->>'admin_level', 'support_admin'));
  end if;
  return new;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 3. Login accepts CNIC again, alongside Hayaat ID / phone / email / employee ID.
-- ---------------------------------------------------------------------------
create or replace function public.login_email(p_id text)
returns text
language sql
security definer
set search_path = public
as $fn$
  select u.email
    from auth.users u
    join public.profiles p on p.id = u.id
    left join public.receptionist_profiles rp on rp.id = p.id
    left join public.lab_worker_profiles lp on lp.id = p.id
   where p.cnic = regexp_replace(p_id, '\D', '', 'g')
      or p.card_number = regexp_replace(p_id, '\s', '', 'g')
      or p.phone_primary = regexp_replace(p_id, '\D', '', 'g')
      or lower(p.email) = lower(trim(p_id))
      or lower(rp.employee_id) = lower(trim(p_id))
      or lower(lp.employee_id) = lower(trim(p_id))
   limit 1
$fn$;
grant execute on function public.login_email(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. P-FR-019 -- doctor/receptionist patient lookup by CNIC.
--
-- Clinical RLS scopes profiles to the owner plus staff who already have a care
-- relationship, so a plain SELECT cannot find a walk-in patient the doctor has
-- never treated. This SECURITY DEFINER function is the one sanctioned way to
-- resolve a patient from the identifier printed on their card: it is callable
-- only by active staff, returns demographics only (no clinical rows), and
-- writes an audit entry for every successful lookup.
--
-- p_identifier accepts a 13-digit CNIC or a 16-digit Hayaat card number, so
-- existing card-number workflows keep working unchanged.
-- ---------------------------------------------------------------------------
-- Dropped first: a function's return type cannot be changed by CREATE OR
-- REPLACE, and find_patient_by_cnic depends on this one.
drop function if exists public.find_patient_by_cnic(text);
drop function if exists public.find_patient_by_identifier(text);

create function public.find_patient_by_identifier(p_identifier text)
returns table (
  id uuid,
  cnic text,
  card_number text,
  full_name text,
  date_of_birth date,
  gender text,
  phone_primary text,
  email text,
  status text,
  blood_group text
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_digits text := regexp_replace(coalesce(p_identifier, ''), '\D', '', 'g');
  v_patient uuid;
begin
  if not public.is_staff() then
    raise exception 'Staff access required.' using errcode = '42501';
  end if;
  if v_digits !~ '^[0-9]{13}$' and v_digits !~ '^[0-9]{16}$' then
    raise exception 'Enter a 13-digit CNIC or a 16-digit Hayaat ID.';
  end if;

  select p.id into v_patient
    from public.profiles p
   where p.role = 'patient'
     and (p.cnic = v_digits or p.card_number = v_digits)
   limit 1;

  if v_patient is null then
    return;
  end if;

  -- P-FR-019 lookups are patient-data access: record who looked up whom.
  insert into public.audit_logs
    (actor_id, actor_role, action, resource_type, resource_id, patient_id, status)
  values
    (auth.uid(), public.my_role(), 'read', 'profiles', v_patient, v_patient, 'success');

  -- Every column is cast to the declared return type: profiles stores
  -- full_name/gender/phone_primary/email/status as varchar, and returning a
  -- varchar where the signature promises text raises
  -- "structure of query does not match function result type".
  return query
    select p.id,
           p.cnic::text,
           p.card_number::text,
           p.full_name::text,
           p.date_of_birth,
           p.gender::text,
           p.phone_primary::text,
           p.email::text,
           p.status::text,
           pp.blood_group::text
      from public.profiles p
      left join public.patient_profiles pp on pp.id = p.id
     where p.id = v_patient;
end;
$fn$;
revoke all on function public.find_patient_by_identifier(text) from public;
grant execute on function public.find_patient_by_identifier(text) to authenticated;

comment on function public.find_patient_by_identifier(text) is
  'P-FR-019 staff patient lookup by 13-digit CNIC or 16-digit Hayaat ID. Demographics only; writes an audit_logs row per successful lookup.';

-- Explicit CNIC-named alias for call sites that only ever pass a CNIC.
create function public.find_patient_by_cnic(p_cnic text)
returns table (
  id uuid,
  cnic text,
  card_number text,
  full_name text,
  date_of_birth date,
  gender text,
  phone_primary text,
  email text,
  status text,
  blood_group text
)
language sql
security definer
set search_path = public
as $fn$ select * from public.find_patient_by_identifier(p_cnic) $fn$;
revoke all on function public.find_patient_by_cnic(text) from public;
grant execute on function public.find_patient_by_cnic(text) to authenticated;
-- ===========================================================================
-- Keep the doctor's clinical narrative away from the laboratory.
--
-- `clinical_staff_can_access_patient()` grants a lab worker access to any
-- patient their lab holds an order for. That is right for the lab workflow --
-- they must read the order and write the result -- but the same helper was
-- also guarding encounters, diagnoses, prescriptions, vitals and allergies,
-- so a lab technician could read the chief complaint, assessment, plan and
-- full medication history of every patient whose sample crossed their bench.
--
-- The prototype scope has the lab working from a queue with the patient's
-- identity masked; it never asks the lab to see the consultation notes.
--
-- This file adds a narrower helper for the narrative tables. The lab keeps
-- exactly what it needs: lab_orders, lab_results, and the lab-results storage
-- folder, all still gated by clinical_staff_can_access_patient().
--
-- Run after product_hardening.sql. Safe to re-run.
-- ===========================================================================

create or replace function public.narrative_staff_can_access_patient(p_patient uuid)
  returns boolean language sql security definer stable set search_path = public as
$fn$
  select case
    when auth.uid() = p_patient then true
    when public.my_role() = 'admin' then true
    -- Treating doctors only. Receptionists (demographics) and lab workers
    -- (specimen workflow) are deliberately excluded.
    when public.my_role() = 'doctor' then exists (
      select 1 from public.appointments a
      where a.patient_id = p_patient
        and a.doctor_id = auth.uid()
        and a.status not in ('cancelled_by_patient','cancelled_by_clinic')
      union all
      select 1 from public.encounters e
      where e.patient_id = p_patient and e.doctor_id = auth.uid()
    )
    else false
  end
$fn$;

revoke all on function public.narrative_staff_can_access_patient(uuid) from public;
grant execute on function public.narrative_staff_can_access_patient(uuid) to authenticated;

comment on function public.narrative_staff_can_access_patient(uuid) is
  'Read access to consultation narrative and prescribing history: the patient, an admin, or a doctor with a care relationship. Excludes lab workers and receptionists.';

-- ---------------------------------------------------------------------------
-- Repoint the narrative tables. Write policies are untouched.
-- ---------------------------------------------------------------------------
drop policy if exists p_enc_sel on public.encounters;
create policy p_enc_sel on public.encounters for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));

drop policy if exists p_cond_sel on public.conditions;
create policy p_cond_sel on public.conditions for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));

drop policy if exists p_med_sel on public.medication_requests;
create policy p_med_sel on public.medication_requests for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));

drop policy if exists p_obs_sel on public.observations;
create policy p_obs_sel on public.observations for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));

drop policy if exists p_alg_sel on public.allergies;
create policy p_alg_sel on public.allergies for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));
-- ===========================================================================
-- One patient, one Hayaat number.
--
-- The Hayaat number lived in three places that were allowed to drift apart:
--   profiles.card_number                 issued by handle_new_user() at sign-up
--   cards.card_number                    issued again by request_card()
--   patient_profiles.health_card_number  written once at sign-up, never updated
--
-- Two conflicting definitions of request_card() shipped in the repo:
-- revision.sql used `coalesce(card_number, v_num)` and kept the number the
-- patient was given at sign-up, while cards.sql used a bare `= v_num` and
-- replaced it with a freshly generated one. Whichever file was applied last
-- won. With the cards.sql version deployed, asking for a card silently changed
-- the patient's Hayaat ID and left patient_profiles pointing at the old value,
-- so one person ended up with three different 16-digit numbers.
--
-- This file makes the number stable: it is minted once, at sign-up, and every
-- later write reuses it. It also reconciles rows that already drifted.
--
-- Run after cards.sql and hayaat_id_only.sql. Safe to re-run.
-- ===========================================================================

drop function if exists public.request_card(text, date, text, text, text);
drop function if exists public.request_card(text, text, date, text, text, text);

create function public.request_card(
  p_name_en text default null,
  p_name_ur text default null,
  p_dob date default null,
  p_blood_group text default null,
  p_city text default null,
  p_photo_url text default null)
  returns public.cards language plpgsql security definer set search_path = public as
$fn$
declare
  v_role text;
  v_name text;
  v_num text;
  v_card public.cards;
begin
  select role, full_name, card_number into v_role, v_name, v_num
    from public.profiles where id = auth.uid();
  if v_role is null then raise exception 'Profile not found.'; end if;

  -- Reuse the number issued at sign-up. Only mint one if the account somehow
  -- has none (rows created before card numbers existed).
  if v_num is null or v_num !~ '^[0-9]{16}$' then
    v_num := public.gen_hayaat_id();
  end if;

  select * into v_card from public.cards where profile_id = auth.uid();
  if v_card.id is null then
    insert into public.cards
      (profile_id, card_number, role, name_en, name_ur, date_of_birth,
       blood_group, city, photo_url, status)
    values
      (auth.uid(), v_num, v_role, coalesce(nullif(p_name_en, ''), v_name),
       p_name_ur, p_dob, p_blood_group, p_city, p_photo_url, 'virtual')
    returning * into v_card;
  else
    update public.cards set
      card_number   = v_num,
      name_en       = coalesce(nullif(p_name_en, ''), name_en),
      name_ur       = p_name_ur,
      date_of_birth = p_dob,
      blood_group   = p_blood_group,
      city          = p_city,
      photo_url     = coalesce(p_photo_url, photo_url),
      updated_at    = now()
    where profile_id = auth.uid()
    returning * into v_card;
  end if;

  -- Keep all three copies of the number, and the demographics, in step.
  update public.profiles
     set card_number   = v_num,
         date_of_birth = coalesce(date_of_birth, p_dob)
   where id = auth.uid();

  update public.patient_profiles
     set blood_group        = coalesce(p_blood_group, blood_group),
         address_city       = coalesce(p_city, address_city),
         health_card_number = v_num
   where id = auth.uid();

  return v_card;
end;
$fn$;

revoke all on function public.request_card(text, text, date, text, text, text) from public;
grant execute on function public.request_card(text, text, date, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Reconcile rows that already drifted. profiles.card_number is authoritative
-- because it is the value the sign-up trigger issued and the value login and
-- staff lookup resolve against.
-- ---------------------------------------------------------------------------
update public.cards c
   set card_number = p.card_number,
       updated_at  = now()
  from public.profiles p
 where p.id = c.profile_id
   and p.card_number is not null
   and c.card_number is distinct from p.card_number;

update public.patient_profiles pp
   set health_card_number = p.card_number
  from public.profiles p
 where p.id = pp.id
   and p.card_number is not null
   and pp.health_card_number is distinct from p.card_number;
