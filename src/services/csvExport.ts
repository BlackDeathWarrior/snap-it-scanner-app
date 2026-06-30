import type { KeyValue } from './kvParser';
import type { ScanRecord } from './historyRepo';

function escapeCsv(field: string): string {
  if (/[",\n\r]/.test(field)) {
    return `"${field.replace(/"/g, '""')}"`;
  }
  return field;
}

/** Serialize key/value pairs to a two-column CSV string. */
export function kvToCsv(pairs: KeyValue[]): string {
  const rows = [
    ['Field', 'Value'],
    ...pairs.map((kv) => [kv.key, kv.value]),
  ];
  return rows.map((r) => r.map(escapeCsv).join(',')).join('\r\n');
}

// Scan-level metadata columns that lead every history export.
const META_COLUMNS = [
  'Date',
  'Time',
  'Input Type',
  'Barcode',
  'Barcode Format',
] as const;

// Preferred ordering for the AI/label field columns; anything else follows
// alphabetically. Mirrors the demarcated fields shown on the Results screen.
const FIELD_PRIORITY = [
  'Product Name',
  'Brand',
  'Category',
  'MRP',
  'Price',
  'Quantity',
  'Weight/Volume',
  'Expiry',
  'MFG Date',
  'Batch/Lot',
  'HSN',
  'Serial',
  'Description',
  'Ingredients',
  'Source',
];

function orderedFieldKeys(scans: ScanRecord[]): string[] {
  const keys = new Set<string>();
  for (const s of scans) for (const kv of s.kvPairs) keys.add(kv.key);
  const priority = FIELD_PRIORITY.filter((k) => keys.has(k));
  const rest = [...keys]
    .filter((k) => !FIELD_PRIORITY.includes(k))
    .sort((a, b) => a.localeCompare(b));
  return [...priority, ...rest];
}

/**
 * Serialize the full scan history to a WIDE CSV: one row per scan, with every
 * AI/label field as its own column (the union of all fields across scans). Each
 * field is demarcated exactly as on the Results screen. Missing fields are blank.
 */
export function historyToCsv(scans: ScanRecord[]): string {
  const fieldKeys = orderedFieldKeys(scans);
  const header = [...META_COLUMNS, ...fieldKeys];

  const rows = scans.map((s) => {
    const map: Record<string, string> = {};
    for (const kv of s.kvPairs) map[kv.key] = kv.value;
    const d = new Date(s.createdAt);
    const meta = [
      d.toLocaleDateString(),
      d.toLocaleTimeString(),
      s.inputType,
      s.barcodeValue ?? '',
      s.barcodeFormat ?? '',
    ];
    return [...meta, ...fieldKeys.map((k) => map[k] ?? '')];
  });

  return [header, ...rows]
    .map((r) => r.map(escapeCsv).join(','))
    .join('\r\n');
}

/** Trigger a browser download of the given CSV text. */
export function downloadCsv(csv: string, filename = 'scan.csv'): void {
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
