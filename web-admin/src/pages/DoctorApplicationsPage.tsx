import { useEffect, useState } from 'react';
import { adminApi } from '../api/admin';
import type { DoctorApplication } from '../api/types';
import { Spinner, Empty, Modal, StatusBadge } from '../components/ui';

export default function DoctorApplicationsPage() {
  const [apps, setApps] = useState<DoctorApplication[] | null>(null);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<DoctorApplication | null>(null);
  const [rejecting, setRejecting] = useState<DoctorApplication | null>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  function load() {
    setApps(null);
    adminApi
      .doctorApplications('pending')
      .then(setApps)
      .catch((e) => setError(e.message));
  }
  useEffect(load, []);

  async function approve(app: DoctorApplication) {
    setBusy(true);
    try {
      await adminApi.approveDoctor(app.id);
      setSelected(null);
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed.');
    } finally {
      setBusy(false);
    }
  }

  async function reject() {
    if (!rejecting || !reason.trim()) return;
    setBusy(true);
    try {
      await adminApi.rejectDoctor(rejecting.id, reason.trim());
      setRejecting(null);
      setReason('');
      setSelected(null);
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed.');
    } finally {
      setBusy(false);
    }
  }

  if (error) return <div className="error-text">{error}</div>;
  if (!apps) return <Spinner />;

  return (
    <div className="card">
      {apps.length === 0 ? (
        <Empty>No pending doctor applications. 🎉</Empty>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Hayaat ID</th>
              <th>PMDC No.</th>
              <th>Specialization</th>
              <th>Clinic</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {apps.map((a) => (
              <tr key={a.id}>
                <td>{a.full_name}</td>
                <td className="mono">{a.card_number?.replace(/(\d{4})(?=\d)/g, '$1 ')}</td>
                <td>{a.pmdc_number}</td>
                <td>{a.specialization_primary}</td>
                <td>{a.clinic?.name ?? '—'}</td>
                <td className="actions">
                  <button className="btn btn-ghost btn-sm" onClick={() => setSelected(a)}>
                    Review
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {selected && (
        <Modal
          title="Doctor Application"
          onClose={() => setSelected(null)}
          footer={
            <>
              <button className="btn btn-danger" onClick={() => setRejecting(selected)} disabled={busy}>
                Reject
              </button>
              <button className="btn btn-success" onClick={() => approve(selected)} disabled={busy}>
                Approve
              </button>
            </>
          }
        >
          <Detail label="Full name" value={selected.full_name} />
          <Detail label="Hayaat ID" value={selected.card_number?.replace(/(\d{4})(?=\d)/g, '$1 ')} mono />
          <Detail label="Email" value={selected.email ?? '—'} />
          <Detail label="Phone" value={selected.phone_primary} />
          <Detail label="PMDC number" value={selected.pmdc_number} />
          <Detail label="Specialization" value={selected.specialization_primary} />
          <Detail
            label="Qualifications"
            value={[
              selected.qualification_mbbs && 'MBBS',
              selected.qualification_md && 'MD',
              selected.qualification_fcps && 'FCPS',
            ]
              .filter(Boolean)
              .join(', ') || '—'}
          />
          <Detail label="Experience" value={selected.years_of_experience ? `${selected.years_of_experience} years` : '—'} />
          <Detail label="Clinic" value={selected.clinic?.name ?? '—'} />
          <Detail label="Status" value={<StatusBadge status={selected.status} />} />
        </Modal>
      )}

      {rejecting && (
        <Modal
          title="Reject Application"
          onClose={() => setRejecting(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setRejecting(null)}>
                Cancel
              </button>
              <button className="btn btn-danger" onClick={reject} disabled={busy || !reason.trim()}>
                Confirm rejection
              </button>
            </>
          }
        >
          <p className="muted">A reason is required and will be recorded in the audit log (P-FR-046).</p>
          <div className="field">
            <label>Rejection reason</label>
            <textarea
              className="input"
              rows={3}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g. PMDC number could not be verified."
            />
          </div>
        </Modal>
      )}
    </div>
  );
}

function Detail({ label, value, mono }: { label: string; value: React.ReactNode; mono?: boolean }) {
  return (
    <div className="between" style={{ padding: '7px 0', borderBottom: '1px solid var(--border)' }}>
      <span className="muted">{label}</span>
      <span className={mono ? 'mono' : ''}>{value}</span>
    </div>
  );
}
