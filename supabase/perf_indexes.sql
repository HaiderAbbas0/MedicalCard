-- ============================================================================
-- perf_indexes.sql — Phase-3 performance: indexes on the foreign-key / filter
-- columns that RLS policies and app queries actually use. Without these, every
-- "my records" / "this patient's records" / "this lab's queue" query is a full
-- table scan. Run any time; idempotent (create index if not exists).
-- ============================================================================

-- Appointments — patient view, doctor day view, clinic schedule.
create index if not exists idx_appointments_patient       on public.appointments (patient_id);
create index if not exists idx_appointments_doctor_date    on public.appointments (doctor_id, appointment_date);
create index if not exists idx_appointments_clinic_date    on public.appointments (clinic_id, appointment_date);

-- Encounters — patient timeline, doctor's encounters.
create index if not exists idx_encounters_patient          on public.encounters (patient_id);
create index if not exists idx_encounters_doctor           on public.encounters (doctor_id);
create index if not exists idx_encounters_appointment      on public.encounters (appointment_id);

-- Clinical children — joined by encounter, filtered by patient.
create index if not exists idx_conditions_encounter        on public.conditions (encounter_id);
create index if not exists idx_conditions_patient          on public.conditions (patient_id);
create index if not exists idx_medreq_encounter            on public.medication_requests (encounter_id);
create index if not exists idx_medreq_patient_status       on public.medication_requests (patient_id, status);
create index if not exists idx_observations_encounter      on public.observations (encounter_id);
create index if not exists idx_observations_patient        on public.observations (patient_id);
create index if not exists idx_allergies_patient           on public.allergies (patient_id);

-- Lab workflow — patient results, lab queue (by lab + status), doctor review.
create index if not exists idx_lab_orders_patient          on public.lab_orders (patient_id);
create index if not exists idx_lab_orders_lab_status       on public.lab_orders (lab_id, status);
create index if not exists idx_lab_orders_encounter        on public.lab_orders (encounter_id);
create index if not exists idx_lab_orders_doctor           on public.lab_orders (ordering_doctor_id);
create index if not exists idx_lab_results_patient         on public.lab_results (patient_id);

-- Doctor availability — by doctor, by clinic.
create index if not exists idx_availability_doctor         on public.doctor_availability (doctor_id);
create index if not exists idx_availability_clinic         on public.doctor_availability (clinic_id);

-- Notifications — the recipient's unread-first list (bell + patient notifications).
create index if not exists idx_notifications_recipient     on public.notifications (recipient_id, is_read, created_at desc);

-- Audit log — admin review (recent first) and per-actor / per-patient lookups.
create index if not exists idx_audit_timestamp             on public.audit_logs ("timestamp" desc);
create index if not exists idx_audit_actor                 on public.audit_logs (actor_id);
create index if not exists idx_audit_patient               on public.audit_logs (patient_id);

-- Profiles — admin user list filters + signup phone lookup.
create index if not exists idx_profiles_role_status        on public.profiles (role, status);
create index if not exists idx_profiles_phone              on public.profiles (phone_primary);

-- Role-extended profiles — clinic / lab scoping.
create index if not exists idx_doctor_profiles_clinic      on public.doctor_profiles (clinic_id);
create index if not exists idx_lab_worker_profiles_lab     on public.lab_worker_profiles (lab_id);
create index if not exists idx_receptionist_profiles_clinic on public.receptionist_profiles (clinic_id);

-- Medication adherence logs.
create index if not exists idx_medication_logs_patient     on public.medication_logs (patient_id);
create index if not exists idx_medication_logs_medication  on public.medication_logs (medication_id);
