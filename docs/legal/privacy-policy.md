# Privacy Policy — SehatID / HayaatID Digital Health Card

**Version:** 2026-07-04 · **Last updated:** 4 July 2026

> ⚠️ **Template — pending review by qualified legal counsel.** This document is a
> good-faith draft for a Pakistan CNIC-linked digital health platform. It must be
> reviewed and finalised by a lawyer before production use and must not be relied
> upon as final legal advice.

## 1. Who we are
SehatID/HayaatID ("the platform", "we") operates a centralised digital health-card
service that links a person's medical history to their CNIC and makes it available,
**with consent**, to approved clinics, hospitals, and diagnostic labs.

## 2. Data we collect
- **Identity**: CNIC, full name, phone number, email (optional), date of birth,
  gender, city.
- **Health card**: card number, card photo, blood group.
- **Clinical records**: encounters/visits, diagnoses, prescriptions, vital-sign
  observations, allergies, lab orders and lab results.
- **Interactions**: appointments, in-app messages with your clinicians,
  notifications, and consent records.
- **Technical/security**: for audit entries, the IP address and device
  (user-agent) associated with sensitive actions, and timestamps.

## 3. Why we process it (purpose & legal basis)
- To provide the health-card service and give treating clinicians the information
  needed for your care — on the basis of **your consent**, which you give at
  sign-up and can review at any time.
- To operate accounts, appointments, and messaging.
- To keep the service secure and to maintain a tamper-resistant **audit trail** of
  who accessed your records (a legitimate and legally-expected safeguard for
  health data).

## 4. Who can access your data
- **You** — your own records, in full.
- **Treating clinicians and clinic staff** (doctor, lab worker, receptionist) —
  only to the extent needed to provide care. Lab workers see orders with your
  identity **masked**; receptionists see demographic/appointment data only, not
  clinical records.
- **Administrators** — for approvals, account management, and audit review.
- Access is enforced in the database by Row Level Security, not merely in the app.
  Suspended or not-yet-approved staff have **no** data access.

We do **not** sell your data or share it with advertisers.

## 5. Where your data is stored
Data is stored in our managed PostgreSQL database and file storage (Supabase).
Lab-result files are kept in a **private** store and served only via short-lived,
signed links. Card photos are stored in a separate bucket writable only by you.

## 6. Retention
See the [Data Retention Policy](./data-retention-policy.md). In short: clinical
records are retained for the period required for continuity of care and applicable
law; audit logs are retained as an immutable record; on account deletion, personal
and clinical data are erased (subject to limited legal-hold exceptions).

## 7. Your rights
- **Access & export** — download a machine-readable copy of all your data at any
  time ("Download my data").
- **Correction** — update your profile details; ask a clinician to correct
  clinical entries.
- **Deletion** — request deletion of your account and data ("Delete my account").
  See the [Deletion Policy](./data-retention-policy.md#deletion).
- **Withdraw consent** — you may withdraw consent, which will limit or end the
  service.

## 8. Security
Passwords are hashed (bcrypt). Access to health data is governed by database-level
Row Level Security. Sensitive actions are audit-logged with actor, IP, device, and
time. Privileged operations (account creation/deletion) run only in server-side
functions using service credentials never exposed to the app.

## 9. Children
The service is intended for use by adults or by guardians on behalf of dependants,
consistent with applicable Pakistani law.

## 10. Contact
For privacy questions or to exercise your rights, contact the data protection
contact listed in-app. *(Insert a real contact email/postal address before
launch.)*

## 11. Changes
We will update the version and "last updated" date above when this policy changes,
and record your acceptance of the current version.
