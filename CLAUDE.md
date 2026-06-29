# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Flutter single-codebase multi-platform barcode/QR/OCR scanner app targeting **Windows + Android + iOS**. Scans product images, decodes barcodes/QR codes, runs OCR, extracts key-value pairs from labels, and looks up product info via Open Food Facts.

The full implementation plan is in [i-want-to-create-refactored-ember.md](i-want-to-create-refactored-ember.md).

## Commands

```sh
# Run on target platforms
flutter run -d windows
flutter run -d <android-device-id>
flutter run -d <ios-device-id>

# Tests
flutter test                          # all unit tests
flutter test test/services/kv_parser_test.dart  # single test file

# Build
flutter build apk
flutter build windows
flutter build ios

# Check dependencies
flutter pub get
flutter pub outdated
```

## Architecture

### Platform Abstraction (critical constraint)

`mobile_scanner` and all `google_mlkit_*` packages **do not support Windows**. The entire scanning/OCR path is hidden behind a `ScanEngine` abstract interface in `lib/core/scan_engine.dart`:

```dart
abstract class ScanEngine {
  Future<BarcodeResult?> scanBarcode(InputImage img);
  Future<String> recognizeText(InputImage img);
  bool get supportsLiveCamera;
}
```

Two concrete implementations:
- **`MobileScanEngine`** (`lib/core/engines/mobile_scan_engine.dart`) — Android/iOS only. Uses `mobile_scanner` (live camera) + `google_mlkit_text_recognition` (OCR).
- **`DesktopScanEngine`** (`lib/core/engines/desktop_scan_engine.dart`) — Windows only. Uses `flutter_zxing` (barcode/QR from still image) + `tesseract_ocr` FFI (OCR, requires bundled `eng.traineddata`).

Engine is selected at startup via `Platform.isWindows` and injected via Riverpod. **No platform branching anywhere else in the app.**

### State Management

`flutter_riverpod` throughout. Providers live close to their feature. The scan engine is a top-level provider injected in `main.dart`.

### Project Structure

```
lib/
  main.dart                       # bootstrap, engine selection, ProviderScope
  core/
    scan_engine.dart              # abstract ScanEngine + BarcodeResult + InputImage models
    engines/
      mobile_scan_engine.dart
      desktop_scan_engine.dart
  features/
    capture/                      # camera / gallery / drag-drop UI + controllers
    results/                      # editable key-value display, copy/share
    history/                      # saved scans list + detail view
  services/
    kv_parser.dart                # heuristic KV extractor (pure Dart, offline)
    product_lookup.dart           # Open Food Facts client + on-device cache
    history_repository.dart       # drift DAO
  ui/                             # shared widgets, theme, design tokens
```

### KV Parser (`lib/services/kv_parser.dart`)

Pure-Dart offline pipeline — must be heavily unit-tested (TDD):
1. Normalize OCR text → trimmed lines
2. Split lines with `:` or `=` into explicit key/value pairs
3. Regex matchers for unlabeled values: price, weight/volume, dates/expiry, quantity, batch/lot, raw barcode digits
4. Classify QR payloads (URL, vCard, WiFi, plain text) → typed key-values
5. Merge with Open Food Facts fields when a barcode resolved
6. Output `List<KeyValue>` (ordered, user-editable)

### Storage

`drift` ORM (with `sqflite_common_ffi` init on Windows) for local scan history.

### Routing

`go_router` for navigation between Capture → Results → History screens.

## Key Package Constraints

- `mobile_scanner` + `google_mlkit_text_recognition`: Android/iOS/macOS only
- `flutter_zxing`: Windows (and others) for still-image barcode decode
- `tesseract_ocr`: Windows — requires bundling `eng.traineddata` as asset and shipping the native lib
- `desktop_drop` + `file_selector`: Windows drag-and-drop / file import
- `sqflite_common_ffi`: required for drift on Windows (desktop FFI init before app starts)

Always pin package versions from `pub.dev` at implementation time — do not rely on memory for version numbers.

## Platform Setup Requirements

- **Android:** `AndroidManifest.xml` camera permission; ML Kit barcode model dependency; `minSdk` per `mobile_scanner` (API 21+)
- **iOS:** `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` in `Info.plist`; min iOS 12
- **Windows:** Flutter desktop enabled; Tesseract `eng.traineddata` bundled as asset; `sqflite_common_ffi` initialized before `runApp`

## Build Milestones (order matters)

1. Scaffold — `flutter create --platforms=windows,android,ios`, deps, Riverpod + go_router + theme
2. Engine abstraction — `ScanEngine` interface + models + platform-selected provider
3. Mobile engine — live camera barcode/QR + ML Kit OCR + gallery pick
4. Results + KV parser — TDD parser + editable results screen
5. Product lookup — Open Food Facts + cache + merge into results
6. History — drift schema + CRUD
7. Desktop engine — `flutter_zxing` + Tesseract + `desktop_drop`/`file_selector`
8. Polish — permissions, error/loading/empty states, responsive layout, accessibility, app icons
