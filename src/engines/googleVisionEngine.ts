import { OcrError, splitDataUrl, type OcrEngine } from './ocrEngine';

const ENDPOINT = '/api/vision';

interface VisionProxyResponse {
  text?: string;
  error?: string;
}

/**
 * Google Cloud Vision TEXT_DETECTION via the app's own backend. The browser
 * sends the base64 image to `/api/vision`; the Express server authenticates to
 * Google with an OAuth2 service-account token (API-key auth is not accepted by
 * the Vision API). No per-user Google key is needed.
 */
export const googleVisionEngine: OcrEngine = {
  id: 'google',
  label: 'Google Cloud Vision',
  // Auth lives on the backend, so the engine is always "ready"; an unreachable
  // backend surfaces as a runtime error below.
  isReady: () => true,
  async recognizeText(imageDataUrl: string): Promise<string> {
    const { base64 } = splitDataUrl(imageDataUrl);

    let resp: Response;
    try {
      resp = await fetch(ENDPOINT, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ image: base64 }),
      });
    } catch {
      throw new OcrError(
        'Could not reach the OCR backend. Start it with "npm run server" (or deploy it) and try again.',
      );
    }

    const json = (await resp.json().catch(() => ({}))) as VisionProxyResponse;
    if (!resp.ok) {
      throw new OcrError(
        json.error ?? `Google Vision failed (HTTP ${resp.status}).`,
      );
    }
    return json.text ?? '';
  },
};
