# CNIC-Based Health Card System

A centralized digital health-card platform for Pakistan: every citizen's medical
history is linked to their CNIC, accessible to any approved clinic, hospital, or
lab with consent. This repository implements the **investor prototype** described
in `docs/ibbi docs/CNIC_Health_Card_PROTOTYPE_Scope.pdf` (the production
reference is `CNIC_Health_Card_System_Design.pdf`).

## The three parts (kept cleanly separated)

| Folder        | Stack                     | Serves                                   |
| ------------- | ------------------------- | ---------------------------------------- |
| `backend/`    | Node.js + Express         | Shared REST API for every role + both web apps |
| `lib/`        | Flutter (Android + iOS)   | **Mobile** — patient · doctor · lab worker · receptionist |
| `web-admin/`  | React 18 + TypeScript (Vite) | **Admin web app** — administrators only |
| `web-staff/`  | React 18 + TypeScript (Vite) | **Staff web app** — doctor · lab worker · receptionist (role-routed) |

> The mobile app (`lib/`) and the two web apps (`web-admin/`, `web-staff/`) are
> entirely separate codebases. They share nothing but the backend's HTTP contract.
> The mobile app remains available for doctor/lab/receptionist too — staff can use
> phone or web; admins are web-only; patients are mobile-only.

## The five roles

| Role          | Client      | Highlights                                                        |
| ------------- | ----------- | ----------------------------------------------------------------- |
| Patient       | Mobile      | Health timeline, prescriptions, lab results, book appointments    |
| Doctor        | Mobile + Web (`web-staff`) | Search patient by CNIC, encounters, prescribe (with allergy check), lab orders, review/release results, availability |
| Lab worker    | Mobile + Web (`web-staff`) | Priority order queue, sample tracking, result upload (masked patient identity) |
| Receptionist  | Mobile + Web (`web-staff`) | Clinic schedule, walk-in booking, check-in (demographics only)    |
| Admin         | Web (`web-admin`) | Approve doctors/labs, suspend/reactivate users, clinics, dashboard, audit log |

## Architecture decision

The prototype uses the existing **Node/Express** backend as its API layer with an
in-memory data store that mirrors the 12 prototype tables. Supabase/PostgreSQL,
HAPI FHIR, NADRA verification, OTP/MFA, and offline mode remain **production**
concerns (per the scope document) and are intentionally out of scope here.

## Running the prototype

### 1. Backend (required by both apps)

```bash
cd backend
npm install
npm start          # http://localhost:3000   (API under /api)
```

### 2. Web apps

```bash
# Admin web app
cd web-admin && npm install && npm run dev     # http://localhost:5173

# Staff web app (doctor / lab worker / receptionist)
cd web-staff && npm install && npm run dev     # http://localhost:5174
```

Both proxy `/api` → `:3000`. The admin app accepts only `admin` accounts; the
staff app accepts `doctor`, `lab_worker`, and `receptionist` (role-routed into
the right workspace). Each uses its own session key so they can run side by side.

### 3. Mobile app (Flutter)

```bash
# From the repo root. Requires Windows Developer Mode enabled for plugin symlinks.
flutter pub get
flutter run --dart-define=WIFI_IP=<your-machine-LAN-IP>
```

Point the mobile app at your machine's LAN IP (see `lib/services/api_config.dart`)
so a physical device can reach the backend.

## Demo accounts (password: `password123`)

| Role          | Login (CNIC)      |
| ------------- | ----------------- |
| Patient       | `3520112345671`   |
| Doctor        | `3520199999991`   |
| Lab worker    | `3520177777771`   |
| Receptionist  | `3520166666661`   |
| Admin (web)   | `3520100000001`   |

There is also a **pending** doctor (`3520188888882`) and a **pending lab** so the
admin approval queue is populated for a live demo.

## Status & setup notes

The full prototype scope (P-FR-001 … P-FR-055) is implemented across backend, web, and mobile and verified end-to-end. Two environment notes:

- **Flutter requires Windows Developer Mode** (`ms-settings:developers`) for plugin symlinks before `flutter pub get` will succeed. The mobile app adds the `file_picker` plugin (lab result upload), so this is required to build.
- **Device push (FCM)** is the one remaining *production* add-on: notifications are created server-side and delivered **in-app** (every role can read `/me/notifications`; the patient app shows them live). Background push to the device needs a Firebase project + `google-services.json`, which is outside the prototype stack per the scope document.

## Where the spec maps to code

- API surface (Scope §11) → `backend/src/routes/*.routes.js`
- DB schema (Scope §4) → `backend/src/store.js` + `backend/src/seed.js`
- RBAC & audit (Scope §12, §15) → `backend/src/middleware.js`, `backend/src/audit.js`
- State machines (Scope §10) → status transitions in the route handlers
- Role permission matrix (Scope §13) → `requireRole(...)` guards per route
