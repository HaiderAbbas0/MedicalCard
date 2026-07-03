# CNIC-Based Health Card System

A centralized digital health-card platform for Pakistan: every citizen's medical
history is linked to their CNIC, accessible to any approved clinic, hospital, or
lab with consent. This repository implements the system described in
`docs/ibbi docs/CNIC_Health_Card_System_Design.pdf` (prototype scope:
`CNIC_Health_Card_PROTOTYPE_Scope.pdf`).

## Architecture: Supabase-first (single production backend)

**Supabase is the one production backend.** All three client apps talk to it
directly — there is no separate application API server in production.

```
                         ┌──────────────────────────────────────┐
                         │              Supabase                 │
   Flutter (lib/) ─────► │  Auth · Postgres (RLS) · Storage ·    │
   web-admin/     ─────► │  Edge Functions (service-role only)   │
   web-staff/     ─────► │                                       │
                         └──────────────────────────────────────┘
```

| Layer | Responsibility |
| ----- | -------------- |
| **Supabase Auth** | Identity, sessions, JWTs. Login via CNIC/phone/card-number → `<id>@hayaat.id`. |
| **Supabase Postgres** | All data. 21 tables, **Row Level Security on every table**, `SECURITY DEFINER` role helpers, triggers. See `supabase/`. |
| **Supabase Storage** | `lab-results` (private, signed-URL access) and `card-photos` buckets. |
| **Supabase Edge Functions** | Privileged, server-only operations that must use the service-role key (e.g. `admin-create-user`). Never done from the client. |

> **The `backend/` folder (Node/Express) is demo-only and NOT part of the
> production architecture.** It is a legacy in-memory prototype kept solely so the
> mobile chat screen has something to call until messaging is migrated to Supabase
> Realtime. Do not build new features against it. See `backend/README.md`.

## The clients

| Folder        | Stack                     | Serves                                   |
| ------------- | ------------------------- | ---------------------------------------- |
| `lib/`        | Flutter (Android + iOS)   | **Mobile** — patient · doctor · lab worker · receptionist |
| `web-admin/`  | React 18 + TS (Vite, :5173) | **Admin web app** — administrators only |
| `web-staff/`  | React 18 + TS (Vite, :5174) | **Staff web app** — doctor · lab worker · receptionist (role-routed) |

## The five roles

| Role          | Client      | Highlights                                                        |
| ------------- | ----------- | ----------------------------------------------------------------- |
| Patient       | Mobile      | Health timeline, prescriptions, lab results, book appointments    |
| Doctor        | Mobile + Web | Search patient by CNIC, encounters, prescribe (allergy check), lab orders, review/release results, availability |
| Lab worker    | Mobile + Web | Priority order queue, sample tracking, result upload (masked patient identity) |
| Receptionist  | Mobile + Web | Clinic schedule, walk-in booking, check-in (demographics only)    |
| Admin         | Web         | Approve doctors/labs, suspend/reactivate users, clinics, dashboard, audit log |

## Setup

### 1. Provision Supabase (once)

Follow **`supabase/SUPABASE_SETUP.md`**. In order, run against your project's SQL
editor: `schema.sql` → `cards.sql` → `revision.sql` → `security.sql` →
`fix_demo_login.sql`. `security.sql` is **mandatory** — it hardens the RLS
policies. Then, in the dashboard, turn OFF Authentication → Email → "Confirm
email". Optionally deploy the Edge Function:

```bash
supabase functions deploy admin-create-user
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

If unset, all three fall back to the shared dev/demo project baked into source.

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

## Demo accounts (password: `password123`)

| Role          | Login (CNIC)      |
| ------------- | ----------------- |
| Patient       | `3520112345671`   |
| Doctor        | `3520199999991`   |
| Lab worker    | `3520177777771`   |
| Receptionist  | `3520166666661`   |
| Admin (web)   | `3520100000001`   |

A **pending** doctor (`3520188888882`) is seeded so the admin approval queue is
populated for a live demo. Passwords are bcrypt-hashed in Postgres.

## Known production gaps (tracked, being hardened phase-by-phase)

- **OTP** — signup OTP is a hardcoded demo code (`11111`); a real OTP/SMS
  provider is not yet wired.
- **Device push (FCM)** — notifications are in-app only; background push needs a
  Firebase project + `google-services.json`.
- **MFA, password policy, rate limiting, legal/compliance pages, CI/CD** —
  in progress. Do not consider this production-ready until these land and are
  verified end-to-end.

### Recently landed
- **Real messaging** — patient↔doctor chat now runs on Supabase (`conversations`
  + `messages`, participant-only RLS, realtime). Patient side in the Flutter app;
  doctor side in `web-staff` (**Messages**). Requires `supabase/chat.sql` applied.
  The old fake chat (Node stub, mock fallback, simulated replies) is gone.
- **Security hardening** (`supabase/security_hardening.sql`) — `is_staff()` gated on
  active status, `card-photos` write locked to owner, append-only + IP/device-stamped
  audit logs, password policy on all sign-up forms. Verified by the RLS test suite
  (`supabase/tests`).
- **CI/CD** — GitHub Actions (`.github/workflows`): web typecheck/build, Flutter
  analyze/test, RLS suite, CodeQL, Dependabot. See `docs/DEPLOYMENT.md`.
- **Compliance** — legal pages (Privacy/Terms) in all clients, consent recorded at
  sign-up (`consents`), self-service data export (`export_my_data()`), account-deletion
  requests + admin queue + `delete-account` Edge Function. Legal docs in `docs/legal/`.
  Requires `supabase/compliance.sql` applied.

## Where the spec maps to code

- DB schema, RLS, triggers, seed → `supabase/*.sql`
- Privileged server ops → `supabase/functions/*`
- Client data access → `lib/services/*` (Flutter), `web-*/src/api/*` (React)
- Setup + demo accounts → `supabase/SUPABASE_SETUP.md`
