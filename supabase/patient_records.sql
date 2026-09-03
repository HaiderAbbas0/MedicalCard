-- Specialty-first patient record library and durable original-document storage.
-- Run after hayaat_id_only.sql. Safe to re-run.

alter table public.lab_results
  add column if not exists result_file_path text;

create table if not exists public.medical_documents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  uploaded_by uuid references public.profiles(id),
  doctor_id uuid references public.profiles(id),
  clinic_id uuid references public.clinics(id),
  encounter_id uuid references public.encounters(id) on delete set null,
  specialty text not null default 'General Medicine',
  record_type text not null default 'other' check (record_type in (
    'prescription', 'laboratory', 'imaging', 'medical_certificate',
    'discharge_summary', 'procedure_note', 'vaccination', 'referral',
    'consultation', 'clinical_note', 'vital_signs', 'diagnosis',
    'medication_history', 'allergy', 'chronic_disease', 'follow_up', 'other'
  )),
  title text not null,
  record_date date not null default current_date,
  facility_name text,
  doctor_name text,
  notes text,
  file_paths text[] not null default '{}',
  file_names text[] not null default '{}',
  mime_types text[] not null default '{}',
  extracted_metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint medical_documents_file_metadata_lengths check (
    cardinality(file_names) in (0, cardinality(file_paths)) and
    cardinality(mime_types) in (0, cardinality(file_paths))
  )
);

create index if not exists medical_documents_patient_specialty_date_idx
  on public.medical_documents(patient_id, specialty, record_date desc);
create index if not exists medical_documents_encounter_idx
  on public.medical_documents(encounter_id) where encounter_id is not null;

alter table public.medical_documents enable row level security;

drop policy if exists "patient reads own medical documents" on public.medical_documents;
create policy "patient reads own medical documents"
  on public.medical_documents for select
  using (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or uploaded_by = auth.uid()
    or public.my_role() = 'admin'
  );

drop policy if exists "patient or staff uploads medical documents" on public.medical_documents;
create policy "patient or staff uploads medical documents"
  on public.medical_documents for insert
  with check (
    patient_id = auth.uid()
    or (
      public.my_role() in ('doctor', 'lab_worker', 'admin')
      and uploaded_by = auth.uid()
    )
  );

drop policy if exists "document uploader maintains metadata" on public.medical_documents;
create policy "document uploader maintains metadata"
  on public.medical_documents for update
  using (
    patient_id = auth.uid()
    or (public.my_role() in ('doctor', 'lab_worker', 'admin') and uploaded_by = auth.uid())
  )
  with check (
    patient_id = auth.uid()
    or (public.my_role() in ('doctor', 'lab_worker', 'admin') and uploaded_by = auth.uid())
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'medical-documents',
  'medical-documents',
  false,
  52428800,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'application/dicom']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "medical document owner or staff reads files" on storage.objects;
create policy "medical document owner or staff reads files"
  on storage.objects for select
  using (
    bucket_id = 'medical-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
          from public.medical_documents document
         where name = any (document.file_paths)
           and (
             document.doctor_id = auth.uid()
             or document.uploaded_by = auth.uid()
             or public.my_role() = 'admin'
           )
      )
    )
  );

drop policy if exists "medical document owner or staff uploads files" on storage.objects;
create policy "medical document owner or staff uploads files"
  on storage.objects for insert
  with check (
    bucket_id = 'medical-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.my_role() in ('doctor', 'lab_worker', 'admin')
    )
  );

grant select, insert, update on public.medical_documents to authenticated;
