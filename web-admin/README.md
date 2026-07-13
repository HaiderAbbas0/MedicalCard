# HayaatID — Admin Web Portal

React + TypeScript (Vite) web portal for **system administrators** of the HayaatID
Health Card System.

The platform has two web apps:
- **`web-admin/`** (this app) — administrators only.
- **`web-staff/`** — doctors, lab workers, and receptionists (clinic staff), role-routed.

Patients use the Flutter mobile app at the repository root (`/lib`).

## What it does (Scope §11.6, §13)

- **Dashboard** — aggregate stats (patients, doctors, pending applications, appointments today, pending lab orders).
- **Doctor applications** — review, approve, or reject pending doctor registrations (rejection requires a reason).
- **Lab applications** — approve / reject diagnostic-lab registrations.
- **Users** — search/filter all accounts; suspend (with reason) and reactivate.
- **Clinics** — create and list clinics / hospitals.
- **Audit log** — view the append-only audit trail.

Only accounts with role `admin` can sign in here; any other role is rejected.

## Run

This app talks **directly to Supabase** — there is no backend to start. First
apply the SQL in `supabase/` (see `supabase/SUPABASE_SETUP.md`), then:

```bash
cp .env.example .env    # set VITE_SUPABASE_URL + VITE_SUPABASE_PUBLISHABLE_KEY
npm install
npm run dev             # http://localhost:5173
```

If `.env` is omitted, it falls back to the shared dev/demo project baked into
`src/api/supabase.ts`.


## Structure

```
src/
  api/          fetch client + shared types
  auth/         AuthContext (session + login)
  components/   Layout, sidebar, reusable UI (Modal, StatusBadge, Spinner)
  pages/        one file per screen
  App.tsx       routing + protected routes
```
