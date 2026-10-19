# Slip Vault Release Engineering & Launch Checklist

This runbook guides you step by step through generating signing keys, building production App Bundles with R8 and symbol obfuscation, completing the 14-day closed testing mandate, passing Google Play reviews, and managing the first 30 days post-launch.

---

## 1. Keystore Generation & Key Properties

### 1.1 Generate Production Upload Keystore
Run the following standard Java `keytool` command in PowerShell / Terminal:

```bash
keytool -genkey -v -keystore c:/dev/inAI/slip_vault/upload-keystore.jks `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload
```

* Answer the prompts for your name, organization, city, and passwords.
* **CRITICAL BACKUP RULE:** Save `upload-keystore.jks` and your passwords to two separate secure locations (e.g., an encrypted USB drive and a 1Password/Bitwarden vault). If you lose this keystore, you cannot update your app unless Google Play App Signing is enabled!

### 1.2 Create `android/key.properties` (Git-Ignored)
Copy `android/key.properties.example` to `android/key.properties` and fill with:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../../upload-keystore.jks
```

* Verify that `android/key.properties` and `upload-keystore.jks` are ignored by git (`git status`).

---

## 2. Production App Bundle Build & Obfuscation

Build the optimized `core` production App Bundle with R8 shrinking and debug symbols:

```bash
flutter build appbundle --flavor core --release --obfuscate --split-debug-info=build/symbols
```

### 2.1 Artifacts Generated
* **AAB Bundle:** `build/app/outputs/bundle/coreRelease/app-core-release.aab`
* **De-obfuscation Symbols:** `build/symbols/app.android-arm64.symbols`, `build/symbols/app.android-x64.symbols`
* **R8 ProGuard Mapping:** `build/app/outputs/mapping/coreRelease/mapping.txt`

In Play Console under **App Bundle Explorer > Downloads**, upload `mapping.txt` and the native symbols ZIP to enable human-readable crash stack traces in Android Vitals.

---

## 3. Permissions Audit & Flavor Selection

### 3.1 `core` Flavor (Recommended Default)
* **Declared Permissions:** **ZERO (`0`)**
* **Storage Access:** None. Imports use the system Photo Picker and Share Target (`ACTION_SEND`, `ACTION_SEND_MULTIPLE`).
* **Play Store Risk:** **Zero**. No sensitive permission declarations or video reviews required.

### 3.2 `autoscan` Flavor (Background Directory Watch)
* **Declared Permissions:** `READ_MEDIA_IMAGES` and `READ_EXTERNAL_STORAGE` (maxSdk 32).
* **When to Use:** ONLY if you release a specialized version that monitors the gallery in the background without user interaction.
* **Core Use Case Justification Draft for Play Console:**
  > "Slip Vault is a specialized payment receipt organizer. The core functionality requires detecting and parsing transfer slips directly as they are saved to the screenshot gallery to maintain real-time offline ledger balances for small business merchants."

---

## 4. 14-Day / 12-Tester Closed Testing Runbook

For personal Google Play accounts registered after November 13, 2023, you must run a closed test with at least 12 testers opted in for 14 continuous days before applying for production access.

### 4.1 Tester Recruitment Message Template
Send this message to friends, colleagues, shop owners, or freelancer groups via WhatsApp or Telegram:

```text
Hey! I've built a free offline Android app called Slip Vault. It automatically reads payment confirmation screenshots (JazzCash, Easypaisa, SadaPay, bank receipts) and keeps your receipts organized so you never lose proof of payment.

Google Play requires 12 people to test the app for 14 days before I can launch it publicly. Could you help me test it?

1. Join the Google Group here: [GOOGLE_GROUP_URL]
2. Download the app from the Play Store test link: [PLAY_STORE_TEST_LINK]
3. Keep it installed on your phone for 2 weeks and try importing a slip or two.

I'd really appreciate your feedback!
```

### 4.2 14-Day Testing Schedule
* **Day 1:** Create Google Group, invite 15–20 testers (ensure at least 12 accept), upload closed testing track AAB, start track.
* **Days 2–4:** Confirm all 12+ testers have opted in. Check Play Console dashboard: "Opted-in testers" must display >= 12.
* **Days 5–7:** Solicit initial feedback on slip parsing accuracy, search responsiveness, and dark mode.
* **Day 8:** Ship at least one update (`version: 1.0.1+2`) with minor UI polish or parser tweaks to prove active maintenance.
* **Days 9–13:** Monitor Android Vitals. Confirm crash rate = 0% and ANR rate = 0%.
* **Day 14:** The 14-day timer completes! The **Apply for Production** button becomes active.

---

## 5. Production Access Application Answers

When submitting your production access application in Play Console, use these honest, compliant answers:

1. **How did you recruit testers?**
   > "Testers were recruited from a network of small shopkeepers, freelance service providers, and colleagues who regularly handle peer-to-peer and bank payment screenshots in Pakistan."
2. **What feedback did you collect during closed testing?**
   > "Testers provided feedback on OCR text extraction speed across different mobile wallet slip designs (JazzCash, Easypaisa, SadaPay), requested clearer confidence indicators on parsed amounts, and verified that Excel CSV exports properly opened Urdu text without character corruption."
3. **What changes did you make based on feedback?**
   > "We released an update during testing that improved counterparty name extraction for business titles containing hyphens and dots, fine-tuned the OCR confidence threshold, and enhanced contrast for AMOLED dark mode."
4. **Why is your app ready for production?**
   > "The app has completed 14 days of testing with zero crash reports, zero ANRs, and positive user feedback confirming smooth offline performance and zero battery drain."

---

## 6. Staged Rollout & Android Vitals Thresholds

When production access is approved, launch with a staged rollout:
* **Stage 1 (Day 1–3):** 20% rollout. Monitor Android Vitals daily.
* **Stage 2 (Day 4–6):** 50% rollout if crash rate < 0.20%.
* **Stage 3 (Day 7):** 100% full release.

### Vitals Health Gates (Google Bad Thresholds):
* **User-perceived crash rate:** Must stay strictly below **1.09%** (Slip Vault target: `< 0.20%`).
* **User-perceived ANR rate:** Must stay strictly below **0.47%** (Slip Vault target: `< 0.05%`).
* **Rollback Action:** If crash rate exceeds 0.50%, halt staged rollout immediately in Play Console.

---

## 7. First 30 Days Post-Launch Playbook

1. **ASO Experiment (Week 2):** In Play Console > Store presence > Store listing experiments, run an A/B test on:
   - Variant A: Current Icon with Navy / Gold Vault dial.
   - Variant B: High-contrast Green / White Receipt icon.
2. **Review Response Template:**
   - *Positive review:* "Thank you for the review! We're committed to keeping Slip Vault 100% offline and private."
   - *Issue / OCR miss review:* "Thanks for your feedback! Slip formats change frequently—please share the wallet name or layout with us at [CONTACT_EMAIL] so we can update the parser in the next weekly update."
