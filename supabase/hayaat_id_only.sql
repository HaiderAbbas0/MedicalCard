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
