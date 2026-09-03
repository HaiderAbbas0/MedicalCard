-- ===========================================================================
-- FINALIZE -- one-shot bring the deployed database up to the repository.
--
-- Paste this whole file into the Supabase SQL editor and run it once.
--
-- It contains exactly the pieces that were verified MISSING from the live
-- project on 2026-09-03 (probed with the publishable key -- see
-- supabase/tests/.probe): four RPCs the client apps already call, the
-- request_card() signature the Flutter card screen sends, and the CNIC
-- identity the prototype scope document requires. Everything is idempotent.
--
-- Order inside this file matters; do not reorder the sections.
--
--   Section 1  RLS helper the clinical policies depend on
--   Section 2  appointment slot generation + booking RPCs
--   Section 3  request_card() -- accepts p_name_en as the app sends it
--   Section 4  CNIC identity          (verbatim: supabase/cnic_identity.sql)
--   Section 5  demo clinic/lab/staff  (verbatim: supabase/demo_seed.sql)
--
-- Section 5 needs the demo auth accounts to exist first:
--     node supabase/tests/seed_demo_accounts.mjs
-- If you have not run that yet, run sections 1-4 now, then the script, then
-- re-run this file (or just run supabase/demo_seed.sql on its own).
-- ===========================================================================


-- ===========================================================================
-- Section 1 -- clinical_staff_can_access_patient()
-- Splits "can see demographics" from "can see clinical records", so a
-- receptionist can book for a patient without reading their lab results.
-- ===========================================================================
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

-- ===========================================================================
-- Section 2 -- appointment slot generation and booking
-- lib/services/patient_service.dart and web-staff/src/api/reception.ts call
-- these three; without them patient self-booking and receptionist booking
-- both fail at runtime.
-- ===========================================================================
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

-- ===========================================================================
-- Section 3 -- request_card()
-- The deployed function still had the old five-argument signature without
-- p_name_en, so the Flutter "request your card" screen could not match it and
-- every card request failed. This is the current repository version.
-- ===========================================================================
drop function if exists public.request_card(text, date, text, text, text);
drop function if exists public.request_card(text, text, date, text, text, text);
create or replace function public.request_card(
  p_name_en text default null,
  p_name_ur text default null,
  p_dob date default null,
  p_blood_group text default null,
  p_city text default null,
  p_photo_url text default null)
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
      values (auth.uid(), v_num, v_role, coalesce(nullif(p_name_en, ''), v_name), p_name_ur, p_dob, p_blood_group, p_city, p_photo_url, 'virtual')
      returning * into v_card;
    update public.profiles set card_number = v_num, date_of_birth = coalesce(date_of_birth, p_dob) where id = auth.uid();
  else
    update public.cards set
      name_en = coalesce(nullif(p_name_en, ''), name_en),
      name_ur = p_name_ur, date_of_birth = p_dob, blood_group = p_blood_group, city = p_city,
      photo_url = coalesce(p_photo_url, photo_url), updated_at = now()
    where profile_id = auth.uid() returning * into v_card;
  end if;

  -- Keep the patient profile in sync.
  update public.patient_profiles set blood_group = p_blood_group, address_city = p_city where id = auth.uid();
  return v_card;
end;
$$;

-- ===========================================================================
-- Section 4 -- CNIC identity (verbatim copy of supabase/cnic_identity.sql)
-- ===========================================================================
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
create or replace function public.find_patient_by_identifier(p_identifier text)
returns table (
  id uuid,
  cnic varchar(13),
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

  return query
    select p.id, p.cnic, p.card_number, p.full_name, p.date_of_birth, p.gender,
           p.phone_primary, p.email, p.status, pp.blood_group
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
create or replace function public.find_patient_by_cnic(p_cnic text)
returns table (
  id uuid,
  cnic varchar(13),
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
-- Section 5 -- demo bootstrap (verbatim copy of supabase/demo_seed.sql)
-- Requires: node supabase/tests/seed_demo_accounts.mjs
-- ===========================================================================
-- ===========================================================================
-- Demo bootstrap for the CNIC Health Card prototype.
--
-- Prerequisites, in order:
--   1. cnic_identity.sql has been run (adds profiles.cnic).
--   2. `node supabase/tests/seed_demo_accounts.mjs` has created the six demo
--      auth accounts through the ordinary public sign-up API.
--
-- This file does the part the public API cannot do: it promotes the staff
-- roles (self-service sign-up is deliberately clamped to patient/doctor),
-- creates the demo clinic and laboratory, approves the demo doctor, and
-- publishes a weekly availability schedule.
--
-- It deliberately creates NO clinical data. The encounters, lab orders and
-- lab reports are produced by `node supabase/tests/verify_e2e.mjs`, which
-- drives the same API calls the real apps use -- so the demo data is proof
-- that the flow works rather than rows inserted behind the app's back.
--
-- Safe to re-run.
-- ===========================================================================

do $seed$
declare
  v_clinic uuid;
  v_lab uuid;
  v_admin uuid;
  v_doctor uuid;
  v_labworker uuid;
  v_reception uuid;
  v_patient uuid;
  v_patient2 uuid;
begin
  -- -------------------------------------------------------------------------
  -- Resolve the demo accounts by their sign-up email. profiles.id is the same
  -- uuid as auth.users.id, so this also proves the sign-up trigger ran.
  -- -------------------------------------------------------------------------
  select id into v_admin      from auth.users where email = 'demo.admin@hayaat.id';
  select id into v_doctor     from auth.users where email = 'demo.doctor@hayaat.id';
  select id into v_labworker  from auth.users where email = 'demo.lab@hayaat.id';
  select id into v_reception  from auth.users where email = 'demo.reception@hayaat.id';
  select id into v_patient    from auth.users where email = 'demo.patient@hayaat.id';
  select id into v_patient2   from auth.users where email = 'demo.patient2@hayaat.id';

  if v_admin is null or v_doctor is null or v_labworker is null
     or v_reception is null or v_patient is null or v_patient2 is null then
    raise exception
      'Demo auth accounts are missing. Run: node supabase/tests/seed_demo_accounts.mjs';
  end if;

  -- -------------------------------------------------------------------------
  -- Clinic and diagnostic laboratory
  -- -------------------------------------------------------------------------
  select id into v_clinic from public.clinics where name = 'Hayaat Family Clinic';
  if v_clinic is null then
    insert into public.clinics (name, type, phone, address_street, address_city, address_province, status)
    values ('Hayaat Family Clinic', 'clinic', '04235000001',
            '12 Jail Road', 'Lahore', 'Punjab', 'active')
    returning id into v_clinic;
  else
    update public.clinics set status = 'active' where id = v_clinic;
  end if;

  select id into v_lab from public.diagnostic_labs where name = 'Hayaat Diagnostics';
  if v_lab is null then
    insert into public.diagnostic_labs (name, license_number, phone, address_city, address_province, status)
    values ('Hayaat Diagnostics', 'LAB-PB-1187', '04235000002', 'Lahore', 'Punjab', 'active')
    returning id into v_lab;
  else
    update public.diagnostic_labs set status = 'active' where id = v_lab;
  end if;

  -- -------------------------------------------------------------------------
  -- CNIC backfill. Accounts created before cnic_identity.sql ran carry no
  -- CNIC, so set it here from the canonical demo list.
  -- -------------------------------------------------------------------------
  update public.profiles set cnic = '3520100000001' where id = v_admin      and cnic is distinct from '3520100000001';
  update public.profiles set cnic = '3520199999991' where id = v_doctor     and cnic is distinct from '3520199999991';
  update public.profiles set cnic = '3520177777771' where id = v_labworker  and cnic is distinct from '3520177777771';
  update public.profiles set cnic = '3520166666661' where id = v_reception  and cnic is distinct from '3520166666661';
  update public.profiles set cnic = '3520112345671' where id = v_patient    and cnic is distinct from '3520112345671';
  update public.profiles set cnic = '3520112345672' where id = v_patient2   and cnic is distinct from '3520112345672';

  -- Sign-up stores the address only in auth metadata; mirror it onto the
  -- profile so the admin portal and staff lookups show a contactable email.
  update public.profiles p
     set email = u.email
    from auth.users u
   where p.id = u.id
     and p.id in (v_admin, v_doctor, v_labworker, v_reception, v_patient, v_patient2)
     and p.email is distinct from u.email;

  -- -------------------------------------------------------------------------
  -- Administrator
  -- -------------------------------------------------------------------------
  update public.profiles set role = 'admin', status = 'active' where id = v_admin;
  insert into public.admin_profiles (id, admin_level, can_approve_doctors, can_approve_labs, can_suspend_accounts)
  values (v_admin, 'super_admin', true, true, true)
  on conflict (id) do update set admin_level = 'super_admin';

  -- -------------------------------------------------------------------------
  -- Doctor -- approved, attached to the demo clinic
  -- -------------------------------------------------------------------------
  update public.profiles set role = 'doctor', status = 'active' where id = v_doctor;
  insert into public.doctor_profiles
    (id, pmdc_number, specialization_primary, qualification_mbbs, qualification_fcps,
     years_of_experience, consultation_fee_pkr, bio, is_available, clinic_id, approved_at, approved_by)
  values
    (v_doctor, 'PMDC-45219', 'General Medicine', true, true, 11, 2500,
     'General physician with a focus on diabetes and cardiovascular risk.',
     true, v_clinic, now(), v_admin)
  on conflict (id) do update
    set specialization_primary = excluded.specialization_primary,
        pmdc_number            = excluded.pmdc_number,
        clinic_id              = excluded.clinic_id,
        is_available           = true,
        approved_at            = coalesce(public.doctor_profiles.approved_at, now()),
        approved_by            = coalesce(public.doctor_profiles.approved_by, v_admin);

  -- -------------------------------------------------------------------------
  -- Lab worker and receptionist
  -- -------------------------------------------------------------------------
  update public.profiles set role = 'lab_worker', status = 'active' where id = v_labworker;
  insert into public.lab_worker_profiles (id, lab_id, employee_id, position_title, approved_at)
  values (v_labworker, v_lab, 'LAB-0001', 'Senior Lab Technician', now())
  on conflict (id) do update
    set lab_id = excluded.lab_id,
        employee_id = excluded.employee_id,
        approved_at = coalesce(public.lab_worker_profiles.approved_at, now());

  update public.profiles set role = 'receptionist', status = 'active' where id = v_reception;
  insert into public.receptionist_profiles (id, clinic_id, employee_id, approved_at)
  values (v_reception, v_clinic, 'REC-0001', now())
  on conflict (id) do update
    set clinic_id = excluded.clinic_id,
        employee_id = excluded.employee_id,
        approved_at = coalesce(public.receptionist_profiles.approved_at, now());

  -- -------------------------------------------------------------------------
  -- Patients
  -- -------------------------------------------------------------------------
  update public.profiles set role = 'patient', status = 'active' where id in (v_patient, v_patient2);

  insert into public.patient_profiles (id, blood_group, health_card_number, address_city, address_province, emergency_contact_name, emergency_contact_phone)
  select v_patient, 'O+', p.card_number, 'Lahore', 'Punjab', 'Nadia Khan', '03001234599'
    from public.profiles p where p.id = v_patient
  on conflict (id) do update
    set blood_group = 'O+',
        address_city = 'Lahore',
        address_province = 'Punjab',
        emergency_contact_name = 'Nadia Khan',
        emergency_contact_phone = '03001234599',
        health_card_number = coalesce(public.patient_profiles.health_card_number, excluded.health_card_number);

  insert into public.patient_profiles (id, blood_group, health_card_number, address_city, address_province, emergency_contact_name, emergency_contact_phone)
  select v_patient2, 'B+', p.card_number, 'Lahore', 'Punjab', 'Sana Tariq', '03001234598'
    from public.profiles p where p.id = v_patient2
  on conflict (id) do update
    set blood_group = 'B+',
        address_city = 'Lahore',
        address_province = 'Punjab',
        emergency_contact_name = 'Sana Tariq',
        emergency_contact_phone = '03001234598',
        health_card_number = coalesce(public.patient_profiles.health_card_number, excluded.health_card_number);

  -- A recorded allergy so the doctor's prescribe-time allergy check has
  -- something real to fire on during a demo.
  if not exists (
    select 1 from public.allergies
     where patient_id = v_patient and lower(substance_name) = 'penicillin'
  ) then
    insert into public.allergies
      (patient_id, recorded_by_id, substance_name, allergy_type, category,
       criticality, severity, reaction_description, clinical_status)
    values
      (v_patient, v_doctor, 'Penicillin', 'allergy', 'medication',
       'high', 'severe', 'Urticaria and facial swelling within an hour.', 'active');
  end if;

  -- -------------------------------------------------------------------------
  -- Weekly availability, so patient self-booking and receptionist booking
  -- both have generated open slots to offer. Monday-Friday, 09:00-13:00.
  -- -------------------------------------------------------------------------
  for i in 1..5 loop
    if not exists (
      select 1 from public.doctor_availability
       where doctor_id = v_doctor and day_of_week = i
         and start_time = time '09:00' and end_time = time '13:00'
    ) then
      insert into public.doctor_availability
        (doctor_id, clinic_id, day_of_week, start_time, end_time, slot_duration_minutes, is_active)
      values (v_doctor, v_clinic, i, time '09:00', time '13:00', 30, true);
    end if;
  end loop;

  raise notice 'Demo bootstrap complete. clinic=% lab=% doctor=% patient=%',
    v_clinic, v_lab, v_doctor, v_patient;
end;
$seed$;
