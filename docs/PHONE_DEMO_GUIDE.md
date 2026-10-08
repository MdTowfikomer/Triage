# Triage phone and live-sync demo

The native Android APK now records microphone audio as bounded 16 kHz mono PCM and runs the same pinned Needle/Whistle WASM worker and models in a hidden local WebView. It uses the system WebView's WebAssembly engine rather than a custom native Needle/FFI build. The browser route remains available for laptop Chrome and Android Chrome; the APK also schedules native reminders. Physical-device permission/audio behavior still needs confirmation on the target handset before filming.

## 1. Prepare the PC

Install Flutter 3.38.1 or newer, Android platform tools (`adb`), and Docker Desktop. From the repository root, resolve workspace packages and prepare the pinned local inference assets:

```powershell
$env:PUB_CACHE = "$PWD/.spike-cache/pub"
$env:PATH = "$PWD/.spike-cache/flutter/bin;$PWD/.spike-cache/flutter/bin/cache/dart-sdk/bin;$PWD/.spike-cache/pub/bin;$env:PATH"
flutter pub get
./triage/triage_flutter/tool/prepare_web.ps1 -DownloadModels
```

The first setup downloads about 52 MB of Needle/Whistle model weights, plus the Flutter web build assets. The first privacy check in a browser downloads the pinned Desert Ant Redact model (about 24.5 MB) from its model host and caches it on device; transcript text is processed locally and is never part of that download. The first browser capture can take longer while these models load and Needle prepares its prefix. In this environment, the browser smoke test successfully initialized LiteRT but the Hugging Face model listing request returned HTTP 405; therefore model download/runtime masking in the browser still needs validation on a network that permits that host/API. Redaction fails closed, so saves remain blocked if it cannot initialize.

Find the PC's Wi-Fi IPv4 address with `ipconfig` (look under the connected Wireless LAN adapter; ignore VPN, Docker, and disconnected adapters). Keep the phone and PC on the same trusted network.

## 2. Start the development database and Serverpod

In a separate PowerShell terminal:

```powershell
cd triage/triage_server
./tool/init_secrets.ps1
cd ..
$env:SERVERPOD_API_SERVER_PUBLIC_HOST = "<PC_WIFI_IPV4>"
serverpod start
```

`serverpod start` starts the configured development PostgreSQL service and API using the workspace's development setup. Leave this terminal open. It applies pending migrations on startup. Serverpod 4.0.4 binds the API to an IPv6 wildcard socket (`::`, dual-stack for IPv4 clients), so the listener accepts connections on network interfaces; `apiServer.publicHost` advertises the address and is set above for the phone. The checked-in development config still defaults to `localhost` for laptop-only use.

If Windows Firewall prompts, allow the development server only on the trusted Private network. Do not expose the development server directly to the public internet. Check that the server reports port 8080 before continuing.

## 3. Live microphone on the Android APK

Prepare the pinned engine bundle once from the repository root (this also prepares the Web harness and bundled Redact assets):

```powershell
./triage/triage_flutter/tool/prepare_web.ps1 -DownloadModels
```

From `triage/triage_flutter`, build and install a backend-free demo APK:

```powershell
flutter pub get
flutter build apk --dart-define=TRIAGE_DEMO=true
adb install -r .\build\app\outputs\flutter-apk\app-release.apk
```

The release APK is written to `triage/triage_flutter/build/app/outputs/flutter-apk/app-release.apk`. Tap the voice capsule; Android should prompt for microphone permission, then show recording elapsed time and waveform. Tap again to stop. PCM16 samples are capped at 30 seconds, passed to the local WebView worker, transcribed by Whistle, and routed by Needle before the existing date/redaction/review flow. The demo define uses the local demo repository, not Serverpod persistence. For a backend-backed APK, omit `TRIAGE_DEMO=true` and pass `--dart-define=SERVER_URL=http://<PC_WIFI_IPV4>:8080/`.

The worker, WASM binary, tools and both model files are packaged in Flutter assets; the first initialization loads roughly 52 MB of Needle/Whistle model data from the APK. `cact` and `wasm` are marked no-compress in Android resources. No audio file is written to disk or uploaded. The release artifact built and verified in this checkout is 226.9 MB at `triage/triage_flutter/build/app/outputs/flutter-apk/app-release.apk`. Because models are bundled, rebuild after running the preparation command if the source model revision changes.

## 4. Start Flutter Web and connect the phone

Use USB debugging and authorize the PC on the phone. In another terminal:

```powershell
cd triage/triage_flutter
adb devices
adb reverse tcp:8082 tcp:8082
adb reverse tcp:8080 tcp:8080
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8082 --dart-define=SERVER_URL=http://localhost:8080/
```

Keep this terminal open. On the phone, open Chrome to `http://localhost:8082`. `adb reverse` makes the phone's localhost web origin and API port reach the PC while preserving a secure localhost context for microphone permission. On the laptop, open the same URL in Chrome. Accept the browser microphone permission when prompted on the phone. If the model assets were not prepared in step 1, the first capture will fail to initialize.

Both browser sessions should use the same Serverpod account. For a new development account, use Sign up and read the verification code in the Serverpod terminal logs. Keep both sessions open in the inbox. Record and save an item on one; the other session should receive its `InboxEvent` and render it without refresh. Swipe right to complete and swipe left to delete; those updates are also broadcast. On reconnect, the client subscribes again and reloads the session-scoped inbox snapshot.

If you cannot use USB debugging, serve the web app over your LAN and use an HTTPS origin with a trusted certificate. Plain `http://<PC_IP>` is not a secure microphone origin on Android Chrome. Set `SERVER_URL` to `http://<PC_IP>:8080/` only for a trusted development network, and allow the required ports through Windows Firewall's Private profile.

## 5. Reminder alerts on Android

Native local alerts use `flutter_local_notifications` 22.3.1, the device IANA timezone, Android notification permission, and an exact alarm when Android grants exact-alarm access. If exact alarms are denied, Triage requests an inexact idle-safe schedule. The alert uses the resolved reminder `DateTime`; it is scheduled after the server acknowledges creation, and rescheduled/cancelled from create/update/complete/delete stream events. Serverpod's `ReminderFutureCall` independently marks the persisted reminder as fired and broadcasts that state.

The plugin does not support scheduled delivery on Flutter Web. To exercise Android OS alerts, connect an Android device over USB and run the native shell:

```powershell
flutter run -d <ANDROID_DEVICE_ID> --dart-define=SERVER_URL=http://<PC_WIFI_IPV4>:8080/
```

Grant notification and exact-alarm permissions when Android requests them. In the Android shell, tap the voice capsule and grant microphone permission to test local microphone-to-Needle inference. For a quick reminder smoke test, create a reminder and leave the app; local alert delivery also depends on Android notification settings and OEM battery policies.

## 6. Expected six-utterance behavior

These are the pinned model's measured WASM outputs documented in [SPIKE_RESULTS.md](SPIKE_RESULTS.md), not hand-authored expected calls. A suppressed candidate stays in Review Required and is never automatically saved.

| Utterance | Measured route | Client behavior |
| --- | --- | --- |
| “Remind me to call the dentist tomorrow at 3pm” | `add_reminder`, confidence 0.2972 | Resolves local tomorrow 15:00 to UTC, shows confirmation, saves redacted item, schedules Android alert. |
| “Buy eggs, milk, and bread from Whole Foods” | Three suppressed shopping candidates, confidence 0.0172; quantity/store extraction is incorrect | Review Required with raw transcript local; no shopping rows are written until user repairs the fields. |
| “The client meeting went well, they approved the Q4 budget” | Suppressed task candidate, confidence 0.0052 | Review Required; no automatic note is created. |
| “Fix the login bug by Friday, high priority” | Suppressed task candidate, confidence 0.0941 | Review Required; no automatic task is created. |
| “What if we made the onboarding a game?” | Suppressed task candidate, confidence 0.0162 | Review Required; no automatic idea is created. |
| “Um, so, email Sarah about the proposal, and oh, grab milk” | Two suppressed candidates, confidence 0.0438 | Review Required; no candidate is promoted or conjunction-split. User must edit/create the intended items. |

The raw original transcript remains in the account-scoped device cache. Needle extracts first; then the official Desert Ant Redact model masks names, address components, emails, phones, payment cards, and government identifiers in transcript/title/body/tags before the confirmation countdown and `createItem`. A deterministic regex/Luhn pass adds defense in depth for formatted email, phone, card, SSN, and street-address patterns. `originalTranscript` is not in the endpoint model or payload. If model redaction fails, the draft remains local and save is blocked. The SDK's published evaluation is not a guarantee that every PII span is detected, so treat redaction as a strong filter rather than proof of zero leakage.

## Verification boundaries

- Flutter client tests verify fake audio-result → tool parse → date resolution → redaction → repository write, local raw cache retention, fail-closed redaction, reminder scheduling/cancellation, and two active client controllers consuming create/update/delete events.
- The Serverpod integration suite verifies authenticated same-user session event delivery and cross-user isolation. This guide has not been run against a physical phone or a user's running backend; use the steps above for the live acceptance demo.
- Flutter Web audio/model inference has a prior browser integration test. Android APK now uses the native microphone plugin and local WebView WASM runner; no Android handset was attached for this implementation turn, so physical permission prompts, microphone audio, and APK inference must be smoke-tested on the target phone before claiming device validation. iOS native voice capture remains follow-up work.
- Web notification APIs do not provide scheduled local delivery in the selected plugin; run the native Android shell for OS alert verification.
- Recurrence values remain stored (`none`, `daily`, `weekly`), but repeated local/backend scheduling is not implemented. One future call and one local alert are scheduled per reminder.

Android voice capture uses `record` 7.1.1 PCM16 streaming, `permission_handler` 12.0.3 runtime permission, and `androidx.webkit:webkit` 1.17.0's local asset loader. The browser bridge pins `@desert-ant-labs/redact` 3.6.0 and `@litertjs/core` 2.5.3; Android pins `ai.desertant:redact:3.6.0` and requires API 24+. The official Redact model uses local WebAssembly/LiteRT in browsers and LiteRT on Android. [Official SDK and model documentation](https://github.com/Desert-Ant-Labs/desert-ant-core/blob/main/docs/models/redact.md), [Serverpod configuration](https://docs.serverpod.dev/concepts/lookups/configuration-reference), [record](https://pub.dev/packages/record), [permission_handler](https://pub.dev/packages/permission_handler), [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications), and [flutter_timezone](https://pub.dev/packages/flutter_timezone).
