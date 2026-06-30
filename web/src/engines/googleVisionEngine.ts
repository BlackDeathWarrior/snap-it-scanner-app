import { OcrError, splitDataUrl, type OcrEngine } from './ocrEngine';
import { useSettings } from '../store/settings';

const ENDPOINT = 'https://vision.googleapis.com/v1/images:annotate';

interface VisionResponse {
  responses?: Array<{
    fullTextAnnotation?: { text?: string };
    error?: { message?: string };
  }>;
  error?: { message?: string; status?: string };
}

/**
 * Google Cloud Vision TEXT_DETECTION via REST, authenticated with the user's
 * own API key (passed as a query param — the BYO-key model). CORS-enabled, so
 * it runs directly from the browser with no backend.
 */
export const googleVisionEngine: OcrEngine = {
  id: 'google',
  label: 'Google Cloud Vision (your API key)',
  isReady: () => useSettings.getState().googleKey.trim().length > 0,
  async recognizeText(imageDataUrl: string): Promise<string> {
    const key = useSettings.getState().googleKey.trim();
    if (!key) {
      throw new OcrError(
        'Add a Google Cloud Vision API key in Settings to use Google.',
        { needsKey: true },
      );
    }

    const { base64 } = splitDataUrl(imageDataUrl);

    let resp: Response;
    try {
      resp = await fetch(`${ENDPOINT}?key=${encodeURIComponent(key)}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          requests: [
            {
              image: { content: base64 },
              features: [{ type: 'TEXT_DETECTION', maxResults: 1 }],
            },
          ],
        }),
      });
    } catch {
      throw new OcrError('Network error. Check your connection and try again.');
    }

    const json = (await resp.json().catch(() => ({}))) as VisionResponse;

    if (resp.status === 400 || resp.status === 403) {
      throw new OcrError(
        json.error?.message ??
          'Invalid Google API key or Vision API not enabled. Check Settings.',
        { needsKey: true },
      );
    }
    if (!resp.ok) {
      throw new OcrError(
        json.error?.message ?? `Google Vision failed (HTTP ${resp.status}).`,
      );
    }

    const first = json.responses?.[0];
    if (first?.error?.message) {
      throw new OcrError(first.error.message);
    }
    return first?.fullTextAnnotation?.text ?? '';
  },
};
