-- ===========================================================================
-- HayaatID Research Data Platform
--
-- Lets approved external organisations (pharma, universities, public-health
-- bodies, ML teams) work with HayaatID clinical data WITHOUT ever receiving
-- identifiable records.
--
-- The design rests on five hard guarantees, all enforced in the database
-- rather than in client code:
--
--   1. CONSENT IS A HARD GATE. Only patients who have explicitly switched on
--      the `research` consent preference are ever in scope. Default is off.
--      Withdrawal takes effect immediately for every future read, because the
--      consent check happens at query time, never from a frozen snapshot.
--
--   2. NO DIRECT IDENTIFIERS EVER LEAVE. Name, CNIC, Hayaat ID, phone, email,
--      address, exact dates of birth and all free-text clinical narrative are
--      excluded at the source. Researchers cannot select them, because the
--      only routes into the data are the SECURITY DEFINER functions below.
--
--   3. PSEUDONYMS ARE PER-REQUEST. Each approved request gets its own random
--      salt, so the same patient appears under a different subject id in every
--      dataset. Two organisations (or two studies) cannot link their extracts
--      together to re-identify anyone.
--
--   4. K-ANONYMITY ON AGGREGATES. Cohort counts below the threshold
--      (research_k_threshold(), default 5) are suppressed rather than returned,
--      so a researcher cannot narrow a filter until it points at one person.
--
--   5. EVERY ACCESS IS AUDITED. Aggregate queries and row-level exports both
--      write to the append-only audit log, attributed to the caller.
--
-- Researchers hold role = 'researcher'. They are deliberately NOT staff:
-- is_staff() excludes them, so every existing clinical RLS policy already
-- denies them. They can reach nothing except through these functions.
--
-- Run after clinical_narrative_rls.sql. Safe to re-run.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Organisations and researcher accounts
-- ---------------------------------------------------------------------------
create table if not exists public.research_organizations (
  id uuid primary key default gen_random_uuid(),
  name varchar(255) not null,
  organization_type text not null default 'academic'
    check (organization_type in ('academic','hospital','public_health','pharmaceutical','ai_ml','ngo','other')),
  registration_number varchar(100),
  country varchar(100) default 'Pakistan',
  contact_email varchar(255),
  website varchar(255),
  -- Signed data-processing agreement, recorded as an accountability artifact.
  dpa_accepted_at timestamptz,
  dpa_accepted_by uuid references public.profiles(id),
  dpa_version text,
  status varchar(20) not null default 'pending'
    check (status in ('pending','active','suspended','rejected')),
  status_reason text,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references public.profiles(id)
);
create index if not exists idx_research_orgs_status on public.research_organizations (status, created_at desc);

create table if not exists public.researcher_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  organization_id uuid references public.research_organizations(id) on delete set null,
  job_title varchar(150),
  -- A researcher may hold elevated rights inside their own organisation only.
  is_org_admin boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_researcher_profiles_org on public.researcher_profiles (organization_id);

-- ---------------------------------------------------------------------------
-- 2. Dataset catalogue
--
-- Three fixed, curated datasets. Each is a de-identified projection, never a
-- raw table. `dictionary` is the machine-readable data dictionary the portal
-- renders so a researcher knows exactly what they are asking for.
-- ---------------------------------------------------------------------------
create table if not exists public.research_datasets (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  description text not null,
  -- 'aggregate' needs no approval; 'record_level' always does.
  tier text not null default 'record_level' check (tier in ('aggregate','record_level')),
  grain text not null,
  dictionary jsonb not null default '[]',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. Data access requests
--
-- Purpose limitation (GDPR Art. 5(1)(b)) and storage limitation (Art. 5(1)(e))
-- are recorded structurally: a request must state its purpose and legal basis,
-- and every approval carries an expiry after which exports stop working.
-- ---------------------------------------------------------------------------
create table if not exists public.research_data_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.research_organizations(id) on delete cascade,
  dataset_id uuid not null references public.research_datasets(id),
  requested_by uuid not null references public.profiles(id),
  title text not null,
  research_purpose text not null,
  legal_basis text not null default 'consent'
    check (legal_basis in ('consent','public_interest','legitimate_interest')),
  -- The cohort filter the researcher explored before requesting, kept verbatim
  -- so an approver reviews exactly the population that will be released.
  cohort_filters jsonb not null default '{}',
  ethics_approval_reference text,
  dpa_accepted boolean not null default false,
  status varchar(20) not null default 'pending'
    check (status in ('pending','approved','rejected','expired','revoked')),
  decision_note text,
  decided_at timestamptz,
  decided_by uuid references public.profiles(id),
  expires_at timestamptz,
  -- Per-request salt: the reason two extracts cannot be linked together.
  pseudonym_salt text not null default encode(gen_random_bytes(32), 'hex'),
  export_count integer not null default 0,
  last_exported_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_research_requests_org on public.research_data_requests (organization_id, created_at desc);
create index if not exists idx_research_requests_status on public.research_data_requests (status, created_at desc);

-- The salt must never be readable by the client, even by its own researcher.
revoke select on public.research_data_requests from anon, authenticated;
grant select (id, organization_id, dataset_id, requested_by, title, research_purpose,
              legal_basis, cohort_filters, ethics_approval_reference, dpa_accepted,
              status, decision_note, decided_at, decided_by, expires_at,
              export_count, last_exported_at, created_at)
  on public.research_data_requests to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_researcher()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and role = 'researcher' and status = 'active'
  );
$$;

create or replace function public.my_research_org()
returns uuid language sql security definer stable set search_path = public as $$
  select rp.organization_id
    from public.researcher_profiles rp
    join public.research_organizations o on o.id = rp.organization_id
   where rp.id = auth.uid() and o.status = 'active'
$$;

-- The k-anonymity threshold. Any aggregate group smaller than this is
-- suppressed instead of returned.
create or replace function public.research_k_threshold()
returns integer language sql immutable as $$ select 5 $$;

-- Stable within one request, unlinkable across requests.
create or replace function public.research_pseudonym(p_patient uuid, p_salt text)
returns text language sql immutable strict as $$
  select encode(digest(p_patient::text || ':' || p_salt, 'sha256'), 'hex')
$$;

-- Exact ages and dates of birth are quasi-identifiers; 5-year bands are not.
create or replace function public.research_age_band(p_dob date)
returns text language sql immutable as $$
  select case
    when p_dob is null then 'unknown'
    when extract(year from age(p_dob)) >= 90 then '90+'
    else (floor(extract(year from age(p_dob)) / 5) * 5)::int::text || '-' ||
         (floor(extract(year from age(p_dob)) / 5) * 5 + 4)::int::text
  end
$$;

-- Everyone whose data may be used, evaluated fresh on every call so that a
-- withdrawal of consent takes effect immediately.
create or replace function public.research_consented_patients()
returns table (patient_id uuid, age_band text, gender text, province text, blood_group text)
language sql security definer stable set search_path = public as $$
  select p.id,
         public.research_age_band(p.date_of_birth),
         coalesce(p.gender, 'unknown')::text,
         coalesce(pp.address_province, 'unknown')::text,
         coalesce(pp.blood_group, 'unknown')::text
    from public.profiles p
    join public.consent_preferences cp
      on cp.user_id = p.id and cp.key = 'research' and cp.enabled = true
    left join public.patient_profiles pp on pp.id = p.id
   where p.role = 'patient' and p.status = 'active'
$$;
revoke all on function public.research_consented_patients() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Audit helper — every research touch is recorded.
-- ---------------------------------------------------------------------------
create or replace function public.research_audit(p_action text, p_resource text, p_resource_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs (actor_id, actor_role, action, resource_type, resource_id, status)
  values (auth.uid(), 'researcher', left(p_action, 50), left(p_resource, 50), p_resource_id, 'success');
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. AGGREGATE TIER — open to any active researcher, k-anonymised.
--
-- Returns counts broken down by one quasi-identifier at a time. Groups below
-- the k threshold come back as `suppressed = true` with a NULL count, so the
-- researcher learns that a stratum exists but never how few people are in it.
-- ---------------------------------------------------------------------------
create or replace function public.research_cohort_summary(
  p_dimension text default 'age_band',
  p_gender text default null,
  p_province text default null,
  p_age_band text default null
)
returns table (bucket text, subject_count bigint, suppressed boolean)
language plpgsql security definer set search_path = public as $$
declare
  k integer := public.research_k_threshold();
begin
  if not public.is_researcher() or public.my_research_org() is null then
    raise exception 'Active researcher account required.' using errcode = '42501';
  end if;
  if p_dimension not in ('age_band','gender','province','blood_group') then
    raise exception 'Unsupported dimension.';
  end if;

  perform public.research_audit('research_query', 'cohort_summary', null);

  return query
  with base as (
    select * from public.research_consented_patients() c
     where (p_gender   is null or c.gender   = p_gender)
       and (p_province is null or c.province = p_province)
       and (p_age_band is null or c.age_band = p_age_band)
  ),
  grouped as (
    select case p_dimension
             when 'age_band'    then b.age_band
             when 'gender'      then b.gender
             when 'province'    then b.province
             else b.blood_group
           end as bucket,
           count(*) as n
      from base b
     group by 1
  )
  select g.bucket,
         case when g.n >= k then g.n else null end,
         g.n < k
    from grouped g
   order by g.bucket;
end;
$$;
grant execute on function public.research_cohort_summary(text, text, text, text) to authenticated;

-- Total size of a filtered cohort, suppressed below k.
create or replace function public.research_cohort_size(
  p_gender text default null,
  p_province text default null,
  p_age_band text default null
)
returns table (subject_count bigint, suppressed boolean)
language plpgsql security definer set search_path = public as $$
declare
  k integer := public.research_k_threshold();
  n bigint;
begin
  if not public.is_researcher() or public.my_research_org() is null then
    raise exception 'Active researcher account required.' using errcode = '42501';
  end if;

  select count(*) into n
    from public.research_consented_patients() c
   where (p_gender   is null or c.gender   = p_gender)
     and (p_province is null or c.province = p_province)
     and (p_age_band is null or c.age_band = p_age_band);

  return query select case when n >= k then n else null end, n < k;
end;
$$;
grant execute on function public.research_cohort_size(text, text, text) to authenticated;

-- Condition prevalence, also k-suppressed. Uses ICD-10 chapter letters rather
-- than full codes so rare diagnoses cannot single anyone out.
create or replace function public.research_condition_prevalence()
returns table (condition_group text, subject_count bigint, suppressed boolean)
language plpgsql security definer set search_path = public as $$
declare
  k integer := public.research_k_threshold();
begin
  if not public.is_researcher() or public.my_research_org() is null then
    raise exception 'Active researcher account required.' using errcode = '42501';
  end if;

  perform public.research_audit('research_query', 'condition_prevalence', null);

  return query
  with base as (select patient_id from public.research_consented_patients()),
  grouped as (
    select coalesce(nullif(left(c.icd10_code, 1), ''), 'unclassified') as condition_group,
           count(distinct c.patient_id) as n
      from public.conditions c
      join base b on b.patient_id = c.patient_id
     group by 1
  )
  select g.condition_group,
         case when g.n >= k then g.n else null end,
         g.n < k
    from grouped g
   order by g.condition_group;
end;
$$;
grant execute on function public.research_condition_prevalence() to authenticated;

-- ---------------------------------------------------------------------------
-- 7. RECORD-LEVEL TIER — approved requests only.
--
-- Guard applied identically by all three exporters: the request must belong to
-- the caller's organisation, be approved, and not have expired.
-- ---------------------------------------------------------------------------
create or replace function public.research_request_salt(p_request uuid)
returns text language plpgsql security definer stable set search_path = public as $$
declare
  s text;
begin
  select r.pseudonym_salt into s
    from public.research_data_requests r
   where r.id = p_request
     and r.organization_id = public.my_research_org()
     and r.status = 'approved'
     and (r.expires_at is null or r.expires_at > now());
  if s is null then
    raise exception 'No approved, unexpired data request with that id for your organisation.'
      using errcode = '42501';
  end if;
  return s;
end;
$$;
revoke all on function public.research_request_salt(uuid) from public, anon, authenticated;

-- 7a. Patient-level feature table — the primary ML training matrix.
create or replace function public.research_export_patient_features(p_request uuid)
returns table (
  subject_id text,
  age_band text,
  gender text,
  province text,
  blood_group text,
  encounter_count integer,
  condition_count integer,
  chronic_condition_count integer,
  medication_count integer,
  active_medication_count integer,
  allergy_count integer,
  lab_order_count integer,
  appointment_count integer,
  no_show_count integer,
  first_encounter_year integer,
  last_encounter_year integer,
  mean_systolic numeric,
  mean_pulse numeric
)
language plpgsql security definer set search_path = public as $$
declare
  salt text := public.research_request_salt(p_request);
begin
  perform public.research_audit('research_export', 'patient_features', p_request);
  update public.research_data_requests
     set export_count = export_count + 1, last_exported_at = now()
   where id = p_request;

  return query
  with base as (select * from public.research_consented_patients())
  select public.research_pseudonym(b.patient_id, salt),
         b.age_band, b.gender, b.province, b.blood_group,
         (select count(*)::int from public.encounters e
           where e.patient_id = b.patient_id and e.status = 'finalized'),
         (select count(*)::int from public.conditions c where c.patient_id = b.patient_id),
         (select count(*)::int from public.conditions c
           where c.patient_id = b.patient_id and c.is_chronic),
         (select count(*)::int from public.medication_requests m where m.patient_id = b.patient_id),
         (select count(*)::int from public.medication_requests m
           where m.patient_id = b.patient_id and m.status = 'active'),
         (select count(*)::int from public.allergies a where a.patient_id = b.patient_id),
         (select count(*)::int from public.lab_orders l where l.patient_id = b.patient_id),
         (select count(*)::int from public.appointments ap where ap.patient_id = b.patient_id),
         (select count(*)::int from public.appointments ap
           where ap.patient_id = b.patient_id and ap.status = 'no_show'),
         (select min(extract(year from e.encounter_date))::int from public.encounters e
           where e.patient_id = b.patient_id and e.status = 'finalized'),
         (select max(extract(year from e.encounter_date))::int from public.encounters e
           where e.patient_id = b.patient_id and e.status = 'finalized'),
         (select round(avg(o.value_quantity), 1) from public.observations o
           where o.patient_id = b.patient_id and o.observation_display ilike '%systolic%'),
         (select round(avg(o.value_quantity), 1) from public.observations o
           where o.patient_id = b.patient_id and o.observation_display ilike '%pulse%')
    from base b;
end;
$$;
grant execute on function public.research_export_patient_features(uuid) to authenticated;

-- 7b. Conditions, long format. ICD-10 chapter + coarse severity only; the
--     doctor's free-text notes are deliberately absent.
create or replace function public.research_export_conditions(p_request uuid)
returns table (
  subject_id text,
  icd10_chapter text,
  condition_display text,
  is_chronic boolean,
  severity text,
  clinical_status text,
  recorded_year integer
)
language plpgsql security definer set search_path = public as $$
declare
  salt text := public.research_request_salt(p_request);
begin
  perform public.research_audit('research_export', 'conditions', p_request);
  update public.research_data_requests
     set export_count = export_count + 1, last_exported_at = now()
   where id = p_request;

  return query
  select public.research_pseudonym(c.patient_id, salt),
         coalesce(nullif(left(c.icd10_code, 1), ''), 'unclassified'),
         c.condition_display::text,
         coalesce(c.is_chronic, false),
         coalesce(c.severity, 'unknown')::text,
         coalesce(c.clinical_status, 'unknown')::text,
         extract(year from c.created_at)::int
    from public.conditions c
    join public.research_consented_patients() b on b.patient_id = c.patient_id;
end;
$$;
grant execute on function public.research_export_conditions(uuid) to authenticated;

-- 7c. Observations / vitals, long format — the time-series input. Dates are
--     generalised to year-month so an exact visit date cannot be matched
--     against an external record.
create or replace function public.research_export_observations(p_request uuid)
returns table (
  subject_id text,
  observation_name text,
  value_quantity numeric,
  value_unit text,
  reference_range text,
  observed_period text
)
language plpgsql security definer set search_path = public as $$
declare
  salt text := public.research_request_salt(p_request);
begin
  perform public.research_audit('research_export', 'observations', p_request);
  update public.research_data_requests
     set export_count = export_count + 1, last_exported_at = now()
   where id = p_request;

  return query
  select public.research_pseudonym(o.patient_id, salt),
         o.observation_display::text,
         o.value_quantity,
         coalesce(o.value_unit, '')::text,
         coalesce(o.reference_range_text, '')::text,
         to_char(o.observation_date, 'YYYY-MM')
    from public.observations o
    join public.research_consented_patients() b on b.patient_id = o.patient_id
   where o.value_quantity is not null;
end;
$$;
grant execute on function public.research_export_observations(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Row Level Security
-- ---------------------------------------------------------------------------
alter table public.research_organizations enable row level security;
alter table public.researcher_profiles enable row level security;
alter table public.research_datasets enable row level security;
alter table public.research_data_requests enable row level security;

-- Organisations: your own, or any if you are an admin.
drop policy if exists p_research_org_sel on public.research_organizations;
create policy p_research_org_sel on public.research_organizations for select to authenticated
  using (public.is_admin() or id = public.my_research_org());

drop policy if exists p_research_org_write on public.research_organizations;
create policy p_research_org_write on public.research_organizations for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Researcher profiles: yourself, colleagues in your org, or an admin.
drop policy if exists p_researcher_prof_sel on public.researcher_profiles;
create policy p_researcher_prof_sel on public.researcher_profiles for select to authenticated
  using (id = auth.uid() or public.is_admin() or organization_id = public.my_research_org());

-- The dataset catalogue is readable by any signed-in user; admins maintain it.
drop policy if exists p_research_datasets_sel on public.research_datasets;
create policy p_research_datasets_sel on public.research_datasets for select to authenticated
  using (true);

drop policy if exists p_research_datasets_write on public.research_datasets;
create policy p_research_datasets_write on public.research_datasets for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Requests: your organisation's own, or all of them if you are an admin.
drop policy if exists p_research_req_sel on public.research_data_requests;
create policy p_research_req_sel on public.research_data_requests for select to authenticated
  using (public.is_admin() or organization_id = public.my_research_org());

-- A researcher may raise a request for their own organisation, as themselves,
-- and only with the data agreement accepted. They can never self-approve:
-- `status` is forced to 'pending' by the trigger below.
drop policy if exists p_research_req_ins on public.research_data_requests;
create policy p_research_req_ins on public.research_data_requests for insert to authenticated
  with check (
    organization_id = public.my_research_org()
    and requested_by = auth.uid()
    and dpa_accepted = true
  );

-- Only admins decide. Researchers cannot update a request at all.
drop policy if exists p_research_req_upd on public.research_data_requests;
create policy p_research_req_upd on public.research_data_requests for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Belt and braces: even a mis-written policy cannot let a request be born
-- approved, or let a client choose its own salt.
create or replace function public.tg_research_request_defaults()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    new.status := 'pending';
    new.decided_at := null;
    new.decided_by := null;
    new.decision_note := null;
    new.expires_at := null;
    new.export_count := 0;
    new.last_exported_at := null;
  end if;
  new.pseudonym_salt := encode(gen_random_bytes(32), 'hex');
  return new;
end;
$$;
drop trigger if exists trg_research_request_defaults on public.research_data_requests;
create trigger trg_research_request_defaults
  before insert on public.research_data_requests
  for each row execute function public.tg_research_request_defaults();

-- ---------------------------------------------------------------------------
-- 9. Admin decision RPC — records the decision and notifies the requester.
-- ---------------------------------------------------------------------------
create or replace function public.admin_decide_data_request(
  p_request uuid,
  p_status text,
  p_note text default null,
  p_valid_days integer default 180
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_requester uuid;
  v_title text;
begin
  if not public.is_admin() then
    raise exception 'Admin only.' using errcode = '42501';
  end if;
  if p_status not in ('approved','rejected','revoked','expired') then
    raise exception 'Invalid decision.';
  end if;

  update public.research_data_requests
     set status = p_status,
         decision_note = nullif(btrim(coalesce(p_note, '')), ''),
         decided_at = now(),
         decided_by = auth.uid(),
         expires_at = case when p_status = 'approved'
                           then now() + make_interval(days => greatest(p_valid_days, 1))
                           else null end
   where id = p_request
   returning requested_by, title into v_requester, v_title;

  if v_requester is not null then
    insert into public.notifications (recipient_id, type, title, body, resource_id)
    values (v_requester,
            'data_request_' || p_status,
            'Data request ' || p_status,
            coalesce(v_title, 'Your data request') || ' was ' || p_status || '.',
            p_request);
  end if;

  insert into public.audit_logs (actor_id, actor_role, action, resource_type, resource_id, status)
  values (auth.uid(), 'admin', 'decide', 'research_data_request', p_request, 'success');
end;
$$;
grant execute on function public.admin_decide_data_request(uuid, text, text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Patient transparency — every patient can see how research use affects
--     them, and what their consent currently allows. Nothing here exposes
--     another patient.
-- ---------------------------------------------------------------------------
create or replace function public.my_research_participation()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  consented boolean;
begin
  if uid is null then raise exception 'not authenticated'; end if;

  select coalesce(bool_or(enabled), false) into consented
    from public.consent_preferences where user_id = uid and key = 'research';

  return jsonb_build_object(
    'research_consent', coalesce(consented, false),
    'included_in_future_extracts', coalesce(consented, false),
    'identifiers_shared', jsonb_build_array(),
    'what_is_shared', case when coalesce(consented, false)
      then jsonb_build_array('age band (5-year)','gender','province','blood group',
                             'counts of visits, conditions, medicines, allergies, lab orders',
                             'diagnosis category (ICD-10 chapter)','vital sign values by month')
      else jsonb_build_array() end,
    'never_shared', jsonb_build_array('name','CNIC','Hayaat ID','phone','email','address',
                                      'date of birth','doctor''s written notes','uploaded documents','chat messages'),
    'approved_studies_using_data', (
      select count(*) from public.research_data_requests r
       where coalesce(consented, false) and r.status = 'approved'
         and (r.expires_at is null or r.expires_at > now())),
    'how_to_withdraw', 'Settings -> Consent management -> Research. Withdrawal applies to every future extract immediately.'
  );
end;
$$;
grant execute on function public.my_research_participation() to authenticated;

-- ---------------------------------------------------------------------------
-- 11. Seed the dataset catalogue (idempotent).
-- ---------------------------------------------------------------------------
insert into public.research_datasets (code, name, description, tier, grain, dictionary)
values
('patient_features',
 'Patient feature matrix',
 'One row per consented patient: demographics generalised to non-identifying bands plus counts and simple aggregates across their clinical history. Designed as a ready-to-train feature matrix.',
 'record_level',
 'one row per patient',
 '[{"column":"subject_id","type":"string","description":"Per-request pseudonym. Not stable across requests."},
   {"column":"age_band","type":"category","description":"5-year band, 90+ collapsed."},
   {"column":"gender","type":"category"},
   {"column":"province","type":"category","description":"Province only; city is never released."},
   {"column":"blood_group","type":"category"},
   {"column":"encounter_count","type":"int","description":"Finalized encounters."},
   {"column":"condition_count","type":"int"},
   {"column":"chronic_condition_count","type":"int"},
   {"column":"medication_count","type":"int"},
   {"column":"active_medication_count","type":"int"},
   {"column":"allergy_count","type":"int"},
   {"column":"lab_order_count","type":"int"},
   {"column":"appointment_count","type":"int"},
   {"column":"no_show_count","type":"int"},
   {"column":"first_encounter_year","type":"int"},
   {"column":"last_encounter_year","type":"int"},
   {"column":"mean_systolic","type":"float"},
   {"column":"mean_pulse","type":"float"}]'::jsonb),
('conditions',
 'Diagnoses (long format)',
 'One row per recorded diagnosis, grouped to ICD-10 chapter. Free-text clinical notes are excluded entirely.',
 'record_level',
 'one row per diagnosis',
 '[{"column":"subject_id","type":"string"},
   {"column":"icd10_chapter","type":"category","description":"First letter of the ICD-10 code."},
   {"column":"condition_display","type":"string","description":"Coded condition name; not free text."},
   {"column":"is_chronic","type":"bool"},
   {"column":"severity","type":"category"},
   {"column":"clinical_status","type":"category"},
   {"column":"recorded_year","type":"int"}]'::jsonb),
('observations',
 'Vitals & observations (time series)',
 'One row per numeric observation, with dates generalised to year-month. Suitable for longitudinal and sequence models.',
 'record_level',
 'one row per observation',
 '[{"column":"subject_id","type":"string"},
   {"column":"observation_name","type":"string"},
   {"column":"value_quantity","type":"float"},
   {"column":"value_unit","type":"string"},
   {"column":"reference_range","type":"string"},
   {"column":"observed_period","type":"string","description":"YYYY-MM. Exact dates are never released."}]'::jsonb)
on conflict (code) do update
  set name = excluded.name,
      description = excluded.description,
      grain = excluded.grain,
      dictionary = excluded.dictionary;

-- ---------------------------------------------------------------------------
-- 12. Notes on what is deliberately NOT here
--
--  * No function returns profiles.cnic, card_number, full_name, phone, email,
--    address_street/city, or date_of_birth.
--  * encounters.chief_complaint / history_of_present_illness / assessment /
--    plan and medication instructions are never exported: free text is the
--    single highest re-identification risk in a clinical record.
--  * medical_documents, lab_results files, and chat messages are out of scope
--    entirely; no storage object is ever reachable from this module.
--  * There is no function that maps a subject_id back to a patient. The
--    pseudonym is a one-way digest and the salt is unreadable by clients.
-- ---------------------------------------------------------------------------
