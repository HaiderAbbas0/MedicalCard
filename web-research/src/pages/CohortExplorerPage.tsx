import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { researchApi } from '../api/research';
import type { CohortBucket, CohortFilters, CohortSize, PrevalenceRow } from '../api/types';
import { Bar, Notice, Spinner } from '../components/ui';

const PROVINCES = [
  'Punjab',
  'Sindh',
  'Khyber Pakhtunkhwa',
  'Balochistan',
  'Islamabad Capital Territory',
];
const GENDERS = ['male', 'female', 'other'];
const AGE_BANDS = [
  '0-4', '5-9', '10-14', '15-19', '20-24', '25-29', '30-34', '35-39',
  '40-44', '45-49', '50-54', '55-59', '60-64', '65-69', '70-74',
  '75-79', '80-84', '85-89', '90+',
];

const ICD_CHAPTERS: Record<string, string> = {
  A: 'Infectious diseases', B: 'Infectious diseases', C: 'Neoplasms',
  D: 'Blood & immune', E: 'Endocrine & metabolic', F: 'Mental & behavioural',
  G: 'Nervous system', H: 'Eye & ear', I: 'Circulatory',
  J: 'Respiratory', K: 'Digestive', L: 'Skin',
  M: 'Musculoskeletal', N: 'Genitourinary', O: 'Pregnancy & childbirth',
  P: 'Perinatal', Q: 'Congenital', R: 'Symptoms & signs',
  S: 'Injury', T: 'Injury & poisoning', Z: 'Health status factors',
  unclassified: 'Unclassified',
};

export default function CohortExplorerPage() {
  const navigate = useNavigate();
  const [filters, setFilters] = useState<CohortFilters>({});
  const [size, setSize] = useState<CohortSize | null>(null);
  const [byAge, setByAge] = useState<CohortBucket[] | null>(null);
  const [byProvince, setByProvince] = useState<CohortBucket[] | null>(null);
  const [byGender, setByGender] = useState<CohortBucket[] | null>(null);
  const [prevalence, setPrevalence] = useState<PrevalenceRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    setSize(null);
    try {
      const [s, age, province, gender, prev] = await Promise.all([
        researchApi.cohortSize(filters),
        researchApi.cohortBreakdown('age_band', filters),
        researchApi.cohortBreakdown('province', filters),
        researchApi.cohortBreakdown('gender', filters),
        researchApi.conditionPrevalence(),
      ]);
      setSize(s);
      setByAge(age);
      setByProvince(province);
      setByGender(gender);
      setPrevalence(prev);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not load cohort data.');
      setSize({ subject_count: 0, suppressed: false });
    }
  }, [filters]);

  useEffect(() => {
    void load();
  }, [load]);

  const set = (key: keyof CohortFilters, value: string) =>
    setFilters((f) => ({ ...f, [key]: value || null }));

  const hasFilters = Boolean(filters.gender || filters.province || filters.age_band);
  const maxOf = (rows: CohortBucket[] | null) =>
    Math.max(1, ...(rows ?? []).map((r) => r.subject_count ?? 0));

  return (
    <div className="stack">
      <Notice tone="indigo" icon="shield">
        Counts here cover only patients who have switched on research consent, and any group smaller
        than <strong>5 people</strong> is suppressed rather than shown. Narrow a filter far enough
        and you will see <strong>&lt; 5</strong> instead of a number — that is the k-anonymity
        threshold working as intended.
      </Notice>

      <div className="card card-pad">
        <div className="toolbar" style={{ marginBottom: 0 }}>
          <div className="field" style={{ marginBottom: 0, minWidth: 170 }}>
            <label htmlFor="f-age">Age band</label>
            <select id="f-age" className="select" value={filters.age_band ?? ''} onChange={(e) => set('age_band', e.target.value)}>
              <option value="">All ages</option>
              {AGE_BANDS.map((b) => <option key={b} value={b}>{b}</option>)}
            </select>
          </div>
          <div className="field" style={{ marginBottom: 0, minWidth: 170 }}>
            <label htmlFor="f-gender">Gender</label>
            <select id="f-gender" className="select" value={filters.gender ?? ''} onChange={(e) => set('gender', e.target.value)}>
              <option value="">All genders</option>
              {GENDERS.map((g) => <option key={g} value={g}>{g}</option>)}
            </select>
          </div>
          <div className="field" style={{ marginBottom: 0, minWidth: 230 }}>
            <label htmlFor="f-province">Province</label>
            <select id="f-province" className="select" value={filters.province ?? ''} onChange={(e) => set('province', e.target.value)}>
              <option value="">All provinces</option>
              {PROVINCES.map((p) => <option key={p} value={p}>{p}</option>)}
            </select>
          </div>
          {hasFilters && (
            <button className="btn btn-ghost" onClick={() => setFilters({})}>Clear filters</button>
          )}
          <button
            className="btn btn-primary"
            style={{ marginLeft: 'auto' }}
            onClick={() => navigate('/catalog', { state: { filters } })}
          >
            Request this cohort →
          </button>
        </div>
      </div>

      {error && <div className="card card-pad error-text" style={{ marginTop: 0 }}>{error}</div>}

      <div className="card card-pad">
        <div className="section-title">Matching subjects</div>
        {size === null ? (
          <Spinner />
        ) : size.suppressed ? (
          <Notice tone="amber" icon="alert">
            Fewer than 5 consented patients match these filters, so the exact count is withheld.
            Broaden the cohort to see a number.
          </Notice>
        ) : (
          <div className="cohort-size">
            <span className="n">{size.subject_count?.toLocaleString() ?? '0'}</span>
            <span className="unit">consented patients match</span>
          </div>
        )}
      </div>

      <div className="grid-2">
        <div className="card card-pad">
          <div className="section-title">By age band</div>
          {byAge === null ? <Spinner /> : byAge.length === 0 ? (
            <p className="muted">No data for this cohort.</p>
          ) : (
            byAge.map((b) => (
              <Bar key={b.bucket} label={b.bucket} value={b.subject_count} suppressed={b.suppressed} max={maxOf(byAge)} />
            ))
          )}
        </div>

        <div className="card card-pad">
          <div className="section-title">By province</div>
          {byProvince === null ? <Spinner /> : byProvince.length === 0 ? (
            <p className="muted">No data for this cohort.</p>
          ) : (
            byProvince.map((b) => (
              <Bar key={b.bucket} label={b.bucket} value={b.subject_count} suppressed={b.suppressed} max={maxOf(byProvince)} />
            ))
          )}
        </div>

        <div className="card card-pad">
          <div className="section-title">By gender</div>
          {byGender === null ? <Spinner /> : byGender.length === 0 ? (
            <p className="muted">No data for this cohort.</p>
          ) : (
            byGender.map((b) => (
              <Bar key={b.bucket} label={b.bucket} value={b.subject_count} suppressed={b.suppressed} max={maxOf(byGender)} />
            ))
          )}
        </div>

        <div className="card card-pad">
          <div className="section-title">Diagnosis prevalence (ICD-10 chapter)</div>
          <p className="muted" style={{ marginTop: 0, fontSize: 12.5 }}>
            Grouped to chapter level across the whole consented population, so a rare diagnosis
            cannot single anyone out.
          </p>
          {prevalence === null ? <Spinner /> : prevalence.length === 0 ? (
            <p className="muted">No diagnoses recorded yet.</p>
          ) : (
            prevalence.map((p) => (
              <Bar
                key={p.condition_group}
                label={ICD_CHAPTERS[p.condition_group] ?? p.condition_group}
                value={p.subject_count}
                suppressed={p.suppressed}
                max={Math.max(1, ...prevalence.map((r) => r.subject_count ?? 0))}
              />
            ))
          )}
        </div>
      </div>
    </div>
  );
}
