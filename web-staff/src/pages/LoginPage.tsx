import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      await login(identifier.trim(), password);
      navigate('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={onSubmit}>
        <img src="/favicon.svg" width={56} height={56} alt="HayaatID" style={{ display: 'block', margin: '0 auto 14px', borderRadius: 14, boxShadow: '0 4px 14px rgba(0,0,0,0.12)' }} />
        <h2 style={{ textAlign: 'center' }}>HayaatID Staff</h2>
        <p className="sub" style={{ textAlign: 'center' }}>Doctors · Lab · Reception</p>

        <div className="field">
          <label>Hayaat ID, Employee ID, or Email</label>
          <input className="input" value={identifier} onChange={(e) => setIdentifier(e.target.value)} autoFocus />
        </div>
        <div className="field">
          <label>Password</label>
          <input className="input" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </div>

        {error && <div className="error-text">{error}</div>}

        <button className="btn btn-primary" style={{ width: '100%', marginTop: 8 }} disabled={busy}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>

        <p style={{ textAlign: 'center', marginTop: 16 }}>
          <a href="/register-doctor">Are you a doctor? Register here →</a>
        </p>
        <p className="muted" style={{ fontSize: 12, marginTop: 8, textAlign: 'center' }}>
          Use your 16-digit Hayaat ID, employee ID, or approved email.
        </p>
        <p className="muted" style={{ fontSize: 12, marginTop: 8, textAlign: 'center' }}>
          <Link to="/legal/privacy">Privacy Policy</Link> · <Link to="/legal/terms">Terms of Service</Link>
        </p>
      </form>
    </div>
  );
}
