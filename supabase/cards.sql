-- ============================================================================
--  HayaatID — Card issuance (run AFTER schema.sql, once, in the SQL Editor)
--
--  Adds: per-role card numbers (HAY-PAT-0001 …), a cards table, request RPCs,
--  RLS, and a public storage bucket for card photos. Safe to re-run.
-- ============================================================================

-- Card number on the profile (also a DB lookup key).
alter table public.profiles add column if not exists card_number text unique;

-- Per-role sequences.
create sequence if not exists public.hay_pat_seq start 1;
create sequence if not exists public.hay_doc_seq start 1;
create sequence if not exists public.hay_lab_seq start 1;
create sequence if not exists public.hay_rec_seq start 1;
create sequence if not exists public.hay_adm_seq start 1;

create or replace function public.gen_card_number(p_role text)
  returns text language plpgsql security definer set search_path = public as
$$
declare n bigint; prefix text;
begin
  case p_role
    when 'doctor'       then n := nextval('public.hay_doc_seq'); prefix := 'DOC';
    when 'lab_worker'   then n := nextval('public.hay_lab_seq'); prefix := 'LAB';
    when 'receptionist' then n := nextval('public.hay_rec_seq'); prefix := 'REC';
    when 'admin'        then n := nextval('public.hay_adm_seq'); prefix := 'ADM';
    else                     n := nextval('public.hay_pat_seq'); prefix := 'PAT';
  end case;
  return 'HAY-' || prefix || '-' || lpad(n::text, 4, '0');
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
create or replace function public.request_card(
  p_name_ur text, p_dob date, p_blood_group text, p_city text, p_photo_url text)
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
      values (auth.uid(), v_num, v_role, v_name, p_name_ur, p_dob, p_blood_group, p_city, p_photo_url, 'virtual')
      returning * into v_card;
    update public.profiles set card_number = v_num, date_of_birth = coalesce(date_of_birth, p_dob) where id = auth.uid();
  else
    update public.cards set
      name_ur = p_name_ur, date_of_birth = p_dob, blood_group = p_blood_group, city = p_city,
      photo_url = coalesce(p_photo_url, photo_url), updated_at = now()
    where profile_id = auth.uid() returning * into v_card;
  end if;

  -- Keep the patient profile in sync.
  update public.patient_profiles set blood_group = p_blood_group, address_city = p_city where id = auth.uid();
  return v_card;
end;
$$;

-- Request a physical card (delivery details + status).
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

-- Public bucket for card photos.
insert into storage.buckets (id, name, public) values ('card-photos', 'card-photos', true)
on conflict (id) do nothing;
drop policy if exists p_cardphoto_read on storage.objects;
drop policy if exists p_cardphoto_write on storage.objects;
create policy p_cardphoto_read on storage.objects for select to authenticated using (bucket_id = 'card-photos');
create policy p_cardphoto_write on storage.objects for insert to authenticated with check (bucket_id = 'card-photos');
