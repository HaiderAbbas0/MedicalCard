import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { useLocation } from 'react-router-dom';
import { researchApi } from '../api/research';
import type { CohortFilters, ResearchDataset } from '../api/types';
import { useAuth } from '../auth/AuthContext';
import { CardSkeleton } from '../components/Skeleton';
import { Empty, Modal, Notice } from '../components/ui';

const LEGAL_BASES = [
  { value: 'consent', label: 'Explicit consent (GDPR Art. 9(2)(a))' },
  { value: 'public_interest', label: 'Public interest in public health (Art. 9(2)(i))' },
  { value: 'legitimate_interest', label: 'Scientific research (Art. 9(2)(j))' },
];

export default function CatalogPage() {
  const { user } = useAuth();
  const location = useLocation();
  // A cohort carried over from the explorer, so the approver reviews exactly
  // the population the researcher looked at.
  const carried = (location.state as { filters?: CohortFilters } | null)?.filters ?? {};

  const [datasets, setDatasets] = useState<ResearchDataset[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [target, setTarget] = useState<ResearchDataset | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setDatasets(await researchApi.datasets());
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not load the catalogue.');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const describeFilters = (f: CohortFilters) => {
    const parts = [
      f.age_band && `age ${f.age_band}`,
      f.gender && `gender ${f.gender}`,
      f.province && f.province,
    ].filter(Boolean);
    return parts.length ? parts.join(' · ') : 'Entire consented population';
  };

  return (
    <div className="stack">
      <Notice tone="indigo" icon="lock">
        Every dataset below is a de-identified projection, never a raw table. Record-level access
        requires an approved request, and each approval is time-limited.
      </Notice>

      {error && <div className="card card-pad error-text">{error}</div>}

      {datasets === null ? (
        <CardSkeleton count={3} />
      ) : datasets.length === 0 ? (
        <div className="card"><Empty>No datasets are published yet.</Empty></div>
      ) : (
        datasets.map((d) => (
          <div key={d.id} className="card card-pad">
            <div className="dataset-head">
              <div>
                <h3 style={{ margin: '0 0 4px' }}>{d.name}</h3>
                <div className="row" style={{ gap: 8 }}>
                  <span className="badge badge-indigo">{d.code}</span>
                  <span className="badge badge-gray">{d.grain}</span>
                  <span className={`badge ${d.tier === 'aggregate' ? 'badge-green' : 'badge-amber'}`}>
                    {d.tier === 'aggregate' ? 'open aggregate' : 'approval required'}
                  </span>
                </div>
              </div>
              <button className="btn btn-primary" onClick={() => setTarget(d)}>
                Request access
              </button>
            </div>
            <p className="muted" style={{ marginBottom: 14 }}>{d.description}</p>

            <details>
              <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: 13 }}>
                Data dictionary ({d.dictionary.length} columns)
              </summary>
              <div className="table-wrap" style={{ marginTop: 10 }}>
                <table className="table dict-table">
                  <thead>
                    <tr><th>Column</th><th>Type</th><th>Description</th></tr>
                  </thead>
                  <tbody>
                    {d.dictionary.map((c) => (
                      <tr key={c.column}>
                        <td className="col">{c.column}</td>
                        <td className="type">{c.type}</td>
                        <td className="muted">{c.description ?? '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </details>
          </div>
        ))
      )}

      {target && user?.extended?.organization_id && (
        <RequestModal
          dataset={target}
          organizationId={user.extended.organization_id}
          filters={carried}
          describeFilters={describeFilters}
          onClose={() => setTarget(null)}
        />
      )}
    </div>
  );
}

function RequestModal({
  dataset,
  organizationId,
  filters,
  describeFilters,
  onClose,
}: {
  dataset: ResearchDataset;
  organizationId: string;
  filters: CohortFilters;
  describeFilters: (f: CohortFilters) => string;
  onClose: () => void;
}) {
  const [title, setTitle] = useState('');
  const [purpose, setPurpose] = useState('');
  const [legalBasis, setLegalBasis] = useState('consent');
  const [ethicsRef, setEthicsRef] = useState('');
  const [agreed, setAgreed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!title.trim() || purpose.trim().length < 30) {
      setError('Give the study a title and describe the purpose in at least 30 characters.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await researchApi.createRequest({
        organization_id: organizationId,
        dataset_id: dataset.id,
        title: title.trim(),
        research_purpose: purpose.trim(),
        legal_basis: legalBasis,
        ethics_approval_reference: ethicsRef.trim() || null,
        cohort_filters: filters,
      });
      setDone(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not submit the request.');
    } finally {
      setBusy(false);
    }
  };

  if (done) {
    return (
      <Modal
        title="Request submitted"
        onClose={onClose}
        footer={<button className="btn btn-primary" onClick={onClose}>Done</button>}
      >
        <Notice tone="green" icon="check">
          Your request has been sent for review. You will be notified once an administrator makes a
          decision, and the dataset will then appear under <strong>Downloads</strong>.
        </Notice>
      </Modal>
    );
  }

  return (
    <Modal
      title={`Request access — ${dataset.name}`}
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose} disabled={busy}>Cancel</button>
          <button className="btn btn-primary" onClick={submit} disabled={busy || !agreed}>
            {busy ? 'Submitting…' : 'Submit request'}
          </button>
        </>
      }
    >
      <form onSubmit={submit}>
        <div className="field">
          <label htmlFor="r-title">Study title</label>
          <input id="r-title" className="input" value={title} onChange={(e) => setTitle(e.target.value)} autoFocus />
        </div>

        <div className="field">
          <label htmlFor="r-purpose">Research purpose</label>
          <textarea
            id="r-purpose"
            className="textarea"
            rows={4}
            value={purpose}
            onChange={(e) => setPurpose(e.target.value)}
            placeholder="What question will this data answer, and how will the results be used?"
          />
          <div className="hint">
            Recorded verbatim and bound to the extract. Using the data for anything else breaches
            purpose limitation (GDPR Art. 5(1)(b)).
          </div>
        </div>

        <div className="field">
          <label htmlFor="r-basis">Legal basis</label>
          <select id="r-basis" className="select" value={legalBasis} onChange={(e) => setLegalBasis(e.target.value)}>
            {LEGAL_BASES.map((b) => <option key={b.value} value={b.value}>{b.label}</option>)}
          </select>
        </div>

        <div className="field">
          <label htmlFor="r-ethics">Ethics approval reference (optional)</label>
          <input id="r-ethics" className="input" value={ethicsRef} onChange={(e) => setEthicsRef(e.target.value)} placeholder="e.g. IRB-2026-0142" />
        </div>

        <div className="field">
          <label>Cohort requested</label>
          <div className="card card-pad" style={{ boxShadow: 'none', background: 'var(--bg)' }}>
            {describeFilters(filters)}
          </div>
          <div className="hint">Carried over from the Cohort Explorer so the approver sees exactly what you looked at.</div>
        </div>

        <label className="row" style={{ alignItems: 'flex-start', gap: 10, cursor: 'pointer' }}>
          <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} style={{ marginTop: 3 }} />
          <span style={{ fontSize: 13, lineHeight: 1.55 }}>
            On behalf of my organisation I accept the data-sharing agreement: we will not attempt to
            re-identify any individual, will not link this extract to any other dataset or person,
            will use it only for the stated purpose, and will delete it when access expires.
          </span>
        </label>

        {error && <div className="error-text">{error}</div>}
      </form>
    </Modal>
  );
}
