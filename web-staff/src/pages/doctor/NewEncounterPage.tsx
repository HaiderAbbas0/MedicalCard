import { useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { doctorApi } from '../../api/doctor';
import { Spinner } from '../../components/ui';

export default function NewEncounterPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const created = useRef(false);

  const [encounterId, setEncounterId] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const [chief, setChief] = useState('');
  const [followUp, setFollowUp] = useState('');
  const [diagnoses, setDiagnoses] = useState<string[]>([]);
  const [meds, setMeds] = useState<string[]>([]);
  const [vitals, setVitals] = useState<string[]>([]);
  const [labOrders, setLabOrders] = useState<string[]>([]);
  const [labs, setLabs] = useState<{ id: string; name: string }[]>([]);
  const [warning, setWarning] = useState('');

  const [dxInput, setDxInput] = useState('');
  const [medInput, setMedInput] = useState('');
  const [vitalName, setVitalName] = useState('');
  const [vitalValue, setVitalValue] = useState('');
  const [testInput, setTestInput] = useState('');
  const [labId, setLabId] = useState('');
  const [priority, setPriority] = useState('routine');

  useEffect(() => {
    if (created.current) return;
    created.current = true;
    doctorApi.createEncounter(id).then((enc) => setEncounterId(enc.id)).catch((e) => setError(e.message));
    doctorApi.labs().then((l) => { setLabs(l); if (l[0]) setLabId(l[0].id); }).catch(() => undefined);
  }, [id]);

  async function run(fn: () => Promise<unknown>) {
    try {
      await fn();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Action failed.');
    }
  }

  async function addDx() {
    if (!dxInput.trim() || !encounterId) return;
    await run(async () => {
      await doctorApi.addCondition(encounterId, { condition_display: dxInput.trim() });
      setDiagnoses((d) => [...d, dxInput.trim()]);
      setDxInput('');
    });
  }

  async function addMed() {
    if (!medInput.trim() || !encounterId) return;
    await run(async () => {
      const res = await doctorApi.addMedication(encounterId, { medication_name: medInput.trim() });
      setMeds((m) => [...m, medInput.trim()]);
      setMedInput('');
      if (res.allergy_warning) setWarning(res.allergy_warning);
    });
  }

  async function addVital() {
    if (!vitalName.trim() || !encounterId) return;
    await run(async () => {
      await doctorApi.addVital(encounterId, { observation_display: vitalName.trim(), value_quantity: vitalValue ? Number(vitalValue) : undefined });
      setVitals((v) => [...v, `${vitalName.trim()}${vitalValue ? ` = ${vitalValue}` : ''}`]);
      setVitalName('');
      setVitalValue('');
    });
  }

  async function addLab() {
    if (!testInput.trim() || !encounterId || !labId) return;
    await run(async () => {
      await doctorApi.addLabOrder(encounterId, { test_name: testInput.trim(), lab_id: labId, priority });
      setLabOrders((l) => [...l, `${testInput.trim()} (${priority})`]);
      setTestInput('');
    });
  }

  async function finalize() {
    if (!encounterId) return;
    setBusy(true);
    try {
      const patch: Record<string, unknown> = {};
      if (chief.trim()) patch.chief_complaint = chief.trim();
      if (followUp.trim()) { patch.follow_up_required = true; patch.follow_up_date = followUp.trim(); }
      if (Object.keys(patch).length) await doctorApi.updateEncounter(encounterId, patch);
      await doctorApi.finalizeEncounter(encounterId);
      navigate(`/doctor/patient/${id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to finalize.');
      setBusy(false);
    }
  }

  if (error && !encounterId) return <div className="error-text">{error}</div>;
  if (!encounterId) return <Spinner />;

  return (
    <div style={{ maxWidth: 720 }}>
      <button className="btn btn-ghost" onClick={() => navigate(`/doctor/patient/${id}`)}>← Back to record</button>

      {warning && (
        <div className="card card-pad" style={{ marginTop: 16, background: 'var(--red-bg)', borderColor: 'var(--red)' }}>
          <strong style={{ color: 'var(--red)' }}>⚠ Allergy warning</strong>
          <p style={{ margin: '6px 0 0' }}>{warning}</p>
          <button className="btn btn-ghost btn-sm" style={{ marginTop: 8 }} onClick={() => setWarning('')}>Acknowledge</button>
        </div>
      )}

      <div className="card card-pad" style={{ marginTop: 16 }}>
        <div className="field"><label>Chief complaint</label>
          <textarea className="input" rows={2} value={chief} onChange={(e) => setChief(e.target.value)} /></div>
      </div>

      <Section title="Diagnoses" items={diagnoses}>
        <div className="row">
          <input className="input" placeholder="Condition (e.g. Hypertension)" value={dxInput} onChange={(e) => setDxInput(e.target.value)} />
          <button className="btn btn-ghost" onClick={addDx}>Add</button>
        </div>
      </Section>

      <Section title="Medications" items={meds}>
        <div className="row">
          <input className="input" placeholder="Medication name" value={medInput} onChange={(e) => setMedInput(e.target.value)} />
          <button className="btn btn-ghost" onClick={addMed}>Add</button>
        </div>
      </Section>

      <Section title="Vitals" items={vitals}>
        <div className="row">
          <input className="input" placeholder="Name (e.g. BP Systolic)" value={vitalName} onChange={(e) => setVitalName(e.target.value)} />
          <input className="input" style={{ maxWidth: 120 }} placeholder="Value" value={vitalValue} onChange={(e) => setVitalValue(e.target.value)} />
          <button className="btn btn-ghost" onClick={addVital}>Add</button>
        </div>
      </Section>

      <Section title="Lab orders" items={labOrders}>
        <div className="row">
          <input className="input" placeholder="Test name (e.g. CBC)" value={testInput} onChange={(e) => setTestInput(e.target.value)} />
          <select className="select" style={{ maxWidth: 180 }} value={labId} onChange={(e) => setLabId(e.target.value)}>
            {labs.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
          </select>
          <select className="select" style={{ maxWidth: 130 }} value={priority} onChange={(e) => setPriority(e.target.value)}>
            <option value="routine">Routine</option>
            <option value="urgent">Urgent</option>
            <option value="stat">STAT</option>
          </select>
          <button className="btn btn-ghost" onClick={addLab}>Add</button>
        </div>
      </Section>

      <div className="card card-pad" style={{ marginTop: 16 }}>
        <div className="field"><label>Follow-up date (optional)</label>
          <input type="date" className="input" value={followUp} onChange={(e) => setFollowUp(e.target.value)} /></div>
      </div>

      {error && <div className="error-text">{error}</div>}

      <button className="btn btn-primary" style={{ marginTop: 16, width: '100%' }} onClick={finalize} disabled={busy}>
        {busy ? 'Finalizing…' : 'Finalize encounter (locks the record)'}
      </button>
    </div>
  );
}

function Section({ title, items, children }: { title: string; items: string[]; children: React.ReactNode }) {
  return (
    <div className="card card-pad" style={{ marginTop: 16 }}>
      <p className="section-title">{title}</p>
      {children}
      {items.length > 0 && <ul style={{ marginBottom: 0 }}>{items.map((it, i) => <li key={i}>{it}</li>)}</ul>}
    </div>
  );
}
