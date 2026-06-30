import { callClaudeVision } from '../engines/claudeEngine';
import { OcrError } from '../engines/ocrEngine';

export interface ProductInfo {
  barcode: string;
  name?: string;
  brand?: string;
  category?: string;
  description?: string;
  quantity?: string;
  ingredients?: string;
  price?: string;
  imageUrl?: string;
  source?: string;
  extra: Record<string, string>;
}

export function productToKvMap(p: ProductInfo): Record<string, string> {
  const m: Record<string, string> = {};
  if (p.name) m['Product Name'] = p.name;
  if (p.brand) m['Brand'] = p.brand;
  if (p.category) m['Category'] = p.category;
  if (p.quantity) m['Quantity'] = p.quantity;
  if (p.price) m['Price'] = p.price;
  if (p.description) m['Description'] = p.description;
  if (p.ingredients) m['Ingredients'] = p.ingredients;
  Object.assign(m, p.extra);
  if (p.source) m['Source'] = p.source;
  return m;
}

const cache = new Map<string, ProductInfo | null>();

/**
 * Looks up a product by barcode across free, keyless sources. Returns null when
 * no source recognizes the code. Order mirrors the Flutter app: UPCitemdb
 * (universal retail) then Open Food Facts (food). UPCitemdb often blocks
 * browser CORS — that failure is swallowed and we fall through to OFF.
 */
export async function lookupBarcode(
  barcode: string,
): Promise<ProductInfo | null> {
  if (cache.has(barcode)) return cache.get(barcode) ?? null;

  let info: ProductInfo | null = null;
  try {
    info = await lookupUpcItemDb(barcode);
  } catch {
    // CORS / network — ignore and try the next source.
  }
  if (!info) {
    try {
      info = await lookupOpenFoodFacts(barcode);
    } catch {
      // ignore; null result returned below
    }
  }

  cache.set(barcode, info);
  return info;
}

async function lookupUpcItemDb(barcode: string): Promise<ProductInfo | null> {
  const resp = await fetch(
    `https://api.upcitemdb.com/prod/trial/lookup?upc=${encodeURIComponent(barcode)}`,
  );
  if (!resp.ok) return null;
  const json = (await resp.json()) as {
    items?: Array<Record<string, unknown>>;
  };
  const item = json.items?.[0];
  if (!item) return null;

  const nonEmpty = (v: unknown): string | undefined => {
    const s = v == null ? '' : String(v).trim();
    return s.length ? s : undefined;
  };

  const images = item.images as string[] | undefined;
  const offers = item.offers as Array<Record<string, unknown>> | undefined;
  let price: string | undefined;
  if (offers?.length) {
    const prices = offers
      .map((o) => o.price)
      .filter((p): p is number => typeof p === 'number' && p > 0);
    const lowest = prices.length ? Math.min(...prices) : undefined;
    const currency = (offers[0].currency as string) ?? 'USD';
    if (lowest != null) price = `${lowest.toFixed(2)} ${currency}`;
  }

  return {
    barcode,
    name: nonEmpty(item.title),
    brand: nonEmpty(item.brand),
    category: nonEmpty(item.category),
    description: nonEmpty(item.description),
    price,
    imageUrl: images?.length ? images[0] : undefined,
    source: 'UPCitemdb',
    extra: {},
  };
}

async function lookupOpenFoodFacts(
  barcode: string,
): Promise<ProductInfo | null> {
  const resp = await fetch(
    `https://world.openfoodfacts.org/api/v3/product/${encodeURIComponent(barcode)}.json`,
  );
  if (!resp.ok) return null;
  const json = (await resp.json()) as {
    status?: string;
    product?: Record<string, unknown>;
  };
  const p = json.product;
  if (!p || json.status === 'failure') return null;

  const str = (v: unknown): string | undefined => {
    const s = v == null ? '' : String(v).trim();
    return s.length ? s : undefined;
  };

  const extra: Record<string, string> = {};
  const nutr = p.nutriments as Record<string, unknown> | undefined;
  const energy = nutr?.['energy-kcal_serving'];
  if (typeof energy === 'number') {
    extra['Calories (per serving)'] = `${energy} kcal`;
  }

  return {
    barcode,
    name: str(p.product_name),
    brand: str(p.brands),
    category: str(p.categories),
    quantity: str(p.quantity),
    ingredients: str(p.ingredients_text),
    imageUrl: str(p.image_front_url),
    source: 'Open Food Facts',
    extra,
  };
}

const IDENTIFY_PROMPT =
  'You are reading a product label/tag. Extract every field you can see. ' +
  'Respond with ONLY a strict JSON object, no markdown, no prose, using ' +
  'these keys: {"name": string, "brand": string, "category": string, ' +
  '"description": string, "mrp": string, "price": string, ' +
  '"quantity": string, "weight": string, "expiry": string, ' +
  '"batch": string, "hsn": string, ' +
  '"extra": object of any other label fields as string key/value pairs}. ' +
  'Use an empty string for any field you cannot determine, and {} for ' +
  'extra when there is nothing else.';

/**
 * Google-Lens-style "identify product from photo" using Claude vision. Mirrors
 * ProductLookup.lookupByImage in the Flutter app. Throws OcrError (with
 * needsKey) when no Claude key is configured.
 */
export async function identifyFromImage(
  imageDataUrl: string,
): Promise<ProductInfo | null> {
  const text = await callClaudeVision(imageDataUrl, IDENTIFY_PROMPT);
  const parsed = extractJson(text);
  if (!parsed) throw new OcrError('Could not read the AI response.');

  const field = (k: string): string | undefined => {
    const v = parsed[k];
    const s = v == null ? '' : String(v).trim();
    return s.length ? s : undefined;
  };

  const extra: Record<string, string> = {};
  const put = (label: string, v: string | undefined) => {
    if (v) extra[label] = v;
  };
  put('MRP', field('mrp'));
  put('Weight/Volume', field('weight'));
  put('Expiry', field('expiry'));
  put('Batch/Lot', field('batch'));
  put('HSN', field('hsn'));

  const extraObj = parsed.extra;
  if (extraObj && typeof extraObj === 'object') {
    for (const [k, v] of Object.entries(extraObj as Record<string, unknown>)) {
      const key = k.trim();
      const val = v == null ? '' : String(v).trim();
      if (key && val) extra[key] = val;
    }
  }

  const name = field('name');
  const brand = field('brand');
  if (!name && !brand && Object.keys(extra).length === 0) return null;

  return {
    barcode: '',
    name,
    brand,
    category: field('category'),
    description: field('description'),
    quantity: field('quantity'),
    price: field('price'),
    source: 'Claude Vision',
    extra,
  };
}

function extractJson(text: string): Record<string, unknown> | null {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end <= start) return null;
  try {
    return JSON.parse(text.substring(start, end + 1)) as Record<string, unknown>;
  } catch {
    return null;
  }
}
