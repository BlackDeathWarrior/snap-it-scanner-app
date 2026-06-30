import Dexie, { type Table } from 'dexie';
import type { KeyValue } from './kvParser';

export type InputType = 'camera' | 'gallery' | 'file';

/** One saved scan. Mirrors the Flutter drift ScanHistoryTable schema. */
export interface ScanRecord {
  id?: number;
  createdAt: number; // epoch ms
  inputType: InputType;
  barcodeValue?: string;
  barcodeFormat?: string;
  ocrText?: string;
  kvPairs: KeyValue[];
  productName?: string;
  productBrand?: string;
  /** Captured image stored inline as a data URL (works offline). */
  imageDataUrl?: string;
}

class SnapItDb extends Dexie {
  scans!: Table<ScanRecord, number>;
  constructor() {
    super('snapit-history');
    this.version(1).stores({
      // Indexed fields only; kvPairs/image are stored but not indexed.
      scans: '++id, createdAt, barcodeValue, productName',
    });
  }
}

const db = new SnapItDb();

export async function addScan(record: ScanRecord): Promise<number> {
  return db.scans.add(record);
}

export function listScans(): Promise<ScanRecord[]> {
  return db.scans.orderBy('createdAt').reverse().toArray();
}

export function getScan(id: number): Promise<ScanRecord | undefined> {
  return db.scans.get(id);
}

export async function deleteScan(id: number): Promise<void> {
  await db.scans.delete(id);
}

export async function clearHistory(): Promise<void> {
  await db.scans.clear();
}

export { db };
