import { useEffect, useState } from 'react';
import { adminApi } from '../api/admin';
import type { DeletionRequest, DeletionStatus } from '../api/types';
import { Spinner, Empty, Modal, StatusBadge } from '../components/ui';

const ACTIONS: { status: DeletionStatus; label: string; cls: string }[] = [
  { status: 'processing', label: 'Mark processing', cls: 'btn-ghost' },
  { status: 'completed', label: 'Erase account', cls: 'btn-success' },
  { status: 'rejected', label: 'Reject', cls: 'btn-danger' },
];

export default function DeletionRequestsPage() {
  const [requests, setRequests] = useState<DeletionRequest[] | null>(null);
  const [error, setError] = useState('');
  const [acting, setActing] = useState<{ req: DeletionRequest; status: DeletionStatus } | null>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);

  function load() {
    setRequests(null);
    adminApi.deletionRequests().then(setRequests).catch((e) => setError(e.message));
  }
  useEffect(load, []);

  function begin(req: DeletionRequest, status: DeletionStatus) {
    setActing({ req, status });
    setNote(req.note ?? '');
  }

  async function confirm() {
    if (!acting) return;
    setBusy(true);
    try {
      await adminApi.updateDeletionRequest(acting.req.id, acting.status, note);
      setActing(null);
      setNote('');
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to update request.');
    } finally {
      setBusy(false);
    }
  }

  if (error) return <div className="error-text">{error}</div>;

  return (
    <>
      <div className="card">
        {!requests ? (
          <Spinner />
        ) : requests.length === 0 ? (
          <Empty>No account deletion requests.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Requested</th>
                <th>Name</th>
                <th>Hayaat ID</th>
                <th>Reason</th>
                <th>Status</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {requests.map((r) => (
                <tr key={r.id}>
                  <td className="muted">{new Date(r.requested_at).toLocaleString()}</td>
                  <td>{r.full_name ?? '—'}</td>
                  <td className="mono">{r.card_number?.replace(/(\d{4})(?=\d)/g, '$1 ') ?? '—'}</td>
                  <td className="muted">{r.reason || '—'}</td>
                  <td><StatusBadge status={r.status} /></td>
                  <td className="actions">
                    {ACTIONS.map((a) => (
                      <button
                        key={a.status}
                        className={`btn ${a.cls} btn-sm`}
                        disabled={r.status === a.status || r.status === 'completed' || (a.status === 'completed' && !r.user_id)}
                        onClick={() => begin(r, a.status)}
                      >
                        {a.label}
                      </button>
                    ))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {acting && (
        <Modal
          title={`Update request — ${acting.req.full_name ?? acting.req.card_number ?? 'user'}`}
          onClose={() => setActing(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setActing(null)}>
                Cancel
              </button>
              <button
                className={acting.status === 'rejected' ? 'btn btn-danger' : acting.status === 'completed' ? 'btn btn-success' : 'btn btn-primary'}
                onClick={confirm}
                disabled={busy}
              >
                {busy ? 'Saving…' : acting.status === 'completed' ? 'Erase account' : `Set to ${acting.status}`}
              </button>
            </>
          }
        >
          {acting.status === 'completed' && (
            <p className="muted">
              This calls the delete-account Edge Function. The request is marked completed only after
              storage, profile data, and the Supabase Auth user are erased.
            </p>
          )}
          <div className="field">
            <label>Note (optional)</label>
            <textarea className="input" rows={3} value={note} onChange={(e) => setNote(e.target.value)} />
          </div>
        </Modal>
      )}
    </>
  );
}
