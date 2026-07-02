import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { adminApi } from '../api/admin';
import type { DashboardStats } from '../api/types';
import { Spinner } from '../components/ui';
import Icon from '../components/Icon';

const CARDS: { key: keyof DashboardStats; label: string; icon: string; tint: string }[] = [
  { key: 'total_patients', label: 'Registered Patients', icon: 'patients', tint: 'var(--teal)' },
  { key: 'approved_doctors', label: 'Approved Doctors', icon: 'doctor', tint: 'var(--blue)' },
  { key: 'pending_doctor_applications', label: 'Pending Doctor Applications', icon: 'pending', tint: 'var(--amber)' },
  { key: 'pending_lab_applications', label: 'Pending Lab Applications', icon: 'pending', tint: 'var(--amber)' },
  { key: 'appointments_today', label: 'Appointments Today', icon: 'calendar', tint: 'var(--teal)' },
  { key: 'pending_lab_orders', label: 'Pending Lab Orders', icon: 'pill', tint: 'var(--blue)' },
  { key: 'total_clinics', label: 'Clinics', icon: 'clinic', tint: 'var(--teal)' },
  { key: 'total_labs', label: 'Diagnostic Labs', icon: 'lab', tint: 'var(--amber)' },
];

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    adminApi
      .dashboard()
      .then(setStats)
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <div className="error-text">{error}</div>;
  if (!stats) return <Spinner />;

  return (
    <>
      <div className="stat-grid">
        {CARDS.map((c) => (
          <div className="stat" key={c.key}>
            <div className="stat-icon" style={{ color: c.tint, background: `color-mix(in srgb, ${c.tint} 12%, transparent)` }}>
              <Icon name={c.icon} size={20} />
            </div>
            <div className="value">{stats[c.key]}</div>
            <div className="label">{c.label}</div>
          </div>
        ))}
      </div>

      {(stats.pending_doctor_applications > 0 || stats.pending_lab_applications > 0) && (
        <div className="card card-pad" style={{ marginTop: 24 }}>
          <p className="section-title">Needs your attention</p>
          {stats.pending_doctor_applications > 0 && (
            <p>
              <Link to="/doctor-applications">
                {stats.pending_doctor_applications} doctor application(s) awaiting review →
              </Link>
            </p>
          )}
          {stats.pending_lab_applications > 0 && (
            <p>
              <Link to="/lab-applications">
                {stats.pending_lab_applications} lab registration(s) awaiting review →
              </Link>
            </p>
          )}
        </div>
      )}
    </>
  );
}
