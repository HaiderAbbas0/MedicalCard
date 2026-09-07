# Privacy Policy — HayaatID Digital Health Card

**Version:** 2026-09-07 · **Last updated:** 7 September 2026

> **What changed in this version:** we added section 5, describing the optional
> use of de-identified data for health research. This is **opt-in only** — no
> data is used for research unless you switch it on yourself.

> ⚠️ **Template — pending review by qualified legal counsel.** This document is a
> good-faith draft for a digital health platform. It must be
> reviewed and finalised by a lawyer before production use and must not be relied
> upon as final legal advice.

## 1. Who we are
HayaatID ("the platform", "we") operates a centralised digital health-card
service that links a person's medical history to their unique Hayaat ID and makes it available,
**with consent**, to approved clinics, hospitals, and diagnostic labs.

## 2. Data we collect
- **Identity**: Hayaat ID, full name, phone number, email (optional), date of birth,
  gender, city.
- **Health card**: Hayaat ID, card photo, blood group.
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
- **Optionally**, and only if you switch it on, to contribute **de-identified**
  data to approved health research — see section 5.

## 4. Who can access your data
- **You** — your own records, in full.
- **Treating clinicians and clinic staff** (doctor, lab worker, receptionist) —
  only to the extent needed to provide care. Lab workers see orders with your
  identity **masked**; receptionists see demographic/appointment data only, not
  clinical records.
- **Administrators** — for approvals, account management, and audit review.
- **Approved research organisations** — **only if you opt in**, and only ever in
  de-identified form. They cannot see your identity, your doctor's written notes,
  your documents or your messages. See section 5.
- Access is enforced in the database by Row Level Security, not merely in the app.
  Suspended or not-yet-approved staff have **no** data access.

We do **not** sell your data or share it with advertisers.

## 5. Research use (optional, opt-in only)

You can choose to let your data contribute to health research by turning on
**Research** under *Settings → Consent management*. It is **off by default** —
doing nothing means your data is never used for research.

**This is separate from, and additional to, the consent you give at sign-up.**
Turning it off again does not affect your care in any way.

### What a researcher receives
If you opt in, approved research organisations can receive a **de-identified**
version of your record:

- Your age as a **5-year band** (for example "30–34"), never your date of birth
- Your gender, province, and blood group — **never your city or address**
- Counts drawn from your history: number of visits, diagnoses, chronic
  conditions, medicines, allergies, lab orders and appointments
- Your diagnosis **category** (ICD-10 chapter) and the coded condition name
- Numeric vital-sign readings, dated only to the **month** they were taken

### What a researcher never receives
Under no circumstances is any of the following released:

- Your name, CNIC, Hayaat ID, phone number, email address or postal address
- Your date of birth
- **Anything your doctor typed in their own words** — complaints, history,
  examination notes, assessments, treatment plans and medication instructions are
  excluded entirely
- Your uploaded documents, lab-result files, or messages with clinicians

### How you are protected
- **You are given a different code in every dataset.** Your record is labelled
  with a scrambled code rather than an identifier, and that code is regenerated
  for each separate study — so two research organisations cannot put their
  datasets side by side and work out that two records belong to the same person.
  There is no way to convert that code back into your identity.
- **Small groups are hidden.** Any statistic covering fewer than five people is
  withheld rather than shown, so a researcher cannot narrow a search until it
  points at one individual.
- **Every organisation is vetted.** They must be approved by us, state the
  purpose of their study, accept a data-sharing agreement that forbids any
  attempt to identify anyone, and their access expires automatically.
- **Every query and download is logged.**

### Legal basis and withdrawal
The legal basis is your **explicit consent** (GDPR Art. 6(1)(a) and Art.
9(2)(a)). You can withdraw at any time in *Settings → Consent management*, and
withdrawal takes effect **immediately** — the check runs every time data is read,
so you are excluded from every subsequent query and download.

Datasets already downloaded before you withdrew cannot be recalled from the
organisation that holds them; their agreement requires deletion when their access
expires. This is why the choice is opt-in and asked of you plainly.

You can see your current status, exactly what is and is not shared, and how many
approved studies are using data, at any time in the app.

## 6. Where your data is stored
Data is stored in our managed PostgreSQL database and file storage (Supabase).
Lab-result files are kept in a **private** store and served only via short-lived,
signed links. Card photos are stored in a separate bucket writable only by you.

## 7. Retention
See the [Data Retention Policy](./data-retention-policy.md). In short: clinical
records are retained for the period required for continuity of care and applicable
law; audit logs are retained as an immutable record; on account deletion, personal
and clinical data are erased (subject to limited legal-hold exceptions).

## 8. Your rights
- **Access & export** — download a machine-readable copy of all your data at any
  time ("Download my data").
- **Correction** — update your profile details; ask a clinician to correct
  clinical entries.
- **Deletion** — request deletion of your account and data ("Delete my account").
  See the [Deletion Policy](./data-retention-policy.md#deletion).
- **Withdraw consent** — you may withdraw consent, which will limit or end the
  service.
- **Opt out of research** — turn off *Research* under Consent management at any
  time. This takes effect immediately and does not affect your care.

## 9. Security
Passwords are hashed (bcrypt). Access to health data is governed by database-level
Row Level Security. Sensitive actions are audit-logged with actor, IP, device, and
time. Privileged operations (account creation/deletion) run only in server-side
functions using service credentials never exposed to the app.

## 10. Children
The service is intended for use by adults or by guardians on behalf of dependants,
consistent with applicable Pakistani law.

## 11. Contact
For privacy questions or to exercise your rights, contact the data protection
contact listed in-app. *(Insert a real contact email/postal address before
launch.)*

## 12. Changes
We will update the version and "last updated" date above when this policy changes,
and record your acceptance of the current version.
