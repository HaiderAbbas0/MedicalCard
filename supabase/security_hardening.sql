-- ============================================================================
-- security_hardening.sql — Phase 5 incremental RLS/security fixes.
-- Run AFTER security.sql (and any time; idempotent). Complements it.
--
-- Fixes three findings from the security audit:
--   1. Suspended / pending staff still passed is_staff() → they could still read
--      PHI at the data layer even though the app blocks their login. Now
--      is_staff() also requires status = 'active', so suspension/pending is
--      enforced by RLS itself.
--   2. The card-photos bucket allowed ANY authenticated user to write to ANY
--      path. Now writes are limited to the owner's own folder (<uid>/...) or staff.
--   3. audit_logs hardened as append-only: UPDATE/DELETE are revoked outright
--      (in addition to being denied by the absence of any RLS policy for them).
-- ============================================================================

-- 1. Active-status gate on staff access ------------------------------------
create or replace function public.is_staff()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid()
       and role in ('doctor', 'lab_worker', 'receptionist', 'admin')
       and status = 'active'
  );
$$;

-- 2. card-photos: writes only to your own folder (or staff) ------------------
-- Uploads use the path `<auth.uid()>/<timestamp>.png` (see card_service.dart /
-- web card upload), so the first path segment is the owner's id.
drop policy if exists p_cardphoto_write on storage.objects;
create policy p_cardphoto_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'card-photos'
    and (public.is_staff() or (storage.foldername(name))[1] = auth.uid()::text)
  );

-- Needed so the client's `upsert: true` (overwrite own photo) still works.
drop policy if exists p_cardphoto_upd on storage.objects;
create policy p_cardphoto_upd on storage.objects for update to authenticated
  using (
    bucket_id = 'card-photos'
    and (public.is_staff() or (storage.foldername(name))[1] = auth.uid()::text)
  )
  with check (
    bucket_id = 'card-photos'
    and (public.is_staff() or (storage.foldername(name))[1] = auth.uid()::text)
  );

-- 3. audit_logs: append-only (no client updates/deletes, ever) ---------------
revoke update, delete on public.audit_logs from authenticated;
revoke update, delete on public.audit_logs from anon;

-- 4. audit_logs: server-stamped context (IP / device / role / time) ----------
-- Records who/where/when from the SERVER's view so a client cannot spoof its
-- role, backdate an entry, or omit its origin. actor_id integrity is already
-- guaranteed by the INSERT policy (actor_id = auth.uid()); this adds the rest.
alter table public.audit_logs add column if not exists ip         text;
alter table public.audit_logs add column if not exists user_agent text;
alter table public.audit_logs add column if not exists reason     text;

create or replace function public.stamp_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  hdrs json;
begin
  begin
    hdrs := current_setting('request.headers', true)::json;
  exception when others then
    hdrs := null;  -- not a PostgREST request (e.g. SQL editor) — leave blank
  end;

  -- Trust the JWT for the actor's role, never the client-supplied value.
  if auth.uid() is not null then
    new.actor_role := (select role from public.profiles where id = auth.uid());
  end if;

  -- Server clock — clients cannot backdate.
  new."timestamp" := now();

  if hdrs is not null then
    new.ip := nullif(split_part(coalesce(hdrs->>'x-forwarded-for', ''), ',', 1), '');
    new.user_agent := left(nullif(coalesce(hdrs->>'user-agent', ''), ''), 300);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_stamp_audit on public.audit_logs;
create trigger trg_stamp_audit
  before insert on public.audit_logs
  for each row execute function public.stamp_audit();
