import { create } from 'zustand';
import type { KeyValue } from '../services/kvParser';
import type { InputType } from '../services/historyRepo';

export interface ActiveScan {
  pairs: KeyValue[];
  ocrText: string;
  barcodeValue?: string;
  barcodeFormat?: string;
  productName?: string;
  productBrand?: string;
  imageDataUrl?: string;
  inputType: InputType;
  engineLabel: string;
}

interface ScanSessionState {
  active: ActiveScan | null;
  setActive: (s: ActiveScan) => void;
  setPairs: (pairs: KeyValue[]) => void;
  clear: () => void;
}

/** Ephemeral (non-persisted) holder for the scan currently being reviewed. */
export const useScanSession = create<ScanSessionState>((set, get) => ({
  active: null,
  setActive: (active) => set({ active }),
  setPairs: (pairs) => {
    const active = get().active;
    if (active) set({ active: { ...active, pairs } });
  },
  clear: () => set({ active: null }),
}));
