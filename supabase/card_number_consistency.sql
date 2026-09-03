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
