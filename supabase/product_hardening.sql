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
