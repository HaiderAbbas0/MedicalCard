# HayaatID — Supabase setup (one-time, ~2 minutes)

The apps talk directly to Supabase (project `iikwdtiqvxxatrzahuzo`). Do these
three steps once.

## 1. Create the database
Supabase dashboard → **SQL Editor** → **New query**. Paste and **Run** each file
**in this exact order** (all are idempotent / safe to re-run):

1. [`schema.sql`](./schema.sql) — tables, base RLS, signup trigger, and buckets. Its optional development seed is disabled by default.
2. [`cards.sql`](./cards.sql) — card numbers, the `cards` table, request RPCs, `card-photos` bucket
3. [`revision.sql`](./revision.sql) — `medication_logs`, card-number assignment at signup, `login_email` RPC
4. [`security.sql`](./security.sql) — **MANDATORY.** Hardens the RLS policies (restricts PHI to owner/staff, makes the `lab-results` bucket private, prevents self-signup role escalation and audit-log forgery). The DB is **not safe without this.**
5. [`chat.sql`](./chat.sql) — real patient↔doctor messaging (`conversations` + `messages` tables, RLS, realtime)
6. [`security_hardening.sql`](./security_hardening.sql) — gates `is_staff()` on active status, restricts photo writes, and hardens audit logs
7. [`compliance.sql`](./compliance.sql) — consent, account-deletion requests, and data export
8. [`card_workflow.sql`](./card_workflow.sql) — card notifications and delivery workflow
9. [`perf_indexes.sql`](./perf_indexes.sql) — query and RLS indexes
10. [`product_hardening.sql`](./product_hardening.sql) — scheduling constraints, prescription footer fields, email login, and double-booking prevention
11. [`remove_demo_data.sql`](./remove_demo_data.sql) — removes legacy fixed demo identities if this project was previously seeded
12. [`hayaat_id_only.sql`](./hayaat_id_only.sql) — replaces all legacy identifiers with unique 16-digit numeric Hayaat IDs and removes the `cnic` column
13. [`patient_records.sql`](./patient_records.sql) — specialty record library, durable lab file paths, generic documents, and secure original-file storage

> Order matters: `security.sql` re-defines policies created by `schema.sql`, and
> `security_hardening.sql` re-defines `is_staff()` from `security.sql` — so run
> them in the numbered order.

### Verify the policies (optional but recommended)
An automated suite signs in as every role and asserts each policy:
```bash
cd supabase/tests && npm install && npm test    # exit 0 = all policies correct
```

## 2. Turn OFF email confirmation
Development may disable email confirmation because phone-only accounts use an
internal auth alias. Production must use verified email or phone ownership.

Dashboard → **Authentication** → **Providers** → **Email** → turn **OFF**
"Confirm email" → Save.

(Also fine to leave "Enable Sign Ups" ON so patients/doctors can self-register.)

## 3. You're done
The apps are already wired with your keys:
- URL: `https://iikwdtiqvxxatrzahuzo.supabase.co`
- anon key: configured in `lib/services/supabase_client.dart` (mobile) and
  `web-admin/.env` · `web-staff/.env` (web).

## Login model
- **New patients** receive a 16-digit Hayaat ID and log in with Hayaat ID, email, or phone.
- **Staff** receive a 16-digit Hayaat ID and log in with Hayaat ID, Employee ID, or email.
- A patient uses the same Hayaat ID on their virtual and physical card.

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
