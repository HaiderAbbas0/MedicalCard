import { useCallback, useEffect, useState } from 'react';
import { doctorApi } from '../../api/doctor';
import type { LabOrderForReview } from '../../api/types';
import { Spinner, Empty } from '../../components/ui';

export default function LabReviewPage() {
  const [orders, setOrders] = useState<LabOrderForReview[] | null>(null);
  const [error, setError] = useState('');

  const load = useCallback(() => {
    setOrders(null);
    doctorApi.labOrdersForReview().then(setOrders).catch((e) => setError(e.message));
  }, []);

  useEffect(load, [load]);

  async function act(fn: () => Promise<unknown>) {
    try {
      await fn();
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Action failed.');
    }
  }

  if (error) return <div className="error-text">{error}</div>;
  if (!orders) return <Spinner />;
  if (orders.length === 0) return <div className="card"><Empty>No lab results awaiting review.</Empty></div>;

  return (
    <div style={{ display: 'grid', gap: 16 }}>
      {orders.map((o) => {
        const structured = o.result?.structured_results ?? [];
        return (
          <div key={o.id} className="card card-pad">
            <div className="between">
              <h3 style={{ margin: 0 }}>{o.test_name}</h3>
              <span className={`badge ${o.status === 'reviewed' ? 'badge-blue' : 'badge-amber'}`}>{o.status}</span>
            </div>
            <p className="muted" style={{ marginTop: 4 }}>Patient: {o.patient?.full_name ?? '—'}</p>

            {structured.length > 0 && (
              <table className="table" style={{ marginTop: 8 }}>
                <tbody>
                  {structured.map((r, i) => (
                    <tr key={i}>
                      <td>{r.name}</td>
                      <td style={{ textAlign: 'right' }}><strong>{r.value} {r.unit}</strong></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            {o.result?.comments && <p style={{ fontStyle: 'italic' }} className="muted">{o.result.comments}</p>}
            {o.result?.result_file_url && (
              <p><a href={o.result.result_file_url} target="_blank" rel="noreferrer">📄 {o.result.result_file_name ?? 'View result file'}</a></p>
            )}

            <div className="toolbar" style={{ marginTop: 12, marginBottom: 0 }}>
              {o.status === 'resulted' && (
                <button className="btn btn-ghost" onClick={() => act(() => doctorApi.reviewLabOrder(o.id))}>Mark reviewed</button>
              )}
              {o.status === 'reviewed' && (
                <button className="btn btn-success" onClick={() => act(() => doctorApi.releaseLabOrder(o.id))}>Release to patient</button>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
