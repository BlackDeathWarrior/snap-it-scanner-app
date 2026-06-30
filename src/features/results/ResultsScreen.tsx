import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useScanSession } from '../../store/scanSession';
import { useSettings } from '../../store/settings';
import type { KeyValue } from '../../services/kvParser';
import { kvToCsv, downloadCsv } from '../../services/csvExport';
import { addScan } from '../../services/historyRepo';
import { identifyFromImage, productToKvMap } from '../../services/productLookup';
import { OcrError } from '../../engines';

export function ResultsScreen() {
  const navigate = useNavigate();
  const active = useScanSession((s) => s.active);
  const setPairs = useScanSession((s) => s.setPairs);
  const recordUsage = useSettings((s) => s.recordUsage);

  const [saved, setSaved] = useState(false);
  const [copied, setCopied] = useState(false);
  const [aiBusy, setAiBusy] = useState(false);
  const [aiMsg, setAiMsg] = useState<string | null>(null);
  const [aiNeedsKey, setAiNeedsKey] = useState(false);

  useEffect(() => {
    if (!active) navigate('/', { replace: true });
  }, [active, navigate]);
  if (!active) return null;

  const pairs = active.pairs;

  const updatePair = (i: number, patch: Partial<KeyValue>) =>
    setPairs(pairs.map((p, idx) => (idx === i ? { ...p, ...patch } : p)));
  const deletePair = (i: number) =>
    setPairs(pairs.filter((_, idx) => idx !== i));
  const addPair = () =>
    setPairs([...pairs, { key: 'New field', value: '', isEdited: true }]);

  const asText = () => pairs.map((p) => `${p.key}: ${p.value}`).join('\n');

  const copyAll = async () => {
    await navigator.clipboard.writeText(asText());
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const share = async () => {
    if (navigator.share) {
      await navigator.share({ title: 'Scan result', text: asText() });
    } else {
      await copyAll();
    }
  };

  const exportCsv = () => {
    const name = active.barcodeValue || active.productName || 'scan';
    downloadCsv(kvToCsv(pairs), `${name}.csv`.replace(/[^\w.-]+/g, '_'));
  };

  const save = async () => {
    await addScan({
      createdAt: Date.now(),
      inputType: active.inputType,
      barcodeValue: active.barcodeValue,
      barcodeFormat: active.barcodeFormat,
      ocrText: active.ocrText,
      kvPairs: pairs,
      productName: active.productName,
      productBrand: active.productBrand,
      imageDataUrl: active.imageDataUrl,
    });
    setSaved(true);
    setTimeout(() => setSaved(false), 1500);
  };

  const identifyWithAi = async () => {
    if (!active.imageDataUrl) return;
    setAiBusy(true);
    setAiMsg(null);
    setAiNeedsKey(false);
    try {
      const info = await identifyFromImage(active.imageDataUrl);
      recordUsage('claude');
      if (!info) {
        setAiMsg('Claude could not identify anything in the image.');
        return;
      }
      // Existing values win; AI fills gaps only (mirrors the Flutter merge).
      const existing: Record<string, string> = {};
      for (const p of pairs) existing[p.key] = p.value;
      const merged = { ...productToKvMap(info), ...existing };
      const next: KeyValue[] = Object.entries(merged).map(([key, value]) => ({
        key,
        value,
      }));
      setPairs(next);
      setAiMsg('Added details from Claude.');
    } catch (e) {
      setAiNeedsKey(e instanceof OcrError && e.needsKey);
      setAiMsg(e instanceof Error ? e.message : 'AI lookup failed.');
    } finally {
      setAiBusy(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <button className="btn-ghost px-3 py-1.5 text-sm" onClick={() => navigate('/')}>
          ← New scan
        </button>
        <span className="ml-auto text-xs text-slate-400">
          via {active.engineLabel}
        </span>
      </div>

      {active.imageDataUrl && (
        <img
          src={active.imageDataUrl}
          alt="Scanned"
          className="max-h-52 w-full rounded-2xl object-contain bg-ink-800"
        />
      )}

      <div className="card divide-y divide-white/5">
        {pairs.length === 0 && (
          <p className="p-5 text-center text-sm text-slate-400">
            No fields detected. Add one manually or try the AI lookup.
          </p>
        )}
        {pairs.map((p, i) => (
          <div key={i} className="flex items-start gap-2 p-3">
            <div className="flex-1 space-y-1.5">
              <input
                className="input py-1.5 text-xs font-semibold text-slate-300"
                value={p.key}
                onChange={(e) => updatePair(i, { key: e.target.value })}
              />
              <textarea
                className="input min-h-[2.5rem] resize-y py-1.5 text-sm"
                value={p.value}
                rows={1}
                onChange={(e) =>
                  updatePair(i, { value: e.target.value, isEdited: true })
                }
              />
            </div>
            <button
              className="mt-1 rounded-lg px-2 py-2 text-slate-500 hover:bg-white/5 hover:text-red-300"
              onClick={() => deletePair(i)}
              aria-label="Delete field"
            >
              ✕
            </button>
          </div>
        ))}
        <button
          className="w-full p-3 text-sm font-medium text-brand-400 hover:bg-white/5"
          onClick={addPair}
        >
          + Add field
        </button>
      </div>

      {active.imageDataUrl && (
        <div className="card p-3">
          <button
            className="btn-ghost w-full"
            onClick={identifyWithAi}
            disabled={aiBusy}
          >
            {aiBusy ? 'Asking Claude…' : '🔄 Re-scan with Claude'}
          </button>
          {aiMsg && (
            <div className="mt-2 text-center text-xs text-slate-300">
              {aiMsg}
              {aiNeedsKey && (
                <button
                  className="ml-2 font-medium text-brand-400 underline"
                  onClick={() => navigate('/settings')}
                >
                  Add key
                </button>
              )}
            </div>
          )}
        </div>
      )}

      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <button className="btn-ghost text-sm" onClick={copyAll}>
          {copied ? 'Copied ✓' : 'Copy'}
        </button>
        <button className="btn-ghost text-sm" onClick={share}>
          Share
        </button>
        <button className="btn-ghost text-sm" onClick={exportCsv}>
          Export CSV
        </button>
        <button className="btn-primary text-sm" onClick={save}>
          {saved ? 'Saved ✓' : 'Save'}
        </button>
      </div>
    </div>
  );
}
