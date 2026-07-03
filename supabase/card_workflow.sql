-- ============================================================================
-- card_workflow.sql — Phase 7: card delivery workflow + admin notifications.
-- Run AFTER cards.sql and security_hardening.sql. Idempotent.
--
--   * Admins are notified in-app when a patient APPLIES for a card, and again
--     when a patient requests PHYSICAL delivery.
--   * Admins may update cards (to mark a physical card delivered).
-- ============================================================================

-- Let admins act on cards (mark delivered, etc.). The existing owner policy
-- (profile_id = auth.uid()) stays; RLS allows a row if EITHER policy passes.
drop policy if exists p_cards_upd_admin on public.cards;
create policy p_cards_upd_admin on public.cards for update to authenticated
  using (public.my_role() = 'admin')
  with check (public.my_role() = 'admin');

-- Fan a notification out to every active admin. SECURITY DEFINER so the trigger
-- can write notifications addressed to other users.
create or replace function public.notify_admins(p_type text, p_title text, p_body text, p_resource uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare a uuid;
begin
  for a in select id from public.profiles where role = 'admin' and status = 'active' loop
    insert into public.notifications (recipient_id, type, title, body, resource_id)
    values (a, p_type, p_title, p_body, p_resource);
  end loop;
end;
$$;

-- New card application → notify admins.
create or replace function public.tg_card_insert_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare nm text;
begin
  select full_name into nm from public.profiles where id = new.profile_id;
  perform public.notify_admins(
    'card_request',
    'New card application',
    coalesce(nm, 'A patient') || ' applied for a health card (' || coalesce(new.card_number, '') || ').',
    new.profile_id);
  return new;
end;
$$;

drop trigger if exists trg_card_insert_notify on public.cards;
create trigger trg_card_insert_notify after insert on public.cards
  for each row execute function public.tg_card_insert_notify();

-- Physical delivery requested → notify admins (only on the transition).
create or replace function public.tg_card_physical_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare nm text;
begin
  if new.status = 'physical_requested'
     and coalesce(old.status, '') is distinct from 'physical_requested' then
    select full_name into nm from public.profiles where id = new.profile_id;
    perform public.notify_admins(
      'card_delivery',
      'Physical card delivery requested',
      coalesce(nm, 'A patient') || ' requested physical delivery of card ' || coalesce(new.card_number, '') || '.',
      new.profile_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_card_physical_notify on public.cards;
create trigger trg_card_physical_notify after update on public.cards
  for each row execute function public.tg_card_physical_notify();
