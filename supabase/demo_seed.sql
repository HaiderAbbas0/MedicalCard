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
