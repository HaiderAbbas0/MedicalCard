import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { Icon } from './Icon';

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
  const title = NAV.find((n) => pathname.startsWith(n.to))?.label ?? 'Research Portal';
  const org = user?.extended?.organization;

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">✚ HayaatID</div>
        <div className="brand-sub">Research Portal</div>
        <nav>
          {NAV.map((n) => (
            <NavLink key={n.to} to={n.to}>
              <span className="nav-row">
                <Icon name={n.icon} size={18} />
                {n.label}
              </span>
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
          <h1>{title}</h1>
          <span className="badge badge-indigo">De-identified access</span>
        </header>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
