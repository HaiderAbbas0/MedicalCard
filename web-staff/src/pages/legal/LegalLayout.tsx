import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';

export const LEGAL_VERSION = '2026-07-04';
export const LEGAL_LAST_UPDATED = '4 July 2026';

/** Shared wrapper for the public legal pages: readable max-width container,
 * mandatory "pending legal review" disclaimer, version + last-updated line. */
export default function LegalLayout({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg, #f4f6fb)', padding: '32px 16px' }}>
      <article
        className="card card-pad"
        style={{ maxWidth: 820, margin: '0 auto', lineHeight: 1.65 }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
          <span style={{ fontSize: 22 }}>✚</span>
          <strong style={{ fontSize: 15 }}>HayaatID · SehatID</strong>
        </div>
        <h1 style={{ fontSize: 28, margin: '4px 0 4px' }}>{title}</h1>
        <p className="muted" style={{ marginTop: 0 }}>
          Version {LEGAL_VERSION} · Last updated {LEGAL_LAST_UPDATED}
        </p>

        <div
          role="note"
          style={{
            border: '1px solid var(--amber-border, #f0c36d)',
            background: 'var(--amber-bg, #fff8e6)',
            borderRadius: 10,
            padding: '12px 14px',
            margin: '16px 0 24px',
            fontSize: 14,
          }}
        >
          <strong>Disclaimer:</strong> This is a template pending review by qualified legal counsel
          and must not be relied upon as final legal advice.
        </div>

        {children}

        <hr style={{ margin: '28px 0 16px', border: 'none', borderTop: '1px solid #e5e7eb' }} />
        <p className="muted" style={{ fontSize: 13 }}>
          <Link to="/legal/privacy">Privacy Policy</Link> · <Link to="/legal/terms">Terms of Service</Link> ·{' '}
          <Link to="/login">Back to sign in</Link>
        </p>
      </article>
    </div>
  );
}
