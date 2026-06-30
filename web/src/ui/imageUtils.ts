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
 * Downscale a data URL so the longest edge is <= maxEdge px and re-encode as
 * JPEG. Keeps OCR/vision payloads small (faster uploads, smaller history).
 */
export async function downscaleDataUrl(
  dataUrl: string,
  maxEdge = 1600,
  quality = 0.85,
): Promise<string> {
  const img = await loadImage(dataUrl);
  const scale = Math.min(1, maxEdge / Math.max(img.width, img.height));
  if (scale >= 1) return dataUrl;

  const canvas = document.createElement('canvas');
  canvas.width = Math.round(img.width * scale);
  canvas.height = Math.round(img.height * scale);
  const ctx = canvas.getContext('2d');
  if (!ctx) return dataUrl;
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
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
