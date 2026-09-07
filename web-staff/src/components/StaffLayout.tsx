import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import type { Role } from '../api/types';
import Icon from './Icon';
import { ThemeToggle } from './ThemeToggle';

interface NavItem {
  to: string;
  label: string;
  icon: string;
  end?: boolean;
}

const NAV_BY_ROLE: Record<string, NavItem[]> = {
  doctor: [
    { to: '/doctor', label: "Today's Appointments", icon: 'calendar', end: true },
    { to: '/doctor/patients', label: 'Find Patient', icon: 'users' },
    { to: '/doctor/lab-results', label: 'Lab Results', icon: 'lab' },
    { to: '/doctor/messages', label: 'Messages', icon: 'chat' },
    { to: '/doctor/availability', label: 'Availability', icon: 'pending' },
    { to: '/doctor/profile', label: 'My Profile', icon: 'doctor' },
  ],
  lab_worker: [{ to: '/lab', label: 'Order Queue', icon: 'lab', end: true }],
  receptionist: [{ to: '/reception', label: 'Clinic Schedule', icon: 'reception', end: true }],
};

const ROLE_LABEL: Record<string, string> = {
  doctor: 'Doctor',
  lab_worker: 'Lab Worker',
  receptionist: 'Receptionist',
};

export default function StaffLayout() {
  const { user, logout } = useAuth();
  const { pathname } = useLocation();
  const [navOpen, setNavOpen] = useState(false);

  const role = (user?.role ?? 'doctor') as Role;
  const nav = NAV_BY_ROLE[role] ?? [];
  const current = nav.find((n) => (n.end ? pathname === n.to : pathname.startsWith(n.to)));

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
        <div className="brand-sub">{ROLE_LABEL[role] ?? 'Staff'} Portal</div>
        <nav>
          {nav.map((n) => (
            <NavLink key={n.to} to={n.to} end={n.end} className={({ isActive }) => (isActive ? 'active' : '')}>
              <Icon name={n.icon} /> {n.label}
            </NavLink>
          ))}
        </nav>
        <div className="user-box">
          <div className="name">{user?.full_name}</div>
          <small>{ROLE_LABEL[role] ?? 'Staff'}</small>
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
              {current?.label ?? ROLE_LABEL[role] ?? 'Staff Portal'}
            </h1>
          </div>
          <ThemeToggle />
        </header>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
