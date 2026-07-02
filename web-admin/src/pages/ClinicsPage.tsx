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
  const [busy, setBusy] = useState(false);

  function load() {
    setClinics(null);
    adminApi.clinics().then(setClinics).catch((e) => setError(e.message));
  }
  useEffect(load, []);

  async function create(e: FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;
    setBusy(true);
    try {
      await adminApi.createClinic(form);
      setShowCreate(false);
      setForm({ name: '', type: 'clinic', phone: '', address_city: '', address_province: '' });
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
          </form>
        </Modal>
      )}
    </>
  );
}
