import { useEffect, useState } from 'react';
import { api } from '../api/client';
import type { Lab } from '../api/types';
import { Spinner, Empty, Modal } from '../components/ui';

export default function LabApplicationsPage() {
  const [labs, setLabs] = useState<Lab[] | null>(null);
  const [error, setError] = useState('');
  const [rejecting, setRejecting] = useState<Lab | null>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  function load() {
    setLabs(null);
    api
      .get<Lab[]>('/admin/applications/labs?status=pending')
      .then(setLabs)
      .catch((e) => setError(e.message));
  }
  useEffect(load, []);

  async function approve(lab: Lab) {
    setBusy(true);
    try {
      await api.post(`/admin/applications/labs/${lab.id}/approve`);
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
      await api.post(`/admin/applications/labs/${rejecting.id}/reject`, { reason: reason.trim() });
      setRejecting(null);
      setReason('');
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed.');
    } finally {
      setBusy(false);
    }
  }

  if (error) return <div className="error-text">{error}</div>;
  if (!labs) return <Spinner />;

  return (
    <div className="card">
      {labs.length === 0 ? (
        <Empty>No pending lab registrations.</Empty>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Lab name</th>
              <th>License No.</th>
              <th>City</th>
              <th>Phone</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {labs.map((l) => (
              <tr key={l.id}>
                <td>{l.name}</td>
                <td className="mono">{l.license_number}</td>
                <td>{l.address_city}</td>
                <td>{l.phone}</td>
                <td className="actions">
                  <button className="btn btn-ghost btn-sm" onClick={() => setRejecting(l)} disabled={busy}>
                    Reject
                  </button>
                  <button className="btn btn-success btn-sm" style={{ marginLeft: 8 }} onClick={() => approve(l)} disabled={busy}>
                    Approve
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {rejecting && (
        <Modal
          title={`Reject ${rejecting.name}`}
          onClose={() => setRejecting(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setRejecting(null)}>
                Cancel
              </button>
              <button className="btn btn-danger" onClick={reject} disabled={busy || !reason.trim()}>
                Confirm
              </button>
            </>
          }
        >
          <div className="field">
            <label>Rejection reason</label>
            <textarea className="input" rows={3} value={reason} onChange={(e) => setReason(e.target.value)} />
          </div>
        </Modal>
      )}
    </div>
  );
}
