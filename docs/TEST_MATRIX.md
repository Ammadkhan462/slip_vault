# Slip Vault Quality Assurance & Test Matrix

This document defines the formal QA test matrix, automated test coverage, and device-level verification procedures for **Slip Vault: Payment Receipts** (`com.slipvault.app`).

---

## 1. Automated Test Suite Summary

The automated test suite verifies all critical business logic, database integrity, OCR parsers, report exports, and UI components:

| Suite | Category | Files | What It Tests |
|---|---|---|---|
| **Database & FTS5** | Integration | `test/database/database_fts_test.dart` | SQLite schema, triggers (`AFTER INSERT`, `AFTER UPDATE`, `AFTER DELETE`), FTS5 index sync, rank ordering, monthly totals |
| **Parser Fixtures** | Unit | `test/parser_test.dart`, `test/parser/parser_edge_cases_test.dart` | JazzCash, Easypaisa, SadaPay, NayaPay, Raast, Meezan, Alfalah, HBL, UBL slips; counterparty extraction; TID formats; confidence scoring |
| **Cash Flow Totals** | Unit | `test/features/totals_and_filtering_test.dart` | Net cash flow (+/-), paisa minor unit conversions, filter predicates (received, sent, review, other) |
| **Image & Storage** | Unit | `test/image_storage_service_test.dart` | SHA-256 duplicate detection, byte-level image hashing |
| **Backup & Security** | Unit | `test/backup_service_test.dart` | PK zip archive structure, manifest creation, private directory archiving |
| **Export Services** | Unit | `test/report_export_test.dart` | UTF-8 BOM CSV for Excel compatibility, PDF statement layout |
| **Widget UI** | Widget | `test/widgets/vault_screen_test.dart` | Empty state, seeded list rendering, filter tabs, hero cash flow card |
| **Review UI** | Widget | `test/widgets/review_screen_test.dart` | Field pre-fill, confidence percentage dots, interactive correction, save flow |
| **Search UI** | Widget | `test/widgets/search_screen_test.dart` | FTS5 search query reactivity, query clearing, instant filtering |
| **Reports UI** | Widget | `test/widgets/reports_screen_test.dart` | Month selector, net totals, PDF & CSV export action buttons |
| **Paywall UI** | Widget | `test/widgets/paywall_screen_test.dart` | Lifetime Pro value proposition, benefits list, one-time purchase button |
| **End-to-End Flow**| Integration | `test/integration/slip_vault_flow_test.dart` | 20 batch slip inserts, search across counterparties, totals, and report exports |

---

## 2. Device & OS Compatibility Matrix

| Environment | Target | Verification Checkpoints | Pass Criteria |
|---|---|---|---|
| **Android 7.0 (API 24)** | Minimum supported SDK | Vector drawables, SQLite FTS5 extension initialization, notification channels fallback | App boots without crashing; SQLite triggers run without syntax errors |
| **Android 11 (API 30)** | Scoped storage baseline | Private internal storage directory read/writes, no external storage permissions requested | Images saved to `app_flutter/slips` without `READ_EXTERNAL_STORAGE` permission |
| **Android 14 (API 34)** | Modern Android Photo Picker | Android 14 Selected Photos Access (`READ_MEDIA_VISUAL_USER_SELECTED`), Photo Picker sheet | Photo Picker launches in zero-permission mode; shares work via `ACTION_SEND` |
| **Android 15 (API 35)** | Edge-to-edge default | 16 KB page size compatibility, edge-to-edge window insets, system gesture navigation | Insets properly handled with `SafeArea`; no overlapping system bars |
| **Low-RAM (2GB - 3GB)** | Memory constrained | Multi-image batch import (10 slips at once), image downscaling (1600px long edge, JPEG 85) | Heap memory remains under 128 MB; no OOM (Out Of Memory) crashes during OCR |

---

## 3. UI, Accessibility & Localization Matrix

### 3.1 Urdu RTL & Arabic Typography
- **Locale:** `ur_PK`
- **Directionality:** Complete Right-to-Left (`TextDirection.rtl`)
- **Font Rendering:** Clear legibility for Urdu Nastaliq / Naskh glyphs; correct alignment for amounts and currency labels.
- **Form Layouts:** Input fields, icons, chevron controls properly mirrored.

### 3.2 Dark & Light Theme Contrast
- **WCAG 2.1 AA Compliance:** Minimum 4.5:1 contrast ratio for all body text, amounts, and badges.
- **Card Backgrounds:** High-contrast elevation styling in both light (`#F9F9FB`) and dark (`#111318`).
- **Status Colors:**
  - Positive Cash Flow (Received): `#006C4C` (Light) / `#66DBA4` (Dark)
  - Negative Cash Flow (Sent): `#BA1A1A` (Light) / `#FFB4AB` (Dark)

### 3.3 Accessibility (Font Scaling 1.3x - 1.5x)
- **Checkpoints:**
  - No text clipped inside filter chips or month selectors.
  - Buttons expand gracefully with `IntrinsicHeight` or wrap text.
  - Scrollviews enable full vertical access on compact screens (e.g. 4.7" displays).

---

## 4. Hardware & Offline Hardening

1. **100% Airplane Mode:**
   - Turn off Wi-Fi and Cellular data.
   - Import payment slips.
   - Full OCR, parsing, database search, and PDF exports must execute with zero network requests.
2. **First-Run ML Kit Model Download:**
   - On first install, Google Play services handles the ML Kit OCR model.
   - If model is provisioning, the app displays user-friendly progress and allows retrying without crashing.
3. **App Lifecycle & Background Kill:**
   - Minimize the app during a batch import.
   - Restore the app; verify state is preserved or gracefully resumed without corrupting the database.

---

## 5. Performance Benchmarks

- **Scroll Jank:** 60 fps / 120 fps butter-smooth list scrolling with 500+ records in the Vault.
- **Search Latency:** Full-text search (FTS5) returns ranked results in `< 100 ms` for 500+ records.
- **Storage Footprint:** Clean downscaling guarantees slips occupy `< 350 KB` per slip, allowing 1,000 slips in `< 350 MB`.
