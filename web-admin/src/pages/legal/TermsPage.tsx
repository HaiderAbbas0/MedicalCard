import LegalLayout from './LegalLayout';

/**
 * Public terms of service for the HayaatID / SehatID CNIC-linked digital health
 * card platform (Pakistan). Not lawyer-vetted — see the disclaimer in LegalLayout.
 */
export default function TermsPage() {
  return (
    <LegalLayout title="Terms of Service">
      <p>
        These Terms of Service (&ldquo;Terms&rdquo;) govern your use of the HayaatID / SehatID digital
        health-card platform (&ldquo;the Platform&rdquo;). By registering for or using the Platform you agree
        to these Terms. If you do not agree, do not use the Platform.
      </p>

      <div
        role="note"
        style={{
          border: '1px solid var(--red-border, #f3b4b4)',
          background: 'var(--red-bg, #fdeeee)',
          borderRadius: 10,
          padding: '12px 14px',
          margin: '16px 0 24px',
          fontSize: 14,
        }}
      >
        <strong>Not an emergency service.</strong> The Platform does not provide emergency medical
        care and must not be used in an emergency. In a medical emergency in Pakistan, call{' '}
        <strong>1122</strong> or go to the nearest hospital immediately.
      </div>

      <h2>1. Acceptable use</h2>
      <p>
        You may use the Platform only for lawful purposes and only to access records you are
        authorised to access. You must not attempt to access another person&rsquo;s data without
        authority, interfere with the Platform&rsquo;s security, upload malicious content, or use the
        Platform to harass, defraud, or harm others. You are responsible for keeping your login
        credentials confidential and for all activity under your account.
      </p>

      <h2>2. Accounts and roles</h2>
      <p>
        Accounts are linked to a CNIC and are assigned a role — patient, doctor, laboratory worker,
        receptionist, or administrator. Each role grants only the access appropriate to that role.
        You must provide accurate registration information and keep it up to date. Clinician and
        laboratory accounts may require verification and administrator approval before activation,
        and access may be suspended where information cannot be verified or where these Terms are
        breached.
      </p>

      <h2>3. Staff obligations</h2>
      <p>
        Clinicians, laboratory staff, and receptionists must access patient data only where they are
        involved in that patient&rsquo;s care or where their duties require it, must handle all patient
        information as confidential, must record clinical information accurately, and must comply
        with applicable professional, ethical, and legal obligations. Access is logged, and misuse
        may lead to suspension and referral to the relevant authorities.
      </p>

      <h2>4. Patient responsibilities</h2>
      <p>
        Information on the Platform supports, but does not replace, professional medical judgement.
        You should verify important details with your treating clinician and should not make
        health decisions solely on the basis of information displayed on the Platform.
      </p>

      <h2>5. Availability</h2>
      <p>
        We aim to keep the Platform available but do not guarantee uninterrupted or error-free
        operation. The Platform may be unavailable for maintenance or for reasons outside our
        control.
      </p>

      <h2>6. Limitation of liability</h2>
      <p>
        To the maximum extent permitted by law, the Platform and its operator are not liable for any
        indirect, incidental, or consequential loss, or for loss arising from reliance on
        information in the Platform, from clinical decisions, from unavailability of the service, or
        from any failure to obtain emergency care. Nothing in these Terms excludes liability that
        cannot lawfully be excluded.
      </p>

      <h2>7. Suspension and termination</h2>
      <p>
        We may suspend or terminate access where these Terms are breached, where required by law, or
        to protect patient safety or the integrity of the Platform. You may request deletion of your
        account as described in the Privacy Policy.
      </p>

      <h2>8. Changes to these Terms</h2>
      <p>
        We may update these Terms from time to time. The version and last-updated date at the top of
        this page indicate the current version. Continued use after an update constitutes acceptance.
      </p>

      <h2>9. Governing law</h2>
      <p>
        These Terms are governed by the laws of the Islamic Republic of Pakistan, and the courts of
        Pakistan have jurisdiction over any dispute arising from them.
      </p>

      <h2>10. Contact</h2>
      <p>
        Questions about these Terms can be sent to{' '}
        <a href="mailto:support@hayaat.id">support@hayaat.id</a>.
      </p>
    </LegalLayout>
  );
}
