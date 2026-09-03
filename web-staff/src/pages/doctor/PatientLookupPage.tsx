import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { doctorApi } from '../../api/doctor';

export default function PatientLookupPage() {
  const navigate = useNavigate();
  const [identifier, setIdentifier] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function search(e: FormEvent) {
    e.preventDefault();
    setError('');
    // 13 digits = CNIC (P-FR-019, the usual case); 16 = Hayaat card number.
    const query = identifier.replace(/\D/g, '');
    if (!/^\d{13}$/.test(query) && !/^\d{16}$/.test(query)) {
      setError('Enter a 13-digit CNIC or a 16-digit Hayaat ID.');
      return;
    }
    setBusy(true);
    try {
      const patient = await doctorApi.searchPatient(query);
      navigate(`/doctor/patient/${patient.id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Patient not found.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="card card-pad" style={{ maxWidth: 520 }}>
      <p className="section-title">Find a patient by CNIC</p>
      <p className="muted" style={{ marginTop: 0 }}>
        Enter the patient&apos;s 13-digit CNIC. The 16-digit number on their Hayaat
        card also works. Every lookup is recorded in the access audit log.
      </p>
      <form onSubmit={search} className="row" style={{ marginTop: 16 }}>
        <input className="input" inputMode="numeric" maxLength={16}
          placeholder="13-digit CNIC (or 16-digit Hayaat ID)" value={identifier}
          onChange={(e) => setIdentifier(e.target.value.replace(/\D/g, '').slice(0, 16))} autoFocus />
        <button className="btn btn-primary" disabled={busy}>{busy ? 'Searching…' : 'Search'}</button>
      </form>
      {error && <div className="error-text">{error}</div>}
    </div>
  );
}
