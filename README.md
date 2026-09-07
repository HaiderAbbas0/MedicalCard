# HayaatID Health Platform

A centralized digital health-card platform for Pakistan. Every citizen is
identified by their **13-digit CNIC** — that is the key they register with, log
in with, and that a doctor types to pull up their record (prototype scope
P-FR-001/002/005/019). On top of that identity each account is also issued a
random, unique, **16-digit Hayaat ID**: the number printed on the physical and
virtual health card. The two are complementary — CNIC identifies the person,
the Hayaat ID identifies the card.

---

## Architecture: Supabase-first (single production backend)

**Supabase is the one production backend.** All three client apps talk to it
directly — there is no separate application API server.

```
                         ┌──────────────────────────────────────┐
                         │              Supabase                 │
   Flutter (lib/) ─────► │  Auth · Postgres (RLS) · Storage ·    │
   web-admin/     ─────► │  Realtime · Edge Functions            │
   web-staff/     ─────► │  (service-role, server-only)          │
                         └──────────────────────────────────────┘
```

| Layer | Responsibility |
| ----- | -------------- |
| **Supabase Auth** | Identity and sessions. Login via CNIC, Hayaat ID, email, phone, or staff Employee ID — all resolved by the `login_email()` RPC. |
| **Supabase Postgres** | All data. **Row Level Security on every table**, `SECURITY DEFINER` role helpers, triggers, audit log. See `supabase/`. |
| **Supabase Storage** | `lab-results`, `medical-documents` (both private, signed-URL access) and `card-photos` (owner-write). |
| **Supabase Realtime** | Live delivery of chat messages between patient and doctor. |
| **Supabase Edge Functions** | Privileged, server-only operations that need the service-role key: `admin-create-user`, `delete-account`. Never done from the client. |

> There is **no application server** and no container in this architecture. The
> earlier Node/Express prototype (`backend/`) has been **removed** — every client
> talks to Supabase directly. The security boundary is RLS, not application code.

### The clients

| Folder        | Stack                        | Serves                                   |
| ------------- | ---------------------------- | ---------------------------------------- |
| `lib/`        | Flutter (Android + iOS + web) | **Mobile** — patient · doctor · lab worker · receptionist |
| `web-admin/`  | React 18 + TS (Vite, :5173)  | **Admin web app** — administrators only |
| `web-staff/`  | React 18 + TS (Vite, :5174)  | **Staff web app** — doctor · lab worker · receptionist (role-routed) |
| `web-research/` | React 18 + TS (Vite, :5175) | **Research web app** — approved external organisations, de-identified data only |

### The six roles

| Role          | Client       | Highlights                                                        |
| ------------- | ------------ | ----------------------------------------------------------------- |
| Patient       | Mobile       | Health timeline, prescriptions, lab results, appointments, chat, digital card, voice input, AI record explainer, PDF export, data export / account deletion |
| Doctor        | Mobile + Web | Patient lookup by CNIC, encounters, prescribing (with allergy check), lab orders, result review/release, availability, messaging, document upload |
| Lab worker    | Mobile + Web | Priority order queue, sample tracking, result upload (masked patient identity) |
| Receptionist  | Mobile + Web | Clinic schedule, slot-aware walk-in booking, check-in (demographics only) |
| Admin         | Web          | Approvals, suspensions, clinics, staff creation, dashboard, audit log, notification bell, card-delivery queue, account-deletion queue, research org & data-request review |
| Researcher    | Web (research) | Cohort exploration on k-anonymised aggregates, dataset catalogue, data-access requests, ML-ready de-identified exports. **No access to any identifiable record.** |

---

# Features

## 1. Identity, authentication & accounts

- **CNIC as citizen identity** — 13 digits, unique across every role
  (`profiles_cnic_unique`), format-checked in the database
  (`profiles_cnic_format`) and validated client-side before sign-up.
- **16-digit Hayaat ID** — minted at sign-up by `gen_hayaat_id()`, carries a
  **Luhn check digit** (`hayaat_luhn_check_digit`) and is enforced by a
  `CHECK` constraint. One number per person, kept consistent across
  `profiles.card_number`, `patient_profiles.health_card_number` and
  `cards.card_number` (`card_number_consistency.sql` reconciles historical drift).
- **Multi-identifier login** — one field accepts CNIC, Hayaat ID, email, phone,
  or a staff Employee ID; `login_email()` resolves any of them to the underlying
  auth email. Callable by `anon` so login works pre-authentication.
- **Role clamping at sign-up** — `handle_new_user()` trusts a privileged role
  only from `raw_app_meta_data` (service-role only). A self-service sign-up that
  asks for `admin` is silently clamped to `patient`. Self-registration can
  therefore only ever produce **patient** or **doctor**.
- **Doctors register pending** — a self-registered doctor is created with
  `status = 'pending'`, signed out immediately, and cannot log in until an admin
  approves them.
- **Status gating** — suspended/pending accounts are blocked at login *and* at
  the data layer: `is_staff()` requires `status = 'active'`, so suspension is
  enforced by RLS, not just the UI.
- **Pre-flight uniqueness check** — sign-up checks CNIC and phone against the
  database *before* sending the user through OTP, with distinct messages
  ("An account is already registered with this CNIC." / "A user with this phone
  number already exists.").
- **Password policy** — minimum 8 characters with at least one letter and one
  digit, enforced on every sign-up and password-change form across all clients.
- **Namespaced sessions** — `hayaat_admin_auth` and `hayaat_staff_auth` storage
  keys keep the two web portals from clobbering each other's session on the same
  origin. Sessions persist and auto-refresh.
- **Portal role gates** — a non-admin who authenticates against the admin portal
  is signed out with "This portal is for administrators only."; the staff portal
  does the same for admins ("Administrators use the admin portal.") and patients
  ("Patients use the mobile app.").
- **Password reset** — privacy-preserving response ("Password reset email sent
  if the account exists.") that doesn't disclose whether an account exists.

## 2. Patient mobile app

### Dashboard
- Personalized greeting ("Assalam-o-Alaikum"), health-card preview with a live
  **QR code** encoding `healthId|name|blood|dob`.
- **Four rich stat tiles** — Active Meds, Allergies, Recent Visits, Next Appt.
  Each embeds a scrollable mini-preview list (medicine names, allergy
  substances, recent visits, appointment details) above the number, with
  context-aware sublabels ("None active" / "Tap to view" / "None booked").
- **Quick actions** — horizontally scrolling row: Records, Reports, Reminders,
  Chat, Notifications, and a danger-styled **Emergency SOS**.
- **Emergency SOS** — confirmation dialog then dials **1122** via `url_launcher`,
  with a graceful fallback snackbar if no dialer exists.
- **Recent activity** feed with a "See all" link.
- Pull-to-refresh; inline shimmer cards while records load.

### Records library (three-level folder model)
- **Specialty folders** — a **30-specialty** head-to-toe taxonomy
  (`lib/models/medical_specialty.dart`). A folder appears **only** when the
  patient actually has a record in it — never a static list.
- **Alias normalization** so older/provider-side specialty spellings map onto
  the canonical patient-facing names.
- **Search** across specialty, body system, doctor, and record type, with a
  distinct "no matching records" state separate from "library is empty".
- **Specialty folder view** — records grouped by **year**, newest first, with
  record-type filter chips (shown only when more than one type exists), per-type
  icon + color across **17 record types**, and an attachment count.
- **Normalized index** merges seven sources: finalized encounters, prescriptions
  grouped by encounter, vitals/observations, chronic diagnoses, released lab and
  imaging results, allergy records, and uploaded original documents.
- **Record viewer** —
  - PDFs render with `pdfrx`, all pages scrollable, with **determinate download
    progress** (`bytesDownloaded / totalBytes`).
  - Images keep source resolution with pan/zoom (`InteractiveViewer`, 0.8×–8×).
  - Multiple attachments get a labelled file switcher.
  - Digital prescriptions render as a formatted ℞ document from stored fields,
    including the doctor's snapshot signature block.
  - **Responsive**: side-by-side document + 340 px metadata rail at ≥900 px,
    stacked below that.
  - Three distinct file-level failure states (PDF failed / image failed /
    unpreviewable format), each still exposing metadata.
- **Signed URLs are created on demand** (1 hour) — the database stores object
  paths, never long-lived links.

### Prescriptions
- Active/Past gradient segmented control.
- Dose schedule per medicine (morning / afternoon / evening / night), duration,
  route, and free-text patient directions.
- **Drug-interaction / allergy warning banners** in amber.
- Right-aligned **doctor signature block** (name, credentials, registration
  footer) when the prescribing encounter captured one.
- Shortcut into medicine reminders.

### Medicine reminders & adherence
- Doses bucketed by time of day with distinct icons (twilight / sun / cloud /
  night).
- **Taken / Skipped** logging to `medication_logs`.
- **Adherence ring** — circular progress with the percentage in the centre.
- **Optimistic updates with rollback**: the tile flips immediately, shows a
  per-dose inline spinner, and reverts with a snackbar if the write fails.
- Taken doses get a green-tinted card border.

### Lab reports
- Grouped by specialty with a per-group count pill.
- Semantic status pills — **Ready / Reviewed / Abnormal**.
- Download action that first checks whether the original document actually
  exists ("Original report is not available yet.").

### Appointments
- Upcoming and past appointments with color-coded status chips (pending,
  confirmed, checked-in, completed, cancelled, no-show).
- **Booking sheet** — doctor search, **slot-aware time picker** driven by the
  `available_appointment_slots()` RPC (respects the doctor's weekly availability,
  excludes taken slots, and enforces a 2-hour lead time for same-day bookings),
  date picker bounded to today→+120 days, and a free-text reason field.
- **Voice dictation** on the reason/notes field.
- **Self-service cancellation** with a "Keep / Cancel it" dialog (avoiding
  Cancel/Cancel ambiguity), gated to ≥24 hours before the appointment.

### Allergies
- Active and Past/Resolved sections, showing substance, reaction, trigger note,
  criticality and severity.
- Positive empty state (green check, "No allergies on record.").

### Digital & physical health card
- **Premium card widget** (`HayaatCard`) — credit-card aspect ratio with
  **role-themed palettes** (patient teal→green, doctor navy→blue, lab
  amber/brown, receptionist light, admin magenta), each with its own derived
  glow shadow, decorative geometry, and role pill.
- **Urdu name rendered RTL** inside its own `Directionality`, regardless of app
  language. Urdu is printed automatically.
- Photo tile with computed initials fallback; monospaced card number.
- **Card request flow** — name on card, DOB, blood group, city, and a photo.
- **In-app photo cropper** — full-screen dialog with drag-to-pan square crop box,
  dimmed outside area, rule-of-thirds grid, live guidance ("Clear background •
  good lighting • straight face"), and real canvas cropping to PNG. Works on web.
- **Draft caching** — a half-filled card form is preserved in `SharedPreferences`.
- **Physical card delivery** — request with address/phone, PKR delivery fee,
  status tracked (`virtual` → `physical_requested` → `delivered`).
- Requesting a card or delivery **notifies every active admin** via a database
  trigger.

### Messaging
- Real patient↔doctor chat on Supabase (`conversations` + `messages`), **participant-only RLS**,
  **Supabase Realtime** delivery.
- Asymmetric bubble corners, gradient outgoing vs bordered incoming bubbles,
  "Today" separator, timestamps, unread badges, online/offline indicator.
- **Optimistic send** with realtime echo suppression.
- Auto-scroll to bottom on open, on send, and after rebuilds.
- Auto mark-as-read on opening a thread.
- **Voice input** on the composer and **read-aloud** on every incoming message.
- Persistent amber safety banner: *"For emergencies, call 1122 — do not wait for
  a reply here."*

### Notifications
- In-app notification centre with per-type icon and colour (appointment
  confirmed/cancelled, lab result ready, doctor approved/rejected, record added,
  card request, card delivery).
- Unread dot, **optimistic mark-read**, and a "Mark all read" action that appears
  only when there is something unread.

### Profile & settings
- Profile shows Hayaat ID, CNIC-derived demographics, blood group, allergies,
  chronic conditions, emergency contact.
- **Profile photo** change (gated on having requested a card first).
- Edit profile, change password, login & security, help & support with
  **animated FAQ accordions**.
- **Dark mode toggle** (hand-built animated pill), **language switch**
  (English / Urdu), and a bottom-sheet logout confirmation.

### Compliance & data rights
- **Privacy Policy and Terms** viewable in-app with a version + last-updated
  line and a legal-review disclaimer banner.
- **Consent recorded at sign-up** (`consents`, append-only, server-stamped with
  IP/user-agent/time).
- **Consent management** — four toggles (share history, emergency access,
  research, notifications) persisted server-side via `set_consent_preference()`
  with a `SharedPreferences` fallback and optimistic revert on failure.
- **Data export** — `export_my_data()` returns everything the account holds as
  one JSON document, pretty-printed into a selectable dialog with copy-to-clipboard.
- **Account deletion request** — free-text reason, explicit "this cannot be
  undone" confirmation, then an admin-processed erasure queue.

## 3. Voice input & text-to-speech *(new)*

- **Speech-to-text dictation** (`speech_to_text`) via a reusable
  `VoiceInputButton` that appends recognized speech into any text field,
  streaming **live partial results** as you speak and committing on final.
  Idle = mic icon; listening = danger-tinted circle with a stop icon.
- Wired into the **chat composer**, the **appointment reason/notes** field, and
  the doctor's **chief complaint** field.
- **Text-to-speech read-aloud** (`flutter_tts`) via `SpeakButton` — on every
  incoming chat message and on AI explanations. Tapping while speaking stops it.
- Runs entirely on-device; no API key or cloud cost.
- Android `RECORD_AUDIO` permission and `android.speech.RecognitionService`
  queries entry; iOS `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` are declared.

## 4. AI record explainer *(new)*

- An **"Explain this record"** action on the record viewer (✨ app-bar icon) and
  an **"Explain this visit"** button on visit detail.
- Sends the record's structured content to a **locally-running LM Studio**
  server via its OpenAI-compatible `/v1/chat/completions` endpoint — the model
  runs entirely on your own machine, so **no PHI leaves the device** and there
  is no API key or per-call cost.
- **Model auto-discovery** — queries `/v1/models` and picks the first loaded
  non-embedding model; override with `--dart-define=LM_STUDIO_MODEL=<id>`.
  Endpoint override: `--dart-define=LM_STUDIO_URL=http://host:port/v1`.
- Reasoning-model aware: generous output budget, and a clear message if a
  reasoning model exhausts it before answering.
- **Safety-first prompt** — explains terms and reference ranges in plain
  language, never gives a new diagnosis, never contradicts the treating doctor,
  never suggests changing medication, and always closes by pointing back to the
  doctor.
- Responds **in Urdu** automatically when the app language is Urdu, rendered RTL.
- Persistent amber disclaimer: *"AI-generated general information — not a
  diagnosis. Always confirm with your doctor."*
- Output is **selectable** (copyable) and has a **read-aloud** button.

> Requires LM Studio's local server running with a model loaded, and — for web
> builds — its **Enable CORS** setting turned on.

## 5. PDF export & sharing *(new)*

- **Branded, Unicode-safe PDF generation** (`pdf` + `printing`), using Noto Sans
  via Google Fonts with a built-in-font fallback when offline.
- Three document builders:
  - **Single record** — prescription (formatted ℞ with signature block),
    consultation, lab report, or uploaded document. An original single-file PDF
    is passed through as-is; images are embedded on pages.
  - **Visit summary** — symptoms, diagnosis, medicines table, follow-up, advice.
  - **Full health record** — demographics, allergies, active medicines, visits,
    and lab reports in one document.
- Every page carries a branded header, a patient identity block (name, formatted
  Hayaat ID, formatted CNIC, blood group), a page footer with generation
  timestamp, page numbering, and a "patient-held copy, not a substitute for a
  clinician's signed document" notice.
- **Export sheet** offers **Share / save PDF** (OS share sheet — WhatsApp,
  email, Files) and **Print**. Bytes are built lazily only after the user picks,
  behind a "Preparing PDF…" snackbar.
- Entry points: record viewer app bar, visit detail, and
  Settings → Your Data → **Download health record (PDF)**.
- Covered by 6 unit tests.

## 6. Doctor workspace (mobile + web)

- **Patient lookup by CNIC** (P-FR-019) through the staff-only
  `find_patient_by_identifier()` SECURITY DEFINER RPC — clinical RLS scopes
  `profiles` to existing care relationships, so a plain select cannot find a
  walk-in. Accepts 13-digit CNIC or 16-digit Hayaat ID, returns **demographics
  only**, and **writes its own audit row on every successful lookup**. The UI
  states this explicitly: *"Every lookup is recorded in the access audit log."*
- **Patient record view** — red allergy banner, active-conditions line, active
  medications table, and a finalized-encounter health timeline with per-encounter
  medication and lab-order counts.
- **New encounter** — a draft row is created on open (guarded against React
  StrictMode double-mount), and each item is persisted as it is added:
  - Specialty (29-item patient-friendly taxonomy), chief complaint (with
    **voice dictation** on mobile), diagnoses with optional ICD-10.
  - **Prescribing** with a **live ℞ template preview** that renders the
    prescription as you type, including the signature block.
  - Route, frequency, duration-in-days, per-dose time-of-day checkboxes, and
    patient directions — validated (whole number > 0; frequency *or* at least one
    time of day required).
  - **Allergy interaction check** — case-insensitive bidirectional substring
    match against the patient's active allergies, surfacing "Patient has a
    recorded {criticality} allergy to {substance}" as an acknowledgeable warning.
  - Vitals/observations with numeric values and units.
  - **Lab orders** with lab selection (active labs only) and priority
    (Routine / Urgent / **STAT**).
  - **Finalize** locks the record, stamps `finalized_at`, **snapshots the
    doctor's prescription signature** onto the encounter (so later profile edits
    never rewrite historical prescriptions), and notifies the patient.
- **Record allergy** for a patient — substance, reaction, trigger, severity,
  criticality.
- **Upload medical document** (web) — title, 28 specialties, 17 record types,
  date, notes, and **multi-file upload** (PDF/image/DICOM, max 10 files, ≤25 MB
  each, MIME *or* extension validated) with **live per-file progress** and
  **transactional rollback** — if any upload or the final insert fails, every
  already-uploaded object is deleted. Notifies the patient on success.
- **Lab result review & two-stage release** — `resulted` → **Mark reviewed** →
  **Release to patient**, with structured values rendered as a table and a
  notification fired to the patient on release.
- **Weekly availability editor** — day, start/end time, slot length, with
  client-side duplicate detection *and* a server-side unique-constraint backstop
  rewritten to a friendly message.
- **Messaging** — two-pane chat with realtime inserts, batched unread counts (no
  N+1), auto-scroll, auto-mark-read.
- **Profile** — specialization, consultation fee, public bio, availability
  toggle, and the **prescription signature block** (signing name, qualifications
  auto-composed from MBBS/FCPS flags, registration footer) with an explicit
  "this is not a handwritten or cryptographic signature" disclaimer.

## 7. Lab worker workspace

- **Order queue scoped to the worker's own lab** (empty if unassigned).
- **Priority-ranked ordering** — STAT → Urgent → Routine, oldest first within a
  priority; terminal states (released, cancelled) are hidden.
- **Masked patient identity** — first name + last initial ("Ayesha K."); the lab
  never sees CNIC, card number, or full surname. A deliberate privacy boundary
  versus the doctor's unmasked view.
- Colour-coded priority badges (red STAT / amber Urgent / green Routine).
- **Sample-tracking ladder** — `ordered` → **Mark collected** →
  `sample_collected` → **Mark processing** → `processing` → **Upload result**.
- **Result upload** — PDF/JPG/PNG, ≤25 MB, MIME *or* extension validated, into
  the private `lab-results` bucket at `{patient_id}/{order_id}/{ts}_{name}`,
  with two-phase progress text and a retry hint on failure. Automatically flips
  the order to `resulted` and **notifies the ordering doctor**.
- RLS keeps lab workers out of the clinical narrative entirely
  (`narrative_staff_can_access_patient()` — see Security below).

## 8. Receptionist workspace

- **Clinic schedule** for all doctors in the receptionist's clinic, by date,
  with a "Today" reset button.
- **Check-in** for pending/confirmed appointments.
- **Cancel** (writes `cancelled_by_clinic`).
- **Walk-in booking** — CNIC lookup via the same staff-only RPC, doctor picker
  (active doctors in this clinic), date bounded to today onward, and a
  **slot-aware time select** that reloads from `available_appointment_slots()`
  whenever doctor or date changes, with context-sensitive placeholders
  ("Choose date first" → "No open slots" → "Choose a time").
- Future-time validation, and a **double-booking collision** message rewritten
  from the Postgres unique-violation to "That doctor already has an appointment
  at this date and time."
- Receptionists see **demographics only** — clinical data is blocked by RLS.

## 9. Admin portal

- **Dashboard** — eight KPI cards (registered patients, approved doctors,
  pending doctor applications, pending lab applications, appointments today,
  pending lab orders, clinics, diagnostic labs) fetched as parallel count-only
  queries, plus a conditional **"Needs your attention"** panel that deep-links
  into the pending queues.
- **Doctor applications** — table of pending registrations, a detail modal
  (full name, CNIC, Hayaat ID, email, phone, PMDC number, specialization,
  composed qualifications, experience, clinic, status), then **Approve**
  (activates + stamps `approved_at` + notifies the doctor) or **Reject** (a
  **mandatory reason** recorded in `status_reason` for the audit log — the
  confirm button stays disabled until a reason is typed — + notifies the applicant).
- **Lab applications** — approve / reject pending diagnostic labs.
- **User management** — role filter, search by name / CNIC / Hayaat ID (with
  non-digits stripped so a dashed CNIC still matches), status badges, and
  **suspend** (mandatory reason, P-FR-048) / **reactivate**. Admins can never be
  suspended from the UI.
- **Create staff account** — receptionist, lab worker, or (super-admins only)
  administrator, with role-conditional required fields (clinic for
  receptionists, active-labs-only for lab workers, admin level for admins), full
  password-policy validation, and a deliberately visible temporary password so
  it can be read back to the new staff member. Runs through the
  `admin-create-user` Edge Function — creating an auth user needs the
  service-role key, which never reaches the browser.
- **Two admin tiers** — `support_admin` and `super_admin`; only super-admins can
  mint new administrators.
- **Clinics** — create clinics/hospitals (5 facility types) with duplicate
  detection by name + city, and an optional **receptionist account created in
  the same step** (all-or-nothing validation on that sub-form).
- **Card deliveries** — physical-card fulfilment queue with an "Include
  delivered" toggle, address/phone/fee, and per-row **Mark delivered** (per-row
  busy state, so other rows stay clickable).
- **Account deletion requests** — the most careful flow in the app:
  **Mark processing** / **Erase account** / **Reject**, each with an optional
  note pre-filled from the existing note. The erase path re-validates the
  request, flips it to `processing` **before** destructive work (so an
  interrupted run is visible, not silently stuck), calls the `delete-account`
  Edge Function, and on failure marks the request `failed` with the server's
  message and re-throws so the admin sees the real error.
- **Audit log** — the 200 most recent entries: time, actor (falling back to
  "System"), role, action, resource, and success/failure status.
- **Notification bell** — unread count polled every 30 s (capped at "99+"),
  dropdown with the 30 most recent items, auto-mark-all-read on open, relative
  timestamps (`now`, `5m`, `3h`, `2d`, then a date), unread highlighting, and
  close-on-outside-click.

## 10. Research data platform *(new)*

Lets approved external organisations — universities, public-health bodies,
pharma, ML teams — work with HayaatID clinical data **without ever receiving an
identifiable record**. Two tiers: open k-anonymised aggregates for exploring
what exists, and approval-gated de-identified row-level extracts for training.

### Five guarantees, enforced in the database

Researchers hold `role = 'researcher'` and are deliberately **not staff** —
`is_staff()` excludes them, so every existing clinical RLS policy already denies
them. They can reach nothing except through `SECURITY DEFINER` functions that
apply all of the following:

1. **Consent is a hard gate.** Only patients who explicitly switched on the
   `research` consent are ever in scope; the default is off. The check runs at
   query time, never from a snapshot, so **withdrawal takes effect immediately**
   for every subsequent query and export.
2. **No direct identifiers can leave.** Name, CNIC, Hayaat ID, phone, email,
   address, and exact date of birth are excluded at source, along with **all
   clinical free text** (chief complaint, history, examination, assessment,
   plan, medication instructions) — free text being the largest
   re-identification risk in a health record. Documents, lab files and chat
   messages are out of scope entirely.
3. **Pseudonyms are per-request.** Each approved request gets its own random
   salt, stored in a table no client role can read, and `subject_id` is a
   one-way SHA-256 digest of the patient id and that salt. The same person
   therefore carries a **different id in every extract**, so two studies or two
   organisations cannot join their datasets to rebuild an individual. No
   function maps a `subject_id` back to a person.
4. **k-anonymity on aggregates.** Any group smaller than **5** is suppressed and
   returned as `< 5` rather than a count, defeating the narrow-the-filter attack.
5. **Every access is audited.** Cohort queries and row-level exports both write
   to the append-only audit log, attributed to the caller and stamped with the
   server clock.

### Generalisation applied

| Field | Released as |
| ----- | ----------- |
| Age / date of birth | 5-year band (`30-34`), 90+ collapsed |
| Location | Province only — city and street are never released |
| Diagnosis | ICD-10 chapter letter, plus the coded condition name |
| Observation date | Year-month (`2026-09`) — never an exact date |

### Datasets (ML-ready)

| Code | Grain | Contents |
| ---- | ----- | -------- |
| `patient_features` | one row per patient | The primary training matrix: banded demographics plus counts of encounters, conditions, chronic conditions, medications, active medications, allergies, lab orders, appointments and no-shows, first/last encounter year, and mean systolic / pulse |
| `conditions` | one row per diagnosis | ICD-10 chapter, coded condition name, chronic flag, severity, clinical status, recorded year |
| `observations` | one row per observation | Numeric vitals with unit and reference range, by year-month — suitable for longitudinal and sequence models |

Each dataset ships a machine-readable **data dictionary** rendered in the portal.

### The researcher journey

1. **Cohort Explorer** — filter by age band, gender and province; see live
   k-anonymised totals, breakdowns and ICD-10-chapter prevalence as bar charts.
   Suppressed strata render as `< 5` rather than a number.
2. **Dataset Catalogue** — browse the three datasets with full column-level data
   dictionaries and tier badges.
3. **Request access** — state a study title, a research purpose (min. 30 chars),
   a legal basis (Art. 9(2)(a) consent / 9(2)(i) public health / 9(2)(j)
   research), an optional ethics reference, and accept the data-sharing
   agreement. The cohort filters explored in step 1 are carried into the request
   so the approver reviews exactly the population that will be released.
4. **Admin review** — an administrator sees the purpose, basis, cohort and
   organisation, then approves with an expiry (default 180 days), rejects with a
   mandatory reason, or revokes a live approval. The decision notifies the
   requester and is audited.
5. **Download** — CSV or JSONL, plus a **provenance manifest** recording the
   request, purpose, legal basis, cohort, approval date, expiry, row count and
   the privacy terms, so an extract is never separated from the terms it was
   released under.

### Structural safeguards

- A researcher **cannot self-approve**: a `BEFORE INSERT` trigger forces
  `status = 'pending'` and discards any client-supplied expiry, and the update
  policy admits admins only.
- **Approvals expire at the database level** — once past `expires_at`, the
  export functions refuse, rather than relying on the UI to hide a button.
- **Organisation suspension is immediate** — `my_research_org()` only resolves
  for an `active` organisation, so suspending one cuts off its researchers and
  their exports at once.
- Patients get a transparency RPC, `my_research_participation()`, returning
  their consent state, exactly what is and is not shared, how many approved
  studies currently use the data, and how to withdraw.

---

# UX & design system

## Flutter app

### Theming
- A `ThemeExtension<AppColors>` carrying **22 semantic tokens**, reached
  everywhere as `context.c.<token>` — never raw hex in screens.
- **Full light and dark themes.** `lerp()` is implemented for all 22 tokens
  including both gradient stops, so switching themes **animates smoothly**
  rather than snapping.
- Theme mode (light / dark / **system**) persisted to `SharedPreferences`;
  `notifyListeners()` fires before the disk write so the UI flips instantly.
- **Material 3**, seeded colour scheme, global `InkRipple`.
- Flat app bars with `systemOverlayStyle` flipped per theme so status-bar icons
  stay legible.
- Themed bottom sheets (26 px radius), **floating inverted snackbars**, and a
  shared input decoration theme.
- **Platform-correct page transitions** — Material fade-forwards on Android,
  Cupertino slide on iOS — plus a custom 280 ms fade for most pushes.
- **Typography** — Manrope for UI, JetBrains Mono for IDs, on a 10-step scale
  (display 28 → small 11.5) with per-step line-heights and letter-spacing.
- **Shadow set** — `card`, `brandCard` (teal glow), `button`.

### Interaction & motion
- **`PressScale`** — every tappable surface scales to 0.97 over 110 ms with
  `Curves.easeOut`, suppressed when disabled. Used in ~24 files.
- **Splash** — staggered logo fade + title slide-up, with a repeating three-dot
  wave loader; navigation waits for auth bootstrap rather than firing blind.
- **Onboarding** — `PageView` with animated pill dots (active dot widens 7→22 px).
- **OTP field** — custom boxes over an invisible real `TextField` (so keyboard,
  paste and autofill work), per-box fill animation, focus glow, and a damped
  **shake animation** on a wrong code.
- **Animated segmented controls** on login (Patient/Staff) and prescriptions
  (Active/Past); **animated dark-mode pill**; **animated FAQ accordions**
  (rotating chevron + cross-fade).
- **Gradient-masked active tab icon** in the bottom nav, with filled/outlined
  icon pairs and tap-again-to-pop-to-root.
- **Hero-wrapped QR code** on the health card.

### Loading, empty & error states
- **Three loading treatments** — shimmer skeletons that mirror the real card
  silhouette (theme-aware base/highlight colours), centred spinners, and
  in-control spinners that don't cause layout jump.
- **Determinate progress** for PDF streaming and per-file upload counters.
- **Purpose-written empty states** throughout, including a *positive* one for
  allergies and a distinction between "library empty" and "no search results".
  Several empty states carry a CTA (e.g. "Request your card").
- **Retry affordances** on staff list screens; a non-blocking amber notice
  banner on History so data still renders when a partial error occurs.
- **Pull-to-refresh on 11 screens**, several with `AlwaysScrollableScrollPhysics`
  so the gesture works on short content — including on empty lists.
- ~30 snackbar sites with consistent hygiene: messenger captured before awaits,
  `context.mounted` re-checked, and `hideCurrentSnackBar()` cascades so messages
  don't queue.

### Safety & confirmation
- **Back-press interception** on the OTP screen (`PopScope`) — "Cancel sign-up?
  Your progress will be lost", with the in-screen back chevron routed through the
  same handler.
- Confirmation dialogs for **SOS**, **logout** (bottom sheet), **account
  deletion** (with reason), and **appointment cancellation** ("Keep" / "Cancel it").
- Irreversible actions state their consequences in the dialog body.

### Forms
- Digits-only input formatters with length limits and hidden counters.
- Inline per-field errors that **clear as you type**.
- Submit buttons disabled (at 50 % opacity) until the form is valid.
- Date pickers with sensible bounds (sign-up opens 25 years back; booking opens
  tomorrow, capped at +120 days).
- Password show/hide toggles with semantic labels that flip.

### Localization & accessibility
- **English / Urdu** language switch, persisted, applied **live** — the whole
  app is wrapped in a `Directionality` so selecting Urdu flips to **RTL without
  a restart**.
- The Urdu name on the health card is always RTL regardless of app language.
- AI explanations render RTL when generated in Urdu.
- **63 accessibility annotations** — `PressScale` propagates `semanticLabel` +
  `button: true`, nav tabs expose `selected:`, icon buttons carry tooltips, and
  composed labels are used where visuals are ambiguous ("Blood group O+",
  "Cardiology, 4 records", "Download Lipid Profile").
- Touch targets ≥44 logical pixels; record type communicated by text as well as
  colour and icon.

### Responsive
- Records library switches to a **2-column grid ≥720 px**.
- Record viewer switches to a **side-by-side split ≥900 px**.
- Documents constrained to 760 px and centred so prescriptions read like a page.
- Chat bubbles capped at 78 % width; keyboard handled manually so the message
  list doesn't re-lay out.

## Web portals (admin & staff)

- **Hand-written design system** — no UI library, no CSS framework. Design
  tokens in `:root` (teal primary with semantic green/amber/red/blue pairs, each
  with a tint), 10 px radius, shared shadow, system font stack.
- Two visually distinct shells so the portals are never confused: **teal
  gradient** for admin, **slate→teal** for staff.
- **Route-level code splitting** (`React.lazy` + `Suspense`) with a spinner
  fallback; the login page stays eagerly loaded.
- **Loading modelled as `null` vs `[]`** so "still loading" and "genuinely
  empty" are always distinguishable — spinners render *inside* the table card so
  toolbars and filters stay interactive.
- **Purpose-written empty states** on every list.
- **Three-layer error handling** — a class `ErrorBoundary` with a Reload button,
  per-page inline error text, and an API layer that normalizes every Supabase
  `{data, error}` into a thrown `Error` (with `[object Object]` guarded against).
- **Humanized error messages** — raw Supabase strings are rewritten ("Invalid
  Hayaat ID or password.", "Your account is not active yet. An administrator
  must approve it.", "That doctor already has an appointment at this date and
  time.", "This weekly slot already exists.").
- **Every destructive action is modal-gated**; no raw `window.confirm`.
- **Mandatory-reason enforcement as a disabled button** (not a post-submit
  error) for doctor rejection, lab rejection, and user suspension.
- **Busy discipline** — every submit disables and swaps to a present-participle
  label ("Signing in…", "Uploading…", "Booking…", "Finalizing…"); card
  deliveries track busy **per row**.
- **Modal** with backdrop-click-to-close and `stopPropagation` so inner clicks
  never dismiss accidentally.
- **Data formatting** — Hayaat IDs rendered in 4-digit groups, monospace for
  IDs/CNICs/phones for column alignment, enum underscores stripped, and an
  explicit "—" for every nullable field.
- **Zero-dependency icon set** — 24×24 stroke SVG paths rendered with
  `currentColor`, with a safe fallback for unknown names.
- **Performance** — `Promise.all` for parallel page loads, batched `in(...)`
  lookups instead of N+1 (doctor names, unread counts).
- **React correctness** — `useRef` guard against StrictMode double-invocation
  when creating draft encounters, ref-mirrored state so realtime callbacks don't
  capture stale closures, and channel cleanup on unmount.

---

# Security model

- **Row Level Security on every table**, verified by an automated suite.
- **Role helpers as `SECURITY DEFINER` functions** — `my_role()`, `is_staff()`,
  `is_admin()`, all requiring `status = 'active'` so suspension is enforced at
  the data layer.
- **Layered care-relationship access:**
  - `staff_can_access_patient()` — doctors with an appointment/encounter,
    receptionists via a clinic appointment, lab workers via a lab order, admins.
  - `clinical_staff_can_access_patient()` — excludes receptionists.
  - **`narrative_staff_can_access_patient()`** — treating doctors and admins
    **only**. This guards encounters, conditions, prescriptions, vitals and
    allergies, so a lab technician who processes a sample **cannot read the
    consultation notes or medication history** of that patient. The lab keeps
    exactly what it needs: lab orders, lab results, and its storage folder.
- **Self-signup role escalation is blocked** — privileged roles are only trusted
  from `raw_app_meta_data`, writable solely by the service role.
- **Private storage buckets** — `lab-results` and `medical-documents` are
  read-scoped to the owner plus clinically-related staff; `card-photos` writes
  are locked to the owner's own folder. Access is always via short-lived signed
  URLs.
- **Append-only audit log** — `UPDATE`/`DELETE` revoked from `authenticated` and
  `anon`; a `BEFORE INSERT` trigger stamps role from the JWT, the server clock
  (clients cannot backdate), IP and user-agent from request headers. Insert
  policy enforces `actor_id = auth.uid()`, so nobody can frame another user.
- **Append-only consents**, stamped the same way.
- **Patient lookups self-audit** — `find_patient_by_identifier()` writes an
  audit row per successful hit.
- **Only the publishable/anon key ever reaches a client.** The service-role key
  is confined to Edge Functions and is explicitly forbidden in `.env.example`.
- **Accepted risk (documented):** `login_email()` is callable by `anon` so
  login-by-identifier can work pre-authentication; this permits ID enumeration
  and should be mitigated in production with Supabase Auth rate limits or a
  captcha rather than by removing the RPC.

---

# Data model

**31 tables.** Clinical core — `profiles`, `patient_profiles`, `doctor_profiles`,
`lab_worker_profiles`, `receptionist_profiles`, `admin_profiles`, `clinics`,
`diagnostic_labs`, `doctor_availability`, `appointments`, `encounters`,
`conditions`, `medication_requests`, `medication_logs`, `observations`,
`allergies`, `lab_orders`, `lab_results`, `medical_documents`, `cards`,
`conversations`, `messages`, `notifications`, `audit_logs`, `consents`,
`consent_preferences`, `deletion_requests`. Research platform —
`research_organizations`, `researcher_profiles`, `research_datasets`,
`research_data_requests`, plus `research_request_secrets` (holds the per-request
pseudonym salt; RLS-enabled with **no policies**, so no client can read it).

**Key RPCs** — `login_email`, `find_patient_by_identifier` /
`find_patient_by_cnic`, `available_appointment_slots`,
`request_patient_appointment`, `book_clinic_appointment`, `request_card`,
`request_physical_card`, `start_conversation`, `export_my_data`,
`set_consent_preference`, `admin_mark_deletion_request`, `gen_hayaat_id`,
`hayaat_luhn_check_digit`, plus the role/access helpers. Research —
`research_cohort_size`, `research_cohort_summary`,
`research_condition_prevalence`, `research_export_patient_features`,
`research_export_conditions`, `research_export_observations`,
`admin_decide_data_request`, `my_research_participation`.

**Triggers** — `on_auth_user_created` (profile + role-extension row + Hayaat ID
+ CNIC validation), `trg_stamp_audit`, `trg_stamp_consent`,
`trg_touch_conversation` (denormalized last-message preview),
`trg_notify_doctor_appt`, `trg_card_insert_notify`, `trg_card_physical_notify`
(both fan out to every active admin).

**Storage buckets** — `lab-results`, `medical-documents`, `card-photos` (all private).

**Realtime** — `messages`, `conversations`.

**Performance** — `perf_indexes.sql` covers every FK and filter column that RLS
policies and app queries touch, plus partial unique indexes preventing
double-booked doctor slots and duplicate availability windows.

---

# Setup

## 1. Provision Supabase (once)

Follow **[`supabase/SUPABASE_SETUP.md`](supabase/SUPABASE_SETUP.md)**. In the SQL
editor, run these **in order** (all idempotent):

```
schema.sql → cards.sql → revision.sql → security.sql → chat.sql
          → security_hardening.sql → compliance.sql → card_workflow.sql
          → perf_indexes.sql → product_hardening.sql → remove_demo_data.sql
          → hayaat_id_only.sql → patient_records.sql → cnic_identity.sql
          → clinical_narrative_rls.sql → card_number_consistency.sql
          → research_platform.sql
```

`cnic_identity.sql` restores the CNIC identity that `hayaat_id_only.sql` had
dropped, and adds `find_patient_by_identifier()`.

**On an already-deployed project**, run [`supabase/FINALIZE.sql`](supabase/FINALIZE.sql)
instead: one paste that adds everything verified missing from the live database.

`security.sql` **and** `security_hardening.sql` are mandatory. The legacy
development seed inside `schema.sql` is disabled by default — do not enable it
in staging or production.

Then turn **off** Authentication → Email → "Confirm email" in the dashboard, and
deploy the Edge Functions:

```bash
supabase functions deploy admin-create-user   # admins create staff/admin accounts
supabase functions deploy delete-account      # performs the actual account erasure
```

## 2. Configure each client's environment

Supabase URL + **publishable** key are read from environment (never the
service-role key):

```bash
cp web-admin/.env.example web-admin/.env       # VITE_SUPABASE_URL, VITE_SUPABASE_PUBLISHABLE_KEY
cp web-staff/.env.example web-staff/.env
```

For Flutter, pass them at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

If unset, all three fall back to the shared development project baked into source.

## 3. Run the web apps

```bash
cd web-admin && npm install && npm run dev      # http://localhost:5173  (admins only)
cd web-staff && npm install && npm run dev      # http://localhost:5174  (doctor/lab/receptionist)
cd web-research && npm install && npm run dev   # http://localhost:5175  (approved research orgs)
```

## 4. Run the mobile app (Flutter)

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

> Flutter on Windows needs **Developer Mode** (`ms-settings:developers`) enabled
> for plugin symlinks before `flutter pub get` will succeed.

## 5. Enable the AI record explainer (optional)

1. Install **LM Studio**, load a chat model, and start its local server
   (Developer → Start Server, default `localhost:1234`).
2. For **web builds**, turn on **Enable CORS** in the server settings — the app
   and LM Studio run on different localhost ports.
3. Non-default host/model:
   `--dart-define=LM_STUDIO_URL=http://<host>:<port>/v1`
   `--dart-define=LM_STUDIO_MODEL=<model-id>`

Without LM Studio running, every other feature works normally; the explainer
shows a clear "could not reach LM Studio" message.

---

# Testing & verification

```bash
# Full integration check: Admin -> Database -> Lab -> Doctor -> Patient.
# Verifies CNIC lookup, ordering, sample tracking, result upload, review,
# release, patient visibility, signed-URL download, and cross-patient isolation.
node supabase/tests/verify_e2e.mjs

# Automated Row Level Security suite (signs in as every role, asserts every policy)
cd supabase/tests && npm install && npm test          # expect: 27 passed, 0 failed

# Card → admin-notification workflow, end to end
node supabase/tests/verify_card_workflow.mjs           # expect: 6 passed, 0 failed

# Privacy verification for the research platform: signs in as a real researcher
# and tries to reach what it must not — direct table reads, k-anonymity bypass,
# self-approval, the pseudonym salt, and identifier columns in an extract.
node supabase/tests/verify_research_privacy.mjs

# Web apps
cd web-admin && npm run build                          # tsc -b + vite build
cd web-staff && npm run build
cd web-research && npm run build

# Mobile
flutter analyze                                        # no errors
flutter test                                           # PDF builders + widget test
```

## Test data seeding

```bash
# 65 fake Pakistani accounts (50 patients, 8 doctors, 3 lab workers,
# 3 receptionists, 1 admin). Paces itself around Supabase's sign-up rate limit.
node supabase/tests/seed_fake_pk_data.mjs
# then paste the generated fake_pk_data_promote.generated.sql into the SQL editor
# (creates clinics/labs and promotes the staff roles)

# Clinical history for 10 of those patients: finalized encounters across 8
# specialties, prescriptions, vitals, lab orders + released results with real
# PDFs, allergies, appointments, and a chat thread.
node supabase/tests/seed_clinical_data.mjs

# Research platform: a demo organisation + researcher account.
node supabase/tests/seed_research_account.mjs
# then paste the generated research_account_promote.generated.sql into the SQL editor

# Opt patients in to research so the portal has a cohort. Uses the same
# set_consent_preference RPC the app's Consent Management screen calls —
# there is no back door. Re-run with --off to withdraw and watch the
# cohort shrink immediately.
node supabase/tests/seed_research_consent.mjs
```

All seeding goes through the **ordinary public API as the signed-in role**, so
it is bound by exactly the same RLS policies as a real user — a successful seed
is itself a policy test.

## CI

GitHub Actions (`.github/workflows/`):
- **Web** (matrix over both apps) — typecheck, build, high-severity dependency
  audit, and build-artifact upload.
- **Flutter** — static analysis + unit/widget tests.
- **RLS policy suite** against Supabase.
- **CodeQL** scanning, plus Dependabot.

---

# Demo & test accounts

**Fake test dataset** (`seed_fake_pk_data.mjs`) — password `Hayaat@2026`,
sign in with CNIC, email, or phone:

| Role | Example account |
| ---- | --------------- |
| Patient | `ahmed.hussain1@hayaatfake.id` · CNIC `3520202000001` |
| Doctor | `dr.ahmed.hussain1@hayaatfake.id` (General Medicine, Al-Shifa) |
| Lab worker | `ahmed.hussain1.lab@hayaatfake.id` (Punjab Diagnostic Lab) |
| Receptionist | `ahmed.hussain1.front@hayaatfake.id` (Al-Shifa) |
| Admin | `fake.admin@hayaatfake.id` |
| Researcher | `researcher@hayaatfake.id` (Punjab Health Research Institute) |

**Original demo set** (`seed_demo_accounts.mjs` + `demo_seed.sql`) — password
`Hayaat@2026`, sign in with the CNIC:

| Role | CNIC | Email |
| ---- | ---- | ----- |
| Admin | `3520100000001` | demo.admin@hayaat.id |
| Doctor | `3520199999991` | demo.doctor@hayaat.id |
| Lab worker | `3520177777771` | demo.lab@hayaat.id |
| Receptionist | `3520166666661` | demo.reception@hayaat.id |
| Patient | `3520112345671` | demo.patient@hayaat.id |
| Patient (2nd, isolation checks) | `3520112345672` | demo.patient2@hayaat.id |

Staff roles are promoted by SQL rather than by the seeding script because
self-service sign-up is deliberately clamped to patient/doctor.

---

# Known gaps

## Blocked on credentials or a product decision
- **OTP** — sign-up OTP is a hardcoded development code (`11111`); a real
  SMS/OTP provider (e.g. Twilio) is not wired up.
- **MFA & email password reset** — need an SMS/email provider configured in
  Supabase Auth.
- **Device push (FCM)** — notifications are in-app only; background push needs a
  Firebase project + `google-services.json`.
- **Email / WhatsApp notifications** — not built. WhatsApp requires a Meta
  Business API account with template approval.
- **Automated deploy** — no hosting provider chosen; manual deploy from CI
  artifacts works today (see `docs/DEPLOYMENT.md`).
- **NADRA identity verification** — out of scope per the prototype spec.

## Known implementation issues
- **Lab result file links don't render on the doctor's review page** — the page
  reads `result_file_url`, but lab upload persists `result_file_path` (a private
  bucket path) and no signed URL is generated for it.
- **`/doctor/*` routes in web-staff are not role-gated** — they are registered
  for every role; separation currently relies on the default redirect, the
  role-filtered sidebar, and RLS blocking the data.
- **No router-level auth gate in Flutter** — go_router has no `redirect`, so
  routes are reachable while logged out; screens defend individually with null
  checks rather than bouncing to `/login`.
- **Urdu coverage is thin** — RTL flips correctly and the nav/settings are
  translated, but only ~25 translation keys exist and only two files call
  `context.tr`; most copy stays English. `localizationsDelegates` is also not
  declared, so Material built-ins (date picker, selection menus) won't localize.
- **`FakeLoader` adds a fixed 1.5 s delay** to History, Reports, Prescriptions
  and Messages on every visit, even when the data is already in memory.
- **Web portals are desktop-only** — there is not a single `@media` query in
  either portal, and neither has a dark mode (the Flutter app has both).
- **No pagination anywhere in the web portals** — users, clinics, deliveries and
  deletion requests fetch unbounded sets; the audit log is hard-capped at 200
  with no "load more", filters, search, or export.
- **Some raw exception strings reach the user** on staff/FutureBuilder screens.
- **Orphaned draft encounters** — the doctor's encounter page creates a draft row
  on open, and navigating away without finalizing leaves it behind; there is no
  discard action.
- **No haptics** anywhere in the Flutter app, including on error shake and
  destructive confirmations.
- Lab rejection reasons and reactivation notes are collected in the admin UI but
  not persisted.
- **Research platform caveats** — organisations are onboarded by an
  administrator rather than self-registering; k is fixed at 5 rather than being
  configurable per dataset; there is no differential-privacy noise layer on top
  of k-anonymity; and export volume is recorded (`export_count`) but not rate-
  limited. Extracts are generated in the browser, so a very large cohort will be
  memory-bound — server-side streaming would be the next step for production scale.

Do not treat the system as production-ready until the OTP/MFA, push, deploy, and
the lab-result-link items above are resolved.

---

# Where the spec maps to code

- DB schema, RLS, triggers, seed → `supabase/*.sql` (setup: `supabase/SUPABASE_SETUP.md`)
- Privileged server ops → `supabase/functions/*`
- RLS verification & seeding → `supabase/tests/`
- Client data access → `lib/services/*` (Flutter), `web-*/src/api/*` (React)
- Research platform → `docs/RESEARCH_PLATFORM.md` (threat model + operations), `supabase/research_platform.sql`, `web-research/`, `supabase/tests/verify_research_privacy.mjs`
- Design system → `lib/theme/*`, `lib/widgets/common/*` (Flutter); `web-*/src/index.css` + `components/ui.tsx` (React)
- Records library model → `docs/PATIENT_RECORDS_LIBRARY.md`, `lib/models/medical_specialty.dart`
- CI/CD & deployment → `.github/workflows/`, `docs/DEPLOYMENT.md`, `docs/OPERATIONS_RUNBOOK.md`
- Legal & compliance → `docs/legal/`
- Requirement traceability → `P-FR-*` IDs cited inline in code comments and UI copy
