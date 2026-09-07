import { Notice } from '../components/ui';

/**
 * The portal's standing statement of how the data was made safe. It is
 * deliberately specific: a researcher should be able to read this and know
 * exactly what they are and are not receiving.
 */
export default function CompliancePage() {
  return (
    <div className="stack" style={{ maxWidth: 860 }}>
      <Notice tone="indigo" icon="shield">
        These controls are enforced in the database itself, not in this web app. A researcher account
        has no direct read access to any clinical table — the only way in is through functions that
        apply every rule below.
      </Notice>

      <div className="card card-pad">
        <h3 style={{ marginTop: 0 }}>1. Consent is a hard gate</h3>
        <p>
          A patient's data is included only if they have explicitly switched on the{' '}
          <strong>research</strong> consent in their app. The default is off — nobody is enrolled by
          inaction. The check runs at query time, never from a stored snapshot, so a patient who
          withdraws consent disappears from every subsequent query and export immediately.
        </p>
        <p className="muted" style={{ marginBottom: 0 }}>
          Basis: GDPR Art. 6(1)(a) and Art. 9(2)(a) — explicit consent for special-category health
          data.
        </p>
      </div>

      <div className="card card-pad">
        <h3 style={{ marginTop: 0 }}>2. What you never receive</h3>
        <p>No function in this platform can return any of the following:</p>
        <ul style={{ lineHeight: 1.8, marginTop: 0 }}>
          <li>Name, CNIC, Hayaat ID, phone number, email address</li>
          <li>Street address or city — location is generalised to province</li>
          <li>Date of birth — age is generalised to a 5-year band, 90+ collapsed</li>
          <li>
            <strong>Any clinical free text</strong> — chief complaints, history, examination notes,
            assessments, plans and medication instructions are excluded outright, because free text
            is the single largest re-identification risk in a health record
          </li>
          <li>Uploaded documents, lab result files, or chat messages</li>
        </ul>
      </div>

      <div className="card card-pad">
        <h3 style={{ marginTop: 0 }}>3. Pseudonyms are per-request</h3>
        <p>
          Each approved request is issued its own random salt, and{' '}
          <code className="mono">subject_id</code> is a one-way digest of the patient identifier and
          that salt. The same person therefore appears under a <em>different</em> id in every
          extract, which means two studies — or two organisations — cannot join their datasets to
          rebuild a fuller picture of an individual.
        </p>
        <p style={{ marginBottom: 0 }}>
          The salt is never readable by any client, and there is no function anywhere that maps a{' '}
          <code className="mono">subject_id</code> back to a person.
        </p>
      </div>

      <div className="card card-pad">
        <h3 style={{ marginTop: 0 }}>4. k-anonymity on aggregates</h3>
        <p style={{ marginBottom: 0 }}>
          Any aggregate group containing fewer than <strong>5</strong> people is suppressed and
          returned as <strong>&lt; 5</strong> rather than a count. This stops the classic attack of
          narrowing filters until a bucket contains exactly one person.
        </p>
      </div>

      <div className="card card-pad">
        <h3 style={{ marginTop: 0 }}>5. Purpose and storage limitation</h3>
        <p>
          Every request records a stated purpose and legal basis before it can be submitted, and an
          administrator reviews both alongside the exact cohort filters used. Approvals carry an
          expiry date; once passed, exports stop working at the database level rather than by
          convention.
        </p>
        <p style={{ marginBottom: 0 }}>
          Every extract downloads with a <strong>provenance manifest</strong> recording the request,
          purpose, legal basis, cohort, approval date, expiry and row count — so a dataset is never
          separated from the terms it was released under.
        </p>
      </div>

      <div className="card card-pad">
        <h3 style={{ marginTop: 0 }}>6. Everything is audited</h3>
        <p style={{ marginBottom: 0 }}>
          Cohort queries and row-level exports both write to an append-only audit log attributed to
          the signed-in researcher. The log cannot be edited or deleted by any client, and its
          timestamps come from the server clock rather than the caller.
        </p>
      </div>

      <div className="card card-pad">
        <h3 style={{ marginTop: 0 }}>Your obligations</h3>
        <ul style={{ lineHeight: 1.8, marginBottom: 0 }}>
          <li>Do not attempt to re-identify any individual, by any means.</li>
          <li>Do not link an extract to any other dataset, record, or person.</li>
          <li>Use the data only for the purpose stated in the approved request.</li>
          <li>Delete extracts when access expires.</li>
          <li>Report any suspected re-identification or breach to HayaatID immediately.</li>
        </ul>
      </div>
    </div>
  );
}
