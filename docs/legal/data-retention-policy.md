# Data Retention & Deletion Policy

**Version:** 2026-09-07 · **Last updated:** 7 September 2026

> ⚠️ **Template — pending review by qualified legal counsel.** Retention periods
> below are placeholders to be confirmed against Pakistani health-records law and
> your regulatory obligations.

## Retention

| Data | Retention | Rationale |
| --- | --- | --- |
| Account & profile (Hayaat ID, name, contact, DOB) | While the account is active | Needed to provide the service |
| Clinical records (encounters, prescriptions, observations, allergies, lab orders/results) | For the period required for continuity of care and by law *(confirm term, e.g. 5–10 years)* | Continuity of care; legal record |
| Card photo | While the card is active | Identification |
| Messages | While the account is active | Care communication history |
| Consent records | Retained as a legal record (append-only) | Proof of consent |
| Audit logs | Retained long-term, **immutable** | Security & accountability |
| Research data requests (purpose, legal basis, cohort, decision) | Retained as a legal record | Accountability for every release |
| Research pseudonym salts | Retained for the life of the request | Required to reproduce an approved extract; unreadable by any client |

## Consent
Consent to the Privacy Policy and Terms is captured at sign-up and stored
immutably (document, version, timestamp, IP, device). When policies change, we
record acceptance of the new version. Users may withdraw consent, which limits or
ends the service.

**Research consent is separate and opt-in.** It is off by default, is recorded in
`consent_preferences` under the `research` key, and can be withdrawn at any time
without affecting the user's care or their use of the service.

## Research extracts

De-identified extracts released to approved organisations are governed by their
own limits:

- **Access expires.** Every approval carries an expiry date, after which the
  export functions refuse at the database level rather than by convention.
- **Withdrawal is immediate for future reads.** The consent check runs at query
  time, so a patient who withdraws is excluded from every subsequent query and
  extract.
- **Already-downloaded extracts cannot be recalled.** Once an organisation has
  downloaded a dataset, deletion is contractual: the data-sharing agreement
  requires them to delete it when access expires, and prohibits retention beyond
  the stated purpose. This limitation is disclosed to patients in the Privacy
  Policy, which is why research use is opt-in rather than assumed.
- **Extracts carry their own terms.** Every download ships with a provenance
  manifest recording the request, purpose, legal basis, cohort, approval date,
  expiry and row count, so a dataset is never separated from the conditions it
  was released under.

## Deletion

### Account deletion (self-service)
A user may request account deletion from the app ("Delete my account"). This
creates a **deletion request**. On fulfilment, the user's account and personal and
clinical data are permanently erased from the database (cascade delete), and the
authentication identity is removed. An audit entry recording that a deletion
occurred is retained for accountability (it contains no clinical detail).

### Legal-hold exceptions
Data subject to a legal hold, an ongoing investigation, or a statutory retention
requirement may be retained for the minimum period required by law, then deleted.

### Staff-initiated deletion
Administrators fulfil deletion requests via the admin portal; the actual erasure
runs in a server-side function using service credentials (`delete-account`), never
from the browser.

### Backups
Deletions propagate to primary storage immediately. Data may persist in encrypted
backups until those backups roll off on their normal cycle.

## Data export (portability)
Users can download a complete, machine-readable (JSON) copy of their data at any
time via "Download my data", powered by the `export_my_data()` database function
(scoped strictly to the requesting user).
