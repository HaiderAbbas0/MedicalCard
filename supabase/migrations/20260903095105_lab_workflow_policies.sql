-- Lab workflow policies from product_hardening.sql.
--
-- Live, p_lo_sel and p_lr_sel still used staff_can_access_patient(), the loose
-- helper that grants a receptionist access to any patient they have booked an
-- appointment for. That let the front desk read clinical lab orders and
-- results. Like the document policies, this block could never have been
-- applied before, because clinical_staff_can_access_patient() did not exist on
-- the deployed project until FINALIZE.sql.
--
-- Doctors (care relationship), lab workers (their own lab) and admins keep
-- their access; the patient keeps their own rows.
drop policy if exists p_lo_sel on public.lab_orders;
create policy p_lo_sel on public.lab_orders for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_lo_write on public.lab_orders;
create policy p_lo_write on public.lab_orders for all to authenticated
  using (
    ordering_doctor_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid() and lwp.lab_id = lab_orders.lab_id
    )
  )
  with check (
    ordering_doctor_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid() and lwp.lab_id = lab_orders.lab_id
    )
  );

drop policy if exists p_lr_sel on public.lab_results;
create policy p_lr_sel on public.lab_results for select to authenticated
  using (patient_id = auth.uid() or public.clinical_staff_can_access_patient(patient_id));
drop policy if exists p_lr_write on public.lab_results;
create policy p_lr_write on public.lab_results for all to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid() and lwp.lab_id = lab_results.lab_id
    )
  )
  with check (
    public.is_admin()
    or exists (
      select 1 from public.lab_worker_profiles lwp
      where lwp.id = auth.uid() and lwp.lab_id = lab_results.lab_id
    )
  );
