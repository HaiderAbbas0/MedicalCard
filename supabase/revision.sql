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
  insert into public.profiles (id, auth_user_id, cnic, full_name, date_of_birth, gender, phone_primary, email, role, status, card_number)
  values (new.id, new.id, m->>'cnic', coalesce(m->>'full_name',''), nullif(m->>'date_of_birth','')::date,
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

-- ── Login by Unique ID: map a card number / CNIC / phone → auth email ───────
create or replace function public.login_email(p_id text)
  returns text language sql security definer set search_path = public as
$$
  select u.email from auth.users u
  join public.profiles p on p.id = u.id
  where p.card_number = p_id or p.cnic = p_id or p.phone_primary = p_id
  limit 1
$$;
grant execute on function public.login_email(text) to anon, authenticated;

-- ── Card request now accepts an English "Name on Card" (+ auto Urdu) ────────
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
