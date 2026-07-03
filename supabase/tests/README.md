# RLS test suite

Automated Row Level Security verification for the HayaatID Supabase project. It
signs in as each demo role (anonymous, patient, other-patient, active doctor,
**pending** doctor, admin) and asserts what each can and cannot read/write —
using only the publishable key, so it exercises the exact policies real clients
hit. No service-role key.

## Run

```bash
cd supabase/tests
npm install
npm test
```

Against a different project, override the config:

```bash
SUPABASE_URL=https://<ref>.supabase.co \
SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
DEMO_PASSWORD=password123 \
npm test
```

Exit code is `0` when every check passes, `1` otherwise (CI-friendly).

## What it covers

- **Anonymous**: cannot read `profiles` / `encounters` / `messages`; `login_email`
  RPC is intentionally callable (documented enumeration tradeoff).
- **Patient (owner)**: reads own profile/encounters only; cannot read another
  patient, cannot read `audit_logs`, cannot insert encounters, cannot forge an
  audit entry as another actor.
- **Active doctor (staff)**: can read + create a patient's encounters; cannot
  read `audit_logs`.
- **Pending doctor**: must be blocked from patient data — this passes only after
  `security_hardening.sql` (the `is_staff()` active-status gate) is applied.
- **Admin**: can read `audit_logs` and all profiles.
- **Chat**: a non-participant cannot read or post into a conversation, and
  `start_conversation` rejects a non-participant caller.

## Prerequisites

The Supabase SQL must be applied (see `../SUPABASE_SETUP.md`), email confirmation
turned off, and the demo accounts seeded.
