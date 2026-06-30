import { OcrError, splitDataUrl, type OcrEngine } from './ocrEngine';
import { useSettings } from '../store/settings';

const MODEL = 'gemini-2.5-flash';
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

interface GeminiPart {
  text?: string;
}
interface GeminiResponse {
  candidates?: Array<{ content?: { parts?: GeminiPart[] } }>;
}

/**
 * Low-level Gemini vision call. Returns the model's text output for a given
 * prompt + image. Mirrors {@link callClaudeVision}: a browser BYO-key model that
 * posts the image directly to Google's Generative Language API (CORS-allowed,
 * so no backend hop — unlike the Cloud Vision engine). Shared by the OCR engine
 * and the product "identify from photo" lookup. Throws a typed {@link OcrError}
 * on every failure path.
 */
export async function callGeminiVision(
  imageDataUrl: string,
  prompt: string,
): Promise<string> {
  const key = useSettings.getState().geminiKey.trim();
  if (!key) {
    throw new OcrError('Add a Gemini API key in Settings to use Gemini.', {
      needsKey: true,
    });
  }

  const { mediaType, base64 } = splitDataUrl(imageDataUrl);

  let resp: Response;
  try {
    resp = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-goog-api-key': key,
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { inlineData: { mimeType: mediaType, data: base64 } },
              { text: prompt },
            ],
          },
        ],
      }),
    });
  } catch {
    throw new OcrError('Network error. Check your connection and try again.');
  }

  if (resp.status === 400 || resp.status === 403) {
    throw new OcrError('Invalid Gemini API key. Update it in Settings.', {
      needsKey: true,
    });
  }
  if (resp.status === 429) {
    throw new OcrError('Gemini is rate-limited. Please try again shortly.');
  }
  if (!resp.ok) {
    throw new OcrError(`Gemini request failed (HTTP ${resp.status}).`);
  }

  const json = (await resp.json()) as GeminiResponse;
  const text = json.candidates?.[0]?.content?.parts?.find(
    (p) => typeof p.text === 'string',
  )?.text;
  if (typeof text !== 'string') {
    throw new OcrError('Gemini returned an unexpected response.');
  }
  return text;
}

const OCR_PROMPT =
  'Transcribe ALL text visible in this image exactly as it appears, preserving ' +
  'line breaks. Output only the raw text, no commentary, no markdown.';

export const geminiEngine: OcrEngine = {
  id: 'gemini',
  label: 'Gemini (your API key)',
  isReady: () => useSettings.getState().geminiKey.trim().length > 0,
  recognizeText: (imageDataUrl) => callGeminiVision(imageDataUrl, OCR_PROMPT),
};
