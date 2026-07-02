# CNIC Health Card — Prototype API

Modular Node/Express backend implementing the prototype API surface (Scope §11).
In-memory data store stands in for Supabase/PostgreSQL; the route layer is written
so the store can be swapped for a real database without changes.

## Run

```bash
npm install
npm start        # http://localhost:3000
```

Dependency-light: only `express` + `cors`. Tokens are HMAC-signed using Node's
built-in `crypto` (no JWT library needed for the prototype).

## Structure

```
server.js                 app wiring, route mounting, demo account banner
src/
  store.js                in-memory tables (12 prototype tables) + helpers
  seed.js                 demo data: clinics, labs, one account per role, full history
  token.js                sign/verify signed access tokens (60-min TTL)
  middleware.js           authenticate + requireRole (RBAC, fall-through on mismatch)
  audit.js                append-only audit log helper
  notify.js               in-DB notification helper (simulated FCM)
  helpers.js              CNIC validation, auth response builder, async wrapper
  routes/
    auth.routes.js        register (patient/doctor), login (lockout), logout, refresh
    patient.routes.js     /me/*, timeline, medications, labs, appointments, doctor search
    doctor.routes.js      patient search, encounters, conditions, meds, vitals, lab orders, availability
    lab.routes.js         order queue, sample tracking, result upload (masked patient)
    receptionist.routes.js clinic schedule, walk-in booking, check-in
    admin.routes.js       approvals, user suspend/reactivate, clinics, dashboard, audit
    legacy.routes.js      back-compat shims for the original patient demo build
```

## Auth

`POST /api/auth/login` accepts `{ identifier, password }` where `identifier` is a
CNIC, email, or phone. The response is `{ token, user }`; `user.role` drives
client routing. The role used for authorization is always read from the stored
profile — never trusted from the client (Scope §12.2).

Notable rules implemented:

- One CNIC → one account of any role (P-FR-005)
- Doctors register **pending**; cannot log in until an admin approves (P-FR-002/003)
- 5 failed logins → 30-minute lockout (P-FR-006)
- Allergy conflict warning on prescription (P-FR-034)
- Lab workers see only their lab's orders, with masked patient identity (P-FR-039)
- Receptionists see demographic + appointment data only — no clinical records (P-FR-044)

## Demo accounts

All use password `password123`. See the startup banner for the CNIC of each role.
