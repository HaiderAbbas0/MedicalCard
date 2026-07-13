import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { doctorApi } from '../../api/doctor';

export default function PatientLookupPage() {
  const navigate = useNavigate();
  const [cardNumber, setCardNumber] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function search(e: FormEvent) {
    e.preventDefault();
    setError('');
    const query = cardNumber.replace(/\s/g, '');
    if (!/^\d{16}$/.test(query)) {
      setError('Enter a valid 16-digit Hayaat ID.');
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
      <p className="section-title">Find a patient by Hayaat ID</p>
      <p className="muted" style={{ marginTop: 0 }}>
        Every patient lookup is securely recorded in the access audit log.
      </p>
      <form onSubmit={search} className="row" style={{ marginTop: 16 }}>
        <input className="input" inputMode="numeric" maxLength={19} placeholder="0000 0000 0000 0000" value={cardNumber}
          onChange={(e) => setCardNumber(e.target.value.replace(/\D/g, '').slice(0, 16).replace(/(.{4})/g, '$1 ').trim())} autoFocus />
        <button className="btn btn-primary" disabled={busy}>{busy ? 'Searching…' : 'Search'}</button>
      </form>
      {error && <div className="error-text">{error}</div>}
    </div>
  );
}
