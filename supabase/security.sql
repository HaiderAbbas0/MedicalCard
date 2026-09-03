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
