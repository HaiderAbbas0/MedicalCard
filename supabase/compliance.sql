-- ============================================================================
-- compliance.sql — Phase 8: consent storage, account-deletion requests, and a
-- self-service data export. Run AFTER security_hardening.sql. Idempotent.
--
--   * consents          — immutable record of a user accepting a document version
--   * deletion_requests — user-initiated "delete my account/data" workflow
--   * export_my_data()  — returns everything the CALLER's account holds, as JSON
-- ============================================================================

-- 1. Consent storage --------------------------------------------------------
create table if not exists public.consents (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  document    text not null,               -- 'privacy_policy' | 'terms' | 'data_processing'
  version     text not null,               -- e.g. '2026-07-04'
  accepted_at timestamptz not null default now(),
  ip          text,
  user_agent  text
);
create index if not exists idx_consents_user on public.consents (user_id);

-- Stamp server-observed context; clients can't spoof IP/device or backdate.
create or replace function public.stamp_consent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare hdrs json;
begin
  begin hdrs := current_setting('request.headers', true)::json;
  exception when others then hdrs := null; end;
  new.accepted_at := now();
  if hdrs is not null then
    new.ip := nullif(split_part(coalesce(hdrs->>'x-forwarded-for', ''), ',', 1), '');
    new.user_agent := left(nullif(coalesce(hdrs->>'user-agent', ''), ''), 300);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_consent on public.consents;
create trigger trg_stamp_consent before insert on public.consents
  for each row execute function public.stamp_consent();

alter table public.consents enable row level security;

drop policy if exists p_consents_sel on public.consents;
create policy p_consents_sel on public.consents for select to authenticated
  using (user_id = auth.uid() or public.is_staff());

drop policy if exists p_consents_ins on public.consents;
create policy p_consents_ins on public.consents for insert to authenticated
  with check (user_id = auth.uid());

-- Append-only: consents are a legal record, never edited or deleted by clients.
revoke update, delete on public.consents from authenticated;
revoke update, delete on public.consents from anon;

-- 2. Account-deletion requests ---------------------------------------------
create table if not exists public.deletion_requests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  reason       text,
  status       text not null default 'pending',   -- pending | processing | completed | rejected | failed
  note         text,                               -- admin note
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_by uuid references public.profiles(id)
);
create index if not exists idx_deletion_requests_status on public.deletion_requests (status, requested_at);

alter table public.deletion_requests enable row level security;

-- A user sees and creates only their own request; admins see and process all.
drop policy if exists p_delreq_sel on public.deletion_requests;
create policy p_delreq_sel on public.deletion_requests for select to authenticated
  using (user_id = auth.uid() or public.my_role() = 'admin');

drop policy if exists p_delreq_ins on public.deletion_requests;
create policy p_delreq_ins on public.deletion_requests for insert to authenticated
  with check (user_id = auth.uid());

-- Only admins may update status / add a note (fulfil or reject the request).
drop policy if exists p_delreq_upd on public.deletion_requests;
create policy p_delreq_upd on public.deletion_requests for update to authenticated
  using (public.my_role() = 'admin')
  with check (public.my_role() = 'admin');

-- 3. Self-service data export ----------------------------------------------
-- Returns ALL data belonging to the calling user as one JSON document. Scoped
-- strictly to auth.uid(), so SECURITY DEFINER is safe (it never reads anyone
-- else's rows). Powers the "Download my data" feature (data portability).
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
    'appointments', (select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb) from public.appointments a         where a.patient_id = uid),
    'encounters',   (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb) from public.encounters e           where e.patient_id = uid),
    'conditions',   (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from public.conditions x           where x.patient_id = uid),
    'medications',  (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb) from public.medication_requests m  where m.patient_id = uid),
    'observations', (select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb) from public.observations o         where o.patient_id = uid),
    'allergies',    (select coalesce(jsonb_agg(to_jsonb(al)), '[]'::jsonb) from public.allergies al          where al.patient_id = uid),
    'lab_orders',   (select coalesce(jsonb_agg(to_jsonb(lo)), '[]'::jsonb) from public.lab_orders lo         where lo.patient_id = uid),
    'lab_results',  (select coalesce(jsonb_agg(to_jsonb(lr)), '[]'::jsonb) from public.lab_results lr        where lr.patient_id = uid),
    'notifications',(select coalesce(jsonb_agg(to_jsonb(n)), '[]'::jsonb) from public.notifications n        where n.recipient_id = uid),
    'consents',     (select coalesce(jsonb_agg(to_jsonb(cs)), '[]'::jsonb) from public.consents cs           where cs.user_id = uid)
  );
end;
$$;

revoke all on function public.export_my_data() from public;
grant execute on function public.export_my_data() to authenticated;
