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
