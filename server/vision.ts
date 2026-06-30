import { GoogleAuth } from 'google-auth-library';

const ENDPOINT = 'https://vision.googleapis.com/v1/images:annotate';

// One shared service account authenticates every request. Credentials are
// resolved from GOOGLE_APPLICATION_CREDENTIALS (a path to the service-account
// JSON) via Application Default Credentials.
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-vision'],
});

interface VisionResponse {
  responses?: Array<{
    fullTextAnnotation?: { text?: string };
    error?: { message?: string };
  }>;
  error?: { message?: string };
}

/**
 * Runs Google Cloud Vision TEXT_DETECTION over a base64 image, authenticated
 * with an OAuth2 access token minted from the service account. Returns the
 * recognized text (possibly empty). Throws on auth/API failure.
 */
export async function annotateImage(base64: string): Promise<string> {
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  if (!token) {
    throw new Error(
      'Could not obtain a Google access token. Check GOOGLE_APPLICATION_CREDENTIALS.',
    );
  }

  const resp = await fetch(ENDPOINT, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      requests: [
        {
          image: { content: base64 },
          features: [{ type: 'TEXT_DETECTION', maxResults: 1 }],
        },
      ],
    }),
  });

  const json = (await resp.json().catch(() => ({}))) as VisionResponse;
  if (!resp.ok) {
    throw new Error(
      json.error?.message ?? `Google Vision failed (HTTP ${resp.status}).`,
    );
  }

  const first = json.responses?.[0];
  if (first?.error?.message) throw new Error(first.error.message);
  return first?.fullTextAnnotation?.text ?? '';
}
