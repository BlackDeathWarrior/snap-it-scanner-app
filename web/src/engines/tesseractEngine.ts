import type { OcrEngine } from './ocrEngine';

/**
 * Free, fully in-browser OCR via tesseract.js. The WASM core and English
 * language data (~3-4 MB) are lazy-loaded only when this engine runs, so they
 * never bloat first paint.
 */
export const tesseractEngine: OcrEngine = {
  id: 'tesseract',
  label: 'Tesseract (free, on-device)',
  isReady: () => true,
  async recognizeText(imageDataUrl: string): Promise<string> {
    const { default: Tesseract } = await import('tesseract.js');
    const result = await Tesseract.recognize(imageDataUrl, 'eng');
    return result.data.text ?? '';
  },
};
