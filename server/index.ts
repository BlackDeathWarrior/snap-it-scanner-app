import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { annotateImage } from './vision';

const app = express();
app.use(cors());
// Base64 images can be sizeable even after downscaling.
app.use(express.json({ limit: '15mb' }));

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

/** Proxies a base64 image to Google Cloud Vision and returns { text }. */
app.post('/api/vision', async (req, res) => {
  const image: unknown = req.body?.image;
  if (typeof image !== 'string' || image.length === 0) {
    res.status(400).json({ error: 'Missing base64 "image" in request body.' });
    return;
  }
  try {
    const text = await annotateImage(image);
    res.json({ text });
  } catch (e) {
    const message = e instanceof Error ? e.message : 'Vision request failed.';
    console.error('[vision]', message);
    res.status(502).json({ error: message });
  }
});

const port = Number(process.env.PORT) || 8787;
app.listen(port, () => {
  console.log(`Vision proxy listening on http://localhost:${port}`);
});
