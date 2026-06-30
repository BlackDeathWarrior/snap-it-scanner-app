import { describe, it, expect } from 'vitest';
import { KvParser, type KeyValue } from './kvParser';
import type { BarcodeResult } from '../engines/barcode';

const parser = new KvParser();

function val(pairs: KeyValue[], key: string): string | undefined {
  return pairs.find((kv) => kv.key === key)?.value;
}

const qr = (value: string): BarcodeResult => ({
  value,
  format: 'QR_CODE',
  isQr: true,
});

describe('explicit key:value pairs', () => {
  it('splits colon-separated pairs', () => {
    const r = parser.parse({ ocrText: 'Weight: 200g\nBrand: Acme' });
    expect(val(r, 'Weight')).toBe('200g');
    expect(val(r, 'Brand')).toBe('Acme');
  });

  it('splits equals-separated pairs', () => {
    const r = parser.parse({ ocrText: 'Price=$4.99' });
    expect(val(r, 'Price')).toBe('$4.99');
  });
});

describe('pattern matchers', () => {
  it('detects price with dollar sign', () => {
    const r = parser.parse({ ocrText: 'Special offer $3.99 today' });
    expect(val(r, 'Price')).toBeDefined();
    expect(val(r, 'Price')).toContain('3.99');
  });

  it('detects weight in grams', () => {
    const r = parser.parse({ ocrText: 'Net weight 250g' });
    expect(val(r, 'Weight/Volume')).toContain('250');
  });

  it('detects expiry via EXP keyword', () => {
    const r = parser.parse({ ocrText: 'EXP: 2025-12-31' });
    expect(val(r, 'Expiry')).toBeDefined();
  });

  it('detects batch/lot number', () => {
    const r = parser.parse({ ocrText: 'Batch: LOT-ABC123' });
    expect(val(r, 'Batch/Lot')).toContain('LOT-ABC123');
  });

  it('detects unlabeled MRP and keeps it out of Price', () => {
    const r = parser.parse({ ocrText: 'M.R.P. ₹120.00 incl. of all taxes' });
    expect(val(r, 'MRP')).toContain('120');
    expect(val(r, 'Price')).toBeUndefined();
  });

  it('detects MRP with /- suffix', () => {
    const r = parser.parse({ ocrText: 'MRP 120/-' });
    expect(val(r, 'MRP')).toContain('120');
  });

  it('detects quantity label', () => {
    const r = parser.parse({ ocrText: 'Qty 6 N' });
    expect(val(r, 'Quantity')).toContain('6');
  });

  it('Net Qty does not double-register as Weight/Volume', () => {
    const r = parser.parse({ ocrText: 'Net Qty 500 g' });
    expect(val(r, 'Quantity')).toContain('500');
    expect(val(r, 'Weight/Volume')).toBeUndefined();
  });

  it('detects HSN code', () => {
    const r = parser.parse({ ocrText: 'HSN Code 04050020' });
    expect(val(r, 'HSN')).toBe('04050020');
  });

  it('detects serial number', () => {
    const r = parser.parse({ ocrText: 'Serial No. ABC12345' });
    expect(val(r, 'Serial')).toContain('ABC12345');
  });

  it('detects IMEI as Serial', () => {
    const r = parser.parse({ ocrText: 'IMEI 358240051111110' });
    expect(val(r, 'Serial')).toContain('358240051111110');
  });
});

describe('key normalization', () => {
  it('explicit mrp label normalizes to MRP', () => {
    const r = parser.parse({ ocrText: 'mrp: 99.00' });
    expect(val(r, 'MRP')).toBe('99.00');
  });

  it('explicit qty label normalizes to Quantity', () => {
    const r = parser.parse({ ocrText: 'Qty: 12' });
    expect(val(r, 'Quantity')).toBe('12');
  });
});

describe('barcode classification', () => {
  it('URL QR code', () => {
    const r = parser.parse({ ocrText: '', barcode: qr('https://example.com') });
    expect(val(r, 'Type')).toBe('URL');
    expect(val(r, 'URL')).toBe('https://example.com');
  });

  it('plain barcode', () => {
    const r = parser.parse({
      ocrText: '',
      barcode: { value: '4006381333931', format: 'EAN_13', isQr: false },
    });
    expect(val(r, 'Barcode')).toBe('4006381333931');
    expect(val(r, 'Format')).toBe('EAN_13');
  });

  it('WiFi QR code', () => {
    const r = parser.parse({
      ocrText: '',
      barcode: qr('WIFI:T:WPA;S:MyNetwork;P:secret;;'),
    });
    expect(val(r, 'SSID')).toBe('MyNetwork');
    expect(val(r, 'Password')).toBe('secret');
  });
});

describe('product fields merge', () => {
  it('merges product fields without duplicating', () => {
    const r = parser.parse({
      ocrText: 'Brand: Acme',
      productFields: { Brand: 'Override', 'Product Name': 'Widget' },
    });
    expect(val(r, 'Brand')).toBe('Acme');
    expect(val(r, 'Product Name')).toBe('Widget');
  });

  it('existing values win over AI fields in merge order', () => {
    const existing = { MRP: '120', Brand: 'Acme' };
    const aiFields = { MRP: '999', HSN: '1905' };
    const r = parser.parse({
      ocrText: '',
      productFields: { ...aiFields, ...existing },
    });
    expect(val(r, 'MRP')).toBe('120');
    expect(val(r, 'HSN')).toBe('1905');
  });
});

describe('deduplication', () => {
  it('does not duplicate keys', () => {
    const r = parser.parse({ ocrText: 'Price: $1.00\nPrice: $2.00' });
    expect(r.filter((kv) => kv.key === 'Price').length).toBe(1);
  });
});
