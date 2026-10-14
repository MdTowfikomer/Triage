# Triage

![Triage: Offline Voice, Hardware Triggers, Serverpod Cloud Sync](docs/assets/illustrations/hero-banner.jpg)

**Instant thought capture. Instant physical action. Zero latency.**  
Triage is a privacy-first, offline-capable assistant designed for the **Serverpod "Build Something Real" Hackathon**. It combines hardware-triggered voice intake, on-device deterministic parsing, and local SQLite queueing with high-speed Serverpod cloud synchronization.

Whether you're offline on the subway or online at your desk, Triage lets you trigger reminders, notes, calls, WhatsApp messages, and timers instantly — then syncs seamlessly with Serverpod and PostgreSQL when connectivity is available.

---

## ⚡ Highlights

- **Hardware Button & Gesture Triggers**: Double-tap `Volume Up` or use **Volume Up + Shake** to summon the assistant in `<50ms` even with the screen off or when inside other apps.
- **100% Offline Core Actions**: WhatsApp handoff, phone calls, reminders, timer alarms, and quick voice notes parse and execute with zero network latency.
- **Offline SQLite Outbox**: Spoken commands are safely saved to a local outbox with retry logic and conflict-free sequence IDs.
- **Serverpod 4.0.4 Cloud Sync**: As soon as internet connectivity returns, the client syncs pending batches to Serverpod's PostgreSQL database and broadcasts live updates over typed WebSockets.
- **ASCII/Pixel Animated Assistant**: Minimalist warm-paper / obsidian UI (`#F8F7F2`, `#242521`, `#E78A4E`) featuring dynamic animated states (*Idle*, *Listening*, *Thinking*, *Speaking*, *Offline*).
- **Gemini Live Conversational Mode**: Switch seamlessly from instant offline triggers to an open-ended conversational session using BYOK Gemini Live WebSockets with direct PCM streaming.

---

## 🏗 Architecture & Offline-to-Cloud Sync

![Offline-First Outbox and Serverpod Cloud Sync Architecture](docs/assets/illustrations/offline-sync-architecture.jpg)

```mermaid
flowchart TD
  subgraph OnDevice["On-Device: Zero Network Needed"]
    Trigger["Hardware Key / Shake / UI Mic"] --> Audio["Local Audio / STT Bridge"]
    Audio --> Parser["Deterministic Regex & Fuzzy Contact Parser"]
    Parser --> Intent{"Intent Decision"}
    Intent -->|Direct Action| Native["Native Android Handoff<br/>WhatsApp / Tel / Alarm / Timer"]
    Intent -->|Data Item| Outbox[("Local SQLite Outbox")]
  end

  subgraph ServerpodCloud["Serverpod Cloud Backend"]
    SyncWorker["Sync Worker / Connectivity Monitor"] -->|Batched POST syncBatch| Endpoint["CommandSyncEndpoint"]
    Endpoint --> DB[("PostgreSQL Cloud Database")]
    Endpoint --> Streams["Typed WebSocket Stream"]
    Streams --> WebClient["Web / Desktop Clients"]
  end

  Outbox -->|When Online| SyncWorker
```

---

## 🗣 Offline Command Guide

Triage includes a built-in offline command reference accessible via the `?` icon in the app header:

| Category | Example Voice Commands | What Triage Does |
| :--- | :--- | :--- |
| **WhatsApp** | `"WhatsApp Dad I am on my way"`<br>`"Send a WhatsApp to Alice see you soon"` | Matches contact against pinned favorites and pre-fills WhatsApp chat ready to send |
| **Phone Calls** | `"Call Mom"`<br>`"Call Doctor on mobile"` | Looks up pinned contact phone number and launches direct native dialer |
| **Reminders** | `"Remind me to buy groceries tomorrow at 6 PM"`<br>`"Reminder take medicine in 2 hours"` | Parses relative date/time deterministically and sets a local notification |
| **Timers & Alarms** | `"Set a timer for 15 minutes"`<br>`"Set an alarm for 7 AM tomorrow"` | Sets system clock alarms directly via native Android intents |
| **Quick Notes** | `"Note down meeting ideas for tomorrow"`<br>`"Take a note buy coffee beans"` | Immediately persists to local SQLite and queues for Serverpod sync |

---

## Product Illustrations

The project includes verified architectural diagrams for privacy, capture pipelines, and review workflows:

![Voice funnel: capture, interpret, then review](docs/assets/illustrations/01-voice-funnel.jpg)

*01 — Voice funnel. Capture feeds local transcription and PII scrubbing, then the action funnel prepares an inbox item or app launch.*

![Privacy vault: raw transcript stays on device](docs/assets/illustrations/02-privacy-vault.jpg)

*02 — Privacy vault. Keep the original transcript local; only a sanitized transcript and structured fields are eligible for sync.*

![Auto-save countdown: confirm, edit, or cancel](docs/assets/illustrations/03-autosave-countdown.jpg)

*03 — Auto-save countdown. Valid confident actions can be saved after a short review window; uncertain or incomplete results require editing.*

## Stack

- **Flutter / Dart Client**: Custom warm-paper minimalist design system with Forui Lucide icons, responsive sheets, and ASCII animated assistant.
- **Serverpod 4.0.4 Backend**: Custom endpoints (`CommandSyncEndpoint`, `RoutineEndpoint`, `TelemetryEndpoint`, `DeviceEndpoint`), typed future calls, ORM relations, and PostgreSQL persistence.
- **Android Native Layer**: Kotlin `TriggerKeyService` and `BackgroundShakeService` for low-latency physical triggers, plus `NativeActionBridge` for intent handoffs.
- **SQLite Outbox**: Local queueing via `sqlite_async` ensuring zero data loss during network dropouts.
- **Gemini Live**: Direct bi-directional WebSocket streaming with 16kHz PCM audio and low-latency audio playback.

- Flutter / Dart client, with a custom dark Linear-inspired inbox and voice capsule.
- Cactus Needle Whistle for on-device speech transcription; Laya/OpenAI-compatible backend adapters and a pure Dart fallback for routing and slot extraction.
- A standalone deterministic Dart `DateResolver` for local relative-date interpretation.
- Desert Ant Labs Redact for local PII filtering, with a regex/Luhn defense-in-depth pass and fail-closed save behavior.
- Serverpod 4.0.4 generated client/server, official email auth, session-scoped endpoints, ORM relations, typed WebSocket events, and reminder future calls.
- PostgreSQL; Android native local alerts via `flutter_local_notifications`.

## Current verification and boundaries

Flutter client tests pass (59), backend unit/integration tests pass (65), and both analyzers are clean. The Whistle-only prepared Android bridge transcribed a prerecorded fixture without Needle routing. Laya/tool-model adapters have controlled contract tests; live model accuracy/latency and physical-phone execution still need validation. Earlier Web/Needle spike evidence remains in the historical reports.

This is a spike/hackathon build, not a claim of fully validated production behavior. The latest Desert Ant **browser** smoke initialized LiteRT but its Hugging Face model listing request returned HTTP 405 in this environment; browser model-backed redaction needs a successful host check before recording a browser privacy demo. The app blocks saving if redaction initialization fails. The Android APK now includes its WASM runtime and model files and has passed a local prerecorded-audio bridge smoke, but no Android handset was attached during this implementation turn, so native permission/microphone/inference still needs physical-device acceptance. Server/client multi-session event handling has automated tests, but a physical phone-to-laptop live sync demo has not yet been performed. See [the phone demo guide](docs/PHONE_DEMO_GUIDE.md) and [the detailed UI/platform report](docs/FLUTTER_UI.md) before presenting features as live-verified.

## Open-source and release notes

The project is licensed under [MIT](LICENSE). See [CONTRIBUTING.md](CONTRIBUTING.md),
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md) for
community and vulnerability reporting guidance. Android signing, the production
backend URL, and the pre-publication checklist are in
[the release readiness guide](docs/RELEASE_READINESS.md).

## Setup and run

### Requirements

- Windows PowerShell (commands below), Flutter 3.47.6 / Dart 3.13.5 or a compatible newer SDK, and Node.js 24 for browser Redact bundling.
- Serverpod CLI 4.0.4 for backend generation/run, and Android SDK/USB debugging for a native Android shell.
- Network access for first-time package/model downloads. The browser voice and Redact models are substantial downloads; see the platform caveats above.

This checkout keeps SDK/package caches under `.spike-cache`. From the repository root, configure the local tools (if present):

```powershell
$env:PUB_CACHE = "$PWD/.spike-cache/pub"
$env:PATH = "$PWD/.spike-cache/flutter/bin;$PWD/.spike-cache/flutter/bin/cache/dart-sdk/bin;$PWD/.spike-cache/pub/bin;$env:PATH"
```

If using your own installed Flutter/Dart and Serverpod CLI, put those binaries on `PATH` instead.

### Backend

```powershell
cd triage
flutter pub get
cd triage_server
./tool/init_secrets.ps1
serverpod generate
cd ..
serverpod start
```

`serverpod start` starts the configured local development database and API and applies pending migrations. The checked-in migrations cover the current schema; after changing model YAML, use `serverpod generate` and `serverpod create-migration <migration_name>` from `triage/triage_server`, then review and apply the generated migration. Keep the service running in this terminal. Local email verification codes are printed in its logs. For phone-on-Wi-Fi access, set the advertised host before startup, e.g. `$env:SERVERPOD_API_SERVER_PUBLIC_HOST = "192.168.1.25"`, and use a trusted LAN; see [PHONE_DEMO_GUIDE.md](docs/PHONE_DEMO_GUIDE.md).

### Flutter Web

In another PowerShell terminal from the repository root:

```powershell
./triage/triage_flutter/tool/prepare_web.ps1 -DownloadModels
cd triage/triage_flutter
flutter pub get
./tool/build_web.ps1
flutter run -d chrome --dart-define=SERVER_URL=http://localhost:8080/
```

The app requires a running backend for sign-in and persistence. Microphone access requires HTTPS or localhost. For a clearly labeled backend-free UI preview only:

```powershell
flutter run -d chrome --dart-define=TRIAGE_DEMO=true
```

### Phone / Android

For browser voice capture on a phone, the phone demo guide uses USB `adb reverse` and the Flutter Web server. The native Android APK uses the local Whistle-only worker, allowlisted Android intents and native reminders; prepare assets before building:

```powershell
./triage/triage_flutter/tool/prepare_web.ps1 -DownloadModels
cd triage/triage_flutter
flutter pub get
flutter run -d <ANDROID_DEVICE_ID> --dart-define=SERVER_URL=http://<PC_WIFI_IPV4>:8080/
```

Grant notification/exact-alarm permissions as requested. Scheduled notifications are unsupported on Web in the selected plugin. For LAN URLs, keep devices on a trusted network and configure Windows Firewall only for the Private profile. See [PHONE_DEMO_GUIDE.md](docs/PHONE_DEMO_GUIDE.md) for the full two-client procedure and limitations.

## Project docs

- [Product requirements](docs/PRD.md) · [Project plan](docs/PROJECT_PLAN.md)
- [Needle / Whistle spike results](docs/SPIKE_RESULTS.md) · [Date resolver](docs/DATE_RESOLVER.md)
- [Serverpod models and security](docs/SERVERPOD_SETUP.md) · [Flutter UI](docs/FLUTTER_UI.md)
- [Phone demo guide](docs/PHONE_DEMO_GUIDE.md) · [Demo video script](docs/DEMO_SCRIPT.md) · [Hackathon submission copy](docs/SUBMISSION.md)

## AI disclosure

- **Runtime AI:** Cactus Needle Whistle for local transcription and Desert Ant Labs Redact for on-device PII filtering. The backend can call Laya for domain decisions and a configured Liquid/OpenAI-compatible tool model for extraction. The default unconfigured/demo path uses deterministic rules; live model inference is not yet validated. Historical Needle 3 spike evidence remains documented separately.
- **Development assistance:** OpenAI Codex was used as a coding assistant in this project. Add any other coding assistants used by the team before submitting; this disclosure should reflect the full development history.
- **Authorship:** Team members remain responsible for reviewing generated code, model behavior, privacy claims, and the final submission.

Review the exact portal-ready text in [docs/SUBMISSION.md](docs/SUBMISSION.md).
