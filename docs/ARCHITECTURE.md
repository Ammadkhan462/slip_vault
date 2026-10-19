# Slip Vault: Architecture & Technical Specification

## 1. Overview
Slip Vault is an offline-first Android payment ledger and screenshot organizer built with Flutter. It extracts transaction details (amounts, counterparty names, transaction IDs, providers, and dates) from digital payment screenshots (JazzCash, Easypaisa, SadaPay, NayaPay, Raast, etc.) completely on-device without cloud dependency or accounts.

## 2. Layered Architecture

```
lib/
├── core/
│   ├── database/       # Drift SQLite database, schema, FTS5 virtual table & triggers
│   ├── providers/      # Global application state providers (Riverpod)
│   ├── router/         # GoRouter declarative navigation
│   └── theme/          # Design system tokens, color palettes, light & dark themes
├── features/
│   ├── import/         # Photo picker & Android share-target image processing
│   ├── vault/          # Home ledger stream, month selector, cash flow hero card
│   ├── search/         # High-speed FTS5 full-text search over OCR text & fields
│   ├── detail/         # Entry viewer, pinch-zoom, metadata editor, WhatsApp card export
│   ├── export/         # Monthly report generators (PDF & CSV with UTF-8 BOM)
│   ├── paywall/        # Pro lifetime non-consumable unlock
│   ├── settings/       # App lock (biometric), theme, language, backup/restore
│   └── onboarding/     # 3-step privacy-first onboarding flow
└── l10n/               # English (en) and Urdu (ur) ARB localization bundles
```

## 3. Package Justifications
- `flutter_riverpod` (^3.4.3): Type-safe, testable state management without BuildContext coupling.
- `go_router` (^18.1.0): Declarative URL-driven navigation supporting deep links and parameter routing.
- `drift` (^2.35.2): Strongly typed SQLite database abstraction with migrations and reactive streams.
- `sqlite3_flutter_libs` (^0.6.0+eol): Bundles SQLite native engine to ensure FTS5 support on API 24+.
- `path_provider` (^2.1.6): Resolves platform directories for private app storage and exports.
- `path` (^1.9.1): Reliable cross-platform file path manipulation.
- `intl` (^0.20.3): Number formatting, currency display, and date localization.
- `google_mlkit_text_recognition` (^0.17.1): Fast on-device Latin script OCR using Google Play services.
- `image_picker` (^1.2.4): Modern zero-permission Android photo picker (`pickMultiImage`).
- `flutter_image_compress` (^2.5.1): Asynchronous downscaling to max 1600px / JPEG 85 to prevent memory spikes.
- `crypto` (^3.0.7): SHA-256 image hashing for duplicate detection.
- `pdf` (^3.13.1): High-fidelity monthly report PDF generation with tabular figures.
- `csv` (^8.0.0): RFC 4180 compliant CSV export with UTF-8 BOM for Excel compatibility.
- `share_plus` (^13.3.1): System share sheet for WhatsApp card image and report documents.
- `local_auth` (^3.0.2): Biometric (fingerprint/face) and device PIN authentication for Pro app lock.
- `google_mobile_ads` (^9.1.0): Monetization via rewarded ads and adaptive banner with UMP consent.
- `in_app_purchase` (^3.3.1): Google Play Billing client for non-consumable Pro lifetime purchase.
- `in_app_review` (^2.0.12): Native Google Play in-app review prompt triggered at positive moments.

## 4. Data Model
- **`entries`**: Core transaction record storing `id`, `kind`, `imagePath`, `imageHash` (unique), `amountMinor` (paisa integer), `currency`, `direction`, `counterpartyName`, `counterpartyAccountMasked`, `transactionId`, `provider`, `feeMinor`, `occurredAt`, `ocrText`, `note`, `confidenceJson`, `needsReview`, `createdAt`, and `updatedAt`.
- **`tags`** & **`entry_tags`**: User categorization tags in a many-to-many relationship.
- **`entries_fts`**: SQLite FTS5 virtual table indexing `ocr_text`, `counterparty_name`, `transaction_id`, and `note`. Automatically kept in sync via SQLite triggers on INSERT, UPDATE, and DELETE.
- **`app_settings`**: Key-value pair storage for persistent preferences (language, theme mode, review prompt counter).

## 5. Android Product Flavors
1. **`core`**: Default production flavor. No storage or media permissions requested. Uses photo picker and share-target intent filter.
2. **`autoscan`**: Optional future flavor adding `READ_MEDIA_IMAGES` and `READ_MEDIA_VISUAL_USER_SELECTED` for background gallery scanning if Play photo-permission declaration is approved.
