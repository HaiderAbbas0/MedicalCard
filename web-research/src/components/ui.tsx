import type { ReactNode } from 'react';
import { Icon } from './Icon';

export function Spinner() {
  return (
    <div className="center">
      <div className="spinner" />
    </div>
  );
}

const STATUS_CLASS: Record<string, string> = {
  active: 'badge-green',
  approved: 'badge-green',
  pending: 'badge-amber',
  suspended: 'badge-red',
  rejected: 'badge-red',
  revoked: 'badge-red',
  expired: 'badge-gray',
};

export function StatusBadge({ status }: { status: string }) {
  return <span className={`badge ${STATUS_CLASS[status] ?? 'badge-gray'}`}>{status}</span>;
}

export function Empty({ children }: { children: ReactNode }) {
  return <div className="empty">{children}</div>;
}

export function Notice({
  tone = 'indigo',
  icon = 'shield',
  children,
}: {
  tone?: 'amber' | 'indigo' | 'green';
  icon?: string;
  children: ReactNode;
}) {
  return (
    <div className={`notice notice-${tone}`}>
      <Icon name={icon} size={17} />
      <div>{children}</div>
    </div>
  );
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

/**
 * A single k-anonymised bar. A suppressed bucket renders as "< k" rather than
 * a number, so the researcher can see the stratum exists without learning how
 * few people are in it.
 */
export function Bar({
  label,
  value,
  suppressed,
  max,
}: {
  label: string;
  value: number | null;
  suppressed: boolean;
  max: number;
}) {
  const pct = value && max > 0 ? Math.max((value / max) * 100, 1.5) : 0;
  return (
    <div className="bar-row">
      <div className="bar-label" title={label}>{label}</div>
      <div className="bar-track">
        <div className="bar-fill" style={{ width: `${pct}%` }} />
      </div>
      {suppressed ? (
        <div className="bar-value suppressed" title="Below the k-anonymity threshold">
          &lt; 5
        </div>
      ) : (
        <div className="bar-value">{value?.toLocaleString() ?? '—'}</div>
      )}
    </div>
  );
}
