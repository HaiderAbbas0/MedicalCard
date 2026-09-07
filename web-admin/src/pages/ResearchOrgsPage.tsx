import { useCallback, useEffect, useState } from 'react';
import { researchAdminApi, type ResearchOrg } from '../api/research';
import { TableSkeleton } from '../components/Skeleton';
import { Empty, Modal, StatusBadge } from '../components/ui';

type Action = { org: ResearchOrg; status: 'active' | 'rejected' | 'suspended' } | null;

const ACTION_COPY: Record<string, { title: string; verb: string; cls: string; needsReason: boolean }> = {
  active: { title: 'Approve organisation', verb: 'Approve', cls: 'btn-success', needsReason: false },
  rejected: { title: 'Reject organisation', verb: 'Reject', cls: 'btn-danger', needsReason: true },
  suspended: { title: 'Suspend organisation', verb: 'Suspend', cls: 'btn-danger', needsReason: true },
};

export default function ResearchOrgsPage() {
  const [orgs, setOrgs] = useState<ResearchOrg[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [action, setAction] = useState<Action>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    setOrgs(null);
    try {
      setOrgs(await researchAdminApi.organizations());
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load organisations.');
      setOrgs([]);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const confirm = async () => {
    if (!action) return;
    setBusy(true);
    try {
      await researchAdminApi.setOrganizationStatus(action.org.id, action.status, reason);
      setAction(null);
      setReason('');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Update failed.');
    } finally {
      setBusy(false);
    }
  };

  const copy = action ? ACTION_COPY[action.status] : null;

  return (
    <>
      <p className="muted" style={{ marginTop: 0 }}>
        Organisations approved here can sign in to the research portal and query de-identified,
        consent-gated data. Suspending one immediately blocks its researchers and its exports.
      </p>

      {error && <div className="error-text" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="card">
        {orgs === null ? (
          <TableSkeleton rows={5} cols={7} />
        ) : orgs.length === 0 ? (
          <Empty>No research organisations have registered yet.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Organisation</th>
                <th>Type</th>
                <th>Registration</th>
                <th>Contact</th>
                <th>Agreement</th>
                <th>Status</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {orgs.map((o) => (
                <tr key={o.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>{o.name}</div>
                    <div className="muted" style={{ fontSize: 12.5 }}>{o.country ?? '—'}</div>
                    {o.status_reason && (
                      <div className="muted" style={{ fontSize: 12.5, marginTop: 3 }}>
                        {o.status_reason}
                      </div>
                    )}
                  </td>
                  <td className="muted">{o.organization_type.replace(/_/g, ' ')}</td>
                  <td className="mono">{o.registration_number ?? '—'}</td>
                  <td className="muted">{o.contact_email ?? '—'}</td>
                  <td>
                    {o.dpa_accepted_at ? (
                      <span className="badge badge-green">signed</span>
                    ) : (
                      <span className="badge badge-amber">not signed</span>
                    )}
                  </td>
                  <td><StatusBadge status={o.status} /></td>
                  <td className="actions">
                    {o.status !== 'active' && (
                      <button
                        className="btn btn-success btn-sm"
                        onClick={() => setAction({ org: o, status: 'active' })}
                      >
                        Approve
                      </button>
                    )}
                    {o.status === 'pending' && (
                      <button
                        className="btn btn-ghost btn-sm"
                        style={{ marginLeft: 8 }}
                        onClick={() => setAction({ org: o, status: 'rejected' })}
                      >
                        Reject
                      </button>
                    )}
                    {o.status === 'active' && (
                      <button
                        className="btn btn-danger btn-sm"
                        style={{ marginLeft: 8 }}
                        onClick={() => setAction({ org: o, status: 'suspended' })}
                      >
                        Suspend
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {action && copy && (
        <Modal
          title={`${copy.title} — ${action.org.name}`}
          onClose={() => setAction(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setAction(null)} disabled={busy}>
                Cancel
              </button>
              <button
                className={`btn ${copy.cls}`}
                onClick={confirm}
                disabled={busy || (copy.needsReason && !reason.trim())}
              >
                {busy ? 'Saving…' : copy.verb}
              </button>
            </>
          }
        >
          {action.status === 'active' && !action.org.dpa_accepted_at && (
            <p style={{ color: 'var(--amber)', fontWeight: 600, marginTop: 0 }}>
              This organisation has not recorded a signed data-sharing agreement. Approve only if the
              agreement is in place outside the system.
            </p>
          )}
          <div className="field">
            <label>{copy.needsReason ? 'Reason (required)' : 'Note (optional)'}</label>
            <textarea
              className="input"
              rows={3}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              autoFocus
            />
          </div>
          <p className="muted" style={{ marginBottom: 0, fontSize: 13 }}>
            Recorded on the organisation record and visible to your fellow administrators.
          </p>
        </Modal>
      )}
    </>
  );
}
