import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import type { DashboardStats } from '../api/types';
import { Spinner } from '../components/ui';

const CARDS: { key: keyof DashboardStats; label: string }[] = [
  { key: 'total_patients', label: 'Registered Patients' },
  { key: 'approved_doctors', label: 'Approved Doctors' },
  { key: 'pending_doctor_applications', label: 'Pending Doctor Applications' },
  { key: 'pending_lab_applications', label: 'Pending Lab Applications' },
  { key: 'appointments_today', label: 'Appointments Today' },
  { key: 'pending_lab_orders', label: 'Pending Lab Orders' },
  { key: 'total_clinics', label: 'Clinics' },
  { key: 'total_labs', label: 'Diagnostic Labs' },
];

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .get<DashboardStats>('/admin/dashboard')
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
