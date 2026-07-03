import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import Icon from './Icon';
import NotificationBell from './NotificationBell';

const NAV = [
  { to: '/dashboard', label: 'Dashboard', icon: 'dashboard' },
  { to: '/doctor-applications', label: 'Doctor Applications', icon: 'doctor' },
  { to: '/lab-applications', label: 'Lab Applications', icon: 'lab' },
  { to: '/users', label: 'Users', icon: 'users' },
  { to: '/clinics', label: 'Clinics', icon: 'clinic' },
  { to: '/card-deliveries', label: 'Card Deliveries', icon: 'card' },
  { to: '/deletion-requests', label: 'Deletion Requests', icon: 'trash' },
  { to: '/audit', label: 'Audit Log', icon: 'audit' },
];

const TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/doctor-applications': 'Doctor Applications',
  '/lab-applications': 'Lab Applications',
  '/users': 'User Management',
  '/clinics': 'Clinics',
  '/card-deliveries': 'Card Deliveries',
  '/deletion-requests': 'Account Deletion Requests',
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
              <span className="nav-row"><Icon name={n.icon} /> {n.label}</span>
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
          <NotificationBell />
        </header>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
