/// In-app legal copy shown in the patient app. The authoritative versions live
/// in `docs/legal/*.md`; keep the version string in sync with
/// [ComplianceService.legalVersion].
class LegalText {
  static const String version = '2026-07-04';
  static const String lastUpdated = '4 July 2026';

  static const String disclaimer =
      'This is a template pending review by qualified legal counsel and must not '
      'be relied upon as final legal advice.';

  static const String privacy = '''
HayaatID collects your Hayaat ID, name, phone, email (optional), date of
birth, gender, city, blood group, card photo, and your clinical records
(visits, prescriptions, vitals, allergies, lab orders and results), along with
appointments, in-app messages, and consent records.

WHY WE USE IT
To provide the health-card service and give the doctors you visit the
information needed for your care — on the basis of your consent, which you give
at sign-up and can review any time. Sensitive actions are audit-logged for your
protection.

WHO CAN SEE IT
• You — your full records.
• Doctors and clinic staff you visit — only as needed for your care. Lab workers
  see orders with your identity masked; receptionists see appointment details
  only, not clinical records.
• Administrators — for approvals and audit review.
Access is enforced in the database (row-level security), not just in the app.
Suspended or unapproved staff have no access. We never sell your data.

WHERE IT IS STORED
In our managed database (Supabase/PostgreSQL). Lab-result files are private and
opened only via short-lived signed links.

YOUR RIGHTS
Access and export a copy of your data, request corrections, and request deletion
of your account and data — all from Settings. You may withdraw consent, which
will limit or end the service.

SECURITY
Passwords are hashed. Data access is governed by row-level security. Privileged
operations run only on the server with credentials never exposed to the app.

For privacy questions contact support@hayaat.id.
''';

  static const String terms = '''
NOT AN EMERGENCY SERVICE
This app is not for medical emergencies. In an emergency call 1122 or go to the
nearest hospital. Messages to clinicians are not monitored in real time.

ACCOUNTS AND ROLES
One Hayaat ID maps to one account. Keep your credentials secure; you are responsible
for activity under your account. Doctors register as pending and cannot use the
service until an administrator approves them. Providing false identity or
credential information is prohibited.

ACCEPTABLE USE
Access only records you are authorised to access. Do not attempt to bypass
access controls or misuse another person's account. All access is audit-logged.

CLINICAL INFORMATION
The platform is a record-keeping and communication tool; it does not itself
provide medical advice. Clinical decisions are the responsibility of licensed
practitioners.

LIABILITY
The service is provided "as is". To the maximum extent permitted by law we are
not liable for indirect damages or for clinical decisions made by practitioners
using the service.

GOVERNING LAW
These Terms are governed by the laws of the Islamic Republic of Pakistan.

You may request deletion of your account at any time from Settings.
''';
}
