# Snap-It Scanner

An installable **Progressive Web App** (React + TypeScript + Vite) that scans barcodes, QR
codes and product labels from your camera or an uploaded image, reads the text with your
choice of OCR engine, extracts editable key/value fields, looks up products, and saves a
local history — all from a single URL on any device.

> Originally a Flutter app; now a single React PWA + a thin OCR backend. No Flutter, no Tesseract.

## Features

- **Two OCR engines, switchable in Settings:**
  - **Claude Vision** — bring your own Anthropic API key (stored in your browser). On capture it
    runs a **single structured call** that reads a product label straight into demarcated fields
    (Product Name, Brand, MRP, Quantity, Expiry, Batch/Lot, HSN, …).
  - **Google Cloud Vision** — authenticated **server-side** via the bundled backend (OAuth2
    service account). No Google key needed in the browser.
- **Image cleanup before OCR** — EXIF orientation fix, downscale, and a mild contrast lift for
  faint labels (`src/ui/imageUtils.ts → preprocessForVision`).
- **Barcode / QR decode** via ZXing (camera stream + still image) with Open Food Facts /
  UPCitemdb product lookup.
- **Editable results**, copy, Web Share, and **CSV export** (per scan, and **export all history**
  as a wide CSV — one row per scan, every AI field its own column).
- **History** stored locally in IndexedDB (Dexie), with image thumbnails.
- **Installable PWA** with offline app shell.

## Architecture

```
src/            React PWA (Vite)
  engines/      claudeEngine, googleVisionEngine, barcode (ZXing), ocrEngine (interface)
  services/     kvParser, productLookup, historyRepo (Dexie), csvExport
  features/     capture, results, history, settings screens
  store/        zustand: settings (keys, engine, usage), scanSession
  ui/           layout, icons, imageUtils
server/         Express OAuth2 proxy for Google Vision (index.ts, vision.ts)
```

The **only** server-side piece is the Google Vision proxy: the browser POSTs a base64 image to
`/api/vision`; Express mints an OAuth2 token from a service account and calls Google. (Google's
Vision API rejects API-key auth, which is why this proxy exists.) Claude stays a direct
browser → Anthropic call with the user's own key.

## Develop

```sh
npm install

# Frontend only
npm run dev          # http://localhost:5173

# Frontend + Google Vision backend together
npm run dev:all      # Vite (5173) + Express (8787); Vite proxies /api → 8787

npm run server       # backend only (tsx watch)
npm run test         # Vitest (KV parser + CSV export)
npm run typecheck    # app + server type-check
npm run build        # production build → dist/
npm run preview      # serve the production build
```

### Google Vision setup (backend)

1. In Google Cloud Console, enable the **Cloud Vision API**.
2. Create a **service account** and download a **JSON key**.
3. Save it as `service-account.json` in the repo root (git-ignored).
4. Copy `.env.example` → `.env` and confirm
   `GOOGLE_APPLICATION_CREDENTIALS=./service-account.json`.
5. `npm run server` (or `npm run dev:all`).

## Deploy

- **Frontend:** static build (`npm run build` → `dist/`) on any static host; `vercel.json` adds
  the SPA rewrite.
- **Backend:** deploy `server/` (Render / Railway / a small Node host) with the
  `GOOGLE_APPLICATION_CREDENTIALS` (or the JSON contents) set as an env secret, and point the
  frontend's `/api` at it (same origin in production).

## Tech

React 18 · TypeScript · Vite · Tailwind · react-router · Zustand · @zxing/browser · Dexie ·
vite-plugin-pwa · Express · google-auth-library
