import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

const NAV = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/doctor-applications', label: 'Doctor Applications' },
  { to: '/lab-applications', label: 'Lab Applications' },
  { to: '/users', label: 'Users' },
  { to: '/clinics', label: 'Clinics' },
  { to: '/audit', label: 'Audit Log' },
];

const TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/doctor-applications': 'Doctor Applications',
  '/lab-applications': 'Lab Applications',
  '/users': 'User Management',
  '/clinics': 'Clinics',
  '/audit': 'Audit Log',
};

export default function Layout() {
  const { user, logout } = useAuth();
  const { pathname } = useLocation();
  const title = TITLES[pathname] ?? 'Admin Portal';

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <span style={{ fontSize: 20 }}>✚</span> HayaatID
        </div>
        <nav>
          {NAV.map((n) => (
            <NavLink key={n.to} to={n.to} className={({ isActive }) => (isActive ? 'active' : '')}>
              {n.label}
            </NavLink>
          ))}
        </nav>
        <div className="user-box">
          <div className="name">{user?.full_name}</div>
          <small>{user?.email}</small>
          <button className="btn btn-ghost btn-sm" style={{ marginTop: 12, width: '100%' }} onClick={logout}>
            Sign out
          </button>
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          <h1>{title}</h1>
        </header>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
