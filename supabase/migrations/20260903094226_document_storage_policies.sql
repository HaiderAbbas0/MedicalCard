-- Storage and medical_documents policies from product_hardening.sql.
--
-- These could never take effect on the deployed project: every one of them
-- calls clinical_staff_can_access_patient(), which did not exist there until
-- FINALIZE.sql was applied. The live medical_documents policy was still the
-- older is_staff() version, which let a receptionist read uploaded clinical
-- documents (caught by supabase/tests/rls.test.mjs).
drop policy if exists p_labresults_read on storage.objects;
drop policy if exists p_labresults_write on storage.objects;
create policy p_labresults_read on storage.objects for select to authenticated
  using (
    bucket_id = 'lab-results'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.clinical_staff_can_access_patient((storage.foldername(name))[1]::uuid))
  );
create policy p_labresults_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'lab-results'
    and exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid()
    )
  );

drop policy if exists p_medicaldocs_read on storage.objects;
drop policy if exists p_medicaldocs_write on storage.objects;
create policy p_medicaldocs_read on storage.objects for select to authenticated
  using (
    bucket_id = 'medical-documents'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.clinical_staff_can_access_patient((storage.foldername(name))[1]::uuid))
  );
create policy p_medicaldocs_write on storage.objects for insert to authenticated
  with check (bucket_id = 'medical-documents' and public.is_staff());

drop policy if exists "patient reads own medical documents" on public.medical_documents;
drop policy if exists "patient or staff uploads medical documents" on public.medical_documents;
drop policy if exists "document uploader maintains metadata" on public.medical_documents;
drop policy if exists p_medical_documents_sel on public.medical_documents;
drop policy if exists p_medical_documents_ins on public.medical_documents;
drop policy if exists p_medical_documents_upd on public.medical_documents;
create policy p_medical_documents_sel on public.medical_documents for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id) or uploaded_by = auth.uid());
create policy p_medical_documents_ins on public.medical_documents for insert to authenticated
  with check (
    patient_id = auth.uid()
    or public.is_admin()
    or (public.my_role() = 'doctor' and doctor_id = auth.uid() and uploaded_by = auth.uid())
    or (
      public.my_role() = 'lab_worker'
      and uploaded_by = auth.uid()
      and exists (
        select 1 from public.lab_worker_profiles lwp
        join public.lab_orders lo on lo.lab_id = lwp.lab_id
        where lwp.id = auth.uid() and lo.patient_id = medical_documents.patient_id
      )
    )
  );
create policy p_medical_documents_upd on public.medical_documents for update to authenticated
  using (patient_id = auth.uid() or uploaded_by = auth.uid() or public.is_admin())
  with check (patient_id = auth.uid() or uploaded_by = auth.uid() or public.is_admin());
