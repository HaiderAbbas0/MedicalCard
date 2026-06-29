import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import type { Role } from '../api/types';

interface NavItem {
  to: string;
  label: string;
  end?: boolean;
}

const NAV_BY_ROLE: Record<string, NavItem[]> = {
  doctor: [
    { to: '/doctor', label: "Today's Appointments", end: true },
    { to: '/doctor/patients', label: 'Find Patient' },
    { to: '/doctor/lab-results', label: 'Lab Results' },
    { to: '/doctor/availability', label: 'Availability' },
    { to: '/doctor/profile', label: 'My Profile' },
  ],
  lab_worker: [{ to: '/lab', label: 'Order Queue', end: true }],
  receptionist: [{ to: '/reception', label: 'Clinic Schedule', end: true }],
};

const ROLE_LABEL: Record<string, string> = {
  doctor: 'Doctor',
  lab_worker: 'Lab Worker',
  receptionist: 'Receptionist',
};

export default function StaffLayout() {
  const { user, logout } = useAuth();
  const { pathname } = useLocation();
  const role = (user?.role ?? 'doctor') as Role;
  const nav = NAV_BY_ROLE[role] ?? [];
  const current = nav.find((n) => (n.end ? pathname === n.to : pathname.startsWith(n.to)));

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <span style={{ fontSize: 20 }}>✚</span> HayaatID
        </div>
        <nav>
          {nav.map((n) => (
            <NavLink key={n.to} to={n.to} end={n.end} className={({ isActive }) => (isActive ? 'active' : '')}>
              {n.label}
            </NavLink>
          ))}
        </nav>
        <div className="user-box">
          <div className="name">{user?.full_name}</div>
          <small>{ROLE_LABEL[role] ?? 'Staff'}</small>
          <button className="btn btn-ghost btn-sm" style={{ marginTop: 12, width: '100%' }} onClick={logout}>
            Sign out
          </button>
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          <h1>{current?.label ?? ROLE_LABEL[role] ?? 'Staff Portal'}</h1>
        </header>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
