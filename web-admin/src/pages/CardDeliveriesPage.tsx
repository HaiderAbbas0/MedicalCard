import { useEffect, useState } from 'react';
import { adminApi } from '../api/admin';
import type { CardDelivery, CardStatus } from '../api/types';
import { Spinner, Empty, StatusBadge } from '../components/ui';

export default function CardDeliveriesPage() {
  const [cards, setCards] = useState<CardDelivery[] | null>(null);
  const [error, setError] = useState('');
  const [showDelivered, setShowDelivered] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);

  function load(withDelivered = showDelivered) {
    setCards(null);
    const statuses: CardStatus[] = withDelivered
      ? ['physical_requested', 'delivered']
      : ['physical_requested'];
    adminApi.cardDeliveries(statuses).then(setCards).catch((e) => setError(e.message));
  }
  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [showDelivered]);

  async function deliver(id: string) {
    setBusyId(id);
    try {
      await adminApi.markCardDelivered(id);
      load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to mark delivered.');
    } finally {
      setBusyId(null);
    }
  }

  if (error) return <div className="error-text">{error}</div>;

  return (
    <>
      <div className="toolbar">
        <label className="row" style={{ gap: 8 }}>
          <input
            type="checkbox"
            checked={showDelivered}
            onChange={(e) => setShowDelivered(e.target.checked)}
          />
          Include delivered
        </label>
      </div>

      <div className="card">
        {!cards ? (
          <Spinner />
        ) : cards.length === 0 ? (
          <Empty>No physical card requests awaiting delivery.</Empty>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Card No.</th>
                <th>Name</th>
                <th>CNIC</th>
                <th>Address</th>
                <th>Phone</th>
                <th>Fee (PKR)</th>
                <th>Status</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {cards.map((c) => (
                <tr key={c.id}>
                  <td className="mono">{c.card_number}</td>
                  <td>{c.full_name ?? c.name_en ?? '—'}</td>
                  <td className="mono">{c.cnic ?? '—'}</td>
                  <td className="muted">{c.delivery_address || '—'}</td>
                  <td className="mono">{c.delivery_phone || '—'}</td>
                  <td>{c.delivery_fee_pkr ?? '—'}</td>
                  <td><StatusBadge status={c.status} /></td>
                  <td className="actions">
                    {c.status === 'physical_requested' ? (
                      <button
                        className="btn btn-success btn-sm"
                        disabled={busyId === c.id}
                        onClick={() => deliver(c.id)}
                      >
                        {busyId === c.id ? 'Saving…' : 'Mark delivered'}
                      </button>
                    ) : (
                      <span className="muted">Delivered</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
