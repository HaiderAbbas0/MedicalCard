# Research Data Platform

How approved external organisations work with HayaatID clinical data without
ever receiving an identifiable record.

Source of truth: `supabase/research_platform.sql`. Portal: `web-research/`.
Verification: `supabase/tests/verify_research_privacy.mjs`.

---

## Threat model

The platform assumes the researcher is **not** malicious in the criminal sense,
but *is* curious, well-resourced, and may hold outside information. The controls
therefore target the realistic attacks:

| Attack | Control |
| ------ | ------- |
| Read the underlying tables directly | Researchers are excluded from `is_staff()`, so every clinical RLS policy denies them. There is no policy anywhere that admits a `researcher`. |
| Narrow a filter until a bucket holds one person | k-anonymity: any group below 5 is suppressed, returning `< 5` instead of a count. |
| Join two extracts to build a fuller picture of someone | Per-request salted pseudonyms — the same patient has a different `subject_id` in every extract. Verified empirically: two extracts of the same 30 patients share **zero** ids. |
| Re-identify from a rare free-text detail | No free text is ever released. Chief complaints, history, examination notes, assessments, plans and medication instructions are excluded at source. |
| Re-identify by matching an exact date or location | Ages are 5-year bands, locations are province-level, observation dates are year-month. |
| Approve their own request | `BEFORE INSERT` trigger forces `status = 'pending'` and discards any client-supplied expiry; the update policy admits admins only; the decision RPC is admin-gated. |
| Keep using data after consent is withdrawn | Consent is checked at query time, not from a snapshot, so withdrawal applies to the next read. |
| Keep using data after approval lapses | `expires_at` is enforced inside the export functions, not in the UI. |
| Reverse the pseudonym | One-way SHA-256 digest, and the salt lives in `research_request_secrets` — RLS on, **no policies**, revoked from `anon` and `authenticated`. Only `SECURITY DEFINER` functions can read it. |

**Residual risk, stated plainly:** an extract already downloaded cannot be
recalled. Deletion after expiry is contractual, not technical. This is disclosed
to patients in the Privacy Policy, and is the reason research use is opt-in.

---

## Architecture

```
  researcher (role='researcher', NOT staff)
        │
        │  can reach nothing directly — every clinical RLS policy denies them
        ▼
  research_* SECURITY DEFINER functions   ← the only doorway
        │
        ├── consent gate      (consent_preferences.research = true, checked live)
        ├── generalisation    (age bands, province, year-month)
        ├── k-anonymity       (suppress groups < 5)
        ├── pseudonymisation  (per-request salt from research_request_secrets)
        └── audit             (audit_logs, append-only)
        ▼
  clinical tables
```

The single most important property: **the functions are the only doorway.**
Adding a new export means writing a new function that applies all five controls;
there is no path that bypasses them.

---

## Tables

| Table | Purpose |
| ----- | ------- |
| `research_organizations` | The organisation, its type, registration, DPA acceptance, and status (`pending`/`active`/`suspended`/`rejected`) |
| `researcher_profiles` | Role-extension row linking a user to an organisation |
| `research_datasets` | The catalogue: code, description, tier, grain, and a JSON data dictionary |
| `research_data_requests` | Purpose, legal basis, cohort filters, decision, expiry, export counter |
| `research_request_secrets` | Per-request pseudonym salt. **RLS on with no policies** — unreadable by every client role |

The salt lives in its own table rather than a column of `research_data_requests`
deliberately: hiding a column with a column-level `GRANT` silently breaks
`select *` for every caller, which is a footgun. An unreadable side table is both
safer and simpler.

---

## Functions

### Aggregate tier — any active researcher
- `research_cohort_size(gender, province, age_band)` → count, suppressed below k
- `research_cohort_summary(dimension, gender, province, age_band)` → k-anonymised
  breakdown by one quasi-identifier at a time; `dimension` is whitelisted
- `research_condition_prevalence()` → ICD-10 chapter prevalence, k-suppressed

### Record-level tier — approved, unexpired requests only
- `research_export_patient_features(request)` → one row per patient (18 columns)
- `research_export_conditions(request)` → one row per diagnosis
- `research_export_observations(request)` → one row per numeric observation

All three call `research_request_salt()`, which raises unless the request belongs
to the caller's organisation, is `approved`, and has not expired.

### Administration and transparency
- `admin_decide_data_request(request, status, note, valid_days)` — admin-gated;
  writes the decision, notifies the requester, and audits, atomically
- `my_research_participation()` — a patient's own view of their consent state,
  what is and is not shared, and how many approved studies are live

---

## Datasets

| Code | Grain | Columns |
| ---- | ----- | ------- |
| `patient_features` | one row per patient | 18 — banded demographics plus counts across the record and mean systolic/pulse |
| `conditions` | one row per diagnosis | 7 — ICD-10 chapter, coded name, chronic flag, severity, status, year |
| `observations` | one row per observation | 6 — name, value, unit, reference range, year-month |

`patient_features` is the training matrix; the other two are long-format event
tables for longitudinal and sequence models. Every download ships with a
provenance manifest recording the request, purpose, legal basis, cohort,
approval date, expiry, row count and the privacy terms.

---

## Operating it

### Onboard an organisation
1. Admin portal → **Research Orgs** → approve (or create the row directly).
2. Create the researcher's auth account, then set `profiles.role = 'researcher'`
   and insert a `researcher_profiles` row linking them to the organisation.
   `supabase/tests/seed_research_account.mjs` generates this SQL for a demo account.

Self-registration is deliberately not offered: a human check precedes even
aggregate access.

### Review a request
Admin portal → **Data Requests**. You see the stated purpose, legal basis, the
exact cohort filters the researcher explored, the organisation and the requester.
Approve with an expiry (default 180 days), reject with a mandatory reason, or
revoke a live approval.

### Cut off access immediately
Suspend the organisation. `my_research_org()` only resolves for an `active`
organisation, so every one of its researchers loses both aggregate queries and
exports on their next call — no session invalidation needed.

### Audit research access
`audit_logs` rows with `action = 'research_query'` or `'research_export'`,
attributed to the researcher, stamped with the server clock.

---

## Verification

```bash
node supabase/tests/verify_research_privacy.mjs
```

41 assertions covering: no direct table access (11 clinical tables plus
`profiles` and `consent_preferences`), consent gating, k-anonymity suppression,
whitelisted dimensions, export refusal for unknown and pending requests,
no self-approval, discarded client expiry, unreadable salt, absence of
identifier columns, digest-shaped `subject_id`, banded ages, and unlinkability
across two extracts.

Supporting scripts:
- `seed_research_account.mjs` — demo organisation + researcher
- `seed_research_consent.mjs` — opts test patients in through the real
  `set_consent_preference` RPC; `--off` withdraws, which is the interesting case
  to demo (the cohort shrinks on the next query)

---

## Known limits

- k is fixed at 5 rather than configurable per dataset.
- No differential-privacy noise layer on top of k-anonymity — repeated
  differencing attacks across many overlapping queries are not defended against
  beyond suppression and audit.
- Export volume is counted (`export_count`) but not rate-limited.
- Extracts are assembled in the browser, so a very large cohort is memory-bound;
  server-side streaming would be the production answer.
- Organisations are onboarded by an administrator rather than self-registering.
