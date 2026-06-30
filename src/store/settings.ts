import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type OcrEngineId = 'claude' | 'google';

export interface UsageCounters {
  claude: number;
  google: number;
}

interface SettingsState {
  claudeKey: string;
  ocrEngine: OcrEngineId;
  /** Month stamp "YYYY-MM" the counters belong to; rolls over automatically. */
  usageMonth: string;
  usage: UsageCounters;

  setClaudeKey: (v: string) => void;
  setOcrEngine: (v: OcrEngineId) => void;
  recordUsage: (engine: OcrEngineId) => void;
  resetUsage: () => void;
}

function currentMonth(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

const emptyUsage = (): UsageCounters => ({ claude: 0, google: 0 });

export const useSettings = create<SettingsState>()(
  persist(
    (set, get) => ({
      claudeKey: '',
      ocrEngine: 'claude',
      usageMonth: currentMonth(),
      usage: emptyUsage(),

      setClaudeKey: (v) => set({ claudeKey: v.trim() }),
      setOcrEngine: (v) => set({ ocrEngine: v }),

      recordUsage: (engine) => {
        const now = currentMonth();
        const rollOver = get().usageMonth !== now;
        const usage = rollOver ? emptyUsage() : { ...get().usage };
        usage[engine] += 1;
        set({ usage, usageMonth: now });
      },

      resetUsage: () =>
        set({ usage: emptyUsage(), usageMonth: currentMonth() }),
    }),
    { name: 'snapit-settings' },
  ),
);

/** Known monthly free-tier reference points, used to scale the usage bars. */
export const USAGE_REFERENCE: Record<OcrEngineId, number | null> = {
  claude: null, // no free tier — bar shows raw count
  google: 1000, // Google Cloud Vision free tier: 1000 units/month
};
