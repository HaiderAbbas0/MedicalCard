# HayaatID Health Platform

A centralized digital health-card platform for Pakistan. Every citizen is
identified by their **13-digit CNIC** — that is the key they register with, log
in with, and that a doctor types to pull up their record (prototype scope
P-FR-001/002/005/019). On top of that identity each account is also issued a
random, unique, **16-digit Hayaat ID**: the number printed on the physical and
virtual health card. The two are complementary — CNIC identifies the person,
the Hayaat ID identifies the card.

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
| **Supabase Postgres** | All data. **Row Level Security on every table** (verified by an automated suite), `SECURITY DEFINER` role helpers, triggers, audit log. See `supabase/`. |
| **Supabase Storage** | `lab-results` (private, signed-URL access) and `card-photos` (owner-write) buckets. |
| **Supabase Realtime** | Live delivery of chat messages between patient and doctor. |
| **Supabase Edge Functions** | Privileged, server-only operations that need the service-role key: `admin-create-user`, `delete-account`. Never done from the client. |

> There is **no application server** and no container in this architecture. The
> earlier Node/Express prototype (`backend/`) has been **removed** — every client
> talks to Supabase directly.

## The clients

| Folder        | Stack                        | Serves                                   |
| ------------- | ---------------------------- | ---------------------------------------- |
| `lib/`        | Flutter (Android + iOS)      | **Mobile** — patient · doctor · lab worker · receptionist |
| `web-admin/`  | React 18 + TS (Vite, :5173)  | **Admin web app** — administrators only |
| `web-staff/`  | React 18 + TS (Vite, :5174)  | **Staff web app** — doctor · lab worker · receptionist (role-routed) |

## The five roles

| Role          | Client       | Highlights                                                        |
| ------------- | ------------ | ----------------------------------------------------------------- |
| Patient       | Mobile       | Health timeline, prescriptions, lab results, book appointments, **chat with doctors**, digital card, **data export / account deletion** |
| Doctor        | Mobile + Web | **Search patient by CNIC**, encounters, prescribe (allergy check), lab orders, review/release results, availability, **Messages** |
| Lab worker    | Mobile + Web | Priority order queue, sample tracking, result upload (masked patient identity) |
| Receptionist  | Mobile + Web | Clinic schedule, walk-in booking, check-in (demographics only)    |
| Admin         | Web          | Approve doctors/labs, suspend/reactivate users, clinics, dashboard, audit log, **notification bell**, **card-delivery queue**, **account-deletion requests** |

## Implemented features

- **Auth & RBAC** — Supabase Auth; roles in `profiles.role`; database-enforced
  Row Level Security on every table. Suspended/pending staff have no data access.
- **Clinical records** — encounters, conditions, prescriptions (with live allergy
  check), vitals, allergies, lab orders/results (FHIR-aligned).
- **Real messaging** — patient↔doctor chat on Supabase (`conversations` +
  `messages`, participant-only RLS, **Realtime**). Patient side in Flutter; doctor
  side is the `web-staff` **Messages** page. (The old fake/stub chat is gone.)
- **Digital + physical card** — patients request a card (issued instantly with a
  16-digit Hayaat ID); can request physical delivery.
- **Card workflow → admin notifications** — applying for a card, or requesting
  delivery, sends an in-app notification to every admin (bell in the admin portal),
  and physical requests appear in the admin **Card Deliveries** queue.
- **Security hardening** (`supabase/security_hardening.sql`) — `is_staff()` gated
  on active status, `card-photos` writes locked to the owner's folder, `audit_logs`
  strictly append-only and stamped server-side with IP / device / role / time,
  password policy on every sign-up form.
- **Compliance** — Privacy/Terms pages in all clients, consent recorded at sign-up
  (`consents`), self-service **data export** (`export_my_data()`), **account-deletion**
  requests + admin queue + `delete-account` Edge Function. Legal docs in `docs/legal/`.
- **Automated RLS test suite** (`supabase/tests/`) — signs in as every role and
  asserts each policy.
- **CI/CD** — GitHub Actions: web typecheck/build, Flutter analyze/test, the RLS
  suite, CodeQL, Dependabot. See `docs/DEPLOYMENT.md`.

## Setup

### 1. Provision Supabase (once)

Follow **[`supabase/SUPABASE_SETUP.md`](supabase/SUPABASE_SETUP.md)**. In the SQL
editor, run these **in order** (all idempotent):

```
schema.sql → cards.sql → revision.sql → security.sql → chat.sql
          → security_hardening.sql → compliance.sql → card_workflow.sql
          → perf_indexes.sql → product_hardening.sql → remove_demo_data.sql
          → hayaat_id_only.sql → patient_records.sql → cnic_identity.sql
          → clinical_narrative_rls.sql → card_number_consistency.sql
```

`cnic_identity.sql` restores the CNIC identity that `hayaat_id_only.sql` had
dropped, and adds `find_patient_by_identifier()` — the staff-only lookup the
doctor and receptionist screens use. It keeps the Hayaat card number intact.

**On an already-deployed project**, run [`supabase/FINALIZE.sql`](supabase/FINALIZE.sql)
instead: one paste that adds everything verified missing from the live database
(booking RPCs, the corrected `request_card()` signature, CNIC identity, and the
demo bootstrap).

`security.sql` **and** `security_hardening.sql` are mandatory (they harden RLS).
The legacy development seed inside `schema.sql` is disabled by default. Do not
enable it in staging or production.
Then turn OFF Authentication → Email → "Confirm email" in the dashboard. Deploy the
Edge Functions (optional but recommended):

```bash
supabase functions deploy admin-create-user   # admins create staff/admin accounts
supabase functions deploy delete-account       # performs the actual account erasure
```

### 2. Configure each client's environment

Supabase URL + **publishable** key are read from environment (never the
service-role key). Copy the example files and fill in your project values:

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

### 3. Run the web apps

```bash
cd web-admin && npm install && npm run dev     # http://localhost:5173  (admins only)
cd web-staff && npm install && npm run dev     # http://localhost:5174  (doctor/lab/receptionist)
```

### 4. Run the mobile app (Flutter)

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

> Flutter on Windows needs **Developer Mode** (`ms-settings:developers`) enabled
> for plugin symlinks before `flutter pub get` will succeed.

## Testing & verification

```bash
# Full integration check: Admin -> Database -> Lab -> Doctor -> Patient.
# Creates the demo lab reports on first run and then verifies every hand-off:
# CNIC lookup, ordering, sample tracking, result upload, review, release,
# patient visibility, signed-URL download, and cross-patient isolation.
node supabase/tests/verify_e2e.mjs

# Automated Row Level Security suite (signs in as every role, asserts every policy)
cd supabase/tests && npm install && npm test          # expect: 27 passed, 0 failed

# Card → admin-notification workflow, end to end
node supabase/tests/verify_card_workflow.mjs           # expect: 6 passed, 0 failed

# Web apps
cd web-admin && npm run build                          # tsc -b + vite build
cd web-staff && npm run build

# Mobile
flutter analyze                                        # no errors/warnings
```

Last verified (against the live dev project): RLS suite **27/27**, card workflow
**6/6**, `flutter analyze` clean, both web apps build cleanly.

## Demo accounts

Created by `node supabase/tests/seed_demo_accounts.mjs`, then given their staff
roles by `supabase/demo_seed.sql`. Password for all six: `Hayaat@2026`.
Sign in with the CNIC.

| Role | CNIC | Email |
| ---- | ---- | ----- |
| Admin | `3520100000001` | demo.admin@hayaat.id |
| Doctor | `3520199999991` | demo.doctor@hayaat.id |
| Lab worker | `3520177777771` | demo.lab@hayaat.id |
| Receptionist | `3520166666661` | demo.reception@hayaat.id |
| Patient | `3520112345671` | demo.patient@hayaat.id |
| Patient (2nd, for isolation checks) | `3520112345672` | demo.patient2@hayaat.id |

Self-service sign-up can only create `patient` and `doctor` accounts — the role
is clamped in `handle_new_user()` so nobody can register themselves as an admin.
That is why the staff roles are promoted by `demo_seed.sql` rather than by the
seeding script.

## Known gaps / blocked (need credentials or a product decision)

- **OTP** — sign-up OTP is a hardcoded development code (`11111`); wiring a real OTP/SMS
  provider (e.g. Twilio) is pending.
- **MFA & email password reset** — need an SMS/email provider configured in
  Supabase Auth.
- **Device push (FCM)** — notifications are in-app only; background push needs a
  Firebase project + `google-services.json`.
- **Automated deploy** — a hosting provider hasn't been chosen; manual deploy from
  CI build artifacts works today (see `docs/DEPLOYMENT.md`).
- **NADRA identity verification** — out of scope per the prototype spec.

Do not treat the system as fully production-ready until the OTP/MFA, push, and
deploy items above are resolved.

## Where the spec maps to code

- DB schema, RLS, triggers, seed → `supabase/*.sql` (setup: `supabase/SUPABASE_SETUP.md`)
- Privileged server ops → `supabase/functions/*`
- RLS verification → `supabase/tests/`
- Client data access → `lib/services/*` (Flutter), `web-*/src/api/*` (React)
- CI/CD & deployment → `.github/workflows/`, `docs/DEPLOYMENT.md`
- Legal & compliance → `docs/legal/`
