# CNIC Health Card — Staff Web Portal

React + TypeScript (Vite) web portal for **clinic staff** of the CNIC Health Card
System: **doctors, lab workers, and receptionists**. One login, role-routed into
the right workspace. (Administrators use the separate `web-admin/` app; patients
use the Flutter mobile app at `/lib`.)

A slate sidebar distinguishes this staff portal from the teal admin portal.

## Run

```bash
# backend must be running (../backend → npm start, :3000)
npm install
npm run dev        # http://localhost:5174  (proxies /api → :3000)
```

Only `doctor`, `lab_worker`, and `receptionist` accounts can sign in here.

**Demo (password `password123`):** doctor `3520199999991` · lab `3520177777771` · receptionist `3520166666661`.
Doctors can self-register at `/register-doctor` (account is created pending admin approval).

## Workspaces

**Doctor** — today's appointments (confirm/check-in/no-show); find patient by CNIC;
patient record (summary, allergies, conditions, consolidated meds, timeline, record
allergy); new encounter (diagnoses, meds with live allergy warning, vitals, lab
orders, follow-up, finalize); lab results review & release; weekly availability;
profile.

**Lab worker** — priority-sorted order queue for their lab (masked patient
identity); mark sample collected → processing; upload result file (real upload,
25 MB limit) or structured values; uploading notifies the ordering doctor.

**Receptionist** — clinic schedule for all doctors; check-in; cancel; book a
walk-in appointment (search patient by CNIC → pick doctor → date/time).

## Structure

```
src/
  api/          client + types + doctor.ts / lab.ts / reception.ts
  auth/         AuthContext (staff roles only)
  components/   StaffLayout (role-aware sidebar) + ui
  pages/
    LoginPage, DoctorRegisterPage
    doctor/     appointments, lookup, record, encounter, lab review, availability, profile
    lab/        order queue
    reception/  clinic schedule + booking
  App.tsx       role-based routing
```
