# Barcode / QR / Tag Scanner App — Implementation Plan

## Context

The user wants a **single-codebase, multi-platform app (Windows + Android + iOS)** that:
- Scans/imports an image of a product (live camera, gallery pick, or drag-drop/file insert)
- Reads **barcodes, QR codes, and tags** and runs **OCR** on product labels
- Displays the result as clean **key-value pairs** (e.g. `Price: $5`, `Weight: 200g`, `Expiry: 2026-01`)
- Looks up product info online from a barcode when available

**Decided requirements (from clarifying Q&A):**
- **Framework:** Flutter (single Dart codebase for all 3 platforms)
- **AI/OCR engine:** On-device, offline-first (no cloud AI in MVP)
- **Outputs:** Raw OCR fields + Barcode product lookup + decoded QR/Tag content
- **KV extraction:** Heuristic rule-based parser (offline, editable results)
- **Product DB:** Open Food Facts (free, no API key)
- **Input modes:** Live camera, gallery pick, drag-drop/file insert
- **MVP scope:** Local-only — no accounts/backend; scan history saved locally on device

## Critical architectural constraint (must read)

`mobile_scanner` and all `google_mlkit_*` packages **support only Android/iOS (+ macOS)** — **NOT Windows** (verified via package docs). To honor "one codebase across Windows + Android + iOS", the scanning/OCR logic is hidden behind a **platform-abstraction interface** with two concrete engines. All UI and business logic stay 100% shared; only the engine implementation differs per platform.

```
abstract class ScanEngine {
  Future<BarcodeResult?> scanBarcode(InputImage img);   // barcode/QR payload + format
  Future<String> recognizeText(InputImage img);          // raw OCR text
  bool get supportsLiveCamera;
}
```
- **MobileScanEngine** (Android/iOS): `mobile_scanner` (live camera barcode/QR) + `google_mlkit_text_recognition` (OCR). On-device, free, fast.
- **DesktopScanEngine** (Windows): `flutter_zxing` (barcode/QR decode from a still image) + a Tesseract-based OCR path (`tesseract_ocr` / FFI, bundle `eng` traineddata). Windows MVP relies on **image import + drag-drop** rather than live camera (live desktop camera scanning is a stretch goal).

Engine is selected at startup via `Platform.isWindows` and injected through a provider so the rest of the app never branches on platform.

## Tech stack & key packages

| Concern | Package | Platforms |
|---|---|---|
| State mgmt | `flutter_riverpod` | all |
| Live camera barcode/QR | `mobile_scanner` | Android/iOS |
| On-device OCR | `google_mlkit_text_recognition` | Android/iOS |
| Desktop barcode/QR | `flutter_zxing` | Windows |
| Desktop OCR | `tesseract_ocr` (FFI) + bundled traineddata | Windows |
| Gallery pick | `image_picker` | all |
| Drag & drop / file insert | `desktop_drop` + `file_selector` | Windows (+ all) |
| Product lookup | `openfoodfacts` (Dart) over `http` | all (online) |
| Local history storage | `drift` (or `sqflite` + `sqflite_common_ffi` for Windows) | all |
| Routing | `go_router` | all |

> Versions to be pinned via Context7 / `pub.dev` at implementation time (do not hardcode from memory).

## Project structure

```
lib/
  main.dart                      # bootstrap, engine selection, provider scope
  core/
    scan_engine.dart             # abstract ScanEngine + result models
    engines/
      mobile_scan_engine.dart    # ML Kit + mobile_scanner
      desktop_scan_engine.dart   # flutter_zxing + tesseract
  features/
    capture/                     # camera / gallery / drag-drop UI + controllers
    results/                     # key-value display, edit, copy/share
    history/                     # saved scans list + detail
  services/
    kv_parser.dart               # heuristic key-value extractor
    product_lookup.dart          # Open Food Facts client + caching
    history_repository.dart      # drift DAO
  ui/                            # shared widgets, theme, design tokens
```

## Heuristic KV parser (`services/kv_parser.dart`)

Pure-Dart, testable, offline. Pipeline:
1. Normalize OCR text → lines, trim noise.
2. **Explicit pairs:** split lines containing `:` or `=` into key/value.
3. **Pattern matchers** (regex) for unlabeled values: price (`$`/currency), weight/volume (`g`, `kg`, `ml`, `L`), dates/expiry (`MFG`/`EXP`/`Best before`), quantity, batch/lot, barcode digits.
4. **Decoded payloads:** QR/tag content classified (URL, vCard, plain text, WiFi) → typed key-values.
5. Merge with Open Food Facts product fields when a barcode resolved.
6. Output an ordered, **user-editable** `List<KeyValue>` shown in the results screen.

Heavily unit-tested with sample label strings (TDD for the parser).

## Build order (milestones)

1. **Scaffold:** `flutter create` with `--platforms=windows,android,ios`, add deps, set up Riverpod + go_router + theme. Verify empty app runs on Windows + an Android emulator.
2. **Engine abstraction:** define `ScanEngine` + result models; wire platform selection + provider.
3. **Mobile engine:** live camera barcode/QR via `mobile_scanner`; ML Kit OCR; gallery pick.
4. **Results + KV parser:** build heuristic parser (TDD) and the editable key-value results screen (with copy/share).
5. **Product lookup:** Open Food Facts integration + on-device cache; merge into results.
6. **History:** drift schema + save/list/detail; delete & re-open.
7. **Desktop engine (Windows):** `flutter_zxing` decode + Tesseract OCR; `desktop_drop` + `file_selector` import flow.
8. **Polish:** permissions handling, empty/loading/error states, responsive layout (mobile vs desktop), accessibility, app icons.

## Platform setup notes

- **Android:** camera permission in `AndroidManifest.xml`; ML Kit barcode model dependency; minSdk per `mobile_scanner` (API 21+).
- **iOS:** `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` in `Info.plist`; min iOS 12.
- **Windows:** enable desktop in Flutter; bundle Tesseract `eng.traineddata` as an asset and ship the native lib; `sqflite_common_ffi` init for drift on desktop.

## Verification

- **Unit tests:** `kv_parser` against a fixture set of real-world label texts (prices, weights, dates, QR payloads); `product_lookup` with mocked Open Food Facts responses.
- **Manual E2E per platform:**
  - Android/iOS: live-scan a real barcode → product info shown; photograph a label → KV pairs extracted; pick from gallery.
  - Windows: drag-drop a product photo → barcode decoded + OCR KV pairs; file-insert flow.
- **History:** save a scan, reopen app, confirm it persists; delete works.
- **Run commands:** `flutter test`, `flutter run -d windows`, `flutter run -d <android-device>`, `flutter run -d <ios-device>`.

## Out of scope (MVP) / future

- User accounts, cloud sync, shared DB.
- Optional **cloud AI "Smart extract"** fallback for messy labels (Claude vision) — clean add-on later behind the same results screen.
- Live camera scanning on Windows desktop.
- Non-food product databases (UPCitemdb/paid) beyond Open Food Facts.
