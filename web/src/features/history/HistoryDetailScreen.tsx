import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { getScan, deleteScan, type ScanRecord } from '../../services/historyRepo';
import { kvToCsv, downloadCsv } from '../../services/csvExport';

export function HistoryDetailScreen() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [scan, setScan] = useState<ScanRecord | null | undefined>(undefined);

  useEffect(() => {
    const n = Number(id);
    if (!Number.isFinite(n)) {
      setScan(null);
      return;
    }
    void getScan(n).then((s) => setScan(s ?? null));
  }, [id]);

  if (scan === undefined) {
    return <p className="p-6 text-center text-sm text-slate-400">Loading…</p>;
  }
  if (scan === null) {
    return (
      <div className="card p-6 text-center text-sm text-slate-400">
        <p>Scan not found.</p>
        <button className="btn-ghost mt-3" onClick={() => navigate('/history')}>
          Back to history
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <button
          className="btn-ghost px-3 py-1.5 text-sm"
          onClick={() => navigate('/history')}
        >
          ← History
        </button>
        <span className="ml-auto text-xs text-slate-400">
          {new Date(scan.createdAt).toLocaleString()}
        </span>
      </div>

      {scan.imageDataUrl && (
        <img
          src={scan.imageDataUrl}
          alt="Scanned"
          className="max-h-52 w-full rounded-2xl bg-ink-800 object-contain"
        />
      )}

      <div className="card divide-y divide-white/5">
        {scan.kvPairs.map((p, i) => (
          <div key={i} className="p-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
              {p.key}
            </p>
            <p className="mt-0.5 break-words text-sm">{p.value}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-2 gap-2">
        <button
          className="btn-ghost text-sm"
          onClick={() =>
            downloadCsv(
              kvToCsv(scan.kvPairs),
              `${scan.barcodeValue || scan.productName || 'scan'}.csv`.replace(
                /[^\w.-]+/g,
                '_',
              ),
            )
          }
        >
          Export CSV
        </button>
        <button
          className="btn-ghost text-sm text-red-300"
          onClick={async () => {
            if (scan.id != null && confirm('Delete this scan?')) {
              await deleteScan(scan.id);
              navigate('/history');
            }
          }}
        >
          Delete
        </button>
      </div>
    </div>
  );
}
