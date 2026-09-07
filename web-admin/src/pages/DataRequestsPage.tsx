import { useCallback, useEffect, useState } from 'react';
import { researchAdminApi, type AdminDataRequest } from '../api/research';
import { TableSkeleton } from '../components/Skeleton';
import { Empty, Modal, StatusBadge } from '../components/ui';

type Decision = 'approved' | 'rejected' | 'revoked';
type Target = { req: AdminDataRequest; decision: Decision } | null;

const DECISION_COPY: Record<Decision, { verb: string; cls: string; needsReason: boolean }> = {
  approved: { verb: 'Approve', cls: 'btn-success', needsReason: false },
  rejected: { verb: 'Reject', cls: 'btn-danger', needsReason: true },
  revoked: { verb: 'Revoke', cls: 'btn-danger', needsReason: true },
};

function describeCohort(filters: Record<string, string | null> | null): string {
  if (!filters) return 'Entire consented population';
  const parts = [
    filters.age_band && `age ${filters.age_band}`,
    filters.gender && `gender ${filters.gender}`,
    filters.province,
  ].filter(Boolean);
  return parts.length ? parts.join(' · ') : 'Entire consented population';
}

export default function DataRequestsPage() {
  const [requests, setRequests] = useState<AdminDataRequest[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [target, setTarget] = useState<Target>(null);
  const [note, setNote] = useState('');
  const [validDays, setValidDays] = useState(180);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    setRequests(null);
    try {
      setRequests(await researchAdminApi.dataRequests());
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load data requests.');
      setRequests([]);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const confirm = async () => {
    if (!target) return;
    setBusy(true);
    try {
      await researchAdminApi.decide(target.req.id, target.decision, note, validDays);
      setTarget(null);
      setNote('');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Decision failed.');
    } finally {
      setBusy(false);
    }
  };

  const fmt = (d: string | null) => (d ? new Date(d).toLocaleDateString() : '—');
  const copy = target ? DECISION_COPY[target.decision] : null;

  return (
    <>
      <p className="muted" style={{ marginTop: 0 }}>
        Each request states a purpose, a legal basis and the exact cohort the researcher explored.
        Approving grants time-limited access to a de-identified, consent-gated extract; nothing here
        can release identifiable data.
      </p>

      {error && <div className="error-text" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="card">
        {requests === null ? (
          <TableSkeleton rows={5} cols={8} />
        ) : requests.length === 0 ? (
          <Empty>No data requests yet.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Study</th>
                <th>Organisation</th>
                <th>Dataset</th>
                <th>Cohort</th>
                <th>Submitted</th>
                <th>Expires</th>
                <th>Status</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {requests.map((r) => (
                <tr key={r.id}>
                  <td style={{ maxWidth: 300 }}>
                    <div style={{ fontWeight: 600 }}>{r.title}</div>
                    <div className="muted" style={{ fontSize: 12.5 }}>{r.research_purpose}</div>
                    <div className="muted" style={{ fontSize: 12.5, marginTop: 4 }}>
                      Basis: {r.legal_basis.replace(/_/g, ' ')}
                      {r.ethics_approval_reference && ` · Ethics ${r.ethics_approval_reference}`}
                      {r.export_count > 0 && ` · ${r.export_count} export(s)`}
                    </div>
                    {r.decision_note && (
                      <div className="muted" style={{ fontSize: 12.5, marginTop: 4 }}>
                        <strong>Note:</strong> {r.decision_note}
                      </div>
                    )}
                  </td>
                  <td>
                    <div>{r.organization?.name ?? '—'}</div>
                    <div className="muted" style={{ fontSize: 12.5 }}>
                      {r.requester?.full_name ?? '—'}
                    </div>
                  </td>
                  <td className="muted">{r.dataset?.name ?? '—'}</td>
                  <td className="muted">{describeCohort(r.cohort_filters)}</td>
                  <td className="muted">{fmt(r.created_at)}</td>
                  <td className="muted">{fmt(r.expires_at)}</td>
                  <td><StatusBadge status={r.status} /></td>
                  <td className="actions">
                    {r.status === 'pending' && (
                      <>
                        <button
                          className="btn btn-success btn-sm"
                          onClick={() => setTarget({ req: r, decision: 'approved' })}
                        >
                          Approve
                        </button>
                        <button
                          className="btn btn-ghost btn-sm"
                          style={{ marginLeft: 8 }}
                          onClick={() => setTarget({ req: r, decision: 'rejected' })}
                        >
                          Reject
                        </button>
                      </>
                    )}
                    {r.status === 'approved' && (
                      <button
                        className="btn btn-danger btn-sm"
                        onClick={() => setTarget({ req: r, decision: 'revoked' })}
                      >
                        Revoke
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {target && copy && (
        <Modal
          title={`${copy.verb} — ${target.req.title}`}
          onClose={() => setTarget(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setTarget(null)} disabled={busy}>
                Cancel
              </button>
              <button
                className={`btn ${copy.cls}`}
                onClick={confirm}
                disabled={busy || (copy.needsReason && !note.trim())}
              >
                {busy ? 'Saving…' : copy.verb}
              </button>
            </>
          }
        >
          <div className="field">
            <label>Purpose stated by the requester</label>
            <div className="card card-pad" style={{ boxShadow: 'none', background: 'var(--bg)' }}>
              {target.req.research_purpose}
            </div>
          </div>

          {target.decision === 'approved' && (
            <div className="field">
              <label htmlFor="valid-days">Access valid for (days)</label>
              <input
                id="valid-days"
                className="input"
                type="number"
                min={1}
                value={validDays}
                onChange={(e) => setValidDays(Number(e.target.value) || 1)}
              />
              <p className="muted" style={{ fontSize: 13, marginBottom: 0 }}>
                Exports stop working automatically at the database level once this expires.
              </p>
            </div>
          )}

          <div className="field">
            <label>{copy.needsReason ? 'Reason (required)' : 'Note to the requester (optional)'}</label>
            <textarea
              className="input"
              rows={3}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              autoFocus
            />
          </div>

          <p className="muted" style={{ marginBottom: 0, fontSize: 13 }}>
            The requester is notified of this decision, and it is written to the audit log.
          </p>
        </Modal>
      )}
    </>
  );
}
