# HayaatID — Supabase setup (one-time, ~2 minutes)

The apps talk directly to Supabase (project `iikwdtiqvxxatrzahuzo`). Do these
three steps once.

## 1. Create the database
Supabase dashboard → **SQL Editor** → **New query** → paste the entire contents
of [`schema.sql`](./schema.sql) → **Run**.

Then run [`cards.sql`](./cards.sql) the same way (card numbers, the `cards`
table, request RPCs, and the `card-photos` storage bucket).

This creates every table, the security policies (RLS), the signup trigger, the
storage buckets, and demo accounts + data. Both files are safe to re-run.

## 2. Turn OFF email confirmation
Because logins use CNIC (mapped internally to `<cnic>@hayaat.id`), there are no
real inboxes to confirm.

Dashboard → **Authentication** → **Providers** → **Email** → turn **OFF**
"Confirm email" → Save.

(Also fine to leave "Enable Sign Ups" ON so patients/doctors can self-register.)

## 3. You're done
The apps are already wired with your keys:
- URL: `https://iikwdtiqvxxatrzahuzo.supabase.co`
- anon key: configured in `lib/services/supabase_client.dart` (mobile) and
  `web-admin/.env` · `web-staff/.env` (web).

## Login model
- **New patients** sign up with name + phone + password (email optional) and **log in with their phone number**.
- **Staff** (and the seeded demo accounts below) **log in with their CNIC**.
- After signing up, a patient taps **"Request your card"** to set DOB / blood group / city / Urdu name / photo and receive a `HAY-PAT-####` number + virtual card.

## Demo accounts — login with the **CNIC** shown + password (`password123`)
| Role | CNIC |
|---|---|
| Patient | `3520112345671` |
| Doctor | `3520199999991` |
| Lab worker | `3520177777771` |
| Receptionist | `3520166666661` |
| Admin (web) | `3520100000001` |

Pending doctor `3520188888882` and a pending lab seed the admin approval queue.

## Web apps (also on Supabase now)
Both web apps talk to Supabase directly (no Node backend):
```bash
cd web-admin && npm install && npm run dev   # http://localhost:5173  (admins)
cd web-staff && npm install && npm run dev   # http://localhost:5174  (doctor/lab/reception)
```

### Optional: enable admin "Create staff/admin account"
Creating a new auth user needs the service role, so it runs in an Edge Function.
Deploy it once (requires the Supabase CLI):
```bash
supabase functions deploy admin-create-user
```
Everything else in the admin portal (approvals, suspend/reactivate, clinics,
dashboard, audit) works without it. The function lives in
`supabase/functions/admin-create-user/`.

## Notes
- New patient/doctor signups go through Supabase Auth and persist immediately.
- Data is stored in your Supabase Postgres — it persists across restarts, shared by mobile + both web apps.
- Lab-result files upload to the public `lab-results` storage bucket; card photos to `card-photos`.
- The old Node backend in `/backend` is no longer used by any app (kept for reference).
