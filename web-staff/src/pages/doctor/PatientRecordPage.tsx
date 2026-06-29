import { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { doctorApi } from '../../api/doctor';
import type { Encounter, PatientSummary } from '../../api/types';
import { Spinner, Modal } from '../../components/ui';

export default function PatientRecordPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const [patient, setPatient] = useState<PatientSummary | null>(null);
  const [timeline, setTimeline] = useState<Encounter[]>([]);
  const [meds, setMeds] = useState<Record<string, unknown>[]>([]);
  const [error, setError] = useState('');
  const [showAllergy, setShowAllergy] = useState(false);

  const load = useCallback(() => {
    Promise.all([doctorApi.patient(id), doctorApi.timeline(id), doctorApi.medications(id)])
      .then(([p, t, m]) => {
        setPatient(p);
        setTimeline(t.items);
        setMeds(m);
      })
      .catch((e) => setError(e.message));
  }, [id]);

  useEffect(load, [load]);

  if (error) return <div className="error-text">{error}</div>;
  if (!patient) return <Spinner />;

  const allergies = (patient.allergies ?? []) as Record<string, unknown>[];

  return (
    <>
      <div className="toolbar between">
        <button className="btn btn-ghost" onClick={() => navigate('/doctor/patients')}>← Back to search</button>
        <div className="row">
          <button className="btn btn-ghost" onClick={() => setShowAllergy(true)}>Record allergy</button>
          <button className="btn btn-primary" onClick={() => navigate(`/doctor/patient/${id}/encounter`)}>+ New encounter</button>
        </div>
      </div>

      <div className="card card-pad">
        <h2 style={{ margin: 0 }}>{patient.full_name}</h2>
        <p className="muted" style={{ marginTop: 4 }}>
          CNIC {patient.cnic} · {patient.gender ?? '—'} · DOB {patient.date_of_birth ?? '—'} · Blood {patient.blood_group ?? '—'}
        </p>
        {allergies.length > 0 && (
          <div style={{ background: 'var(--red-bg)', color: 'var(--red)', padding: '10px 14px', borderRadius: 8, marginTop: 10 }}>
            <strong>Allergies:</strong> {allergies.map((a) => String(a.substance_name)).join(', ')}
          </div>
        )}
        {(patient.active_conditions ?? []).length > 0 && (
          <p style={{ marginBottom: 0 }}>
            <strong>Active conditions:</strong>{' '}
            {(patient.active_conditions ?? []).map((c) => String((c as Record<string, unknown>).condition_display)).join(', ')}
          </p>
        )}
      </div>

      <div className="card card-pad" style={{ marginTop: 16 }}>
        <p className="section-title">Active medications ({meds.length})</p>
        {meds.length === 0 ? (
          <p className="muted">None.</p>
        ) : (
          <table className="table">
            <tbody>
              {meds.map((m) => (
                <tr key={String(m.id)}>
                  <td><strong>{String(m.medication_name)}</strong></td>
                  <td>{[m.dosage_value, m.dosage_unit].filter(Boolean).join(' ')}</td>
                  <td className="muted">{String(m.frequency ?? '').replace(/_/g, ' ')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="card card-pad" style={{ marginTop: 16 }}>
        <p className="section-title">Health timeline ({timeline.length})</p>
        {timeline.length === 0 ? (
          <p className="muted">No finalized encounters.</p>
        ) : (
          timeline.map((e) => {
            const conditions = (e.conditions ?? []) as Record<string, unknown>[];
            const dx = conditions[0] ? String(conditions[0].condition_display) : e.assessment ?? 'Consultation';
            return (
              <div key={e.id} style={{ borderBottom: '1px solid var(--border)', padding: '12px 0' }}>
                <div className="between">
                  <strong>{dx}</strong>
                  <span className="muted">{e.encounter_date}</span>
                </div>
                <div className="muted">Dr. {e.doctor_name}</div>
                {e.chief_complaint && <div style={{ marginTop: 4 }}>{e.chief_complaint}</div>}
                <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>
                  {(e.medications ?? []).length} medication(s) · {(e.lab_orders ?? []).length} lab order(s)
                </div>
              </div>
            );
          })
        )}
      </div>

      {showAllergy && (
        <RecordAllergyModal patientId={id} onClose={() => setShowAllergy(false)} onSaved={() => { setShowAllergy(false); load(); }} />
      )}
    </>
  );
}

function RecordAllergyModal({ patientId, onClose, onSaved }: { patientId: string; onClose: () => void; onSaved: () => void }) {
  const [substance, setSubstance] = useState('');
  const [reaction, setReaction] = useState('');
  const [criticality, setCriticality] = useState('high');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function save() {
    if (!substance.trim()) return setError('Substance is required.');
    setBusy(true);
    try {
      await doctorApi.recordAllergy(patientId, { substance_name: substance.trim(), reaction_description: reaction.trim() || undefined, criticality });
      onSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      title="Record allergy"
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={save} disabled={busy}>Save</button>
        </>
      }
    >
      <div className="field"><label>Substance *</label>
        <input className="input" value={substance} onChange={(e) => setSubstance(e.target.value)} /></div>
      <div className="field"><label>Reaction</label>
        <input className="input" value={reaction} onChange={(e) => setReaction(e.target.value)} /></div>
      <div className="field"><label>Criticality</label>
        <select className="select" value={criticality} onChange={(e) => setCriticality(e.target.value)}>
          <option value="high">High</option>
          <option value="low">Low</option>
          <option value="unable_to_assess">Unable to assess</option>
        </select>
      </div>
      {error && <div className="error-text">{error}</div>}
    </Modal>
  );
}
