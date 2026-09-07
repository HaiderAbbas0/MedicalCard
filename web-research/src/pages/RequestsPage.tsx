import { useCallback, useEffect, useState } from 'react';
import { researchApi } from '../api/research';
import type { DataRequest } from '../api/types';
import { Empty, Notice, Spinner, StatusBadge } from '../components/ui';

export default function RequestsPage() {
  const [requests, setRequests] = useState<DataRequest[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    setRequests(null);
    try {
      setRequests(await researchApi.myRequests());
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not load requests.');
      setRequests([]);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const fmt = (d: string | null) => (d ? new Date(d).toLocaleDateString() : '—');

  return (
    <div className="stack">
      <Notice tone="indigo" icon="info">
        Requests are reviewed by a HayaatID administrator. An approval is time-limited — once it
        expires, exports stop working until you request access again.
      </Notice>

      {error && <div className="card card-pad error-text">{error}</div>}

      <div className="card">
        {requests === null ? (
          <Spinner />
        ) : requests.length === 0 ? (
          <Empty>
            No requests yet. Browse the <strong>Dataset Catalogue</strong> to request access.
          </Empty>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Study</th>
                  <th>Dataset</th>
                  <th>Legal basis</th>
                  <th>Submitted</th>
                  <th>Expires</th>
                  <th>Exports</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {requests.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{r.title}</div>
                      <div className="muted" style={{ fontSize: 12.5, maxWidth: 320 }}>
                        {r.research_purpose.length > 110
                          ? `${r.research_purpose.slice(0, 110)}…`
                          : r.research_purpose}
                      </div>
                      {r.decision_note && (
                        <div className="muted" style={{ fontSize: 12.5, marginTop: 4 }}>
                          <strong>Reviewer:</strong> {r.decision_note}
                        </div>
                      )}
                    </td>
                    <td>{r.dataset?.name ?? '—'}</td>
                    <td className="muted">{r.legal_basis.replace(/_/g, ' ')}</td>
                    <td className="muted">{fmt(r.created_at)}</td>
                    <td className="muted">{fmt(r.expires_at)}</td>
                    <td className="muted">{r.export_count}</td>
                    <td><StatusBadge status={r.status} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
