import { useCallback, useEffect, useRef, useState } from 'react';
import { labApi } from '../../api/lab';
import type { LabQueueOrder } from '../../api/types';
import { Spinner, Empty, Modal } from '../../components/ui';

const PRIORITY_CLASS: Record<string, string> = { stat: 'badge-red', urgent: 'badge-amber', routine: 'badge-green' };

export default function LabQueuePage() {
  const [orders, setOrders] = useState<LabQueueOrder[] | null>(null);
  const [error, setError] = useState('');
  const [uploadFor, setUploadFor] = useState<LabQueueOrder | null>(null);

  const load = useCallback(() => {
    setOrders(null);
    labApi.queue().then(setOrders).catch((e) => setError(e.message));
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

  return (
    <>
      {error && <div className="error-text" style={{ marginBottom: 12 }}>{error}</div>}
      <div className="card">
        {!orders ? (
          <Spinner />
        ) : orders.length === 0 ? (
          <Empty>No pending orders for your lab.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr><th>Priority</th><th>Test</th><th>Patient</th><th>Indication</th><th>Status</th><th /></tr>
            </thead>
            <tbody>
              {orders.map((o) => (
                <tr key={o.id}>
                  <td><span className={`badge ${PRIORITY_CLASS[o.priority] ?? 'badge-gray'}`}>{o.priority.toUpperCase()}</span></td>
                  <td><strong>{o.test_name}</strong></td>
                  <td>{o.patient?.display_name ?? '—'}</td>
                  <td className="muted">{o.clinical_indication ?? '—'}</td>
                  <td>{o.status.replace(/_/g, ' ')}</td>
                  <td className="actions">
                    {o.status === 'ordered' && (
                      <button className="btn btn-ghost btn-sm" onClick={() => act(() => labApi.markCollected(o.id))}>Mark collected</button>
                    )}
                    {o.status === 'sample_collected' && (
                      <button className="btn btn-ghost btn-sm" onClick={() => act(() => labApi.markProcessing(o.id))}>Mark processing</button>
                    )}
                    {o.status === 'processing' && (
                      <button className="btn btn-success btn-sm" onClick={() => setUploadFor(o)}>Upload result</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {uploadFor && (
        <UploadModal order={uploadFor} onClose={() => setUploadFor(null)} onDone={() => { setUploadFor(null); load(); }} />
      )}
    </>
  );
}

function UploadModal({ order, onClose, onDone }: { order: LabQueueOrder; onClose: () => void; onDone: () => void }) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [comments, setComments] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [progress, setProgress] = useState('');

  async function submit() {
    setBusy(true);
    setError('');
    setProgress('Preparing upload...');
    try {
      const file = fileRef.current?.files?.[0];
      if (!file) {
        setError('Select the actual result PDF or image before submitting.');
        return;
      }
      await labApi.uploadResultFile(order.id, file, comments || undefined, setProgress);
      onDone();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Upload failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      title={`Upload result — ${order.test_name}`}
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={submit} disabled={busy}>{busy ? 'Submitting…' : 'Submit result'}</button>
        </>
      }
    >
      <div className="field">
        <label>Result file (PDF / image, max 25 MB)</label>
        <input ref={fileRef} type="file" accept=".pdf,.jpg,.jpeg,.png" className="input" />
      </div>
      <div className="field">
        <label>Comments (optional)</label>
        <textarea className="input" rows={3} value={comments} onChange={(e) => setComments(e.target.value)} />
      </div>
      {progress && <div className="muted" style={{ fontSize: 12 }}>{progress}</div>}
      {error && <div className="error-text">{error}</div>}
      {error && <p className="muted" style={{ fontSize: 12 }}>Fix the issue and submit again to retry.</p>}
      <p className="muted" style={{ fontSize: 12 }}>Submitting notifies the ordering doctor automatically.</p>
    </Modal>
  );
}
