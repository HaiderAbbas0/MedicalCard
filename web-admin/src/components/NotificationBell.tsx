import { useEffect, useRef, useState } from 'react';
import { notificationsApi } from '../api/notifications';
import type { AppNotification } from '../api/types';
import Icon from './Icon';

const POLL_MS = 30_000;

/** Short relative time from an ISO timestamp, e.g. "5m", "3h", "2d". */
function shortAgo(iso: string): string {
  const s = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));
  if (s < 60) return 'now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d}d`;
  return new Date(iso).toLocaleDateString();
}

export default function NotificationBell() {
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<AppNotification[]>([]);
  const [unread, setUnread] = useState(0);
  const wrapRef = useRef<HTMLDivElement>(null);

  async function refreshCount() {
    try {
      setUnread(await notificationsApi.unreadCount());
    } catch {
      /* ignore transient poll errors */
    }
  }

  useEffect(() => {
    refreshCount();
    const t = setInterval(refreshCount, POLL_MS);
    return () => clearInterval(t);
  }, []);

  // Close on outside click.
  useEffect(() => {
    if (!open) return;
    function onDown(e: MouseEvent) {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [open]);

  async function toggle() {
    const next = !open;
    setOpen(next);
    if (next) {
      try {
        const list = await notificationsApi.list();
        setItems(list);
        if (list.some((n) => !n.is_read)) {
          await notificationsApi.markAllRead();
          setItems(list.map((n) => ({ ...n, is_read: true })));
          setUnread(0);
        }
      } catch {
        /* ignore */
      }
    }
  }

  async function markAll() {
    try {
      await notificationsApi.markAllRead();
      setItems((prev) => prev.map((n) => ({ ...n, is_read: true })));
      setUnread(0);
    } catch {
      /* ignore */
    }
  }

  return (
    <div className="notif-wrap" ref={wrapRef}>
      <button className="notif-btn" onClick={toggle} aria-label="Notifications">
        <Icon name="bell" size={20} />
        {unread > 0 && <span className="notif-badge">{unread > 99 ? '99+' : unread}</span>}
      </button>
      {open && (
        <div className="notif-panel">
          <div className="notif-head">
            <span>Notifications</span>
            <button className="notif-mark" onClick={markAll}>
              Mark all read
            </button>
          </div>
          <div className="notif-list">
            {items.length === 0 ? (
              <div className="notif-empty">No notifications.</div>
            ) : (
              items.map((n) => (
                <div key={n.id} className={`notif-item${n.is_read ? '' : ' unread'}`}>
                  <div className="notif-item-top">
                    <span className="notif-title">{n.title}</span>
                    <span className="notif-time">{shortAgo(n.created_at)}</span>
                  </div>
                  {n.body && <div className="notif-body">{n.body}</div>}
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
