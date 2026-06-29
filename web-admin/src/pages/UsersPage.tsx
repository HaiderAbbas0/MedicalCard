import { useEffect, useState } from 'react';
import { api } from '../api/client';
import type { Profile, Role } from '../api/types';
import { Spinner, Empty, Modal, StatusBadge } from '../components/ui';
import CreateAccountModal from '../components/CreateAccountModal';
import { useAuth } from '../auth/AuthContext';

const ROLES: (Role | '')[] = ['', 'patient', 'doctor', 'lab_worker', 'receptionist', 'admin'];

export default function UsersPage() {
  const { user } = useAuth();
  const canCreateAdmin = (user?.extended?.admin_level as string | undefined) === 'super_admin';
  const [users, setUsers] = useState<Profile[] | null>(null);
  const [error, setError] = useState('');
  const [roleFilter, setRoleFilter] = useState<Role | ''>('');
  const [q, setQ] = useState('');
  const [acting, setActing] = useState<{ user: Profile; mode: 'suspend' | 'reactivate' } | null>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [showCreate, setShowCreate] = useState(false);

  function load() {
    setUsers(null);
    const params = new URLSearchParams();
    if (roleFilter) params.set('role', roleFilter);
    if (q.trim()) params.set('q', q.trim());
    api
      .get<Profile[]>(`/admin/users?${params.toString()}`)
      .then(setUsers)
      .catch((e) => setError(e.message));
  }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(load, [roleFilter]);

  async function confirmAction() {
    if (!acting) return;
    if (acting.mode === 'suspend' && !reason.trim()) return;
    setBusy(true);
    try {
      const path = `/admin/users/${acting.user.id}/${acting.mode}`;
      await api.post(path, { reason: reason.trim() || undefined });
      setActing(null);
      setReason('');
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="toolbar">
        <select className="select" style={{ maxWidth: 200 }} value={roleFilter} onChange={(e) => setRoleFilter(e.target.value as Role | '')}>
          {ROLES.map((r) => (
            <option key={r} value={r}>
              {r === '' ? 'All roles' : r}
            </option>
          ))}
        </select>
        <input
          className="input"
          style={{ maxWidth: 280 }}
          placeholder="Search by name or CNIC…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && load()}
        />
        <button className="btn btn-ghost" onClick={load}>
          Search
        </button>
        <button className="btn btn-primary" style={{ marginLeft: 'auto' }} onClick={() => setShowCreate(true)}>
          + Create account
        </button>
      </div>

      {error && <div className="error-text" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="card">
        {!users ? (
          <Spinner />
        ) : users.length === 0 ? (
          <Empty>No users match your filters.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>CNIC</th>
                <th>Role</th>
                <th>Status</th>
                <th>Contact</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td>{u.full_name}</td>
                  <td className="mono">{u.cnic}</td>
                  <td>{u.role}</td>
                  <td><StatusBadge status={u.status} /></td>
                  <td className="muted">{u.email ?? u.phone_primary}</td>
                  <td className="actions">
                    {u.role !== 'admin' && u.status === 'active' && (
                      <button className="btn btn-danger btn-sm" onClick={() => setActing({ user: u, mode: 'suspend' })}>
                        Suspend
                      </button>
                    )}
                    {u.status === 'suspended' && (
                      <button className="btn btn-success btn-sm" onClick={() => setActing({ user: u, mode: 'reactivate' })}>
                        Reactivate
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showCreate && (
        <CreateAccountModal
          canCreateAdmin={canCreateAdmin}
          onClose={() => setShowCreate(false)}
          onCreated={load}
        />
      )}

      {acting && (
        <Modal
          title={`${acting.mode === 'suspend' ? 'Suspend' : 'Reactivate'} — ${acting.user.full_name}`}
          onClose={() => setActing(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setActing(null)}>
                Cancel
              </button>
              <button
                className={acting.mode === 'suspend' ? 'btn btn-danger' : 'btn btn-success'}
                onClick={confirmAction}
                disabled={busy || (acting.mode === 'suspend' && !reason.trim())}
              >
                Confirm
              </button>
            </>
          }
        >
          {acting.mode === 'suspend' && (
            <p className="muted">Suspending invalidates the account's access. A reason is required (P-FR-048).</p>
          )}
          <div className="field">
            <label>{acting.mode === 'suspend' ? 'Suspension reason' : 'Note (optional)'}</label>
            <textarea className="input" rows={3} value={reason} onChange={(e) => setReason(e.target.value)} />
          </div>
        </Modal>
      )}
    </>
  );
}
