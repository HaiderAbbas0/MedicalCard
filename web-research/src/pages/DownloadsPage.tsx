import { useCallback, useEffect, useState } from 'react';
import { buildManifest, downloadFile, researchApi, toCsv, toJsonl } from '../api/research';
import type { DataRequest } from '../api/types';
import { Empty, Notice, Spinner } from '../components/ui';

export default function DownloadsPage() {
  const [requests, setRequests] = useState<DataRequest[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    setRequests(null);
    try {
      const all = await researchApi.myRequests();
      const live = all.filter(
        (r) => r.status === 'approved' && (!r.expires_at || new Date(r.expires_at) > new Date()),
      );
      setRequests(live);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not load approved requests.');
      setRequests([]);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const download = async (req: DataRequest, format: 'csv' | 'jsonl') => {
    const code = req.dataset?.code;
    if (!code) {
      setError('This request is not linked to a known dataset.');
      return;
    }
    setBusyId(req.id);
    setError(null);
    setNote(null);
    try {
      const rows = await researchApi.exportRows(code, req.id);
      if (!rows.length) {
        setNote('That cohort returned no rows — no consented patients currently match.');
        return;
      }
      const stamp = new Date().toISOString().slice(0, 10);
      const base = `hayaat_${code}_${stamp}`;
      if (format === 'csv') {
        downloadFile(`${base}.csv`, toCsv(rows), 'text/csv');
      } else {
        downloadFile(`${base}.jsonl`, toJsonl(rows), 'application/x-ndjson');
      }
      // The manifest travels with the data so an extract is never separated
      // from the terms it was released under.
      downloadFile(
        `${base}_manifest.json`,
        buildManifest(req, rows.length, format),
        'application/json',
      );
      setNote(`Exported ${rows.length.toLocaleString()} rows, plus a provenance manifest.`);
      void load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Export failed.');
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="stack">
      <Notice tone="amber" icon="alert">
        Downloaded extracts are your organisation's responsibility under the data-sharing agreement.
        <code className="mono"> subject_id</code> is salted per request, so the same person carries a
        different id in every extract — attempting to link datasets together to re-identify anyone is
        prohibited and is logged.
      </Notice>

      {error && <div className="card card-pad error-text">{error}</div>}
      {note && (
        <div className="card card-pad" style={{ color: 'var(--green)', fontWeight: 600 }}>{note}</div>
      )}

      {requests === null ? (
        <Spinner />
      ) : requests.length === 0 ? (
        <div className="card">
          <Empty>
            No approved datasets yet. Once a request is approved it will appear here for download.
          </Empty>
        </div>
      ) : (
        requests.map((r) => (
          <div key={r.id} className="card card-pad">
            <div className="between" style={{ alignItems: 'flex-start' }}>
              <div>
                <h3 style={{ margin: '0 0 4px' }}>{r.title}</h3>
                <div className="row" style={{ gap: 8, marginBottom: 8 }}>
                  <span className="badge badge-indigo">{r.dataset?.code}</span>
                  <span className="badge badge-gray">{r.dataset?.grain}</span>
                  {r.expires_at && (
                    <span className="badge badge-amber">
                      expires {new Date(r.expires_at).toLocaleDateString()}
                    </span>
                  )}
                </div>
                <p className="muted" style={{ margin: 0, maxWidth: 620 }}>{r.research_purpose}</p>
              </div>
              <div className="row" style={{ flex: 'none' }}>
                <button
                  className="btn btn-ghost"
                  disabled={busyId === r.id}
                  onClick={() => download(r, 'jsonl')}
                >
                  {busyId === r.id ? 'Exporting…' : 'JSONL'}
                </button>
                <button
                  className="btn btn-primary"
                  disabled={busyId === r.id}
                  onClick={() => download(r, 'csv')}
                >
                  {busyId === r.id ? 'Exporting…' : 'Download CSV'}
                </button>
              </div>
            </div>
          </div>
        ))
      )}
    </div>
  );
}
