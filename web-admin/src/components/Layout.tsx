import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import Icon from './Icon';
import NotificationBell from './NotificationBell';
import { ThemeToggle } from './ThemeToggle';

const NAV = [
  { to: '/dashboard', label: 'Dashboard', icon: 'dashboard' },
  { to: '/doctor-applications', label: 'Doctor Applications', icon: 'doctor' },
  { to: '/lab-applications', label: 'Lab Applications', icon: 'lab' },
  { to: '/users', label: 'Users', icon: 'users' },
  { to: '/clinics', label: 'Clinics', icon: 'clinic' },
  { to: '/card-deliveries', label: 'Card Deliveries', icon: 'card' },
  { to: '/deletion-requests', label: 'Deletion Requests', icon: 'trash' },
  { to: '/research-orgs', label: 'Research Orgs', icon: 'research' },
  { to: '/data-requests', label: 'Data Requests', icon: 'dataset' },
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
  '/research-orgs': 'Research Organisations',
  '/data-requests': 'Research Data Requests',
  '/audit': 'Audit Log',
};

export default function Layout() {
  const { user, logout } = useAuth();
  const { pathname } = useLocation();
  const [navOpen, setNavOpen] = useState(false);
  const title = TITLES[pathname] ?? 'Admin Portal';

  // Close the drawer on navigation, so a tap-through on mobile doesn't leave it open.
  useEffect(() => {
    setNavOpen(false);
  }, [pathname]);

  // Escape closes the drawer — expected of anything overlaying the page.
  useEffect(() => {
    if (!navOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setNavOpen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [navOpen]);

  return (
    <div className="app-shell">
      {navOpen && <div className="sidebar-scrim" onClick={() => setNavOpen(false)} />}

      <aside className={`sidebar${navOpen ? ' is-open' : ''}`}>
        <div className="brand">
          <span style={{ fontSize: 19 }}>✚</span> HayaatID
        </div>
        <div className="brand-sub">Admin Portal</div>
        <nav>
          {NAV.map((n) => (
            <NavLink key={n.to} to={n.to} className={({ isActive }) => (isActive ? 'active' : '')}>
              <Icon name={n.icon} /> {n.label}
            </NavLink>
          ))}
        </nav>
        <div className="user-box">
          <div className="name">{user?.full_name}</div>
          <small>{user?.email}</small>
          <button className="btn btn-ghost btn-sm" style={{ width: '100%' }} onClick={logout}>
            Sign out
          </button>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div className="row" style={{ gap: 12, minWidth: 0 }}>
            <button
              className="nav-toggle"
              onClick={() => setNavOpen((v) => !v)}
              aria-label="Toggle navigation"
              aria-expanded={navOpen}
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
                <path d="M3 6h18M3 12h18M3 18h18" />
              </svg>
            </button>
            <h1 style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {title}
            </h1>
          </div>
          <div className="row" style={{ gap: 10 }}>
            <NotificationBell />
            <ThemeToggle />
          </div>
        </header>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
