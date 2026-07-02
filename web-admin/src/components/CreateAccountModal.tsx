import { useEffect, useState } from 'react';
import { adminApi } from '../api/admin';
import type { Clinic, Lab } from '../api/types';
import { Modal } from './ui';

type StaffRole = 'receptionist' | 'lab_worker' | 'admin';

const ROLE_LABELS: Record<StaffRole, string> = {
  receptionist: 'Receptionist',
  lab_worker: 'Lab worker',
  admin: 'Administrator',
};

/**
 * Create a staff account: receptionist (scoped to a clinic), lab worker (scoped
 * to a lab), or admin (super-admin only — P-FR-004 / P-FR-050).
 */
export default function CreateAccountModal({
  onClose,
  onCreated,
  canCreateAdmin,
}: {
  onClose: () => void;
  onCreated: () => void;
  canCreateAdmin: boolean;
}) {
  const [role, setRole] = useState<StaffRole>('receptionist');
  const [form, setForm] = useState({
    full_name: '',
    cnic: '',
    phone_primary: '',
    email: '',
    password: '',
    clinic_id: '',
    lab_id: '',
    admin_level: 'support_admin',
  });
  const [clinics, setClinics] = useState<Clinic[]>([]);
  const [labs, setLabs] = useState<Lab[]>([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    adminApi.clinics().then(setClinics).catch(() => undefined);
    adminApi.labs().then(setLabs).catch(() => undefined);
  }, []);

  function set(key: string, value: string) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  async function submit() {
    setError('');
    if (form.cnic.trim().length !== 13) return setError('CNIC must be exactly 13 digits.');
    if (!form.full_name.trim() || !form.password) return setError('Full name and password are required.');
    if (role === 'receptionist' && !form.clinic_id) return setError('Select a clinic for the receptionist.');
    if (role === 'lab_worker' && !form.lab_id) return setError('Select a lab for the lab worker.');

    const body: Record<string, string> = {
      cnic: form.cnic.trim(),
      full_name: form.full_name.trim(),
      phone_primary: form.phone_primary.trim(),
      email: form.email.trim(),
      password: form.password,
    };
    if (role === 'receptionist') body.clinic_id = form.clinic_id;
    if (role === 'lab_worker') body.lab_id = form.lab_id;
    if (role === 'admin') body.admin_level = form.admin_level;

    setBusy(true);
    try {
      await adminApi.createStaff(role, body);
      onCreated();
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to create account.');
    } finally {
      setBusy(false);
    }
  }

  const roles: StaffRole[] = canCreateAdmin
    ? ['receptionist', 'lab_worker', 'admin']
    : ['receptionist', 'lab_worker'];

  return (
    <Modal
      title="Create staff account"
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={submit} disabled={busy}>
            {busy ? 'Creating…' : 'Create account'}
          </button>
        </>
      }
    >
      <div className="field">
        <label>Role</label>
        <select className="select" value={role} onChange={(e) => setRole(e.target.value as StaffRole)}>
          {roles.map((r) => (
            <option key={r} value={r}>
              {ROLE_LABELS[r]}
            </option>
          ))}
        </select>
      </div>

      <div className="field">
        <label>Full name *</label>
        <input className="input" value={form.full_name} onChange={(e) => set('full_name', e.target.value)} />
      </div>
      <div className="field">
        <label>CNIC * (13 digits)</label>
        <input
          className="input"
          value={form.cnic}
          maxLength={13}
          onChange={(e) => set('cnic', e.target.value.replace(/\D/g, ''))}
        />
      </div>
      <div className="row">
        <div className="field" style={{ flex: 1 }}>
          <label>Phone</label>
          <input className="input" value={form.phone_primary} onChange={(e) => set('phone_primary', e.target.value)} />
        </div>
        <div className="field" style={{ flex: 1 }}>
          <label>Email</label>
          <input className="input" value={form.email} onChange={(e) => set('email', e.target.value)} />
        </div>
      </div>
      <div className="field">
        <label>Temporary password *</label>
        <input className="input" type="text" value={form.password} onChange={(e) => set('password', e.target.value)} />
      </div>

      {role === 'receptionist' && (
        <div className="field">
          <label>Clinic *</label>
          <select className="select" value={form.clinic_id} onChange={(e) => set('clinic_id', e.target.value)}>
            <option value="">Select a clinic…</option>
            {clinics.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
      )}
      {role === 'lab_worker' && (
        <div className="field">
          <label>Lab *</label>
          <select className="select" value={form.lab_id} onChange={(e) => set('lab_id', e.target.value)}>
            <option value="">Select a lab…</option>
            {labs
              .filter((l) => l.status === 'active')
              .map((l) => (
                <option key={l.id} value={l.id}>
                  {l.name}
                </option>
              ))}
          </select>
        </div>
      )}
      {role === 'admin' && (
        <div className="field">
          <label>Admin level</label>
          <select className="select" value={form.admin_level} onChange={(e) => set('admin_level', e.target.value)}>
            <option value="support_admin">Support admin</option>
            <option value="super_admin">Super admin</option>
          </select>
        </div>
      )}

      {error && <div className="error-text">{error}</div>}
    </Modal>
  );
}
