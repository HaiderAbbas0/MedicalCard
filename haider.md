# HayaatID Session Change Log

This file summarizes the product-hardening work completed in this session. Step 10 from the audit, real OTP/email delivery replacement, was intentionally not implemented per request; the dev OTP flow remains unchanged.

## Backend and Database

- Added stricter active-role helpers in `supabase/product_hardening.sql`: `my_role()`, `is_staff()`, `is_admin()`, and `staff_can_access_patient()`.
- Replaced broad "any staff can access all clinical records" policies with owner, admin, or care-team-based RLS for appointments, encounters, diagnoses, medications, vitals, allergies, lab orders, lab results, patient profiles, and medical documents.
- Hardened doctor availability:
  - removes duplicate weekly slots,
  - removes invalid zero/negative-duration slots,
  - enforces valid day/window/duration constraints,
  - enforces unique doctor/day/start/end/duration slots.
- Kept appointment double-booking protection through the unique doctor/date/time index for non-cancelled appointments.
- Made storage buckets private for `lab-results`, `card-photos`, and `medical-documents`.
- Added signed/private storage policies for card photos, lab result files, and uploaded medical documents.
- Fixed `supabase/cards.sql` so `request_card()` accepts `p_name_en` as used by the app, stores the English name, and creates the card photo bucket as private.
- Added current consent preferences with `consent_preferences` and the `set_consent_preference()` RPC.
- Expanded `export_my_data()` to include medical documents, messages/conversations, consent preferences, and audit logs related to the caller.
- Added `admin_mark_deletion_request()` for admin-side deletion request state changes.
- Changed deletion request retention so requests are not erased when the profile is deleted; `user_id` now uses `on delete set null`.
- Made `supabase/chat.sql` non-destructive by removing `drop table` resets and using `create table if not exists` plus safe column additions.
- Updated the `delete-account` Edge Function to remove private storage folders, mark admin deletion requests completed, delete the profile/auth user, and write an audit log.

## Patient Portal

- Added patient self-booking inside `My appointments`:
  - doctor/specialty search,
  - doctor selection,
  - live weekly availability display,
  - matching date picker,
  - notes for doctor,
  - appointment request submission.
- Replaced fake report download behavior with navigation to the actual record viewer when the original lab report exists.
- Replaced fake visit prescription download behavior with navigation to the structured prescription record when available.
- Wired consent switches to the backend preference RPC instead of only local `SharedPreferences`.
- Added real password-reset request flow from the login screen using Supabase Auth, while leaving OTP behavior unchanged.
- Made SOS call action open the phone dialer with `tel:1122`.
- Changed card photo handling so uploads store private object paths and card reads resolve signed URLs for display.
- Improved text contrast by darkening/lightening tertiary theme colors for WCAG-friendly readability.
- Updated patient-facing package description to HayaatID.

## Staff Portal

- Added doctor-side medical document upload from the patient record page:
  - specialty,
  - record type,
  - record date,
  - title,
  - notes,
  - PDF/image/DICOM file upload.
- Added `doctorApi.uploadMedicalDocument()` to upload the file to `medical-documents`, insert the metadata row, and notify the patient.
- The uploaded documents feed the existing patient specialty-folder record viewer automatically.
- Staff portal builds successfully after these changes.

## Admin Portal

- Changed deletion request completion so it calls the `delete-account` Edge Function instead of only updating a status.
- Admin deletion updates now use `admin_mark_deletion_request()` where available, with a safe fallback for older databases.
- Admin portal builds successfully after these changes.

## Tests and CI

- Updated the Flutter widget smoke test to expect HayaatID branding instead of stale Sehat branding.
- Changed the Supabase RLS test suite so it no longer depends on the removed demo project/users by default. It now skips cleanly unless `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `DEMO_PASSWORD` are provided.
- Verified:
  - `web-staff npm run build` passes.
  - `web-admin npm run build` passes.
  - `supabase/tests npm test` exits cleanly and explains how to enable live RLS checks.
- Not verified locally:
  - Flutter analyze/test/build, because `flutter` is not available on this shell PATH. CI should still run `flutter pub get`, `flutter analyze`, and `flutter test`.

## Important Notes for Developers

- Run database migrations in order, including `patient_records.sql`, `hayaat_id_only.sql`, and the updated `product_hardening.sql`.
- Deploy the updated `delete-account` Edge Function before using admin deletion completion in production.
- Configure Supabase Auth password reset redirect/email templates before relying on the new forgot-password flow.
- Real OTP/email delivery was intentionally skipped and remains dev-phase behavior.
- The worktree already contained many prior MVP-to-product changes before this pass; this file focuses on the additional hardening and integration completed in this session.

## Additional Hardening Completed on 2026-07-13

### Deletion workflow

- Updated `supabase/functions/delete-account/index.ts` so deletion requests move to `processing` first, only become `completed` after storage cleanup, profile deletion, auth deletion, and audit logging succeed, and become `failed` when destructive deletion fails.
- Updated `supabase/product_hardening.sql`, `supabase/compliance.sql`, `web-admin/src/api/types.ts`, `web-admin/src/api/admin.ts`, and `web-admin/src/pages/DeletionRequestsPage.tsx` so admin deletion supports the new `failed` state and the UI action is clearly an account erasure action.

### Baseline schema and RLS

- Repaired `supabase/schema.sql` so a fresh install includes `profiles.card_number`, the `gen_card_number()` helper, private storage constraints, booking indexes, and the same hardening direction as incremental migrations.
- Split patient access helpers:
  - `staff_can_access_patient()` remains suitable for demographics and appointment workflows.
  - `clinical_staff_can_access_patient()` is used for clinical records and document storage.
- Updated clinical table policies and storage/document policies so receptionists can support booking/demographics but cannot browse encounters, lab results, or uploaded medical documents.
- Updated `supabase/product_hardening.sql` with the same helper split and Hayaat ID bootstrap for existing databases.

### Dynamic RLS tests

- Replaced the old fixture/demo-user RLS suite in `supabase/tests/rls.test.mjs`.
- New suite creates throwaway users, clinic, lab, appointment, encounter, lab order/result, medical document, and audit row with the service-role key, then signs in as real users and checks:
  - anonymous users cannot read profiles,
  - patients only see their own data,
  - doctors only see assigned patients,
  - pending doctors are blocked,
  - receptionists can see booked demographics but not clinical records/documents,
  - lab workers only see assigned lab workflow,
  - admins can read audit logs.
- The suite skips cleanly when Supabase env vars are not set.

### Booking polish

- Added database RPCs in `supabase/schema.sql` and `supabase/product_hardening.sql`:
  - `available_appointment_slots(p_doctor, p_date)`
  - `request_patient_appointment(...)`
  - `book_clinic_appointment(...)`
- These generate bookable appointment times from doctor availability, exclude taken slots, enforce future booking, respect clinic/doctor hours, and use the unique doctor/date/time index as final protection.
- Updated `lib/services/patient_service.dart` and `lib/screens/patient/appointments_screen.dart` so patient booking uses generated open slots instead of raw weekly windows.
- Added a 24-hour patient cancellation guard for pending/confirmed appointments.
- Updated `web-staff/src/api/reception.ts` and `web-staff/src/pages/reception/SchedulePage.tsx` so receptionist booking also uses generated open slots and the booking RPC.

### Document upload improvements

- Updated `web-staff/src/api/doctor.ts` and `web-staff/src/pages/doctor/PatientRecordPage.tsx`:
  - supports multiple files per medical document,
  - validates up to 10 files,
  - enforces 25 MB per file,
  - allows PDF/image/DICOM originals,
  - records clearer ownership metadata,
  - removes already uploaded objects if metadata insert fails,
  - shows upload progress/retry guidance in the modal.
- Updated `web-staff/src/api/lab.ts` and `web-staff/src/pages/lab/LabQueuePage.tsx`:
  - validates PDF/JPG/PNG lab result uploads,
  - enforces 25 MB max,
  - shows upload/metadata progress and retry guidance.

### Branding, operations, and production checks

- Cleaned old `SehatID` naming from legal/web copy:
  - `docs/legal/terms-of-service.md`
  - `docs/legal/privacy-policy.md`
  - `web-admin/src/pages/legal/*`
  - `web-staff/src/pages/legal/*`
  - `docs/PRODUCT_AUDIT.md`
- Removed a leftover CNIC phrase from web privacy copy so the legal text now describes a unique Hayaat ID instead.
- Added `docs/OPERATIONS_RUNBOOK.md` covering production gates, monitoring, backups, restore, deployment checklist, and incident notes.
- Added `scripts/check-production-env.ps1` to validate required Supabase env vars and warn about dev OTP/bypass values and missing Flutter.

### Verification performed

- `npm --prefix web-staff run build` passed.
- `npm --prefix web-admin run build` passed after fixing a TypeScript issue in the deletion failure path.
- `node --check supabase/tests/rls.test.mjs` passed.
- `npm --prefix supabase/tests test` skipped cleanly because `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are not set in this terminal.
- `scripts/check-production-env.ps1` correctly reports missing Supabase env vars in this terminal.
- Local launcher check:
  - staff portal responded on `http://[::1]:5174`,
  - admin portal responded on `http://[::1]:5173`.

### Not completed / intentionally deferred

- Real OTP provider replacement remains intentionally skipped per request.
- Full live end-to-end simulation could not be completed from this terminal because:
  - the patient Flutter portal is not running here,
  - Flutter is not installed/on PATH,
  - Supabase service-role env vars are not available for generated staff/lab/admin test setup,
  - the provided password `12345` is rejected by the current patient signup password policy, which requires at least 8 characters with a letter and a number.
- Native package identifiers still contain old `com.sehatid...` bundle IDs. I did not change them because mobile bundle ID migration affects app signing, store identity, installed-app continuity, and release planning.
