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
    const query = cardNumber.trim().toUpperCase();
    if (!query.startsWith('HAY-PAT-')) {
      setError('Card number must start with HAY-PAT-.');
      return;
    }
    if (query.length < 9) {
      setError('Enter a valid Card Number (e.g. HAY-PAT-0004).');
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
      <p className="section-title">Find a patient by Card Number</p>
      <p className="muted" style={{ marginTop: 0 }}>
        Looking up a patient records an access entry in the audit log (Scope §12.2).
      </p>
      <form onSubmit={search} className="row" style={{ marginTop: 16 }}>
        <input className="input" placeholder="Card Number (e.g. HAY-PAT-0004)" value={cardNumber}
          onChange={(e) => setCardNumber(e.target.value)} autoFocus />
        <button className="btn btn-primary" disabled={busy}>{busy ? 'Searching…' : 'Search'}</button>
      </form>
      {error && <div className="error-text">{error}</div>}
    </div>
  );
}
