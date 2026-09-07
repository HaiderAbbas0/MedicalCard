# HayaatID Operations Runbook

Version: 2026-07-13

## Pre-production gate

Run these checks before deploying any patient/staff/admin/research build:

1. `powershell -ExecutionPolicy Bypass -File scripts/check-production-env.ps1`
2. `npm --prefix web-staff run build`
3. `npm --prefix web-admin run build`
4. `npm --prefix web-research run build`
5. `npm --prefix supabase/tests test` with:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
6. `node supabase/tests/verify_research_privacy.mjs` — the research privacy suite (41 assertions; 41/41 on the development project).
7. Flutter machine only: `flutter analyze`, `flutter test`, and the target build command.

Do not deploy if the RLS suite fails, if the research privacy suite fails, or if the production app still uses dev OTP behavior.

## Monitoring

Monitor these signals daily during MVP rollout and alert immediately in production:

- Supabase Auth: signup failures, OTP/send failures, unusual login failures.
- Database: failed Edge Function account deletions, RLS errors, duplicate appointment attempts, slow queries.
- Storage: upload failures, private bucket policy denials, unexpectedly public buckets.
- Product flow: appointment request volume, doctor confirmation lag, lab result upload/release lag.
- Security/compliance: audit log insert failures, admin login spikes, deletion request failures.
- Research platform: `research_data_requests` waiting in `pending`, export volume per organisation, approvals nearing `expires_at`, and any research query or export from an organisation that is not `active`.

Recommended alert thresholds:

- Any account deletion request in `failed` for more than 30 minutes.
- More than 5 upload failures in 10 minutes.
- Any public health-document bucket in production.
- Doctor confirmation median time over 24 hours.
- Lab order in `resulted` but not `released_to_patient` for more than 72 hours.
- Any data request in `pending` for more than 14 days.
- An approved data request within 14 days of `expires_at` and still being exported.

## Backups and restore

- Enable Supabase Point-in-Time Recovery for production.
- Schedule daily logical backups for core tables: `profiles`, role extension tables, `appointments`, clinical tables, `medical_documents`, `cards`, compliance tables, `audit_logs`, and the research tables (`research_organizations`, `researcher_profiles`, `research_datasets`, `research_data_requests`).
- Back up `research_request_secrets` with the same protection as production secrets, and never restore it into a non-production project. It holds the per-request pseudonym salts; leaking them would make previously issued extracts linkable.
- Keep storage bucket backups for `medical-documents`, `lab-results`, and `card-photos`.
- Test restore monthly into a separate non-production project.
- After restore, run the dynamic RLS suite before exposing the environment.

## Deployment checklist

1. Apply SQL migrations in order:
   - Base project: `supabase/schema.sql`
   - Incremental hardening: `supabase/product_hardening.sql`
   - Other feature migrations as needed.
   - Last: `supabase/research_platform.sql`, after `supabase/clinical_narrative_rls.sql`.
2. Confirm all health-document buckets are private.
3. Confirm Edge Function secrets are set:
   - `SUPABASE_URL`
   - service-role key
   - production OTP provider variables when OTP step is allowed.
4. Build staff/admin/research portals.
5. Build Flutter app on a machine with Flutter installed.
6. Run live smoke test:
   - signup
   - OTP
   - card/Hayaat ID
   - appointment request
   - doctor confirmation
   - encounter/prescription
   - lab order/result upload
   - doctor release
   - patient record viewing
   - admin deletion request and erasure.

## Research data platform

Approved external organisations query de-identified, consent-gated data through the research portal (`web-research`). Researchers hold `role = 'researcher'` and are deliberately not staff: `is_staff()` excludes them, so every clinical RLS policy already denies them, and their only route to data is the SECURITY DEFINER `research_*` functions.

### Onboard a research organisation

1. Admin portal → **Research Orgs** (`/research-orgs`). New organisations arrive in `pending`.
2. Verify the registration number, contact email, and that the data agreement is signed (`dpa_accepted_at`). The approve dialog warns when it is not.
3. Approve the organisation. Its status becomes `active`; only then does `my_research_org()` resolve for its researchers.
4. Create the researcher account. Self-service signup is clamped to patient/doctor, so it cannot mint a `researcher` — use `node supabase/tests/seed_research_account.mjs` for a demo account, or the same pattern in production: create the auth user, then promote the profile to `researcher` and link it to the organisation in SQL.
5. Confirm the researcher can sign in to the research portal and see the dataset catalogue. Approval of the organisation alone grants no row-level data — that still requires an approved data request.

### Review a data request

1. Admin portal → **Data Requests** (`/data-requests`). Researchers can only insert requests for their own organisation, as themselves, with the data agreement accepted; a trigger forces `status = 'pending'`, so no one can self-approve.
2. Check the stated purpose, the dataset requested, and that it is proportionate. Nothing here releases direct identifiers or clinical free text — but a narrow request is still a re-identification risk, which is why aggregates below the k-anonymity threshold of 5 are suppressed.
3. Approve with an access period (**Access valid for (days)**, default 180). `admin_decide_data_request()` sets `expires_at = now() + the period`. Expiry is enforced in the database: once past `expires_at`, `research_request_salt()` refuses and every export for that request fails. No client action is needed to end access.
4. Reject or revoke with a reason. Revocation clears `expires_at` and takes effect on the next call. The requester is notified either way, and the decision is written to `audit_logs` as action `decide` on `research_data_request`.
5. Each approved request gets its own random pseudonym salt in `research_request_secrets`. Extracts from two requests are therefore unlinkable, so re-approving a lapsed request issues a new subject id space rather than continuing the old one.

### Cut an organisation off immediately

Suspend the organisation — Admin portal → **Research Orgs** → **Suspend**, with a reason.

`my_research_org()` resolves only for an organisation whose status is `active`. Suspending it therefore stops that organisation's researchers at once: their aggregate queries return nothing, their exports fail the ownership check in `research_request_salt()`, and they lose visibility of their own requests. This is the fastest containment action and needs no per-request revocation and no account changes.

Follow it with:

1. Revoke the organisation's approved data requests, so access does not resume if the organisation is later reactivated.
2. Suspend or disable the individual researcher accounts if the incident concerns a person rather than the organisation (`is_researcher()` also requires `profiles.status = 'active'`).
3. Audit what was taken before the cut-off, using the queries below.
4. Record the reason in `research_organizations.status_reason`; the admin portal writes it from the suspend dialog.

Reactivation is the same page: set the organisation back to `active` only after the incident is closed and the data agreement position is confirmed.

### Audit research access

Every aggregate query and every row-level export writes to `audit_logs` with `actor_role = 'researcher'`:

- Action `research_query` — aggregate reads. `resource_type` is `cohort_summary`, `cohort_size`, or `condition_prevalence`; `resource_id` is null.
- Action `research_export` — row-level extracts. `resource_type` is `patient_features`, `conditions`, or `observations`, and `resource_id` is the data request id, so every exported row set ties back to an approved request and its decision.
- Action `decide` on `research_data_request` — the admin decision, with `actor_id` of the deciding admin.

For an access review, pull `research_export` entries for the period, join `resource_id` to `research_data_requests` and confirm each one was `approved`, unexpired, and belonged to an `active` organisation at the time. An export with no matching approved request should not exist; treat one as an incident.

Consent is checked at query time, never from a snapshot, so a patient who withdraws the `research` consent preference drops out of every subsequent query and export immediately. Withdrawal does not retract extracts already delivered — that is a data-agreement matter, not a database one.

## Incident notes

- Failed deletion: inspect `deletion_requests.status = 'failed'`, Edge Function logs, and storage removal logs. Retry only after confirming the user is not partially erased.
- Upload incident: verify bucket privacy, object path ownership, and `medical_documents.file_paths` consistency.
- Booking incident: check `available_appointment_slots`, doctor availability rows, and the `appointments_unique_doctor_time` index.
- Research access incident: suspend the organisation first (this stops queries and exports immediately), then revoke its approved requests and review `audit_logs` for `research_query` / `research_export` entries. Re-run `node supabase/tests/verify_research_privacy.mjs` before restoring access.
