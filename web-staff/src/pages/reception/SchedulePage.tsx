import { useCallback, useEffect, useState } from 'react';
import { receptionApi } from '../../api/reception';
import type { ClinicAppointment, ClinicDoctor } from '../../api/types';
import { Spinner, Empty, Modal, StatusBadge } from '../../components/ui';

const localToday = () => {
  const now = new Date();
  const offset = now.getTimezoneOffset() * 60_000;
  return new Date(now.getTime() - offset).toISOString().slice(0, 10);
};

export default function SchedulePage() {
  const [appts, setAppts] = useState<ClinicAppointment[] | null>(null);
  const [error, setError] = useState('');
  const [date, setDate] = useState(localToday);
  const [showBook, setShowBook] = useState(false);

  const load = useCallback(() => {
    setAppts(null);
    receptionApi.appointments(date).then(setAppts).catch((e) => setError(e.message));
  }, [date]);

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
      <div className="toolbar between">
        <div className="row">
          <input type="date" className="input" style={{ maxWidth: 190 }} value={date} onChange={(e) => setDate(e.target.value)} />
          {date !== localToday() && <button className="btn btn-ghost" onClick={() => setDate(localToday())}>Today</button>}
        </div>
        <button className="btn btn-primary" onClick={() => setShowBook(true)}>+ New appointment</button>
      </div>

      {error && <div className="error-text" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="card">
        {!appts ? (
          <Spinner />
        ) : appts.length === 0 ? (
          <Empty>No appointments for this clinic.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr><th>Time</th><th>Patient</th><th>Hayaat ID</th><th>Doctor</th><th>Status</th><th /></tr>
            </thead>
            <tbody>
              {appts.map((a) => (
                <tr key={a.id}>
                  <td>{a.appointment_date} · {a.appointment_time}</td>
                  <td>{a.patient?.full_name ?? '—'}</td>
                  <td className="mono">{a.patient?.card_number?.replace(/(\d{4})(?=\d)/g, '$1 ') ?? '—'}</td>
                  <td>{a.doctor_name ?? '—'}</td>
                  <td><StatusBadge status={a.status} /></td>
                  <td className="actions">
                    {(a.status === 'pending' || a.status === 'confirmed') && (
                      <button className="btn btn-success btn-sm" onClick={() => act(() => receptionApi.checkIn(a.id))}>Check in</button>
                    )}
                    {!a.status.startsWith('cancelled') && (
                      <button className="btn btn-ghost btn-sm" style={{ marginLeft: 8 }} onClick={() => act(() => receptionApi.cancel(a.id, 'Cancelled at reception'))}>Cancel</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showBook && <BookModal onClose={() => setShowBook(false)} onBooked={() => { setShowBook(false); load(); }} />}
    </>
  );
}

function BookModal({ onClose, onBooked }: { onClose: () => void; onBooked: () => void }) {
  const [hayaatId, setHayaatId] = useState('');
  const [patient, setPatient] = useState<{ id: string; full_name: string } | null>(null);
  const [doctors, setDoctors] = useState<ClinicDoctor[]>([]);
  const [doctorId, setDoctorId] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [slots, setSlots] = useState<{ slot_time: string; slot_label: string; clinic_id: string }[]>([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    receptionApi.doctors().then((d) => { setDoctors(d); if (d[0]) setDoctorId(d[0].id); }).catch(() => undefined);
  }, []);

  useEffect(() => {
    setTime('');
    setSlots([]);
    if (!doctorId || !date) return;
    receptionApi.availableSlots(doctorId, date)
      .then(setSlots)
      .catch((e) => setError(e instanceof Error ? e.message : 'Could not load available slots.'));
  }, [doctorId, date]);

  async function find() {
    setError('');
    try {
      const digits = hayaatId.replace(/\D/g, '');
      if (!/^\d{16}$/.test(digits)) return setError('Enter a valid 16-digit Hayaat ID.');
      const p = await receptionApi.searchPatient(digits);
      setPatient(p);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Patient not found.');
    }
  }

  async function book() {
    if (!patient || !doctorId || !date || !time) return setError('Find a patient and fill doctor, date, and time.');
    const selected = new Date(`${date}T${time}`);
    if (Number.isNaN(selected.getTime()) || selected <= new Date()) return setError('Appointment time must be in the future.');
    setBusy(true);
    setError('');
    try {
      await receptionApi.book({ patient_id: patient.id, doctor_id: doctorId, appointment_date: date, appointment_time: time, appointment_type: 'in_person' });
      onBooked();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Booking failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      title="New appointment"
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={book} disabled={busy}>{busy ? 'Booking…' : 'Book'}</button>
        </>
      }
    >
      <div className="field">
        <label>Patient Hayaat ID</label>
        <div className="row">
          <input className="input" inputMode="numeric" maxLength={19} placeholder="0000 0000 0000 0000" value={hayaatId}
            onChange={(e) => setHayaatId(e.target.value.replace(/\D/g, '').slice(0, 16).replace(/(.{4})/g, '$1 ').trim())} />
          <button className="btn btn-ghost" onClick={find}>Find</button>
        </div>
        {patient && <div style={{ color: 'var(--green)', fontSize: 13, marginTop: 6 }}>✓ {patient.full_name}</div>}
      </div>
      <div className="field">
        <label>Doctor</label>
        <select className="select" value={doctorId} onChange={(e) => setDoctorId(e.target.value)}>
          {doctors.map((d) => <option key={d.id} value={d.id}>{d.full_name} — {d.specialization_primary}</option>)}
        </select>
      </div>
      <div className="row">
        <div className="field" style={{ flex: 1 }}><label>Date</label>
          <input type="date" className="input" min={localToday()} value={date} onChange={(e) => setDate(e.target.value)} /></div>
        <div className="field" style={{ flex: 1 }}><label>Open time</label>
          <select className="select" value={time} onChange={(e) => setTime(e.target.value)} disabled={!date || slots.length === 0}>
            <option value="">{date ? (slots.length ? 'Choose a time' : 'No open slots') : 'Choose date first'}</option>
            {slots.map((s) => <option key={s.slot_time} value={s.slot_time}>{s.slot_label ?? s.slot_time}</option>)}
          </select>
        </div>
      </div>
      {error && <div className="error-text">{error}</div>}
    </Modal>
  );
}
