import type { KeyValue } from './kvParser';

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
