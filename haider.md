# HayaatID / CNIC Health Card — Session Change Log (2026-09-03)

Finalisation pass across all four modules: **Admin · Doctor · Patient · Lab**.
Focus was synchronisation, CNIC-based identification, database/integration
correctness, demo lab reports, and end-to-end testing.

Everything below was verified against the **live** Supabase project
`iikwdtiqvxxatrzahuzo` — not simulated.

**Final state:** E2E chain **44/44 passed**, RLS suite **18/18 passed**,
`flutter analyze` **0 errors / 0 warnings**, both web apps build clean.

The previous session's log is preserved at the bottom of this file.

---

## 1. Investigation and diagnosis (what the "data sync issue" actually was)

1. Probed the live database with the publishable key and found it was running an
   **older schema than the repository** — client code was calling RPCs the
   database had never seen. This, not corrupt data, was the sync problem.
2. Confirmed `request_card()` still had its old 5-argument signature with no
   `p_name_en`, so **every patient card request failed** at runtime.
3. Confirmed `available_appointment_slots()` did not exist → patient
   self-booking broken.
4. Confirmed `request_patient_appointment()` did not exist → patient booking
   broken.
5. Confirmed `book_clinic_appointment()` did not exist → receptionist booking
   broken.
6. Confirmed `clinical_staff_can_access_patient()` did not exist → the entire
   receptionist/lab RLS split was silently inactive.
7. Confirmed `profiles.cnic` had been dropped by `hayaat_id_only.sql`.
8. Confirmed the live database was **empty** — no clinics, labs, doctors or
   admins — so there was no data for the modules to synchronise in the first
   place.
9. Verified the RPCs that *were* present and working: `login_email`,
   `gen_hayaat_id`, `my_role`, `is_staff`, `staff_can_access_patient`,
   `start_conversation`, `set_consent_preference`, `export_my_data`,
   `request_physical_card`, `admin_mark_deletion_request`.
10. Verified column-level drift was minimal — only `profiles.cnic` was actually
    missing; `encounters.specialty`, `medication_requests.dose_*`,
    `lab_results.structured_results`, `medical_documents.*` and
    `consent_preferences` were all present and correct.
11. Confirmed self-signup role escalation is correctly blocked live — signing up
    with `role: 'admin'` is clamped to `patient`.

## 2. CNIC-based identification — why, and the decision

12. Read the build-target spec `docs/ibbi docs/CNIC_Health_Card_PROTOTYPE_Scope.pdf`
    and confirmed CNIC is mandated, not optional:
    - `profiles.cnic VARCHAR(13) UNIQUE NOT NULL`
    - **P-FR-001** — register as a patient with a valid 13-digit CNIC
    - **P-FR-002** — doctors submit PMDC number **and CNIC** at registration
    - **P-FR-005** — the same CNIC cannot be registered twice, for any role
    - **P-FR-019** — a doctor finds a patient by entering their CNIC number
13. Established that the previous commit `86871fb` (`hayaat_id_only.sql`) had
    dropped CNIC entirely, putting the code **out of alignment with the spec**
    and breaking P-FR-019 as written.
14. **Decision: CNIC and the Hayaat ID coexist — they are not the same thing.**
    - CNIC (13 digits) identifies the **person**: registration, login, staff lookup.
    - Hayaat ID (16 digits) identifies the **card**: printed on the virtual and
      physical health card, still minted by `gen_hayaat_id()`.
15. Chose an **additive** restoration so no existing card work was destroyed.

## 3. CNIC — database layer

16. Added `profiles.cnic varchar(13)`, nullable so rows created while the column
    was dropped keep working.
17. Added constraint `profiles_cnic_format` — exactly 13 digits, no dashes.
18. Added unique index `profiles_cnic_unique` — enforces P-FR-005 across every
    role.
19. Rewrote `handle_new_user()` to normalise the CNIC (strips dashes/spaces),
    **reject** a malformed value rather than silently dropping it, reject an
    already-registered CNIC, and store it on the profile.
20. Kept the existing role clamping intact — self-signup still cannot create an
    admin, lab worker or receptionist.
21. Rewrote `login_email()` so login resolves by **CNIC**, Hayaat ID, phone,
    email, or staff employee ID.
22. Added `find_patient_by_identifier(p_identifier text)` — a staff-only
    `SECURITY DEFINER` lookup that accepts a 13-digit CNIC **or** a 16-digit
    Hayaat ID. Necessary because clinical RLS scopes `profiles` to patients a
    doctor already treats, so a plain `SELECT` can never find a walk-in.
23. Made that function return demographics only (no clinical rows) and write its
    own `audit_logs` entry on every successful lookup.
24. Added `find_patient_by_cnic(p_cnic text)` as an explicit CNIC-named alias.
25. Confirmed `export_my_data()` needed no change — it uses `to_jsonb(p)` on the
    whole profile row, so CNIC is included automatically.

## 4. CNIC — Flutter app (patient · doctor · lab · receptionist)

26. Added a **CNIC field** to patient signup with 13-digit validation, digits-only
    input and a 13-character limit.
27. Added a pre-submit duplicate check for CNIC (P-FR-005) so the user is told
    before sitting through the OTP step.
28. Replaced the raw `profiles` select used for the phone-duplicate check with
    `resolveLoginEmail()`, which does not depend on a blanket read of `profiles`.
29. Threaded `cnic` through the signup chain: `signup_screen` → `otp_screen` →
    `AuthController.signUp()` → `AuthService.register()`.
30. Added `cnic` (required) to `AuthService.registerDoctor()` for P-FR-002.
31. Added 13-digit CNIC validation and clear error messages in `AuthService`
    for both registration paths.
32. Rewrote `DoctorService.searchPatient()` to use the CNIC lookup RPC, accepting
    13 or 16 digits.
33. Rewrote `ReceptionistService.searchPatient()` the same way.
34. Updated the doctor's search dialog: title "Search patient by CNIC", hint
    "13-digit CNIC (or 16-digit Hayaat ID)".
35. Updated the receptionist booking sheet label to "Patient CNIC or Hayaat ID".
36. Updated login screen copy — field label, error text and both info banners now
    lead with CNIC.
37. Added `cnic` to `UserModel` (parse + serialise).
38. Added `cnic` to `PatientSummary`.

## 5. CNIC — web-staff (doctor · lab · receptionist portal)

39. Rewrote `doctorApi.searchPatient()` to use the CNIC lookup RPC.
40. Rewrote `receptionApi.searchPatient()` to use the same RPC.
41. Added a **required CNIC field** to the doctor self-registration form (P-FR-002),
    with 13-digit validation.
42. Rewrote `PatientLookupPage` — heading "Find a patient by CNIC", CNIC-first
    placeholder, accepts 13 or 16 digits.
43. Added CNIC to the patient record header alongside the Hayaat ID.
44. Updated `SchedulePage` booking form label and validation to accept CNIC.
45. Updated login page label and helper text to lead with CNIC.
46. Added `cnic` to the `Profile` and `PatientSummary` types.

## 6. CNIC — web-admin (admin portal)

47. Added a **CNIC column** to the Users table.
48. Added a **CNIC column** to the Doctor Applications table.
49. Added CNIC to the doctor application detail panel.
50. Extended user search to match CNIC as well as name and Hayaat ID, stripping
    non-digits so a CNIC typed with dashes still matches.
51. Added `cnic` to the `Profile` and `DoctorApplication` types and to the
    doctor-applications query.
52. Updated login page label to lead with CNIC.

## 7. Bugs found and fixed

53. **Lab results were invisible to the doctor.** `lab_results.lab_order_id` is
    `UNIQUE`, so PostgREST embeds the result as a **single object, not an array**.
    Both `web-staff/src/api/doctor.ts` and `lib/services/doctor_service.dart`
    read `lab_results[0]` and always got `undefined` — the review page showed no
    values and no file link. Fixed in both; `record_service.dart` already handled
    it. *This is the most likely cause of reports "not appearing for the doctor".*
54. **One patient had three different Hayaat numbers.** Two conflicting
    `request_card()` definitions shipped in the repo — `revision.sql` preserved
    the existing number (`coalesce`), `cards.sql` overwrote it with a fresh one.
    Requesting a card silently changed the patient's Hayaat ID and left
    `patient_profiles.health_card_number` stale.
55. Rewrote `request_card()` to reuse the number issued at sign-up, minting one
    only if the account genuinely has none.
56. Made `request_card()` keep `profiles.card_number`, `cards.card_number` and
    `patient_profiles.health_card_number` in step on every call.
57. Added a one-time reconciliation for rows that had already drifted, with
    `profiles.card_number` as authoritative. **Result: 0 mismatches database-wide.**
58. Dropped the stale 5-argument `request_card()` overload so PostgREST cannot
    hit an ambiguous-signature error.
59. **Fixed a bug in my own migration:** `find_patient_by_identifier` declared
    `RETURNS TABLE (... text)` while `profiles` stores `varchar`, so
    `RETURN QUERY` failed with *"structure of query does not match function
    result type"*. Every column is now cast explicitly.
60. **The RLS test suite could not run at all** — pre-existing, broken since
    `hayaat_id_only.sql` landed. It fabricated 16-digit card numbers that fail
    the Luhn check constraint.
61. Fixed it to mint valid numbers via `gen_hayaat_id()` instead of inventing
    them; removed the now-dead `cardFor()` helper.
62. Fixed a second pre-existing break in that suite: phone numbers were built by
    truncating a 12-character string to 11, which cut off the index digits and
    collided under the `profiles_unique_phone` constraint.

## 8. Security / RLS fixes (real data leaks)

63. Discovered that **three whole policy blocks in `product_hardening.sql` had
    never reached the live database** — every one calls
    `clinical_staff_can_access_patient()`, which did not exist there, so they
    silently no-op'd and the looser `staff_can_access_patient()` stayed in force.
64. **Leak: a receptionist who booked an appointment could read that patient's
    lab orders and lab results.** Fixed by applying the intended `p_lo_sel` /
    `p_lr_sel` policies.
65. **Leak: a receptionist could read uploaded clinical documents.** Fixed by
    applying the intended `medical_documents` and storage-object policies.
66. **Leak: a lab worker could read the doctor's chief complaint, assessment,
    plan, diagnoses, prescriptions, vitals and allergies** for any patient whose
    sample crossed their bench — contrary to the spec's masked lab queue.
67. Added `narrative_staff_can_access_patient()` — a narrower helper granting the
    consultation narrative to the patient, an admin, or a doctor with a real care
    relationship only. Lab workers and receptionists excluded.
68. Repointed `encounters`, `conditions`, `medication_requests`, `observations`
    and `allergies` SELECT policies at the new helper. Write policies untouched.
69. Confirmed the lab keeps exactly what it needs — `lab_orders`, `lab_results`
    and the `lab-results` storage folder — and that the whole lab flow still
    works after tightening.
70. Removed a duplicate `audit_logs` insert from the doctor patient-search path
    in both Flutter and web-staff, since the lookup RPC now writes it server-side
    (previously the client wrote an audit row the database could not verify).

## 9. Files added

71. `supabase/cnic_identity.sql` — CNIC column, constraints, sign-up trigger,
    `login_email()`, `find_patient_by_identifier()`, `find_patient_by_cnic()`.
72. `supabase/clinical_narrative_rls.sql` — `narrative_staff_can_access_patient()`
    and the five repointed narrative policies.
73. `supabase/card_number_consistency.sql` — corrected `request_card()` plus the
    reconciliation of drifted card numbers.
74. `supabase/demo_seed.sql` — demo clinic, laboratory, staff-role promotion,
    doctor approval, CNIC backfill, weekly availability.
75. `supabase/FINALIZE.sql` — one-paste bundle of everything verified missing
    from the deployed project.
76. `supabase/tests/demo_accounts.mjs` — single definition of the six demo
    identities, shared by the seeding and verification scripts.
77. `supabase/tests/seed_demo_accounts.mjs` — creates the demo accounts through
    the ordinary public sign-up API (no service-role key needed).
78. `supabase/tests/verify_e2e.mjs` — the full Admin → Database → Lab → Doctor →
    Patient integration check; also produces the demo lab reports.
79. `supabase/migrations/` — five timestamped migrations, so `supabase db push`
    can apply everything to a linked project.

## 10. Files modified

80. **Flutter (12 files):** `auth_controller.dart`, `auth_model.dart`,
    `clinical_models.dart`, `login_screen.dart`, `otp_screen.dart`,
    `signup_screen.dart`, `doctor_home_screen.dart`,
    `reception_home_screen.dart`, `auth_service.dart`, `doctor_service.dart`,
    `receptionist_service.dart`.
81. **web-staff (8 files):** `api/doctor.ts`, `api/reception.ts`, `api/types.ts`,
    `DoctorRegisterPage.tsx`, `LoginPage.tsx`, `PatientLookupPage.tsx`,
    `PatientRecordPage.tsx`, `SchedulePage.tsx`.
82. **web-admin (5 files):** `api/admin.ts`, `api/types.ts`,
    `DoctorApplicationsPage.tsx`, `LoginPage.tsx`, `UsersPage.tsx`.
83. **SQL:** `supabase/cards.sql` — `request_card()` replaced with the
    non-overwriting version so a fresh install cannot reintroduce bug #54.
84. **Tests:** `supabase/tests/rls.test.mjs` — valid card numbers, unique phone
    numbers, corrected assertion wording.
85. **Docs:** `README.md`, `supabase/SUPABASE_SETUP.md`.
86. Total: **31 files changed, 412 insertions, 148 deletions.**

## 11. Deletions and removals

87. Dropped the obsolete 5-argument `request_card(text,date,text,text,text)`
    from the database.
88. Dropped and recreated `find_patient_by_identifier` / `find_patient_by_cnic`
    (a return type cannot be changed by `CREATE OR REPLACE`).
89. Removed the duplicate client-side `audit_logs` insert from doctor search in
    Flutter and web-staff.
90. Removed the now-redundant `patient_profiles` round-trip from Flutter's
    `searchPatient()` — the RPC already returns `blood_group`.
91. Removed the `cardFor()` helper from the RLS suite.
92. Removed the direct `profiles` query used for signup duplicate-checking.
93. Renamed for clarity: `_HayaatIdSearchDialog` → `_PatientSearchDialog`,
    `_hayaatIdCtrl` → `_patientIdCtrl`, `hayaatId` → `patientIdentifier`,
    `cardNumber` → `identifier`.
94. Deleted all temporary probe scripts and the schema dump used during
    diagnosis — nothing throwaway was left in the repo.

## 12. Database migrations applied to the live project

95. `20260903093510_cnic_identity.sql`
96. `20260903093732_clinical_narrative_rls.sql`
97. `20260903094226_document_storage_policies.sql`
98. `20260903094510_card_number_consistency.sql`
99. `20260903095105_lab_workflow_policies.sql`

## 13. Demo data and demo reports

100. Created six demo accounts through the public sign-up API — no service-role
     shortcut, so account creation is proof the sign-up path works.
101. Password for all six: `Hayaat@2026`. **Sign in with the CNIC.**

| Role | CNIC | Email |
| ---- | ---- | ----- |
| Admin | `3520100000001` | demo.admin@hayaat.id |
| Doctor | `3520199999991` | demo.doctor@hayaat.id |
| Lab worker | `3520177777771` | demo.lab@hayaat.id |
| Receptionist | `3520166666661` | demo.reception@hayaat.id |
| Patient | `3520112345671` | demo.patient@hayaat.id |
| Patient 2 (isolation tests) | `3520112345672` | demo.patient2@hayaat.id |

102. Created the demo clinic **Hayaat Family Clinic** and laboratory
     **Hayaat Diagnostics**, both active.
103. Promoted the admin, lab worker and receptionist roles via SQL — necessary
     because self-signup is deliberately clamped to patient/doctor.
104. Approved the demo doctor, attached to the clinic, with a Mon–Fri
     09:00–13:00 schedule in 30-minute slots.
105. Recorded a Penicillin allergy on the demo patient so the prescribe-time
     allergy check has something real to fire on.
106. Created **three demo lab reports** with real structured values and readable
     PDF files: **Complete Blood Count**, **HbA1c**, **Lipid Profile**.
107. The reports are produced by driving the real app APIs — doctor orders → lab
     collects, processes and uploads → doctor reviews and releases — not by
     inserting rows behind the app's back.

## 14. Testing and verification

108. **E2E integration check: 44 passed, 0 failed.** Re-run with `--force` to
     exercise the whole chain from scratch, not from cached rows.
109. **RLS policy suite: 18 passed, 0 failed** (previously could not run at all).
110. `flutter analyze` — **0 errors, 0 warnings** (46 pre-existing style infos).
111. `web-admin npm run build` — clean.
112. `web-staff npm run build` — clean.
113. Verified live: **card request works** (was completely broken).
114. Verified live: **patient booking works** — 8 generated slots returned, one
     booked, and the taken slot correctly disappears from the next query.
115. Verified live: **receptionist booking works**.
116. Verified doctor visibility — results reach the review queue with structured
     values, and can be reviewed and released.
117. Verified patient visibility — all three reports appear, with the stored file
     path, a working signed URL that serves a genuine PDF, a release
     notification, and the encounter plus prescription on the timeline.
118. Verified isolation — a second patient sees none of the first patient's
     orders or results.
119. Verified the Hayaat-number invariant is now asserted permanently in the E2E
     suite so bug #54 cannot silently return.

## 15. Documentation

120. Rewrote the README opening to explain the CNIC / Hayaat ID split.
121. Added the demo accounts table and the E2E command to the README.
122. Updated the SQL run order in README and `SUPABASE_SETUP.md` to include the
     three new files.
123. Documented that the SQL files are mirrored as timestamped migrations under
     `supabase/migrations/`.

## 16. Known remaining items (not blockers)

124. Two probe accounts remain (`probe.tester.001@`, `probe.admin.001@`) plus
     RLS-suite throwaways prefixed `rls-`. Deletable now the CLI is linked.
125. `profiles.cnic` is nullable rather than `NOT NULL` — rows created while the
     column was dropped carry none. Uniqueness and format are enforced; tighten
     only after a full backfill.
126. OTP is still the hardcoded development code `11111` — unchanged
     deliberately, no SMS provider configured.
127. Native bundle identifiers still read `com.sehatid…` — left alone because
     changing them affects app signing and store identity.
128. One mid-session correction: a Hayaat-number mismatch was first reported
     using a probe that read `profiles` without filtering by id (a patient can
     also read provider rows). The `patient_profiles` ↔ `cards` drift was real
     and is fixed; the specific `profiles` value quoted at that moment was wrong.

---

# Appendix — Previous session log (2026-07-13)

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
