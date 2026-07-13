import { useState } from 'react';
import { doctorApi } from '../../api/doctor';
import { useAuth } from '../../auth/AuthContext';

export default function DoctorProfilePage() {
  const { user } = useAuth();
  const ext = (user?.extended ?? {}) as Record<string, unknown>;
  const [form, setForm] = useState({
    specialization_primary: String(ext.specialization_primary ?? ''),
    consultation_fee_pkr: String(ext.consultation_fee_pkr ?? ''),
    bio: String(ext.bio ?? ''),
    is_available: ext.is_available !== false,
    prescription_signature_name: String(ext.prescription_signature_name ?? user?.full_name ?? ''),
    prescription_signature_credentials: String(ext.prescription_signature_credentials ?? [ext.qualification_mbbs ? 'MBBS' : '', ext.qualification_fcps ? 'FCPS' : ''].filter(Boolean).join(', ')),
    prescription_signature_footer: String(ext.prescription_signature_footer ?? ext.pmdc_number ?? ''),
  });
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [error, setError] = useState('');

  async function save() {
    setBusy(true);
    setMsg('');
    setError('');
    try {
      await doctorApi.updateProfile({
        specialization_primary: form.specialization_primary,
        consultation_fee_pkr: form.consultation_fee_pkr ? Number(form.consultation_fee_pkr) : null,
        bio: form.bio,
        is_available: form.is_available,
        prescription_signature_name: form.prescription_signature_name.trim(),
        prescription_signature_credentials: form.prescription_signature_credentials.trim(),
        prescription_signature_footer: form.prescription_signature_footer.trim(),
      });
      setMsg('Profile updated.');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="card card-pad" style={{ maxWidth: 560 }}>
      <h2 style={{ marginTop: 0 }}>{user?.full_name}</h2>
      <div className="field"><label>Primary specialization</label>
        <input className="input" value={form.specialization_primary} onChange={(e) => setForm({ ...form, specialization_primary: e.target.value })} /></div>
      <div className="field"><label>Consultation fee (PKR)</label>
        <input className="input" type="number" value={form.consultation_fee_pkr} onChange={(e) => setForm({ ...form, consultation_fee_pkr: e.target.value })} /></div>
      <div className="field"><label>Public bio</label>
        <textarea className="input" rows={4} value={form.bio} onChange={(e) => setForm({ ...form, bio: e.target.value })} /></div>
      <div className="card card-pad" style={{ margin: '18px 0', background: 'var(--bg)', boxShadow: 'none' }}>
        <p className="section-title">Prescription signature</p>
        <p className="muted" style={{ marginTop: -4, fontSize: 13 }}>This professional footer is applied to every prescription. It is not a handwritten or cryptographic signature.</p>
        <div className="field"><label>Signing name</label>
          <input className="input" placeholder="Dr. Full Name" value={form.prescription_signature_name} onChange={(e) => setForm({ ...form, prescription_signature_name: e.target.value })} /></div>
        <div className="field"><label>Qualifications</label>
          <input className="input" placeholder="MBBS, FCPS" value={form.prescription_signature_credentials} onChange={(e) => setForm({ ...form, prescription_signature_credentials: e.target.value })} /></div>
        <div className="field" style={{ marginBottom: 0 }}><label>Registration / footer</label>
          <input className="input" placeholder="PMDC registration or designation" value={form.prescription_signature_footer} onChange={(e) => setForm({ ...form, prescription_signature_footer: e.target.value })} /></div>
      </div>
      <label className="row" style={{ cursor: 'pointer' }}>
        <input type="checkbox" checked={form.is_available} onChange={(e) => setForm({ ...form, is_available: e.target.checked })} />
        Available for appointments
      </label>
      {error && <div className="error-text">{error}</div>}
      {msg && <div style={{ color: 'var(--green)', marginTop: 8, fontSize: 13 }}>{msg}</div>}
      <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={save} disabled={busy}>
        {busy ? 'Saving…' : 'Save changes'}
      </button>
    </div>
  );
}
