import type { BarcodeResult } from '../engines/barcode';

export interface KeyValue {
  key: string;
  value: string;
  isEdited?: boolean;
}

// Patterns ported verbatim from lib/services/kv_parser.dart. String.raw keeps
// backslashes literal; every matcher runs case-insensitive (Dart caseSensitive:false).
const PRICE = String.raw`[$€£¥₹]\s*\d+[\.,]\d{2}|\d+[\.,]\d{2}\s*[$€£¥₹]`;
const WEIGHT = String.raw`\b(\d+(?:\.\d+)?)\s*(kg|g|lb|oz|ml|l|litre|liter)\b`;
const EXPIRY = String.raw`(?:exp(?:iry|ires?)?|best\s+before|mfg|manufactured)[:\s]*([0-9A-Za-z/\-\.]+)`;
const DATE = String.raw`\b\d{4}[-/]\d{2}[-/]\d{2}\b|\b\d{2}[-/]\d{2}[-/]\d{4}\b`;
const BATCH = String.raw`(?:batch|lot|lot\s*no\.?)[:\s]*([A-Z0-9\-]+)`;
const MRP = String.raw`(?:m\.?\s*r\.?\s*p\.?|max(?:imum)?\s+retail\s+price)\.?[:\s]*([₹$€£¥]?\s*\d+(?:[\.,]\d{1,2})?(?:\s*/-)?)`;
const QTY = String.raw`(?:net\s+qty|quantity|qty)\.?[:\s]*(\d+(?:\.\d+)?\s*(?:kg|g|lb|oz|ml|l|litre|liter|n|nos|pcs|pieces|units?)?)`;
const HSN = String.raw`(?:hsn|sac)(?:\s*code)?\.?[:\s]*(\d{4,8})`;
const SERIAL = String.raw`(?:s\s*/\s*n|serial(?:\s*no\.?)?|imei)[:\s]*([A-Z0-9\-]{4,})`;

const KEY_ALIASES: Record<string, string> = {
  exp: 'Expiry',
  expiry: 'Expiry',
  'expiry date': 'Expiry',
  expires: 'Expiry',
  'best before': 'Expiry',
  bb: 'Expiry',
  mfg: 'MFG Date',
  manufactured: 'MFG Date',
  'manufacture date': 'MFG Date',
  batch: 'Batch/Lot',
  lot: 'Batch/Lot',
  'lot no': 'Batch/Lot',
  'lot no.': 'Batch/Lot',
  'batch no': 'Batch/Lot',
  'net weight': 'Weight/Volume',
  'net wt': 'Weight/Volume',
  mrp: 'MRP',
  'm.r.p': 'MRP',
  'm.r.p.': 'MRP',
  'max retail price': 'MRP',
  'maximum retail price': 'MRP',
  qty: 'Quantity',
  quantity: 'Quantity',
  'net qty': 'Quantity',
  hsn: 'HSN',
  'hsn code': 'HSN',
  sac: 'HSN',
  's/n': 'Serial',
  sn: 'Serial',
  serial: 'Serial',
  'serial no': 'Serial',
  'serial no.': 'Serial',
  imei: 'Serial',
};

export interface ParseInput {
  ocrText?: string;
  barcode?: BarcodeResult | null;
  productFields?: Record<string, string> | null;
}

export class KvParser {
  parse({ ocrText = '', barcode, productFields }: ParseInput): KeyValue[] {
    const pairs: KeyValue[] = [];

    if (barcode) {
      pairs.push(...this.classifyBarcode(barcode));
    }

    if (ocrText.length > 0) {
      pairs.push(...this.parseOcrText(ocrText));
    }

    if (productFields) {
      for (const [key, value] of Object.entries(productFields)) {
        if (!this.hasKey(pairs, key)) pairs.push({ key, value });
      }
    }

    // Deduplicate by key (keep first occurrence).
    const seen = new Set<string>();
    const deduped = pairs.filter((kv) => {
      const k = kv.key.toLowerCase();
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });

    // Fallback: if OCR produced no pairs at all, show the raw text.
    if (deduped.length === 0 && ocrText.length > 0) {
      deduped.push({ key: 'Scanned Text', value: ocrText.trim() });
    }

    return deduped;
  }

  private classifyBarcode(b: BarcodeResult): KeyValue[] {
    const v = b.value;
    if (this.isUrl(v)) {
      return [
        { key: 'Type', value: 'URL' },
        { key: 'URL', value: v },
      ];
    }
    if (v.startsWith('BEGIN:VCARD')) {
      return [{ key: 'Type', value: 'vCard' }, ...this.parseVCard(v)];
    }
    if (v.startsWith('WIFI:')) {
      return [{ key: 'Type', value: 'WiFi' }, ...this.parseWifi(v)];
    }
    if (b.isQr) {
      return [
        { key: 'Type', value: 'QR Text' },
        { key: 'Content', value: v },
      ];
    }
    return [
      { key: 'Barcode', value: v },
      { key: 'Format', value: b.format },
    ];
  }

  private parseOcrText(text: string): KeyValue[] {
    const lines = text
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 0);

    const pairs: KeyValue[] = [];

    for (const line of lines) {
      // Explicit key: value pairs.
      const colonIdx = line.indexOf(':');
      const equalsIdx = line.indexOf('=');
      const splitIdx =
        colonIdx !== -1 ? colonIdx : equalsIdx !== -1 ? equalsIdx : -1;

      if (splitIdx > 0 && splitIdx < line.length - 1) {
        const k = line.substring(0, splitIdx).trim();
        const val = line.substring(splitIdx + 1).trim();
        if (k.length > 0 && val.length > 0 && k.length < 40) {
          pairs.push({ key: this.normalizeKey(k), value: val });
          continue;
        }
      }

      // Pattern matchers for unlabeled values. MRP and Quantity run before
      // Price/Weight so a labeled line registers under its specific key.
      const mrpMatched = this.matchPattern(line, MRP, 'MRP', pairs, 1);
      const qtyMatched = this.matchPattern(line, QTY, 'Quantity', pairs, 1);
      this.matchPattern(line, HSN, 'HSN', pairs, 1);
      this.matchPattern(line, SERIAL, 'Serial', pairs, 1);
      if (!mrpMatched) this.matchPattern(line, PRICE, 'Price', pairs);
      if (!qtyMatched) {
        this.matchPattern(line, WEIGHT, 'Weight/Volume', pairs, 0);
      }
      this.matchPattern(line, EXPIRY, 'Expiry', pairs, 1);
      this.matchPattern(line, BATCH, 'Batch/Lot', pairs, 1);
      if (!this.hasKey(pairs, 'Date')) {
        this.matchPattern(line, DATE, 'Date', pairs);
      }
    }

    return pairs;
  }

  /** Returns true when a value was matched and added under [key]. */
  private matchPattern(
    line: string,
    pattern: string,
    key: string,
    pairs: KeyValue[],
    groupIndex = 0,
  ): boolean {
    const re = new RegExp(pattern, 'i');
    const m = re.exec(line);
    if (m) {
      const val = groupIndex === 0 ? m[0] : m[groupIndex] ?? '';
      if (val.length > 0 && !this.hasKey(pairs, key)) {
        pairs.push({ key, value: val.trim() });
        return true;
      }
    }
    return false;
  }

  private parseVCard(vcard: string): KeyValue[] {
    const pairs: KeyValue[] = [];
    for (const line of vcard.split('\n')) {
      const parts = line.split(':');
      if (parts.length < 2) continue;
      const key = parts[0].split(';')[0].trim();
      const value = parts.slice(1).join(':').trim();
      if (key === 'BEGIN' || key === 'END' || key === 'VERSION') continue;
      if (value.length > 0) pairs.push({ key, value });
    }
    return pairs;
  }

  private parseWifi(wifi: string): KeyValue[] {
    // WIFI:T:WPA;S:NetworkName;P:Password;;
    const pairs: KeyValue[] = [];
    const body = wifi.substring(5);
    for (const segment of body.split(';')) {
      if (segment.length < 3) continue;
      const colonIdx = segment.indexOf(':');
      if (colonIdx < 1) continue;
      const k = segment.substring(0, colonIdx);
      const v = segment.substring(colonIdx + 1);
      const label =
        k === 'S' ? 'SSID' : k === 'P' ? 'Password' : k === 'T' ? 'Security' : k;
      if (v.length > 0) pairs.push({ key: label, value: v });
    }
    return pairs;
  }

  private isUrl(s: string): boolean {
    return s.startsWith('http://') || s.startsWith('https://');
  }

  private hasKey(pairs: KeyValue[], key: string): boolean {
    return pairs.some((kv) => kv.key.toLowerCase() === key.toLowerCase());
  }

  private normalizeKey(s: string): string {
    const lower = s.toLowerCase().trim();
    if (KEY_ALIASES[lower]) return KEY_ALIASES[lower];
    if (s.length === 0) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

export const kvParser = new KvParser();
