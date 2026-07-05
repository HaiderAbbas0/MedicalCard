import { useEffect, useState, type FormEvent } from 'react';
import { adminApi } from '../api/admin';
import type { Clinic } from '../api/types';
import { Spinner, Empty, Modal } from '../components/ui';

const CLINIC_TYPES = ['clinic', 'hospital', 'polyclinic', 'teaching_hospital', 'basic_health_unit'];

export default function ClinicsPage() {
  const [clinics, setClinics] = useState<Clinic[] | null>(null);
  const [error, setError] = useState('');
  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState({ name: '', type: 'clinic', phone: '', address_city: '', address_province: '' });
  const [receptionist, setReceptionist] = useState({ full_name: '', employee_id: '', password: '' });
  const [busy, setBusy] = useState(false);

  const receptionistFilled =
    receptionist.full_name.trim() || receptionist.employee_id.trim() || receptionist.password.trim();

  function load() {
    setClinics(null);
    adminApi.clinics().then(setClinics).catch((e) => setError(e.message));
  }
  useEffect(load, []);

  async function create(e: FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;

    // If any receptionist field is filled, require all three before proceeding.
    if (receptionistFilled) {
      if (!receptionist.full_name.trim() || !receptionist.employee_id.trim() || !receptionist.password.trim()) {
        setError('Fill out all receptionist fields (Full Name, Employee ID, Password), or leave them all blank.');
        return;
      }
    }

    setBusy(true);
    try {
      const clinic = await adminApi.createClinic(form);

      if (receptionistFilled) {
        await adminApi.createStaff('receptionist', {
          full_name: receptionist.full_name.trim(),
          employee_id: receptionist.employee_id.trim(),
          password: receptionist.password,
          clinic_id: clinic.id,
        });
      }

      setShowCreate(false);
      setForm({ name: '', type: 'clinic', phone: '', address_city: '', address_province: '' });
      setReceptionist({ full_name: '', employee_id: '', password: '' });
      load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="toolbar between">
        <span className="muted">Create and manage clinics and hospitals (P-FR-049).</span>
        <button className="btn btn-primary" onClick={() => setShowCreate(true)}>
          + New Clinic
        </button>
      </div>

      {error && <div className="error-text" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="card">
        {!clinics ? (
          <Spinner />
        ) : clinics.length === 0 ? (
          <Empty>No clinics yet.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>City</th>
                <th>Province</th>
                <th>Phone</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {clinics.map((c) => (
                <tr key={c.id}>
                  <td>{c.name}</td>
                  <td>{c.type.replace(/_/g, ' ')}</td>
                  <td>{c.address_city ?? '—'}</td>
                  <td>{c.address_province ?? '—'}</td>
                  <td>{c.phone ?? '—'}</td>
                  <td><span className="badge badge-green">{c.status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showCreate && (
        <Modal
          title="New Clinic"
          onClose={() => setShowCreate(false)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setShowCreate(false)}>
                Cancel
              </button>
              <button className="btn btn-primary" onClick={create} disabled={busy || !form.name.trim()}>
                Create
              </button>
            </>
          }
        >
          <form onSubmit={create}>
            <div className="field">
              <label>Name *</label>
              <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} autoFocus />
            </div>
            <div className="field">
              <label>Type</label>
              <select className="select" value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                {CLINIC_TYPES.map((t) => (
                  <option key={t} value={t}>
                    {t.replace(/_/g, ' ')}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label>Phone</label>
              <input className="input" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            </div>
            <div className="row">
              <div className="field" style={{ flex: 1 }}>
                <label>City</label>
                <input className="input" value={form.address_city} onChange={(e) => setForm({ ...form, address_city: e.target.value })} />
              </div>
              <div className="field" style={{ flex: 1 }}>
                <label>Province</label>
                <input className="input" value={form.address_province} onChange={(e) => setForm({ ...form, address_province: e.target.value })} />
              </div>
            </div>

            <hr style={{ margin: '16px 0' }} />
            <div className="field">
              <label style={{ fontWeight: 600 }}>Receptionist Account (Optional)</label>
              <p className="muted" style={{ marginTop: 2 }}>
                Fill these in to create a receptionist for this clinic at the same time. They'll log
                into the Staff Portal with their Employee ID and Password.
              </p>
            </div>
            <div className="field">
              <label>Full Name</label>
              <input
                className="input"
                value={receptionist.full_name}
                onChange={(e) => setReceptionist({ ...receptionist, full_name: e.target.value })}
              />
            </div>
            <div className="row">
              <div className="field" style={{ flex: 1 }}>
                <label>Employee ID</label>
                <input
                  className="input"
                  placeholder="e.g. REC-005"
                  value={receptionist.employee_id}
                  onChange={(e) => setReceptionist({ ...receptionist, employee_id: e.target.value })}
                />
              </div>
              <div className="field" style={{ flex: 1 }}>
                <label>Password</label>
                <input
                  className="input"
                  type="password"
                  value={receptionist.password}
                  onChange={(e) => setReceptionist({ ...receptionist, password: e.target.value })}
                />
              </div>
            </div>
          </form>
        </Modal>
      )}
    </>
  );
}