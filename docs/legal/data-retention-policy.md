# Data Retention & Deletion Policy

**Version:** 2026-07-04 · **Last updated:** 4 July 2026

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

## Consent
Consent to the Privacy Policy and Terms is captured at sign-up and stored
immutably (document, version, timestamp, IP, device). When policies change, we
record acceptance of the new version. Users may withdraw consent, which limits or
ends the service.

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
