/** Read a File/Blob into a base64 data URL. */
export function fileToDataUrl(file: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(new Error('Could not read the image file.'));
    reader.readAsDataURL(file);
  });
}

/**
 * Cleanup pass before sending an image to a vision/OCR API. In order:
 *   1. Fix EXIF orientation — phone photos are often rotated, which is the #1
 *      cause of bad OCR. `createImageBitmap(..., { imageOrientation })` bakes the
 *      correct rotation into the pixels.
 *   2. Downscale so the longest edge is <= maxEdge (smaller payload, faster).
 *   3. Apply a *mild* contrast/saturation lift to help faint labels.
 *
 * Note: we deliberately do NOT grayscale or binarize — that helps legacy
 * Tesseract but hurts modern vision models (Claude, Google Vision), which read
 * color labels best. Re-encodes as JPEG.
 */
export async function preprocessForVision(
  dataUrl: string,
  maxEdge = 1600,
  quality = 0.85,
): Promise<string> {
  let bitmap: ImageBitmap | HTMLImageElement;
  let width: number;
  let height: number;

  try {
    const blob = await (await fetch(dataUrl)).blob();
    const bmp = await createImageBitmap(blob, { imageOrientation: 'from-image' });
    bitmap = bmp;
    width = bmp.width;
    height = bmp.height;
  } catch {
    // Older browsers: fall back to a plain <img> (no EXIF correction).
    const img = await loadImage(dataUrl);
    bitmap = img;
    width = img.width;
    height = img.height;
  }

  const scale = Math.min(1, maxEdge / Math.max(width, height));
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(width * scale);
  canvas.height = Math.round(height * scale);
  const ctx = canvas.getContext('2d');
  if (!ctx) return dataUrl;

  // Gentle, OCR-friendly enhancement. Supported on all modern canvases.
  ctx.filter = 'contrast(1.08) saturate(1.05)';
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  if ('close' in bitmap) (bitmap as ImageBitmap).close();

  return canvas.toDataURL('image/jpeg', quality);
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('Could not load image.'));
    img.src = src;
  });
}
