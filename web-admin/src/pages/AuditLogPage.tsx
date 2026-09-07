import { useEffect, useState } from 'react';
import { adminApi } from '../api/admin';
import type { AuditEntry } from '../api/types';
import { TableSkeleton } from '../components/Skeleton';
import { Empty } from '../components/ui';

export default function AuditLogPage() {
  const [logs, setLogs] = useState<AuditEntry[] | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    adminApi.auditLogs(200).then(setLogs).catch((e) => setError(e.message));
  }, []);

  if (error) return <div className="error-text">{error}</div>;
  if (!logs) return <TableSkeleton rows={5} cols={6} />;

  return (
    <div className="card">
      {logs.length === 0 ? (
        <Empty>No audit entries yet.</Empty>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Time</th>
              <th>Actor</th>
              <th>Role</th>
              <th>Action</th>
              <th>Resource</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((l) => (
              <tr key={l.id}>
                <td className="muted">{new Date(l.timestamp).toLocaleString()}</td>
                <td>{l.actor_name}</td>
                <td>{l.actor_role ?? '—'}</td>
                <td><span className="badge badge-blue">{l.action}</span></td>
                <td className="muted">{l.resource_type ?? '—'}</td>
                <td>
                  <span className={`badge ${l.status === 'success' ? 'badge-green' : 'badge-red'}`}>{l.status}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
