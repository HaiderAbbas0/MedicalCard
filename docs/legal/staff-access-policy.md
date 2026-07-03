# Staff Access Policy (Sensitive Data Handling)

**Version:** 2026-07-04 · **Last updated:** 4 July 2026

> ⚠️ **Template — pending review by qualified legal counsel and your clinical
> governance team.**

## Principle
Staff may access patient data **only** to the minimum extent needed to perform
their role in the patient's care, and only while their account is **active and
approved**. All access is recorded.

## Role boundaries (enforced by database Row Level Security)
- **Doctor** — may search a patient by CNIC and view/create clinical records for
  patients in their care. Patient-record reads are audit-logged.
- **Lab worker** — sees only orders routed to their lab, with the patient's
  identity **masked** (first name + last initial). No access to the broader
  clinical record.
- **Receptionist** — demographic and appointment data only. **No** access to
  clinical records.
- **Administrator** — user approvals, suspension/reactivation, clinic/lab
  management, and audit-log review. Admins do not have a clinical role.
- **Suspended or pending** staff have **no** data access at the database layer,
  regardless of the app UI.

## Obligations
- Access data only for a legitimate, care-related purpose.
- Do not export, screenshot, or share patient data outside the platform except as
  clinically necessary and lawful.
- Keep credentials confidential; never share accounts.
- Report suspected unauthorised access or a data breach immediately.

## Accountability
Sensitive actions (patient-record reads, status changes, deletions) are written to
an **immutable, append-only audit log** capturing the actor, their role, IP,
device, timestamp, and the resource. Audit logs are readable only by
administrators and cannot be edited or deleted by any client.

## Breach response
On a suspected breach, administrators review the audit log to scope the incident,
suspend implicated accounts, and follow the incident-response and notification
process required by law. *(Attach your incident-response runbook here.)*
