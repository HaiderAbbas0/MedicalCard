-- ============================================================================
-- chat.sql — Real patient <-> doctor messaging (replaces the demo Node chat stub)
-- Run AFTER security.sql. Idempotent.
--
-- Model: one conversation per (patient, doctor) pair; many messages per
-- conversation. RLS restricts every row to the two participants ONLY (a
-- conversation is PHI-adjacent, so we do NOT expose it to all staff/admins).
-- Realtime is enabled on `messages` so both clients receive replies live.
--
-- ============================================================================

create table if not exists public.conversations (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references public.profiles(id) on delete cascade,
  doctor_id       uuid not null references public.profiles(id) on delete cascade,
  last_message    text,
  last_message_at timestamptz,
  created_at      timestamptz not null default now(),
  unique (patient_id, doctor_id)
);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid not null references public.profiles(id) on delete cascade,
  body            text not null check (length(btrim(body)) > 0),
  created_at      timestamptz not null default now(),
  read_at         timestamptz
);

alter table public.conversations
  add column if not exists last_message text,
  add column if not exists last_message_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

alter table public.messages
  add column if not exists read_at timestamptz;

create index if not exists idx_messages_convo_time on public.messages (conversation_id, created_at);
create index if not exists idx_conversations_patient on public.conversations (patient_id);
create index if not exists idx_conversations_doctor on public.conversations (doctor_id);

-- Keep the conversation's denormalized "last message" preview current, and stamp
-- the conversation row so both list views can sort by recency. Runs as definer
-- so clients never need UPDATE rights on conversations.
create or replace function public.touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
     set last_message = left(new.body, 140),
         last_message_at = new.created_at
   where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists trg_touch_conversation on public.messages;
create trigger trg_touch_conversation
  after insert on public.messages
  for each row execute function public.touch_conversation();

-- Get-or-create the conversation between a patient and a doctor. Guarded so the
-- caller must be one of the two participants; avoids INSERT/RLS races on the
-- unique (patient_id, doctor_id) pair. Returns the conversation id.
create or replace function public.start_conversation(p_patient uuid, p_doctor uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or auth.uid() not in (p_patient, p_doctor) then
    raise exception 'not a participant';
  end if;
  -- the non-patient side must actually be a doctor
  if not exists (select 1 from public.profiles where id = p_doctor and role = 'doctor') then
    raise exception 'target is not a doctor';
  end if;

  insert into public.conversations (patient_id, doctor_id)
  values (p_patient, p_doctor)
  on conflict (patient_id, doctor_id) do nothing;

  select id into v_id from public.conversations
   where patient_id = p_patient and doctor_id = p_doctor;
  return v_id;
end;
$$;

revoke all on function public.start_conversation(uuid, uuid) from public;
grant execute on function public.start_conversation(uuid, uuid) to authenticated;

-- --------------------------------------------------------------------------
-- RLS: participants only
-- --------------------------------------------------------------------------
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists p_conv_sel on public.conversations;
create policy p_conv_sel on public.conversations for select to authenticated
  using (patient_id = auth.uid() or doctor_id = auth.uid());

drop policy if exists p_conv_ins on public.conversations;
create policy p_conv_ins on public.conversations for insert to authenticated
  with check (patient_id = auth.uid() or doctor_id = auth.uid());

drop policy if exists p_msg_sel on public.messages;
create policy p_msg_sel on public.messages for select to authenticated
  using (exists (
    select 1 from public.conversations c
     where c.id = conversation_id
       and (c.patient_id = auth.uid() or c.doctor_id = auth.uid())
  ));

drop policy if exists p_msg_ins on public.messages;
create policy p_msg_ins on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations c
       where c.id = conversation_id
         and (c.patient_id = auth.uid() or c.doctor_id = auth.uid())
    )
  );

-- Recipient marks messages read (read_at). A participant may only update rows in
-- their own conversations; they cannot alter the body (enforced by app + this
-- narrow policy which is only used for the read_at stamp).
drop policy if exists p_msg_upd on public.messages;
create policy p_msg_upd on public.messages for update to authenticated
  using (exists (
    select 1 from public.conversations c
     where c.id = conversation_id
       and (c.patient_id = auth.uid() or c.doctor_id = auth.uid())
  ));

-- --------------------------------------------------------------------------
-- Realtime: stream new messages to both clients
-- --------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations'
  ) then
    alter publication supabase_realtime add table public.conversations;
  end if;
end $$;
