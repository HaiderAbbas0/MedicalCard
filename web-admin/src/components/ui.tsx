import type { ReactNode } from 'react';
import type { AccountStatus } from '../api/types';

export function Spinner() {
  return (
    <div className="center">
      <div className="spinner" />
    </div>
  );
}

const STATUS_CLASS: Record<string, string> = {
  active: 'badge-green',
  pending: 'badge-amber',
  suspended: 'badge-red',
  rejected: 'badge-red',
  closed: 'badge-gray',
  processing: 'badge-blue',
  completed: 'badge-green',
};

export function StatusBadge({ status }: { status: AccountStatus | string }) {
  return <span className={`badge ${STATUS_CLASS[status] ?? 'badge-gray'}`}>{status}</span>;
}

export function Empty({ children }: { children: ReactNode }) {
  return <div className="empty">{children}</div>;
}

export function Modal({
  title,
  children,
  onClose,
  footer,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
  footer?: ReactNode;
}) {
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <header>{title}</header>
        <div className="body">{children}</div>
        {footer && <footer>{footer}</footer>}
      </div>
    </div>
  );
}
