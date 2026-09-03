import { useCallback, useEffect, useRef, useState } from 'react';
import { labApi } from '../../api/lab';
import type { LabQueueOrder, LabRecentReport } from '../../api/types';
import { Spinner, Empty, Modal, StatusBadge } from '../../components/ui';

const PRIORITY_CLASS: Record<string, string> = { stat: 'badge-red', urgent: 'badge-amber', routine: 'badge-green' };

export default function LabQueuePage() {
  const [tab, setTab] = useState<'queue' | 'recent'>('queue');
  const [orders, setOrders] = useState<LabQueueOrder[] | null>(null);
  const [recent, setRecent] = useState<LabRecentReport[] | null>(null);
  const [error, setError] = useState('');
  const [uploadFor, setUploadFor] = useState<LabQueueOrder | null>(null);
  const [showDirectUpload, setShowDirectUpload] = useState(false);
  const [cancellingId, setCancellingId] = useState<string | null>(null);

  const load = useCallback(() => {
    setError('');
    if (tab === 'queue') {
      setOrders(null);
      labApi.queue().then(setOrders).catch((e) => setError(e.message));
    } else {
      setRecent(null);
      labApi.recentReports().then(setRecent).catch((e) => setError(e.message));
    }
  }, [tab]);

  useEffect(load, [load]);

  async function act(fn: () => Promise<unknown>) {
    try {
      await fn();
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Action failed.');
    }
  }

  async function handleCancelSend(orderId: string) {
    if (!window.confirm('Are you sure you want to cancel / recall this report? It will be marked as cancelled and revoked.')) {
      return;
    }
    setCancellingId(orderId);
    try {
      await labApi.cancelReport(orderId);
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to cancel report.');
    } finally {
      setCancellingId(null);
    }
  }

  return (
    <>
      <div className="toolbar between" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            className={`btn ${tab === 'queue' ? 'btn-primary' : 'btn-ghost'}`}
            onClick={() => setTab('queue')}
          >
            Orders Queue
          </button>
          <button
            className={`btn ${tab === 'recent' ? 'btn-primary' : 'btn-ghost'}`}
            onClick={() => setTab('recent')}
          >
            Sent / Uploaded Reports
          </button>
        </div>
        <button className="btn btn-success" onClick={() => setShowDirectUpload(true)}>
          + Add Report by Hayaat ID
        </button>
      </div>

      {error && <div className="error-text" style={{ marginBottom: 12 }}>{error}</div>}

      {tab === 'queue' ? (
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
      ) : (
        <div className="card">
          {!recent ? (
            <Spinner />
          ) : recent.length === 0 ? (
            <Empty>No sent reports found for this lab.</Empty>
          ) : (
            <table className="table">
              <thead>
                <tr>
                  <th>Test Name</th>
                  <th>Patient</th>
                  <th>Hayaat ID</th>
                  <th>Report File</th>
                  <th>Status</th>
                  <th>Date</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {recent.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <strong>{r.test_name}</strong>
                      {r.result?.comments && <div className="muted" style={{ fontSize: 12 }}>{r.result.comments}</div>}
                    </td>
                    <td>{r.patient?.full_name ?? 'Walk-in Patient'}</td>
                    <td className="mono">{r.patient?.card_number ? r.patient.card_number.replace(/(\d{4})(?=\d)/g, '$1 ') : '—'}</td>
                    <td className="muted">{r.result?.result_file_name ?? '—'}</td>
                    <td><StatusBadge status={r.status} /></td>
                    <td className="muted">{r.ordered_at ? new Date(r.ordered_at).toLocaleDateString() : '—'}</td>
                    <td className="actions">
                      {r.status !== 'cancelled' ? (
                        <button
                          className="btn btn-danger btn-sm"
                          onClick={() => handleCancelSend(r.id)}
                          disabled={cancellingId === r.id}
                        >
                          {cancellingId === r.id ? 'Cancelling…' : 'Cancel Send'}
                        </button>
                      ) : (
                        <span className="badge badge-gray">Cancelled</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {uploadFor && (
        <UploadModal order={uploadFor} onClose={() => setUploadFor(null)} onDone={() => { setUploadFor(null); load(); }} />
      )}

      {showDirectUpload && (
        <DirectUploadModal
          onClose={() => setShowDirectUpload(false)}
          onDone={() => {
            setShowDirectUpload(false);
            setTab('recent');
            load();
          }}
        />
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
      <p className="muted" style={{ fontSize: 12 }}>Submitting notifies the ordering doctor and updates the record.</p>
    </Modal>
  );
}

function DirectUploadModal({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [identifier, setIdentifier] = useState('');
  const [patient, setPatient] = useState<{
    id: string;
    cnic: string;
    card_number: string;
    full_name: string;
    gender?: string;
    blood_group?: string;
  } | null>(null);
  const [lookingUp, setLookingUp] = useState(false);
  const [lookupError, setLookupError] = useState('');

  const [testName, setTestName] = useState('');
  const [priority, setPriority] = useState('routine');
  const [indication, setIndication] = useState('Walk-in patient test');
  const [comments, setComments] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [progress, setProgress] = useState('');

  async function handleLookup() {
    const raw = identifier.trim();
    if (!raw) return;
    setLookingUp(true);
    setLookupError('');
    setPatient(null);
    try {
      const p = await labApi.lookupPatient(raw);
      setPatient(p);
    } catch (e) {
      setLookupError(e instanceof Error ? e.message : 'Patient lookup failed.');
    } finally {
      setLookingUp(false);
    }
  }

  async function submit() {
    if (!patient) {
      setError('Please look up and verify the patient first using their 16-digit Hayaat ID.');
      return;
    }
    if (!testName.trim()) {
      setError('Please enter a test name (e.g. Complete Blood Count, Lipid Profile).');
      return;
    }
    const file = fileRef.current?.files?.[0];
    if (!file) {
      setError('Please select a result report file (PDF, JPG, or PNG).');
      return;
    }

    setBusy(true);
    setError('');
    setProgress('Preparing upload...');
    try {
      await labApi.createDirectReport({
        patientId: patient.id,
        testName: testName.trim(),
        priority,
        indication: indication.trim() || undefined,
        file,
        comments: comments.trim() || undefined,
        onProgress: setProgress,
      });
      onDone();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Direct report creation failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      title="Add Direct Report by Hayaat ID"
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={submit} disabled={busy || !patient}>
            {busy ? 'Uploading…' : 'Send Report to Patient'}
          </button>
        </>
      }
    >
      <div className="field">
        <label>Patient 16-digit Hayaat ID (or CNIC)</label>
        <div style={{ display: 'flex', gap: 8 }}>
          <input
            className="input"
            placeholder="e.g. 16-digit card number"
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleLookup(); } }}
          />
          <button
            type="button"
            className="btn btn-primary"
            onClick={handleLookup}
            disabled={lookingUp || !identifier.trim()}
          >
            {lookingUp ? 'Verifying…' : 'Verify'}
          </button>
        </div>
      </div>

      {lookupError && <div className="error-text" style={{ marginBottom: 12 }}>{lookupError}</div>}

      {patient && (
        <div className="card" style={{ padding: 12, marginBottom: 16, background: 'var(--teal-light)', borderColor: 'var(--teal)' }}>
          <div style={{ fontWeight: 600, color: 'var(--teal-dark)', fontSize: 15 }}>
            ✓ Verified Patient: {patient.full_name}
          </div>
          <div className="muted" style={{ fontSize: 13, marginTop: 4 }}>
            Hayaat ID: <strong className="mono">{patient.card_number.replace(/(\d{4})(?=\d)/g, '$1 ')}</strong>
            {patient.blood_group && ` · Blood: ${patient.blood_group}`}
            {patient.gender && ` · ${patient.gender}`}
          </div>
        </div>
      )}

      <div className="field">
        <label>Test Name</label>
        <input
          className="input"
          placeholder="e.g. Complete Blood Count, HbA1c, Lipid Profile, Urine Routine"
          value={testName}
          onChange={(e) => setTestName(e.target.value)}
        />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <div className="field">
          <label>Priority</label>
          <select className="select" value={priority} onChange={(e) => setPriority(e.target.value)}>
            <option value="routine">Routine</option>
            <option value="urgent">Urgent</option>
            <option value="stat">STAT</option>
          </select>
        </div>
        <div className="field">
          <label>Indication / Clinical Note</label>
          <input
            className="input"
            placeholder="e.g. Routine checkup, Walk-in"
            value={indication}
            onChange={(e) => setIndication(e.target.value)}
          />
        </div>
      </div>

      <div className="field">
        <label>Result Report File (PDF / JPG / PNG, max 25 MB)</label>
        <input ref={fileRef} type="file" accept=".pdf,.jpg,.jpeg,.png" className="input" />
      </div>

      <div className="field">
        <label>Technician Comments / Findings (optional)</label>
        <textarea
          className="input"
          rows={2}
          placeholder="e.g. Normal findings, Hemoglobin levels optimal."
          value={comments}
          onChange={(e) => setComments(e.target.value)}
        />
      </div>

      {progress && <div className="muted" style={{ fontSize: 12 }}>{progress}</div>}
      {error && <div className="error-text">{error}</div>}
      <p className="muted" style={{ fontSize: 12 }}>
        This report will be sent directly to the patient's Hayaat account and digital medical record.
      </p>
    </Modal>
  );
}
