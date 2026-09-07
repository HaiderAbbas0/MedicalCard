# Staff Access Policy (Sensitive Data Handling)

**Version:** 2026-09-07 · **Last updated:** 7 September 2026

> ⚠️ **Template — pending review by qualified legal counsel and your clinical
> governance team.**

## Principle
Staff may access patient data **only** to the minimum extent needed to perform
their role in the patient's care, and only while their account is **active and
approved**. All access is recorded.

## Role boundaries (enforced by database Row Level Security)
- **Doctor** — may search a patient by Hayaat ID and view/create clinical records for
  patients in their care. Patient-record reads are audit-logged.
- **Lab worker** — sees only orders routed to their lab, with the patient's
  identity **masked** (first name + last initial). No access to the broader
  clinical record.
- **Receptionist** — demographic and appointment data only. **No** access to
  clinical records.
- **Administrator** — user approvals, suspension/reactivation, clinic/lab
  management, research organisation and data-request review, and audit-log
  review. Admins do not have a clinical role.
- **Researcher** (external, not clinic staff) — **no** access to any identifiable
  record. Researchers are deliberately excluded from `is_staff()`, so every
  clinical RLS policy denies them; they can reach data only through
  de-identifying functions gated on patient opt-in consent. See the
  [Research Platform doc](../RESEARCH_PLATFORM.md).
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
