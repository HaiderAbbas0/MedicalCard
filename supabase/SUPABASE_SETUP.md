# HayaatID — Supabase setup (one-time, ~2 minutes)

The apps talk directly to Supabase (project `iikwdtiqvxxatrzahuzo`). Do these
three steps once.

## 1. Create the database
Supabase dashboard → **SQL Editor** → **New query**. Paste and **Run** each file
**in this exact order** (all are idempotent / safe to re-run):

1. [`schema.sql`](./schema.sql) — tables, base RLS, signup trigger, buckets, demo accounts + data
2. [`cards.sql`](./cards.sql) — card numbers, the `cards` table, request RPCs, `card-photos` bucket
3. [`revision.sql`](./revision.sql) — `medication_logs`, card-number assignment at signup, `login_email` RPC
4. [`security.sql`](./security.sql) — **MANDATORY.** Hardens the RLS policies (restricts PHI to owner/staff, makes the `lab-results` bucket private, prevents self-signup role escalation and audit-log forgery). The DB is **not safe without this.**
5. [`fix_demo_login.sql`](./fix_demo_login.sql) — fixes NULL auth token columns on the seeded demo accounts
6. [`chat.sql`](./chat.sql) — real patient↔doctor messaging (`conversations` + `messages` tables, RLS, realtime)
7. [`security_hardening.sql`](./security_hardening.sql) — Phase-5 fixes: gate `is_staff()` on `status = 'active'` (so suspended/pending staff lose data access), restrict `card-photos` writes to the owner's folder, make `audit_logs` strictly append-only, and stamp every audit entry with the server-observed IP / device / role / time (clients can't spoof them)
8. [`compliance.sql`](./compliance.sql) — consent storage (`consents`), account-deletion requests (`deletion_requests`), and the `export_my_data()` data-portability function
9. [`card_workflow.sql`](./card_workflow.sql) — notifies admins in-app when a patient applies for a card or requests physical delivery, and lets admins mark cards delivered
10. [`perf_indexes.sql`](./perf_indexes.sql) — performance indexes on the foreign-key / filter columns used by queries and RLS (patient timeline, patient search, lab queue, notifications, audit). Safe to run any time.

> Order matters: `security.sql` re-defines policies created by `schema.sql`, and
> `security_hardening.sql` re-defines `is_staff()` from `security.sql` — so run
> them in the numbered order.

### Verify the policies (optional but recommended)
An automated suite signs in as every role and asserts each policy:
```bash
cd supabase/tests && npm install && npm test    # exit 0 = all policies correct
```

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

### Optional: enable account deletion (the erasure step)
Users can *request* deletion, and admins can view/triage requests, without any
function. Performing the actual irreversible erasure (removing the auth user)
needs the service role, so it runs in an Edge Function:
```bash
supabase functions deploy delete-account
```
Until it is deployed, deletion requests are recorded and visible to admins but
the account is not yet erased. The function lives in
`supabase/functions/delete-account/`.

### Realtime (for messaging)
`chat.sql` adds the `messages` and `conversations` tables to the
`supabase_realtime` publication automatically. Confirm under Dashboard →
**Database** → **Replication** that both tables are enabled if live replies
don't arrive.

## Notes
- New patient/doctor signups go through Supabase Auth and persist immediately.
- Data is stored in your Supabase Postgres — it persists across restarts, shared by mobile + both web apps.
- Lab-result files upload to the **private** `lab-results` bucket (downloaded via short-lived signed URLs); card photos to `card-photos`.
- There is **no application backend** — all three clients talk to Supabase directly. (The old Node/Express prototype under `/backend` has been removed.)
