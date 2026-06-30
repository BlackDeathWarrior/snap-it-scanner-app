import { useState } from 'react';
import {
  useSettings,
  USAGE_REFERENCE,
  type OcrEngineId,
} from '../../store/settings';
import { ENGINE_LIST } from '../../engines';

const ENGINE_META: Record<
  OcrEngineId,
  { name: string; tag: string; needsKey: boolean }
> = {
  tesseract: { name: 'Tesseract', tag: 'Free · on-device', needsKey: false },
  claude: { name: 'Claude', tag: 'Your API key', needsKey: true },
  google: { name: 'Google Vision', tag: 'Your API key', needsKey: true },
};

export function SettingsScreen() {
  const {
    claudeKey,
    googleKey,
    ocrEngine,
    usage,
    setClaudeKey,
    setGoogleKey,
    setOcrEngine,
    resetUsage,
  } = useSettings();

  return (
    <div className="space-y-6">
      {/* OCR engine toggle */}
      <section className="card p-4">
        <h2 className="mb-1 text-sm font-bold">OCR Engine</h2>
        <p className="mb-3 text-xs text-slate-400">
          Choose how text is read from images. Tesseract runs free on your
          device; Claude and Google use your own API keys.
        </p>
        <div className="grid grid-cols-3 gap-2">
          {ENGINE_LIST.map((engine) => {
            const meta = ENGINE_META[engine.id];
            const active = ocrEngine === engine.id;
            return (
              <button
                key={engine.id}
                onClick={() => setOcrEngine(engine.id)}
                aria-pressed={active}
                className={`rounded-xl border p-3 text-left transition-colors ${
                  active
                    ? 'border-brand-400 bg-brand-500/15'
                    : 'border-white/10 bg-ink-900/40 hover:border-white/20'
                }`}
              >
                <div className="text-sm font-semibold">{meta.name}</div>
                <div className="text-[11px] text-slate-400">{meta.tag}</div>
                {meta.needsKey && !engine.isReady() && (
                  <div className="mt-1 text-[11px] font-medium text-amber-400">
                    Key needed
                  </div>
                )}
              </button>
            );
          })}
        </div>
      </section>

      {/* API keys */}
      <section className="card space-y-4 p-4">
        <h2 className="text-sm font-bold">API Keys</h2>
        <KeyField
          label="Claude API key"
          help="Stored only in this browser. Required for Claude OCR & AI product lookup."
          value={claudeKey}
          onSave={setClaudeKey}
          placeholder="sk-ant-..."
        />
        <KeyField
          label="Google Cloud Vision API key"
          help="Stored only in this browser. Enable the Cloud Vision API in Google Cloud."
          value={googleKey}
          onSave={setGoogleKey}
          placeholder="AIza..."
        />
        <p className="rounded-lg bg-amber-500/10 px-3 py-2 text-[11px] leading-relaxed text-amber-300/90">
          Keys never leave your device — they're saved in local storage and sent
          directly to each provider from your browser.
        </p>
      </section>

      {/* Usage counters */}
      <section className="card space-y-4 p-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-bold">Usage this month</h2>
          <button
            onClick={resetUsage}
            className="text-xs font-medium text-slate-400 hover:text-slate-200"
          >
            Reset
          </button>
        </div>
        {ENGINE_LIST.map((engine) => (
          <UsageBar
            key={engine.id}
            name={ENGINE_META[engine.id].name}
            count={usage[engine.id]}
            reference={USAGE_REFERENCE[engine.id]}
          />
        ))}
        <p className="text-[11px] text-slate-500">
          Counters track requests made from this browser. Google's bar scales to
          its 1,000/month free tier; counters reset at the start of each month.
        </p>
      </section>
    </div>
  );
}

function KeyField({
  label,
  help,
  value,
  onSave,
  placeholder,
}: {
  label: string;
  help: string;
  value: string;
  onSave: (v: string) => void;
  placeholder: string;
}) {
  const [draft, setDraft] = useState(value);
  const [reveal, setReveal] = useState(false);
  const dirty = draft.trim() !== value;

  return (
    <div>
      <label className="label">{label}</label>
      <div className="mt-1.5 flex gap-2">
        <input
          className="input font-mono"
          type={reveal ? 'text' : 'password'}
          value={draft}
          placeholder={placeholder}
          onChange={(e) => setDraft(e.target.value)}
          autoComplete="off"
          spellCheck={false}
        />
        <button
          className="btn-ghost px-3"
          type="button"
          onClick={() => setReveal((r) => !r)}
          aria-label={reveal ? 'Hide key' : 'Show key'}
        >
          {reveal ? 'Hide' : 'Show'}
        </button>
      </div>
      <p className="mt-1 text-[11px] text-slate-500">{help}</p>
      <div className="mt-2 flex gap-2">
        <button
          className="btn-primary px-3 py-1.5 text-sm"
          disabled={!dirty}
          onClick={() => onSave(draft)}
        >
          Save
        </button>
        {value && (
          <button
            className="btn-ghost px-3 py-1.5 text-sm"
            onClick={() => {
              setDraft('');
              onSave('');
            }}
          >
            Clear
          </button>
        )}
        {!dirty && value && (
          <span className="self-center text-xs text-emerald-400">Saved ✓</span>
        )}
      </div>
    </div>
  );
}

function UsageBar({
  name,
  count,
  reference,
}: {
  name: string;
  count: number;
  reference: number | null;
}) {
  // With a known free tier, fill toward it; otherwise show a soft log-ish fill.
  const pct = reference
    ? Math.min(100, (count / reference) * 100)
    : Math.min(100, count > 0 ? 8 + Math.min(82, Math.log2(count + 1) * 14) : 0);
  const near = reference != null && count / reference >= 0.8;

  return (
    <div>
      <div className="mb-1 flex items-baseline justify-between text-sm">
        <span className="font-medium">{name}</span>
        <span className="text-slate-400">
          {count.toLocaleString()}
          {reference ? ` / ${reference.toLocaleString()}` : ' requests'}
        </span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-ink-900">
        <div
          className={`h-full rounded-full transition-all ${
            near ? 'bg-amber-400' : 'bg-brand-500'
          }`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}
