# Handoff: Scan OCR Fields + AI Lookup + CSV Export Features

## Session Metadata
- Created: 2026-06-30 12:05:29
- Project: D:\BarcodeScannerApp
- Branch: master
- Session duration: ~1 session (plan + full implementation + tests)

### Recent Commits (for context)
  - 9e50ece Add app icons, Windows OCR, and window size polish
  - 399877a Polish: window title, brand subtitle in history tiles
  - b127dee Add user-friendly error snackbars for scan failures
  - 096f2e4 Initial Flutter scaffold + full MVP implementation

> NOTE: This session's work is NOT yet committed. All changes are in the working tree.

## Handoff Chain

- **Continues from**: [2026-06-30-003305-barcode-scanner-app-initial-build.md](./2026-06-30-003305-barcode-scanner-app-initial-build.md)
  - Previous title: BarcodeScannerApp Initial Build — Flutter Multi-Platform Scanner
- **Supersedes**: None

> Review the previous handoff for full context before filling this one.

## Current State Summary

Implemented three requested feature enhancements on top of the existing MVP. Crucial framing: the
codebase was already ~90% complete — these were **gap-closing** changes, not greenfield builds.
All three features are implemented, `flutter analyze lib test` is clean ("No issues found"), and
**all 29 unit tests pass** (25 existing/extended + 4 new CSV tests). Work is **uncommitted**. The
only remaining task is **manual UI verification on a real Windows run** — the logic layer is green
but on-screen flows (AI button, save dialog) have not been exercised live.

## Codebase Understanding

### Architecture Overview

- Flutter multi-platform (Windows + Android + iOS), single codebase.
- Platform abstraction via `ScanEngine` interface (`lib/core/scan_engine.dart`) with two impls:
  `MobileScanEngine` (ML Kit) and `DesktopScanEngine` (flutter_zxing + flutter_ocr_native/Tesseract).
  Engine selected at startup, injected via Riverpod. No platform branching elsewhere.
- State: `flutter_riverpod`. Routing: `go_router` (routes incl. `/capture`, `/results`, `/history`,
  `/history/:id`, `/settings`).
- Pipeline: image → `engine.scanBarcode` + `engine.recognizeText` → `KvParser.parse(ocrText,
  barcode, productFields)` → `ProductLookup` (UPCitemdb/OpenFoodFacts, + optional Claude Vision)
  → `ResultsPage` → `HistoryRepository` (drift/SQLite).

### Critical Files

| File | Purpose | Relevance |
|------|---------|-----------|
| lib/services/kv_parser.dart | Heuristic OCR→KV extraction | Feature 1: added MRP/Qty/HSN/Serial |
| lib/services/product_lookup.dart | Product lookup + Claude Vision | Feature 2: full-label prompt + AiLookupException |
| lib/features/capture/capture_controller.dart | Pipeline orchestrator | Feature 2: lookupWithAi() method |
| lib/features/results/results_page.dart | Results display/edit | Feature 2: "Lookup with AI" button + snackbars |
| lib/services/csv_export_service.dart | NEW — real CSV file writer | Feature 3 |
| lib/features/history/history_page.dart | History list + export action | Feature 3: wired real CSV export |
| lib/services/history_repository.dart | drift DAO + ScanRecord model | Read-only; CSV service reuses ScanRecord |

### Key Patterns Discovered

- `KvParser._matchPattern` returns whether it matched (used to suppress overlapping matchers, e.g.
  MRP-line should not also register as Price; Net-Qty-line should not also register as Weight).
- `KvParser.parse` merges `productFields` with first-occurrence-wins dedup (`_hasKey`,
  case-insensitive). Existing values are never overwritten.
- `ProductInfo.toKvMap()` surfaces the `extra` Map<String,String>, so AI-extracted extra label
  fields flow to results automatically.
- Snackbars use `behavior: SnackBarBehavior.floating` consistently; dark theme via `kAccent`.

## Work Completed

### Tasks Finished

- [x] Feature 1: MRP/Quantity/HSN/Serial regexes + key aliases + 10 new tests in kv_parser
- [x] Feature 2: Claude Vision full-label extraction, typed `AiLookupException`, manual "Lookup
      with AI" button on Results with spinner/error snackbars + Settings shortcut, non-silent
      auto-fallback
- [x] Feature 3: new `csv_export_service.dart` writing a real .csv (native save dialog desktop /
      Downloads+Share mobile), wired into history_page; added `csv: ^6.0.0`; 4 new tests
- [x] `flutter analyze lib test` clean; `flutter test` all 29 pass; `flutter pub get` done

### Files Modified

| File | Changes | Rationale |
|------|---------|-----------|
| lib/services/kv_parser.dart | Added _mrpRe/_qtyRe/_hsnRe/_serialRe, wired into _parseOcrText with match-suppression guards, _matchPattern now returns bool, extended _keyAliases | Extract MRP/Qty/HSN/Serial the user named |
| lib/services/product_lookup.dart | Added AiLookupException; rewrote lookupByImage with fuller JSON prompt, extra-field mapping, typed errors (401/429/network/parse) | Make "Lookup with AI" functional + diagnosable |
| lib/features/capture/capture_controller.dart | Added lookupWithAi(imagePath, existing); _run() now surfaces AiLookupException as lookupNote | On-demand AI + non-silent fallback |
| lib/features/results/results_page.dart | Added _aiLoading state, _lookupWithAi handler, _AiLookupButton widget, imports | Manual AI button + error UX |
| lib/services/csv_export_service.dart | NEW file: buildCsv() + exportToFile() | Real .csv to disk |
| lib/features/history/history_page.dart | Replaced hand-rolled _export/_csv with CsvExportService; tooltip "Export CSV"; dropped services.dart import | Wire real CSV export |
| pubspec.yaml | Added `csv: ^6.0.0` | CSV library |
| test/services/kv_parser_test.dart | +10 tests (MRP/Qty/HSN/Serial/aliases/guards) | Lock new parser behavior |
| test/services/product_lookup_test.dart | Updated no-key vision test to expect throwsA(AiLookupException, needsKey:true) | Contract changed null→throw |
| test/services/csv_export_service_test.dart | NEW: 4 tests (header, kv flatten, comma escaping, null fields) | Cover new service |

### Decisions Made

| Decision | Options Considered | Rationale |
|----------|-------------------|-----------|
| AI lookup throws typed exception vs returns null | keep silent null / throw | User explicitly wanted errors surfaced; null hid all failures |
| MRP matcher runs before Price and suppresses it on same line | independent matchers / ordered+guarded | Prevent MRP value double-registering as generic Price |
| CSV via `csv` package + file_selector getSaveLocation | hand-rolled text / csv pkg | User chose "save real .csv file"; proper RFC-4180 + native dialog |
| Live-camera OCR left OUT of scope | include / exclude | User picked "Add MRP+Qty+more", not the live-camera option |

## Pending Work

## Immediate Next Steps

1. **Manual UI verification**: `flutter run -d windows`, then (a) drop a product-tag photo →
   confirm MRP/Quantity/HSN rows appear; (b) tap "Lookup with AI" with NO key → expect snackbar
   with Settings action; add a real Anthropic key in Settings, retry → fields merge; (c) History →
   Export → save a .csv → open in spreadsheet and confirm columns/escaping.
2. **Commit** the work (currently uncommitted). Suggested message scope: "Add OCR MRP/Qty fields,
   manual AI lookup, real CSV export".
3. (Optional) Consider the deferred items below if the user wants broader coverage.

### Blockers/Open Questions

- [ ] None blocking. AI lookup requires the user to supply their own Anthropic API key in Settings
      (stored in SharedPreferences under `anthropic_api_key`).

### Deferred Items

- Live-camera-path OCR (live scans still barcode-only) — explicitly out of selected scope.
- Per-scan CSV export on history_detail_page — out of selected scope ("Save real .csv file" only).

## Context for Resuming Agent

## Important Context

The user's original request sounded like "build three new features" but exploration (3 Explore
agents) revealed the pipeline already worked end-to-end. Do NOT rebuild — the actual gaps were:
(1) parser missing MRP/Qty patterns, (2) AI vision was coded but only fired silently as a barcode
fallback with no manual trigger and swallowed all errors, (3) "export" never wrote a file. All
three gaps are now closed. The plan file is at
`C:\Users\BlackDeath\.claude\plans\new-features-to-add-atomic-liskov.md`.

### Assumptions Made

- file_selector `getSaveLocation(suggestedName:, acceptedTypeGroups:)` → `FileSaveLocation?` with
  `.path` — VERIFIED against installed file_selector 1.1.0 / platform_interface 2.7.0.
- `csv` 6.0.0 `ListToCsvConverter().convert(rows)` API — VERIFIED via pub get resolution + tests.
- Anthropic model id `claude-opus-4-8` (pre-existing in code) is correct.

### Potential Gotchas

- `flutter test`/`flutter analyze` produce NO output via the Bash tool on this Windows setup —
  use the **PowerShell** tool instead (Bash returned empty).
- KvParser matcher ORDER matters: MRP before Price, Quantity before Weight, each guarded by a
  bool return so a single line doesn't register under two keys. Don't reorder casually.
- The no-key path in `_run()` is guarded by `if (await lookup.visionEnabled)`, so the auto-fallback
  never throws the needs-key exception; only the manual button surfaces the Settings prompt.

## Environment State

### Tools/Services Used

- Flutter/Dart toolchain (flutter test, flutter analyze, flutter pub get) — run via PowerShell tool.
- Anthropic Messages API (https://api.anthropic.com/v1/messages) for Claude Vision lookup — used at
  runtime only, key supplied by end user in Settings.

### Active Processes

- None running. No dev server or emulator left open.

### Environment Variables

- None required for build/test. Runtime AI feature reads `anthropic_api_key` from SharedPreferences
  (NOT an env var) — user-supplied, never stored in repo.

## Related Resources

- Plan file: C:\Users\BlackDeath\.claude\plans\new-features-to-add-atomic-liskov.md
- Project guide: D:\BarcodeScannerApp\CLAUDE.md
- Implementation plan doc: D:\BarcodeScannerApp\i-want-to-create-refactored-ember.md

---

**Security Reminder**: Before finalizing, run `validate_handoff.py` to check for accidental secret exposure.
