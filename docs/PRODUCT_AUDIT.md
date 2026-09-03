# HayaatID Product Audit

Audit date: 2026-07-13

## Executive summary

The application has a credible MVP structure: separate patient, staff, and admin clients share Supabase Auth, Postgres/RLS, Storage, and Realtime. Core role routing works in the live development project. It is not yet safe to call the deployed backend production-ready.

The largest blocker is deployment drift. The repository contains security hardening that the live Supabase project has not received: the automated RLS suite proved that a pending doctor can currently read a patient's encounter. The development database also contains seeded and ad-hoc test records, including duplicate and obviously synthetic clinics. A clean production project and a migration gate are required before real patient data is accepted.

## Live simulation results

| Flow | Result | Evidence / issue |
| --- | --- | --- |
| Admin login and dashboard | Pass | Role route, dashboard, notifications, users, approvals, clinics, deliveries, deletion queue, and audit navigation render. |
| Admin creates hospital + receptionist | Partially pass | One modal supports clinic/hospital creation and optional receptionist provisioning. Validation and duplicate prevention were added. Creation was not submitted to avoid adding more test data. |
| Doctor login and role routing | Pass | Doctor-only navigation and active-account gate work. |
| Doctor appointments | Fixed | The "Today's Appointments" page previously loaded every date. It now defaults to the local current date. |
| Patient lookup | Pass / fixed | Card-number lookup works and creates an audit entry. Internal "Scope §12.2" copy was removed. |
| Weekly availability | Fixed in client; migration pending | Live data contains a duplicate Monday slot. Zero-minute and duplicate additions are now rejected in the UI/service; database checks and a unique index are in `product_hardening.sql`. |
| Prescription authoring | Implemented; migration pending | Structured medication template now captures route, frequency/schedule, duration, and patient directions, shows a live prescription preview, and snapshots the doctor's professional footer at finalization. |
| Doctor professional footer | Implemented; migration pending | Doctor profile now configures signing name, qualifications, and registration/designation. This is explicitly described as a professional footer, not a handwritten or cryptographic signature. |
| Patient prescription display | Implemented; Flutter rebuild pending | Directions and the snapshotted professional footer are displayed with each prescription. |
| Lab worker queue | Pass | Role routing and lab-scoped queue render. The fake "upload" path that created a PDF filename without a file was removed; an actual PDF/image is now required. |
| Receptionist schedule | Pass / fixed | Defaults to today. Booking accepts a 16-digit Hayaat ID and rejects past dates. Reception cancellations now use `cancelled_by_clinic`. |
| Patient signup + OTP | Blocked for requested credentials | The current product password policy requires at least 8 characters with a letter and number; the requested five-character password is intentionally invalid and Supabase also rejects it. Signup additionally requires patient identity fields and a phone. The development OTP remains `11111`; real SMS is not wired. |
| RLS automated suite | Fail | 26 passed, 1 failed: a pending doctor could read patient encounters on the live backend. Apply the migrations before further testing. |

## Changes completed in this pass

- Removed prefilled/demo credentials from admin and staff login screens.
- Removed patient-profile fallbacks to `mockPatient`; missing authenticated data now fails explicitly.
- Added deterministic cleanup SQL for the legacy fixed demo identities, labs, and clinics.
- Added database constraints for weekly availability, medication duration, unique patient phone, and clinician double-booking.
- Added real-email patient authentication when an email is supplied and added email resolution to `login_email`.
- Added current-day filtering for doctor and receptionist schedules.
- Added receptionist Card Number search, future-time validation, and correct cancellation status.
- Added structured prescription authoring, preview, professional footer configuration, historical signature snapshots, and patient display.
- Removed fake lab result submissions without a file.
- Added clinic/hospital required-field, duplicate, and receptionist-password validation.

## Production blockers

### P0 — must fix before real patient data

1. **Live database is behind repository migrations.** Apply `security_hardening.sql` and `product_hardening.sql`, then rerun the RLS suite. A pending doctor currently has PHI access.
2. **RLS uses `is_staff()` too broadly.** Several clinical table policies treat doctor, lab worker, receptionist, and admin as equivalent. Receptionists should only see clinic scheduling demographics; lab workers should only see orders/results for their lab; doctors should require an active treatment/access relationship. Replace broad staff policies with role- and relationship-specific policies and tests.
3. **Development OTP is not identity verification.** `11111` is acceptable only for a development build. Production needs an SMS provider, expiry, attempt throttling, resend throttling, abuse monitoring, and no code displayed in UI/logs.
4. **Shared development backend and baked-in fallback keys.** Production builds must fail closed when environment configuration is missing and must use a separate Supabase project with backups, PITR, monitoring, and secret rotation.
5. **Development data is polluted.** The live project showed 12 patients, 10 clinics, exact duplicate hospitals, and synthetic names/addresses. Do not try to classify these as real data automatically. Create a clean production database; use `remove_demo_data.sql` only for the known fixed seeds.

### P1 — required for a reliable launch

1. **Booking does not yet enforce doctor availability.** The unique index stops double-booking, but booking must also verify day, time window, slot interval, clinic, active status, leave/closures, and timezone in a database transaction/RPC.
2. **Draft encounters are created on page load.** Navigating away leaves orphan drafts. Create on first clinical write, or add explicit discard and scheduled cleanup.
3. **Prescription safety is still basic.** Add medication catalogue/coded drug selection, unit validation, dose bounds, interaction/duplicate-therapy checks, pregnancy/renal/hepatic warnings, discontinue/amend workflows, and an immutable audit trail. Current substring allergy matching is not clinically sufficient.
4. **Lab result URLs are stored as one-year signed URLs.** Store the private object path and mint short-lived URLs on demand. Add virus scanning, MIME validation, size enforcement at storage policy level, and structured result validation.
5. **No server-side transaction across multi-step workflows.** Encounter finalization, booking + notifications, clinic + receptionist creation, and lab result + status changes can partially succeed. Move these to database functions or Edge Functions with transactional semantics/idempotency keys.
6. **Admin destructive/privileged actions need stronger controls.** Add MFA, step-up authentication, reason capture, dual approval for sensitive operations, session timeout, and complete audit coverage.
7. **Patient build was stale and Flutter tooling was unavailable in this environment.** Rebuild the patient web/mobile app from current source and rerun the full signup-to-prescription workflow after database migration.

### P2 — product quality and theme

1. Brand naming is now standardized around `HayaatID` in the legal/web copy; native package identifiers may still use legacy bundle IDs until a release-signing migration is planned.
2. Admin and staff duplicate large CSS files. Extract shared design tokens/components, then add visual regression tests at mobile/tablet/desktop breakpoints.
3. Add clear field labels/ARIA names everywhere, keyboard focus states, error summaries, contrast verification, reduced-motion support, and WCAG 2.1 AA testing.
4. Normalize date/time, phone and Hayaat ID formatting, capitalization, empty states, loading states, and mojibake/encoding checks.
5. Add product analytics and operational telemetry without sending PHI to third-party analytics.

## Release gate

Do not onboard real patients until all P0 items pass. Minimum automated gate:

1. Apply every migration to a clean staging project.
2. RLS suite passes for anonymous, patient, treating/non-treating doctor, pending/suspended doctor, receptionist in/out of clinic, lab worker in/out of lab, and admin.
3. Web builds, Flutter analyze/tests, migration smoke test, and end-to-end role workflows pass in CI.
4. Restore test, backup/PITR test, incident runbook, privacy/legal review, and clinical safety review are complete.
