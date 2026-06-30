import { OcrError, splitDataUrl, type OcrEngine } from './ocrEngine';
import { useSettings } from '../store/settings';

const ENDPOINT = 'https://api.anthropic.com/v1/messages';
const MODEL = 'claude-opus-4-8';

interface ClaudeContentBlock {
  type: string;
  text?: string;
}

/**
 * Low-level Claude vision call. Returns the model's text output for a given
 * prompt + image. Shared by the OCR engine and the product "identify from
 * photo" lookup. Throws a typed {@link OcrError} on every failure path.
 */
export async function callClaudeVision(
  imageDataUrl: string,
  prompt: string,
): Promise<string> {
  const key = useSettings.getState().claudeKey.trim();
  if (!key) {
    throw new OcrError('Add a Claude API key in Settings to use Claude.', {
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
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        // Required to call the API directly from a browser (BYO-key model).
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: { type: 'base64', media_type: mediaType, data: base64 },
              },
              { type: 'text', text: prompt },
            ],
          },
        ],
      }),
    });
  } catch {
    throw new OcrError('Network error. Check your connection and try again.');
  }

  if (resp.status === 401) {
    throw new OcrError('Invalid Claude API key. Update it in Settings.', {
      needsKey: true,
    });
  }
  if (resp.status === 429) {
    throw new OcrError('Claude is rate-limited. Please try again shortly.');
  }
  if (!resp.ok) {
    throw new OcrError(`Claude request failed (HTTP ${resp.status}).`);
  }

  const json = (await resp.json()) as { content?: ClaudeContentBlock[] };
  const text = json.content?.find((b) => b.type === 'text')?.text;
  if (typeof text !== 'string') {
    throw new OcrError('Claude returned an unexpected response.');
  }
  return text;
}

const OCR_PROMPT =
  'Transcribe ALL text visible in this image exactly as it appears, preserving ' +
  'line breaks. Output only the raw text, no commentary, no markdown.';

export const claudeEngine: OcrEngine = {
  id: 'claude',
  label: 'Claude Vision (your API key)',
  isReady: () => useSettings.getState().claudeKey.trim().length > 0,
  recognizeText: (imageDataUrl) => callClaudeVision(imageDataUrl, OCR_PROMPT),
};
