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
