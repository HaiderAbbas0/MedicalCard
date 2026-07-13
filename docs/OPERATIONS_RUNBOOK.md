# HayaatID Operations Runbook

Version: 2026-07-13

## Pre-production gate

Run these checks before deploying any patient/staff/admin build:

1. `powershell -ExecutionPolicy Bypass -File scripts/check-production-env.ps1`
2. `npm --prefix web-staff run build`
3. `npm --prefix web-admin run build`
4. `npm --prefix supabase/tests test` with:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
5. Flutter machine only: `flutter analyze`, `flutter test`, and the target build command.

Do not deploy if the RLS suite fails or if the production app still uses dev OTP behavior.

## Monitoring

Monitor these signals daily during MVP rollout and alert immediately in production:

- Supabase Auth: signup failures, OTP/send failures, unusual login failures.
- Database: failed Edge Function account deletions, RLS errors, duplicate appointment attempts, slow queries.
- Storage: upload failures, private bucket policy denials, unexpectedly public buckets.
- Product flow: appointment request volume, doctor confirmation lag, lab result upload/release lag.
- Security/compliance: audit log insert failures, admin login spikes, deletion request failures.

Recommended alert thresholds:

- Any account deletion request in `failed` for more than 30 minutes.
- More than 5 upload failures in 10 minutes.
- Any public health-document bucket in production.
- Doctor confirmation median time over 24 hours.
- Lab order in `resulted` but not `released_to_patient` for more than 72 hours.

## Backups and restore

- Enable Supabase Point-in-Time Recovery for production.
- Schedule daily logical backups for core tables: `profiles`, role extension tables, `appointments`, clinical tables, `medical_documents`, `cards`, compliance tables, and `audit_logs`.
- Keep storage bucket backups for `medical-documents`, `lab-results`, and `card-photos`.
- Test restore monthly into a separate non-production project.
- After restore, run the dynamic RLS suite before exposing the environment.

## Deployment checklist

1. Apply SQL migrations in order:
   - Base project: `supabase/schema.sql`
   - Incremental hardening: `supabase/product_hardening.sql`
   - Other feature migrations as needed.
2. Confirm all health-document buckets are private.
3. Confirm Edge Function secrets are set:
   - `SUPABASE_URL`
   - service-role key
   - production OTP provider variables when OTP step is allowed.
4. Build staff/admin portals.
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

## Incident notes

- Failed deletion: inspect `deletion_requests.status = 'failed'`, Edge Function logs, and storage removal logs. Retry only after confirming the user is not partially erased.
- Upload incident: verify bucket privacy, object path ownership, and `medical_documents.file_paths` consistency.
- Booking incident: check `available_appointment_slots`, doctor availability rows, and the `appointments_unique_doctor_time` index.
