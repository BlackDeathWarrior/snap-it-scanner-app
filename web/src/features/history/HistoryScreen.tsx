import { useLiveQuery } from 'dexie-react-hooks';
import { Link } from 'react-router-dom';
import { listScans, clearHistory } from '../../services/historyRepo';
import { HistoryIcon } from '../../ui/icons';

export function HistoryScreen() {
  const scans = useLiveQuery(() => listScans(), [], undefined);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-bold">History</h2>
        {scans && scans.length > 0 && (
          <button
            className="text-xs font-medium text-slate-400 hover:text-red-300"
            onClick={() => {
              if (confirm('Clear all saved scans?')) void clearHistory();
            }}
          >
            Clear all
          </button>
        )}
      </div>

      {scans === undefined ? (
        <p className="p-6 text-center text-sm text-slate-400">Loading…</p>
      ) : scans.length === 0 ? (
        <div className="card flex flex-col items-center gap-2 p-10 text-center">
          <HistoryIcon className="h-8 w-8 text-slate-500" />
          <p className="text-sm text-slate-400">No saved scans yet.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {scans.map((s) => {
            const title =
              s.productName ||
              s.barcodeValue ||
              s.kvPairs[0]?.value ||
              'Scan';
            return (
              <Link
                key={s.id}
                to={`/history/${s.id}`}
                className="card flex items-center gap-3 p-3 hover:border-white/20"
              >
                {s.imageDataUrl ? (
                  <img
                    src={s.imageDataUrl}
                    alt=""
                    className="h-12 w-12 rounded-lg object-cover"
                  />
                ) : (
                  <div className="grid h-12 w-12 place-items-center rounded-lg bg-ink-900 text-slate-500">
                    <HistoryIcon className="h-5 w-5" />
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{title}</p>
                  <p className="truncate text-xs text-slate-400">
                    {s.productBrand ? `${s.productBrand} · ` : ''}
                    {new Date(s.createdAt).toLocaleString()}
                  </p>
                </div>
                <span className="text-xs text-slate-500">
                  {s.kvPairs.length} fields
                </span>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
