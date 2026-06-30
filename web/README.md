# Snap-It Scanner

A installable **Progressive Web App** (React + TypeScript + Vite) that scans barcodes, QR
codes and product labels from your camera or an uploaded image, reads the text with your
choice of OCR engine, extracts editable key/value fields, looks up products, and saves a
local history — all from a single URL on any device.

> Rewrite of the original Flutter app as a cross-platform PWA. No Google ML Kit.

## Features

- **Three OCR engines, switchable in Settings:**
  - **Tesseract** — free, runs entirely on-device (no key, works offline).
  - **Claude Vision** — bring your own Anthropic API key.
  - **Google Cloud Vision** — bring your own Google Cloud API key.
- **Per-engine usage counters** in Settings (Google's bar scales to its 1,000/month free tier;
  counters reset monthly).
- **Barcode / QR decode** via ZXing (camera stream + still image).
- **Key/value extraction** — ported 1:1 from the Flutter app's heuristic parser (price, MRP,
  weight, expiry, batch, HSN, serial, quantity, vCard/WiFi/URL QR payloads).
- **Product lookup** — Open Food Facts (and UPCitemdb where CORS allows) + a "✨ Identify with
  Claude" photo lookup.
- **Editable results**, copy, Web Share, **CSV export**.
- **History** stored locally in IndexedDB (Dexie), with image thumbnails.
- **Installable PWA** with offline app shell.

## Privacy / keys

This app has **no backend**. API keys you enter are stored only in your browser's local storage
and are sent **directly** from your browser to the chosen provider (Anthropic / Google). Nothing
is proxied through a server.

## Develop

```sh
npm install
npm run dev        # http://localhost:5173
npm run test       # Vitest (KV parser parity suite)
npm run typecheck
npm run build      # production build → dist/
npm run preview    # serve the production build
```

## Deploy (Vercel)

The repo's Vite app lives in `web/`. In Vercel:

1. Import the GitHub repo.
2. Set **Root Directory** to `web/`.
3. Framework preset auto-detects **Vite**; build `npm run build`, output `dist`.
4. Deploy — `vercel.json` adds the SPA rewrite so client routes work.

## Tech

React 18 · TypeScript · Vite · Tailwind · react-router · Zustand · @zxing/browser ·
tesseract.js · Dexie · vite-plugin-pwa
