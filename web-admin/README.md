# CNIC Health Card — Admin Web Portal

React + TypeScript (Vite) web portal for **system administrators** of the CNIC
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

```bash
# 1. start the backend API (separate terminal, from /backend)
cd ../backend && npm install && npm start      # http://localhost:3000

# 2. start the admin portal
npm install
npm run dev                                     # http://localhost:5173
```

The Vite dev server proxies `/api` → `http://localhost:3000`, so both apps share
one origin in development.

**Demo admin:** CNIC `3520100000001` · password `password123`.

## Structure

```
src/
  api/          fetch client + shared types
  auth/         AuthContext (session + login)
  components/   Layout, sidebar, reusable UI (Modal, StatusBadge, Spinner)
  pages/        one file per screen
  App.tsx       routing + protected routes
```
