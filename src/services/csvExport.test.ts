import { describe, it, expect } from 'vitest';
import { historyToCsv, kvToCsv } from './csvExport';
import type { ScanRecord } from './historyRepo';

function rec(over: Partial<ScanRecord>): ScanRecord {
  return {
    createdAt: Date.parse('2026-06-30T10:00:00Z'),
    inputType: 'file',
    kvPairs: [],
    ...over,
  };
}

describe('historyToCsv (wide)', () => {
  it('builds the union of fields as columns, one row per scan', () => {
    const scans: ScanRecord[] = [
      rec({
        barcodeValue: '8901',
        kvPairs: [
          { key: 'Product Name', value: 'Maggi' },
          { key: 'MRP', value: '12' },
          { key: 'Quantity', value: '70g' },
        ],
      }),
      rec({
        kvPairs: [
          { key: 'Product Name', value: 'Lays' },
          { key: 'Expiry', value: '2027-01' },
        ],
      }),
    ];

    const csv = historyToCsv(scans);
    const [header, row1, row2] = csv.split('\r\n');

    // Meta columns lead, then prioritized + unioned fields.
    expect(header).toContain('Date,Time,Input Type,Barcode,Barcode Format');
    expect(header).toContain('Product Name');
    expect(header).toContain('MRP');
    expect(header).toContain('Quantity');
    expect(header).toContain('Expiry');

    const cols = header.split(',');
    const mrpIdx = cols.indexOf('MRP');
    const expIdx = cols.indexOf('Expiry');

    // Row 1 has MRP=12, blank Expiry; row 2 the reverse.
    expect(row1.split(',')[mrpIdx]).toBe('12');
    expect(row1.split(',')[expIdx]).toBe('');
    expect(row2.split(',')[mrpIdx]).toBe('');
    expect(row2.split(',')[expIdx]).toBe('2027-01');

    // Barcode column populated only for the first scan.
    const barcodeIdx = cols.indexOf('Barcode');
    expect(row1.split(',')[barcodeIdx]).toBe('8901');
    expect(row2.split(',')[barcodeIdx]).toBe('');
  });

  it('escapes commas and quotes in field values', () => {
    const csv = historyToCsv([
      rec({ kvPairs: [{ key: 'Description', value: 'salt, "iodised"' }] }),
    ]);
    expect(csv).toContain('"salt, ""iodised"""');
  });

  it('orders priority fields ahead of the rest alphabetically', () => {
    const csv = historyToCsv([
      rec({
        kvPairs: [
          { key: 'Zeta', value: 'z' },
          { key: 'Brand', value: 'b' },
          { key: 'Alpha', value: 'a' },
        ],
      }),
    ]);
    const cols = csv.split('\r\n')[0].split(',');
    // Brand (priority) precedes Alpha/Zeta (alphabetical leftovers).
    expect(cols.indexOf('Brand')).toBeLessThan(cols.indexOf('Alpha'));
    expect(cols.indexOf('Alpha')).toBeLessThan(cols.indexOf('Zeta'));
  });
});

describe('kvToCsv (single scan, unchanged)', () => {
  it('emits a two-column Field/Value table', () => {
    const csv = kvToCsv([{ key: 'MRP', value: '12' }]);
    expect(csv).toBe('Field,Value\r\nMRP,12');
  });
});
