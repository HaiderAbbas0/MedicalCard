import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { Icon } from './Icon';
import { ThemeToggle } from './ThemeToggle';

const NAV = [
  { to: '/cohorts', label: 'Cohort Explorer', icon: 'cohort' },
  { to: '/catalog', label: 'Dataset Catalogue', icon: 'catalog' },
  { to: '/requests', label: 'My Requests', icon: 'request' },
  { to: '/downloads', label: 'Downloads', icon: 'download' },
  { to: '/compliance', label: 'Compliance', icon: 'shield' },
];

export function Layout() {
  const { user, signOut } = useAuth();
  const { pathname } = useLocation();
  const [navOpen, setNavOpen] = useState(false);

  const title = NAV.find((n) => pathname.startsWith(n.to))?.label ?? 'Research Portal';
  const org = user?.extended?.organization;

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
        <div className="brand">✚ HayaatID</div>
        <div className="brand-sub">Research Portal</div>
        <nav>
          {NAV.map((n) => (
            <NavLink key={n.to} to={n.to}>
              <Icon name={n.icon} size={17} />
              {n.label}
            </NavLink>
          ))}
        </nav>
        <div className="user-box">
          <div className="name">{user?.full_name}</div>
          <small>{org?.name ?? 'No organisation'}</small>
          <button className="btn btn-ghost btn-sm" style={{ width: '100%' }} onClick={signOut}>
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
            <span className="badge badge-accent">
              <span className="dot" />
              De-identified access
            </span>
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
