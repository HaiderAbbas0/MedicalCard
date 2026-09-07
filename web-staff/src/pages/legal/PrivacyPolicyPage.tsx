import LegalLayout from './LegalLayout';

/**
 * Public privacy policy for the HayaatID digital health card
 * platform (Pakistan). Not lawyer-vetted — see the disclaimer in LegalLayout.
 */
export default function PrivacyPolicyPage() {
  return (
    <LegalLayout title="Privacy Policy">
      <p>
        This Privacy Policy explains how the HayaatID digital health-card platform
        (&ldquo;the Platform&rdquo;, &ldquo;we&rdquo;, &ldquo;us&rdquo;) collects, uses, stores, and protects your
        personal and health information. The Platform links a unique Hayaat ID
        to a digital health card so that patients and their treating
        clinicians can access accurate medical records at the point of care.
      </p>

      <h2>1. Who we are</h2>
      <p>
        The Platform is operated as a health-records service for patients, clinics, diagnostic
        laboratories, and their staff in Pakistan. For the purposes of applicable data-protection
        law, the operator of the Platform acts as the data controller for the information described
        below.
      </p>

      <h2>2. What data we collect</h2>
      <p>We collect only the data needed to identify you and to provide safe clinical care:</p>
      <ul>
        <li><strong>Identity data</strong> — Hayaat ID, full name, date of birth, and gender.</li>
        <li><strong>Contact data</strong> — primary phone number and, where provided, email address.</li>
        <li><strong>Card data</strong> — your card photo and unique 16-digit Hayaat ID.</li>
        <li>
          <strong>Clinical data</strong> — blood group, allergies, conditions, encounters and
          consultation notes, prescriptions, appointments, and other records created by treating
          clinicians.
        </li>
        <li><strong>Laboratory data</strong> — lab orders and lab results linked to your card.</li>
        <li>
          <strong>Operational data</strong> — audit logs recording who accessed or changed a record
          and when, which we keep for security and accountability.
        </li>
      </ul>

      <h2>3. Why we collect it and our legal basis</h2>
      <p>
        We process your data to create and maintain your health card, to make your medical history
        available to clinicians treating you, to enable appointments and laboratory workflows, and
        to keep the Platform secure. Our legal basis is your <strong>consent</strong>, given when
        you register or when a record is created on your behalf, together with the need to provide
        health care and to comply with legal and record-keeping obligations. You may withdraw
        consent as described in Section 7; withdrawal does not affect processing already carried out.
      </p>

      <h2>4. Who can access your data</h2>
      <ul>
        <li><strong>You, the patient</strong> — you can view your own card, records, and results.</li>
        <li>
          <strong>Treating clinicians and clinic staff</strong> — doctors, receptionists, and
          laboratory staff involved in your care can access the records necessary for their role.
        </li>
        <li>
          <strong>Administrators</strong> — platform administrators can access account and audit
          data to operate the service, resolve issues, and act on your rights requests.
        </li>
        <li>
          <strong>Approved research organisations</strong> — only if you opt in, and only ever in
          de-identified form. They cannot see your identity, your doctor's written notes, your
          documents or your messages. See Section 5.
        </li>
      </ul>
      <p>
        Access is enforced at the database level through row-level security, so each user sees only
        the records their role permits. We do not sell your data and do not share it for
        advertising.
      </p>

      <h2>5. Research use (optional, opt-in only)</h2>
      <p>
        You can choose to let your data contribute to health research by turning on{' '}
        <strong>Research</strong> under Settings → Consent management in the patient app. It is{' '}
        <strong>off by default</strong> — doing nothing means your data is never used for research.
        This is separate from the consent you give at sign-up, and turning it off does not affect
        your care.
      </p>
      <p>
        If you opt in, approved research organisations receive a de-identified version of your
        record: your age as a <strong>5-year band</strong> (never your date of birth), your gender,
        province and blood group (never your city or address), counts of your visits, diagnoses,
        chronic conditions, medicines, allergies, lab orders and appointments, your diagnosis
        category (ICD-10 chapter), and numeric vital-sign readings dated only to the month.
      </p>
      <p>They never receive:</p>
      <ul>
        <li>Your name, CNIC, Hayaat ID, phone, email or address</li>
        <li>Your date of birth</li>
        <li>
          <strong>Anything your doctor typed in their own words</strong> — complaints, history,
          examination notes, assessments, plans and medication instructions are excluded entirely
        </li>
        <li>Your uploaded documents, lab-result files, or messages with clinicians</li>
      </ul>
      <p>
        You are labelled with a scrambled code that is regenerated for every separate study, so two
        organisations cannot combine their datasets to work out that two records belong to the same
        person, and there is no way to convert that code back into your identity. Any statistic
        covering fewer than five people is withheld rather than shown. Every organisation is vetted,
        must state the purpose of its study, must accept an agreement forbidding any attempt to
        identify anyone, and its access expires automatically. Every query and download is logged.
      </p>
      <p>
        The legal basis is your <strong>explicit consent</strong> (GDPR Art. 6(1)(a) and Art.
        9(2)(a)). You can withdraw at any time and it takes effect immediately for every subsequent
        query and download. Datasets already downloaded before you withdrew cannot be recalled; the
        organisation is contractually required to delete them when its access expires.
      </p>

      <h2>6. Where your data is stored</h2>
      <p>
        Your data is stored in a managed PostgreSQL database hosted on Supabase, protected in transit
        and at rest and governed by row-level security policies. Files such as card photos are held
        in the associated secure object storage.
      </p>

      <h2>7. How long we keep it</h2>
      <p>
        We retain medical records for as long as necessary to provide continuity of care and to meet
        applicable clinical record-keeping requirements. Account and audit records are retained for
        the life of the account and for a reasonable period afterwards for legal and security
        purposes. When you exercise your right to deletion (Section 7), eligible data is erased after
        your request has been reviewed and completed.
      </p>

      <h2>8. Your rights</h2>
      <ul>
        <li><strong>Access</strong> — you can view the personal and clinical data we hold about you.</li>
        <li><strong>Export</strong> — you can request a copy of your data in a portable form.</li>
        <li>
          <strong>Deletion</strong> — you can request deletion of your account and associated data.
          Deletion requests are reviewed by an administrator; once approved and marked completed, the
          account and its data are erased by a secure server-side process. Some records may be
          retained where the law requires.
        </li>
        <li><strong>Correction</strong> — you can ask us to correct inaccurate identity or contact data.</li>
      </ul>

      <h2>9. Security</h2>
      <p>
        We protect your data with role-based access control, row-level security, encrypted
        connections, and audit logging. No system is perfectly secure; please keep your credentials
        confidential and tell us promptly if you suspect unauthorised access.
      </p>

      <h2>10. Children</h2>
      <p>
        Records for minors are created and managed by a parent, guardian, or treating clinician on
        the minor&rsquo;s behalf.
      </p>

      <h2>11. Changes to this policy</h2>
      <p>
        We may update this policy from time to time. The version and last-updated date at the top of
        this page indicate the current version.
      </p>

      <h2>12. Contact</h2>
      <p>
        For any privacy question, or to exercise your rights, contact the Platform&rsquo;s data
        protection team at <a href="mailto:privacy@hayaat.id">privacy@hayaat.id</a>.
      </p>
    </LegalLayout>
  );
}
