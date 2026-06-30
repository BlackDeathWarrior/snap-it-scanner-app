import { BrowserMultiFormatReader } from '@zxing/browser';
import { BarcodeFormat, type Result } from '@zxing/library';

export interface BarcodeResult {
  value: string;
  /** Human-readable format name, e.g. "QR_CODE", "EAN_13". */
  format: string;
  isQr: boolean;
}

function toResult(r: Result): BarcodeResult {
  const format = BarcodeFormat[r.getBarcodeFormat()] ?? 'UNKNOWN';
  return {
    value: r.getText(),
    format,
    isQr: r.getBarcodeFormat() === BarcodeFormat.QR_CODE,
  };
}

let reader: BrowserMultiFormatReader | null = null;
function getReader(): BrowserMultiFormatReader {
  reader ??= new BrowserMultiFormatReader();
  return reader;
}

/** Decode a single barcode/QR from a still image. Returns null if none found. */
export async function decodeImage(
  imageDataUrl: string,
): Promise<BarcodeResult | null> {
  try {
    const result = await getReader().decodeFromImageUrl(imageDataUrl);
    return toResult(result);
  } catch {
    // ZXing throws NotFoundException when no code is present — that's expected.
    return null;
  }
}

/**
 * Continuously decode from a camera stream into the given <video> element.
 * Calls onResult on every successful decode. Returns a stop() function.
 */
export async function decodeFromCamera(
  video: HTMLVideoElement,
  onResult: (r: BarcodeResult) => void,
  onError?: (e: unknown) => void,
): Promise<() => void> {
  try {
    const controls = await getReader().decodeFromVideoDevice(
      undefined,
      video,
      (result) => {
        if (result) onResult(toResult(result));
      },
    );
    return () => controls.stop();
  } catch (e) {
    onError?.(e);
    return () => {};
  }
}
