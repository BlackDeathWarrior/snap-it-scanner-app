# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project Overview

**Snap-It Scanner** — an installable React + TypeScript + Vite **PWA** that scans
barcodes/QR codes and product labels, reads text via an OCR engine, extracts editable
key/value fields, looks up products, and stores a local history. A thin **Express backend**
(`server/`) exists solely to authenticate Google Cloud Vision via OAuth2.

> History: this began as a Flutter app. It has been fully rewritten as a PWA and the Flutter
> project (and Tesseract OCR) have been removed. The React app now lives at the repo root.

## Commands

```sh
npm install
npm run dev          # Vite dev server (http://localhost:5173)
npm run server       # Express Google Vision proxy (http://localhost:8787)
npm run dev:all      # both together (Vite proxies /api → 8787)
npm run test         # Vitest unit tests
npm run typecheck    # tsc for app (tsconfig.json) + server (server/tsconfig.json)
npm run build        # production build → dist/
```

## Architecture

### OCR engines (`src/engines/`)

`OcrEngine` (`ocrEngine.ts`) is the shared interface: `id`, `label`, `isReady()`,
`recognizeText(imageDataUrl)`. Engines are registered in `index.ts` (`ENGINES`, `ENGINE_LIST`).

- **`claudeEngine.ts`** — Claude vision, **browser BYO-key** (`x-api-key`, direct to Anthropic).
  Model `claude-opus-4-8`. `callClaudeVision(image, prompt)` is the shared low-level call.
- **`googleVisionEngine.ts`** — POSTs the base64 image to **`/api/vision`** (the Express backend).
  The backend authenticates with an OAuth2 service account — Google's Vision API does **not**
  accept API-key auth, which is the whole reason the backend exists. No per-user Google key.
- **`barcode.ts`** — ZXing still-image + live-camera decode.

### Capture flow (`src/features/capture/CaptureScreen.tsx`)

`process(imageDataUrl, inputType)`:
1. `preprocessForVision` (EXIF orientation fix + downscale + mild contrast) — `src/ui/imageUtils.ts`.
2. Decode barcode; if found, best-effort product lookup (`services/productLookup.ts`).
3. **Engine branch:**
   - **Claude** → one structured call `identifyFromImage` (the `IDENTIFY_PROMPT` JSON extractor) →
     demarcated fields directly. **No second manual lookup** (that was the old token-burning path).
   - **Google** → `recognizeText` raw text → heuristic `kvParser`.
4. Store `ActiveScan` in `scanSession` (zustand), navigate to Results.

On Results, the **"Re-scan with Claude"** button is an *optional* refine (re-runs
`identifyFromImage`, existing values win), not a required step.

### Services (`src/services/`)

- **`kvParser.ts`** — pure-Dart-ported heuristic key/value extractor (price, MRP, weight, expiry,
  batch, HSN, serial, quantity; vCard/WiFi/URL QR payloads). Unit-tested.
- **`productLookup.ts`** — `ProductInfo`, `productToKvMap`, barcode lookup (UPCitemdb → Open Food
  Facts), and `identifyFromImage` (Claude structured extraction).
- **`historyRepo.ts`** — Dexie/IndexedDB `ScanRecord` store (`snapit-history`).
- **`csvExport.ts`** — `kvToCsv` (single scan, 2-col) and `historyToCsv` (wide: one row per scan,
  union of all fields as columns) + `downloadCsv`.

### State (`src/store/`)

`zustand`. `settings.ts` persists `claudeKey`, `ocrEngine` (`'claude' | 'google'`), and monthly
usage counters. `scanSession.ts` holds the scan under review (ephemeral).

### Backend (`server/`)

`index.ts` — Express, `POST /api/vision`. `vision.ts` — `google-auth-library` `GoogleAuth`
(scope `cloud-vision`) → Bearer token → Vision `images:annotate`. Credentials via
`GOOGLE_APPLICATION_CREDENTIALS` (see `.env.example`; `service-account.json` is git-ignored).

## Conventions

- Engine selection is the **only** place that branches on OCR provider — keep provider logic out
  of the rest of the app.
- Do **not** binarize/grayscale images for the vision APIs (hurts Claude/Google accuracy); the
  right cleanup is orientation + resolution + mild contrast.
- Pin package versions from pub/npm at implementation time; don't rely on memory.
