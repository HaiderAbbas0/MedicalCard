/**
 * Skeletons that mirror the silhouette of the content they stand in for, so the
 * layout doesn't jump when real data lands. Preferred over a bare spinner
 * anywhere the shape of the result is predictable.
 */

export function Skeleton({
  width = '100%',
  height = 12,
  radius = 6,
}: {
  width?: number | string;
  height?: number | string;
  radius?: number;
}) {
  return <div className="skel" style={{ width, height, borderRadius: radius }} />;
}

/** Placeholder for a table, matching column count and row height. */
export function TableSkeleton({ rows = 5, cols = 4 }: { rows?: number; cols?: number }) {
  return (
    <div aria-hidden="true">
      {Array.from({ length: rows }).map((_, r) => (
        <div className="skel-row" key={r}>
          {Array.from({ length: cols }).map((_, c) => (
            <div key={c} style={{ flex: c === 0 ? 2 : 1 }}>
              <Skeleton height={11} width={c === 0 ? '72%' : '52%'} />
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

/** Placeholder for a stat-card grid. */
export function StatGridSkeleton({ count = 8 }: { count?: number }) {
  return (
    <div className="stat-grid" aria-hidden="true">
      {Array.from({ length: count }).map((_, i) => (
        <div className="stat" key={i}>
          <Skeleton width={38} height={38} radius={11} />
          <div style={{ height: 13 }} />
          <Skeleton width="46%" height={26} radius={7} />
          <div style={{ height: 8 }} />
          <Skeleton width="72%" height={11} />
        </div>
      ))}
    </div>
  );
}

/** Placeholder for a stack of cards. */
export function CardSkeleton({ count = 3 }: { count?: number }) {
  return (
    <div className="stack" aria-hidden="true">
      {Array.from({ length: count }).map((_, i) => (
        <div className="card card-pad" key={i}>
          <Skeleton width="34%" height={16} radius={7} />
          <div style={{ height: 12 }} />
          <Skeleton width="88%" height={11} />
          <div style={{ height: 8 }} />
          <Skeleton width="62%" height={11} />
        </div>
      ))}
    </div>
  );
}

/** Placeholder for a chart panel of horizontal bars. */
export function BarsSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div aria-hidden="true">
      {Array.from({ length: rows }).map((_, i) => (
        <div className="bar-row" key={i}>
          <Skeleton height={11} width="76%" />
          <Skeleton height={22} radius={999} />
          <Skeleton height={11} width="66%" />
        </div>
      ))}
    </div>
  );
}
