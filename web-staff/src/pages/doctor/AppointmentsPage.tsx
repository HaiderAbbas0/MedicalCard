import { useCallback, useEffect, useState } from 'react';
import { doctorApi } from '../../api/doctor';
import type { Appointment } from '../../api/types';
import { TableSkeleton } from '../../components/Skeleton';
import { Empty, StatusBadge } from '../../components/ui';

const localToday = () => {
  const now = new Date();
  const offset = now.getTimezoneOffset() * 60_000;
  return new Date(now.getTime() - offset).toISOString().slice(0, 10);
};

export default function AppointmentsPage() {
  const [appts, setAppts] = useState<Appointment[] | null>(null);
  const [error, setError] = useState('');
  const [date, setDate] = useState(localToday);

  const load = useCallback(() => {
    setAppts(null);
    doctorApi.appointments(date).then(setAppts).catch((e) => setError(e.message));
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
      <div className="toolbar">
        <input type="date" className="input" style={{ maxWidth: 200 }} value={date} onChange={(e) => setDate(e.target.value)} />
        {date !== localToday() && <button className="btn btn-ghost" onClick={() => setDate(localToday())}>Today</button>}
      </div>

      {error && <div className="error-text" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="card">
        {!appts ? (
          <TableSkeleton rows={5} cols={6} />
        ) : appts.length === 0 ? (
          <Empty>No appointments for this date.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr><th>Time</th><th>Patient</th><th>Hayaat ID</th><th>Type</th><th>Status</th><th /></tr>
            </thead>
            <tbody>
              {appts.map((a) => (
                <tr key={a.id}>
                  <td>{a.appointment_date} · {a.appointment_time}</td>
                  <td>{a.patient?.full_name ?? '—'}</td>
                  <td className="mono">{a.patient?.card_number?.replace(/(\d{4})(?=\d)/g, '$1 ') ?? '—'}</td>
                  <td>{a.appointment_type.replace(/_/g, ' ')}</td>
                  <td><StatusBadge status={a.status} /></td>
                  <td className="actions">
                    {a.status === 'pending' && (
                      <button className="btn btn-success btn-sm" onClick={() => act(() => doctorApi.confirmAppointment(a.id))}>Confirm</button>
                    )}
                    {a.status === 'confirmed' && (
                      <>
                        <button className="btn btn-ghost btn-sm" onClick={() => act(() => doctorApi.checkInAppointment(a.id))}>Check in</button>
                        <button className="btn btn-ghost btn-sm" style={{ marginLeft: 8 }} onClick={() => act(() => doctorApi.noShowAppointment(a.id))}>No-show</button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
