import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { doctorApi } from '../../api/doctor';

export default function PatientLookupPage() {
  const navigate = useNavigate();
  const [cnic, setCnic] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function search(e: FormEvent) {
    e.preventDefault();
    setError('');
    if (cnic.trim().length !== 13) {
      setError('Enter a 13-digit CNIC.');
      return;
    }
    setBusy(true);
    try {
      const patient = await doctorApi.searchPatient(cnic.trim());
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
        Looking up a patient records an access entry in the audit log (Scope §12.2).
      </p>
      <form onSubmit={search} className="row" style={{ marginTop: 16 }}>
        <input className="input" placeholder="13-digit CNIC, no dashes" value={cnic} maxLength={13}
          onChange={(e) => setCnic(e.target.value.replace(/\D/g, ''))} autoFocus />
        <button className="btn btn-primary" disabled={busy}>{busy ? 'Searching…' : 'Search'}</button>
      </form>
      {error && <div className="error-text">{error}</div>}
    </div>
  );
}
