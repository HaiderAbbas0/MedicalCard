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
| Research portal login and routing | Pass | `web-research` (port 5175 in dev) signs in a `researcher` and routes to the catalogue, cohort explorer, requests, downloads, and compliance pages. Researchers are not staff — `is_staff()` excludes them, so existing clinical RLS denies them outright. |
| Research cohort explorer and aggregates | Pass | `research_cohort_size`, `research_cohort_summary`, and `research_condition_prevalence` return only consented patients and suppress any cell below the k-anonymity threshold of 5. Withdrawing consent drops the numbers on the next query, because the consent check is at query time rather than from a snapshot. |
| Research exports | Pass | `research_export_patient_features`, `research_export_conditions`, and `research_export_observations` require an approved, unexpired request belonging to the caller's active organisation. Pseudonyms are salted per request, so two extracts cannot be linked. No direct identifiers or clinical free text are released. |
| Admin research org and data request review | Pass | Admin portal gains "Research Orgs" (`/research-orgs`) and "Data Requests" (`/data-requests`). Approve/reject/suspend an organisation; approve with an access period, reject, or revoke a request via `admin_decide_data_request`. A trigger forces new requests to `pending`, so a researcher cannot self-approve. |
| Research privacy suite | Pass | `node supabase/tests/verify_research_privacy.mjs` — 41 of 41 assertions pass against the development project. It signs in as a real researcher through the public API and attempts, in good faith, to reach data it should not. |

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
- Added the research data platform: `supabase/research_platform.sql` (organisations, researcher profiles, dataset catalogue, data requests, per-request pseudonym salts in `research_request_secrets` with RLS on and no policies), the `researcher` role, the `research_*` SECURITY DEFINER functions, `admin_decide_data_request`, and `my_research_participation` for patient transparency.
- Added the `web-research` portal (Vite, port 5175 in dev) and the admin "Research Orgs" and "Data Requests" pages.
- Added research seeding and verification scripts: `seed_research_account.mjs`, `seed_research_consent.mjs` (uses the patient app's own `set_consent_preference` RPC; `--off` withdraws), and `verify_research_privacy.mjs`.

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
8. **The privacy suite is outside the CI gate.** `web-research` is now in the `ci.yml` build matrix and `dependabot.yml`, so it is typechecked and patched alongside the other portals. `verify_research_privacy.mjs` still runs manually: it needs a seeded researcher account and an approved request in the target project. Wire it in beside the RLS suite so the privacy guarantees are enforced on every push, not on demand.
9. **Researcher provisioning is manual.** Self-service signup cannot mint a `researcher`, so promotion is done by pasting generated SQL. That is correct as a safety property but needs an audited admin path before onboarding real organisations, along with a signed data agreement recorded outside the `dpa_accepted_at` flag.

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
4. Research privacy suite passes (`verify_research_privacy.mjs`), and no research organisation is `active` without a signed data agreement.
5. Restore test, backup/PITR test, incident runbook, privacy/legal review, and clinical safety review are complete.
