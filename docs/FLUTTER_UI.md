# Task 4 — Flutter core UI

The client is in [triage/triage_flutter](../triage/triage_flutter/lib/main.dart), part of the `triage` Dart workspace. Primary verified platform: Flutter Web, matching the spike. Flutter 3.47.6 / Dart 3.13.5; Serverpod client, Flutter integration, and official auth core are pinned to 4.0.4.

## Implementation

- Custom Linear/Raycast-style inbox, authentication, and bordered detail editor. No default app bar, floating action button, navigation drawer, or Material color theme.
- ChangeNotifier controller with explicit idle → preparing → recording → processing → confirmation/review → saving states. Recording is tap-to-toggle, limited to 30 seconds, with elapsed time, pulsing dot, and twelve microphone frequency bands.
- Uses the canonical Needle/Whistle worker from `spike/web`, not a mock inference service. Models are loaded lazily on first capture. Typed capture uses the same engine and falls back to manual review if unavailable.
- Imports `package:triage_spike/core/date_resolver.dart` through a path dependency; no parser copy. Relative dates use the capture reference clock; payload dates are UTC. Date-only defaults (09:00) explicitly require review.
- Three-second animated auto-save only for numeric confidence ≥0.1, recognized/schema-valid actionable calls, valid required fields, and safe resolved dates. Missing/low confidence, empty calls, suppression, ungrounded arguments, negation, or invalid dates never run a timer. Suppressed candidates are never promoted. Native multi-calls remain separate drafts with one countdown per item; no comma/conjunction splitting.
- Edit, Cancel, backgrounding, and opening an item editor stop the countdown. Save Now cannot double-submit with the timer. Recovered local drafts always open in review. Recording stops when the app becomes inactive.
- Category filters/counts, child-loaded dates, tags, priority, completion checkboxes, swipe-right completion, swipe-left deletion, and keyboard-accessible item-action menus. Counts describe loaded items; Load more fetches subsequent 100-row pages.
- Detail editor saves title/body/priority/date/tags through the secure update endpoint. Unchanged dates preserve seconds/microseconds and existing fired-reminder times. Dirty edits prompt before discard.

## Theme tokens

Source: [ui/theme.dart](../triage/triage_flutter/lib/ui/theme.dart). Durable intent and token mapping are under `triage_flutter/.ui-craft`.

| Role | Value |
| --- | --- |
| Canvas / raised surface / border | `#0B0F17` / `#121824` / `#1E2638` |
| Primary / secondary / dim text | `#F1F5F9` / `#94A3B8` / `#64748B` |
| Task foreground / tint | `#3B82F6` / `#1E293B` |
| Note foreground / tint | `#10B981` / `#132E27` |
| Reminder foreground / tint | `#F59E0B` / `#2A1B0E` |
| Shopping foreground / tint | `#8B5CF6` / `#1E1638` |
| Idea foreground / tint | `#EAB308` / `#2B1F08` |
| Recording / error | `#EF4444` |

Inter and monochrome Noto Emoji are bundled with their OFL licenses; no runtime Google Fonts request. Category emoji are deterministic defaults, not Desert Ant enrichment. Controls use consistent built-in outline icons. Inputs/buttons radius 6, cards 10, modals 14, capsule/chips pill-shaped; borders 1 logical px. Two-layer shadows are reserved for floating capture surfaces. Counts and timers use tabular figures.

Motion is tween-based: 120ms feedback, 200ms filtering/exit, 280ms capture/card entrance, easeOutCubic. Reduced motion removes spatial/pulse animation while retaining state/countdown information. Forms and capture cards scroll with a phone keyboard open. App/header chrome is intentionally subordinate to the queue and capture action; no charts or fabricated metrics were added.

## Auth, backend, and persistence

Custom forms call the generated `client.emailIdp`: login; start/verify/finish registration; and password reset. Official `FlutterAuthSessionManager` stores tokens, restores and validates sessions at startup, refreshes credentials, and reacts through `authInfoListenable`. Passwords and verification codes are not cached. See [official auth setup](https://docs.serverpod.dev/concepts/authentication/setup).

The repository uses generated inbox CRUD and `sync.streamInbox()`. Stream events reconcile with the initial snapshot and are checked against the current owner. Refresh reconnects a failed stream. Added `inbox.updateItem` permits only requested edit fields, verifies ownership, and transactionally replaces reminder queue work when rescheduled. No model changes or new migration were necessary. Creation includes an optional `expectedUserId` concurrency precondition: it rejects a switched account but never determines stored ownership. [Backend contract](SERVERPOD_SETUP.md).

Raw transcripts and pending drafts are **device-only, account-namespaced SharedPreferences storage**. Another device shows “not available on this device” for the raw transcript. Logout retains that account's drafts but does not expose them to another account. Failed/unconfirmed creation keeps the draft and requires checking the inbox before retry; there is no blind replay that could duplicate a committed request.

Privacy boundary: `originalTranscript` is never an endpoint argument. After Needle extraction, Task 5 invokes the official Desert Ant Redact SDK on transcript/title/body/tags before showing confirmation or sending a payload. Browser uses `@desert-ant-labs/redact` 3.6.0 with LiteRT.js; Android uses `ai.desertant:redact:3.6.0`. A deterministic regex/Luhn pass adds defense in depth. If SDK redaction fails, nothing is sent. The model is not a guarantee that all PII is detected. Local drafts/raw text remain plaintext SharedPreferences; production web deployment should configure Serverpod HttpOnly cookie auth. `TRIAGE_COOKIE_AUTH=true` requires matching server cookie/CORS configuration.

Task 5 also schedules and reconciles Android/iOS local reminder alerts from saved/synced reminder rows, alongside the server future call. Web scheduled delivery is unsupported by the selected notification plugin. Web Redact weights (24.5 MB) download and cache on first use; Android includes the model through its Maven dependency (API 24+). See the [phone demo guide](PHONE_DEMO_GUIDE.md) for setup and platform boundaries.

## Run

From the repository root, with Flutter on PATH:

```powershell
./triage/triage_flutter/tool/prepare_web.ps1 -DownloadModels
cd triage/triage_flutter
flutter pub get
flutter run -d chrome --dart-define=SERVER_URL=http://localhost:8080/
```

Start the development backend yourself using the instructions in `SERVERPOD_SETUP.md`. Development email verification codes appear in its logs. This task did not start a standalone backend or send real verification emails.

For a clearly labeled local demo with no backend writes:

```powershell
flutter run -d chrome --dart-define=TRIAGE_DEMO=true
```

Models are ~52.25 MB uncompressed, plus WASM/renderer/fonts. First capture includes model initialization; subsequent inference runs locally. Web microphone requires HTTPS or localhost. `prepare_web.ps1` prepares the browser bundle and Android APK's local WebView worker/model assets. The Android voice path uses the `record` PCM16 stream and a local asset-origin WebView; it does not use Needle FFI. Physical Android permission/microphone/inference verification remains a handset check.

For self-contained web rendering:

```powershell
./tool/build_web.ps1
flutter analyze
flutter test
```

The checkout has Flutter under `.spike-cache/flutter`; prepend its `bin` and Dart `bin` to PATH and set `PUB_CACHE` to `.spike-cache/pub` for workspace commands if using that installation. On Windows, custom web `--output` paths should be absolute: the SDK shader compiler failed with a relative output path during verification.

## Verification

- **46 client tests passed** across auth, UI, and Android PCM buffer suites, including sanitizer coverage, voice-result-to-redacted-write, fail-closed redaction, reminder scheduling/cancellation, active client sync, and PCM sample alignment/30-second bounds.
- **41 backend integration tests passed**, including session-switch rejection, secure edits, ownership isolation, and reminder rescheduling. Real isolated PostgreSQL; no user database changed.
- **Six Node bridge tests passed**, including local metering and microphone cancellation without inference.
- Flutter analyzer: **no issues**; backend analyzer: **no issues**.
- Flutter Web build and Android debug APK build both completed successfully after adding the notification plugin's required Android desugaring configuration. The current Android build includes the official Redact SDK and API 24 minimum.
- Android release APK built with `flutter build apk --dart-define=TRIAGE_DEMO=true`; the 226.9 MB artifact contains both `.cact` models, `needle.wasm`, worker scripts, and tools. Android `RECORD_AUDIO` permission is in the merged manifest. A local Chromium smoke of the bundled Android bridge transcribed the dentist WAV and routed it to `add_reminder`. No physical Android device was attached, so runtime permission prompt and live microphone recording remain manual acceptance checks.
- Built-web browser check passed in Chrome 131 with actual WASM inference and a synthetic test microphone: desktop/390px/320px feed, recording, confirmation, Edit pause, Save Now, local raw storage, offline inference, and suppressed shopping review. No external font/CDN requests or browser errors. [Evidence](ui/browser-check.json).
- Production-auth desktop/320px signup visual check also passed without contacting a backend. [Evidence](ui/auth-check.json), [login](ui/auth-desktop.png), [phone signup](ui/auth-mobile.png).
- Original spike/resolver regression suite: **166/166 passed**.

Screenshots: [desktop inbox](ui/inbox-desktop.png), [phone inbox](ui/inbox-mobile.png), [confirmation](ui/voice-confirmation.png), [review](ui/voice-review.png), [suppressed result](ui/voice-suppressed.png). Browser saves used the labeled demo repository, not a live backend. Auth transport tests use the actual generated client with a controlled HTTP transport; real email delivery and two-device network synchronization still require the running development backend.

Remaining platform work: integrate and validate the official Desert Ant model if available, harden/encrypt local storage, implement native audio-to-Needle inference, recurring notifications, and reliable offline write idempotency.
