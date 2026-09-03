-- ===========================================================================
-- Keep the doctor's clinical narrative away from the laboratory.
--
-- `clinical_staff_can_access_patient()` grants a lab worker access to any
-- patient their lab holds an order for. That is right for the lab workflow --
-- they must read the order and write the result -- but the same helper was
-- also guarding encounters, diagnoses, prescriptions, vitals and allergies,
-- so a lab technician could read the chief complaint, assessment, plan and
-- full medication history of every patient whose sample crossed their bench.
--
-- The prototype scope has the lab working from a queue with the patient's
-- identity masked; it never asks the lab to see the consultation notes.
--
-- This file adds a narrower helper for the narrative tables. The lab keeps
-- exactly what it needs: lab_orders, lab_results, and the lab-results storage
-- folder, all still gated by clinical_staff_can_access_patient().
--
-- Run after product_hardening.sql. Safe to re-run.
-- ===========================================================================

create or replace function public.narrative_staff_can_access_patient(p_patient uuid)
  returns boolean language sql security definer stable set search_path = public as
$fn$
  select case
    when auth.uid() = p_patient then true
    when public.my_role() = 'admin' then true
    -- Treating doctors only. Receptionists (demographics) and lab workers
    -- (specimen workflow) are deliberately excluded.
    when public.my_role() = 'doctor' then exists (
      select 1 from public.appointments a
      where a.patient_id = p_patient
        and a.doctor_id = auth.uid()
        and a.status not in ('cancelled_by_patient','cancelled_by_clinic')
      union all
      select 1 from public.encounters e
      where e.patient_id = p_patient and e.doctor_id = auth.uid()
    )
    else false
  end
$fn$;

revoke all on function public.narrative_staff_can_access_patient(uuid) from public;
grant execute on function public.narrative_staff_can_access_patient(uuid) to authenticated;

comment on function public.narrative_staff_can_access_patient(uuid) is
  'Read access to consultation narrative and prescribing history: the patient, an admin, or a doctor with a care relationship. Excludes lab workers and receptionists.';

-- ---------------------------------------------------------------------------
-- Repoint the narrative tables. Write policies are untouched.
-- ---------------------------------------------------------------------------
drop policy if exists p_enc_sel on public.encounters;
create policy p_enc_sel on public.encounters for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));

drop policy if exists p_cond_sel on public.conditions;
create policy p_cond_sel on public.conditions for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));

drop policy if exists p_med_sel on public.medication_requests;
create policy p_med_sel on public.medication_requests for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));

drop policy if exists p_obs_sel on public.observations;
create policy p_obs_sel on public.observations for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));

drop policy if exists p_alg_sel on public.allergies;
create policy p_alg_sel on public.allergies for select to authenticated
  using (patient_id = auth.uid() or public.narrative_staff_can_access_patient(patient_id));
