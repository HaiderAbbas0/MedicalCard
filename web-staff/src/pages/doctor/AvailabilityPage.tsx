import { useCallback, useEffect, useState } from 'react';
import { doctorApi } from '../../api/doctor';
import type { AvailabilitySlot } from '../../api/types';
import { Spinner, Empty } from '../../components/ui';

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

export default function AvailabilityPage() {
  const [slots, setSlots] = useState<AvailabilitySlot[] | null>(null);
  const [error, setError] = useState('');
  const [form, setForm] = useState({ day_of_week: 1, start_time: '09:00', end_time: '13:00', slot_duration_minutes: 30 });
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setSlots(null);
    doctorApi.availability().then(setSlots).catch((e) => setError(e.message));
  }, []);

  useEffect(load, [load]);

  async function add() {
    setError('');
    if (form.slot_duration_minutes <= 0 || !Number.isInteger(form.slot_duration_minutes)) {
      setError('Slot length must be a whole number greater than 0 minutes.');
      return;
    }
    if (form.start_time >= form.end_time) {
      setError('End time must be later than start time.');
      return;
    }
    const duplicate = slots?.some((slot) =>
      slot.day_of_week === form.day_of_week &&
      slot.start_time.slice(0, 5) === form.start_time &&
      slot.end_time.slice(0, 5) === form.end_time &&
      slot.slot_duration_minutes === form.slot_duration_minutes,
    );
    if (duplicate) {
      setError('This weekly slot already exists.');
      return;
    }
    setBusy(true);
    try {
      await doctorApi.addAvailability(form);
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed.');
    } finally {
      setBusy(false);
    }
  }

  async function remove(id: string) {
    try {
      await doctorApi.deleteAvailability(id);
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed.');
    }
  }

  return (
    <div style={{ display: 'grid', gap: 16, maxWidth: 760 }}>
      <div className="card card-pad">
        <p className="section-title">Add a weekly slot</p>
        <div className="row" style={{ flexWrap: 'wrap' }}>
          <select className="select" style={{ maxWidth: 160 }} value={form.day_of_week} onChange={(e) => setForm({ ...form, day_of_week: Number(e.target.value) })}>
            {DAYS.map((d, i) => <option key={i} value={i}>{d}</option>)}
          </select>
          <input type="time" className="input" style={{ maxWidth: 130 }} value={form.start_time} onChange={(e) => setForm({ ...form, start_time: e.target.value })} />
          <input type="time" className="input" style={{ maxWidth: 130 }} value={form.end_time} onChange={(e) => setForm({ ...form, end_time: e.target.value })} />
          <input type="number" className="input" style={{ maxWidth: 130 }} min={1} step={1} aria-label="Slot length in minutes" value={form.slot_duration_minutes} onChange={(e) => setForm({ ...form, slot_duration_minutes: Number(e.target.value) })} />
          <button className="btn btn-primary" onClick={add} disabled={busy}>Add slot</button>
        </div>
      </div>

      {error && <div className="error-text">{error}</div>}

      <div className="card">
        {!slots ? (
          <Spinner />
        ) : slots.length === 0 ? (
          <Empty>No availability slots yet.</Empty>
        ) : (
          <table className="table">
            <thead><tr><th>Day</th><th>Hours</th><th>Slot length</th><th /></tr></thead>
            <tbody>
              {[...slots].sort((a, b) => a.day_of_week - b.day_of_week).map((s) => (
                <tr key={s.id}>
                  <td>{DAYS[s.day_of_week]}</td>
                  <td>{s.start_time} – {s.end_time}</td>
                  <td>{s.slot_duration_minutes} min</td>
                  <td className="actions"><button className="btn btn-danger btn-sm" onClick={() => remove(s.id)}>Remove</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
