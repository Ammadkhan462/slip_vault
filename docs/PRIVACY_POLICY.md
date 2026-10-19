# Privacy Policy for Slip Vault: Payment Receipts

**Last updated:** October 19, 2026

**Slip Vault: Payment Receipts** ("Slip Vault", "we", "our", or "the app") is built as a privacy-first, offline financial ledger and receipt organizer. Your financial privacy is the cornerstone of our product.

---

## 1. 100% On-Device Data Storage

* **No Cloud Servers:** Slip Vault does not operate cloud storage servers, remote databases, or backend ingestion APIs.
* **On-Device OCR & Processing:** All optical character recognition (OCR) and text parsing are performed entirely on your device using on-device machine learning models.
* **Images & Receipts:** All imported screenshots and receipts remain inside your device's private sandbox application storage directory. They are never uploaded, transmitted, or shared.
* **Database:** All parsed transaction details (amounts, transaction IDs, counterparty names, dates) are saved in a local SQLite database on your device.

---

## 2. Permissions & Data Access

* **Core Flavor (Zero Permissions):** The primary `core` flavor of Slip Vault requires **zero storage permissions**. Images are selected solely via the system Photo Picker or shared directly to Slip Vault using the system Share Sheet.
* **Biometrics:** When Biometric App Lock is enabled, authentication is handled directly by Android's `BiometricPrompt` system framework. The app never accesses, records, or stores your biometric data (fingerprints or facial maps).

---

## 3. Third-Party Services & Advertising

Slip Vault includes integration with trusted third-party SDKs for monetization and app delivery:

### Google AdMob (Free Version Only)
* The free version of the app displays banner or interstitial advertisements provided by Google AdMob to support ongoing development.
* AdMob may collect and process pseudonymous identifiers such as:
  * Google Advertising ID (GAID)
  * IP address (for general country/city level geolocation)
  * App performance diagnostics and crash telemetry
* For more information on how Google manages advertising data, visit [Google Privacy & Terms](https://policies.google.com/technologies/ads).
* Users who purchase **Slip Vault Pro** disable all advertisements.

### Google Play In-App Billing
* All Pro upgrades are processed exclusively by Google Play. We do not process, collect, or store credit card numbers, bank details, or billing addresses.

---

## 4. Data Retention and Deletion

* **Full User Control:** You can delete any receipt or transaction entry at any time directly within the app.
* **Complete Erasure:** Uninstalling the app from your device permanently purges all local SQLite databases, private files, cached images, and settings.
* **Offline Backups:** If you generate an encrypted ZIP backup, it is saved to a folder of your choice on your device or external drive under your complete control.

---

## 5. Children's Privacy

Slip Vault is intended for general audiences and small business operators aged 18 and older. We do not knowingly collect any information from children under the age of 13.

---

## 6. Contact Us

If you have questions or suggestions regarding this Privacy Policy, contact us at:

* **Support Email:** `[CONTACT_EMAIL]`
* **Developer:** Slip Vault Technologies

---

## 7. Public Hosting Instructions (GitHub Pages)

To host this privacy policy at a public URL for your Google Play Console submission:

1. Create a public GitHub repository named `slip-vault-privacy` (or add to your existing user repository).
2. Save this file as `index.md` in the repository root.
3. In GitHub, navigate to **Settings > Pages**.
4. Under **Branch**, select `main` and root (`/`), then click **Save**.
5. Your public URL will be live at: `https://<your-username>.github.io/slip-vault-privacy/`.
6. Paste this URL into Google Play Console under **Policy > App content > Privacy policy**.
