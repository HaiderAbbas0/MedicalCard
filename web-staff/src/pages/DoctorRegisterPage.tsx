import { useState } from 'react';
import { supabase, emailFor } from '../api/supabase';

/** Password policy: at least 8 characters, with a letter and a number. */
function passwordPolicyError(pw: string): string | null {
  if (pw.length < 8) return 'Password must be at least 8 characters.';
  if (!/[A-Za-z]/.test(pw) || !/\d/.test(pw)) return 'Password needs at least one letter and one number.';
  return null;
}

/** Doctor self-registration (P-FR-002). Account is created PENDING. */
export default function DoctorRegisterPage() {
  const [form, setForm] = useState({
    full_name: '', phone_primary: '', email: '', password: '',
    pmdc_number: '', specialization_primary: '',
    qualification_mbbs: true, qualification_fcps: false,
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState('');

  function set(k: string, v: string | boolean) {
    setForm((f) => ({ ...f, [k]: v }));
  }

  async function submit() {
    setError('');
    if (!form.full_name.trim() || !form.password || !form.pmdc_number.trim() || !form.specialization_primary.trim()) {
      return setError('Name, password, PMDC number, and specialization are required.');
    }
    if (!form.email.trim() && !form.phone_primary.trim()) return setError('Email or phone is required.');
    const pwErr = passwordPolicyError(form.password);
    if (pwErr) return setError(pwErr);
    setBusy(true);
    try {
      const { error } = await supabase.auth.signUp({
        email: form.email.trim().toLowerCase() || emailFor(form.phone_primary.replace(/\D/g, '')),
        password: form.password,
        options: {
          data: {
            role: 'doctor',
            full_name: form.full_name.trim(),
            phone: form.phone_primary.trim(),
            email: form.email.trim() || undefined,
            pmdc_number: form.pmdc_number.trim(),
            specialization_primary: form.specialization_primary.trim(),
            qualification_mbbs: form.qualification_mbbs,
            qualification_fcps: form.qualification_fcps,
          },
        },
      });
      if (error) throw new Error(error.message);
      // Doctors start PENDING — sign out so they can't use the app until approved.
      await supabase.auth.signOut();
      setDone('Application submitted. An administrator will review your account before you can log in.');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Registration failed.');
    } finally {
      setBusy(false);
    }
  }

  if (done) {
    return (
      <div className="login-wrap">
        <div className="login-card">
          <h2>Application submitted</h2>
          <p className="sub">{done}</p>
          <a className="btn btn-primary" style={{ width: '100%' }} href="/login">Back to login</a>
        </div>
      </div>
    );
  }

  return (
    <div className="login-wrap">
      <form className="login-card" style={{ maxWidth: 440 }} onSubmit={(e) => { e.preventDefault(); submit(); }}>
        <h2>Register as a doctor</h2>
        <p className="sub">Reviewed by an admin before you can log in.</p>

        <div className="field"><label>Full name *</label>
          <input className="input" value={form.full_name} onChange={(e) => set('full_name', e.target.value)} /></div>
        <div className="row">
          <div className="field" style={{ flex: 1 }}><label>Phone</label>
            <input className="input" value={form.phone_primary} onChange={(e) => set('phone_primary', e.target.value)} /></div>
          <div className="field" style={{ flex: 1 }}><label>Email</label>
            <input className="input" value={form.email} onChange={(e) => set('email', e.target.value)} /></div>
        </div>
        <div className="field"><label>PMDC number *</label>
          <input className="input" value={form.pmdc_number} onChange={(e) => set('pmdc_number', e.target.value)} /></div>
        <div className="field"><label>Primary specialization *</label>
          <input className="input" value={form.specialization_primary} onChange={(e) => set('specialization_primary', e.target.value)} /></div>
        <div className="field"><label>Password *</label>
          <input className="input" type="password" value={form.password} onChange={(e) => set('password', e.target.value)} /></div>
        <label className="row" style={{ marginBottom: 8 }}>
          <input type="checkbox" checked={form.qualification_mbbs} onChange={(e) => set('qualification_mbbs', e.target.checked)} /> MBBS
        </label>
        <label className="row" style={{ marginBottom: 12 }}>
          <input type="checkbox" checked={form.qualification_fcps} onChange={(e) => set('qualification_fcps', e.target.checked)} /> FCPS
        </label>

        {error && <div className="error-text">{error}</div>}
        <button className="btn btn-primary" style={{ width: '100%' }} disabled={busy}>
          {busy ? 'Submitting…' : 'Submit application'}
        </button>
        <p style={{ textAlign: 'center', marginTop: 14 }}><a href="/login">← Back to login</a></p>
      </form>
    </div>
  );
}
