import type { OcrEngineId } from '../store/settings';

/** Raised so the UI can explain why OCR failed (and link to Settings). */
export class OcrError extends Error {
  /** True when the engine needs an API key the user hasn't set yet. */
  readonly needsKey: boolean;
  constructor(message: string, opts?: { needsKey?: boolean }) {
    super(message);
    this.name = 'OcrError';
    this.needsKey = opts?.needsKey ?? false;
  }
}

export interface OcrEngine {
  readonly id: OcrEngineId;
  readonly label: string;
  /** True when the engine is ready to run (key present, etc.). */
  isReady(): boolean;
  /** Run OCR over an image (data URL or blob URL) and return raw text. */
  recognizeText(imageDataUrl: string): Promise<string>;
}

/** Strips a data-URL prefix, returning { mediaType, base64 }. */
export function splitDataUrl(dataUrl: string): {
  mediaType: string;
  base64: string;
} {
  const match = /^data:([^;]+);base64,(.*)$/s.exec(dataUrl);
  if (!match) {
    throw new OcrError('Unsupported image format.');
  }
  return { mediaType: match[1], base64: match[2] };
}
