# Product Requirements Document (PRD)
## Project Triage: Offline-First Assistant & Serverpod Intelligence Hub

**Version:** 2.0.0  
**Target Platform:** Android (API 31+) Client with Serverpod 4.0.4 Backend Hub  
**Architecture Theme:** Local Execution, Cloud Coordination, BYOK Frontier Escalation  

---

## 1. Executive Summary

**Triage** is an offline-first smart voice assistant for Android that executes system-level device actions with **no network round-trip**, while leveraging **Serverpod** for authenticated device registration, outbox sync, and telemetry. On-device alarms schedule offline routines. Serverpod Future Call routines are an optional Growth-plan capability, not part of the Starter deployment. For conversational queries and creative tasks beyond on-device execution, Triage offers an optional **BYOK (Bring Your Own Key)** gateway to frontier LLMs.

### Core Value Proposition
- **Guaranteed Local Utility:** Volume, brightness, DND, alarms, timers, app launches, and media playback execute reliably offline without an internet connection or API keys.
- **Serverpod Showcase:** On Starter, demonstrate real email authentication, device ownership, resilient outbox sync, and device telemetry. WebSocket routine delivery and Serverpod `FutureCall` require a plan that enables Future Calls.
- **Truthful Feedback & Security:** Clear operational boundaries—every action produces a typed result (`success`, `handed_off`, `permission_required`, `ambiguous`, `unsupported`) reflected truthfully by the UI and TTS.

### Starter deployment profile

- Offline actions and local Android exact-alarm routines work without sign-in. Settings offers real email sign-in and registration for connected features; the development pilot-auth endpoint must not be used in production.
- Cloud routine scheduling is disabled in the consumer UI and rejected by the production endpoint unless `TRIAGE_CLOUD_ROUTINES_ENABLED=true` is explicitly configured on a Future Calls-enabled plan.
- A demo sync is successful only after Serverpod acknowledges the actual outbox event IDs. Network or authentication failure leaves events pending and reports failure.
- Serverpod Cloud offers a one-month first-project trial, not a permanent free tier. Published Starter pricing and features must be checked before deployment; see [the deployment runbook](SERVERPOD_CLOUD_DEPLOYMENT.md).

---

## 2. Terminology & Truthful Performance Metrics

| Term | Operational Definition |
| :--- | :--- |
| **No Network Round-Trip** | The voice capture, intent parsing, native system call, and feedback audio execute entirely within the boundaries of the Android device. |
| **Transcription Latency ($t_{\text{stt}}$)** | Time from speech endpointing to structured text emission by Android On-Device Recognizer. |
| **Parsing Latency ($t_{\text{parse}}$)** | Time from transcript emission to deterministic slot resolution ($< 5\text{ ms}$). |
| **Execution Latency ($t_{\text{exec}}$)** | Time taken by Android Platform Channel to invoke the platform API and receive response. |
| **TTS Latency ($t_{\text{tts}}$)** | Time from command completion to initial spoken frame via Android on-device TTS. |
| **Total Response Time** | $T_{\text{total}} = t_{\text{stt}} + t_{\text{parse}} + t_{\text{exec}} + t_{\text{tts}}$. |

---

## 3. Platform Capabilities & Operating System Boundaries

### 3.1 Speech Recognition & Audio Pipeline
- **On-Device STT Verification:**
  - Check `SpeechRecognizer.isOnDeviceRecognitionAvailable(context)` (Android 12 / API 31+).
  - Explicit onboarding check for offline language pack assets.
  - Graceful fallback: If on-device assets are missing, guide user to download offline voice assets via Android Speech Settings.
- **On-Device TTS:**
  - Verify installed offline voice via `TextToSpeech.Engine.ACTION_CHECK_TTS_DATA`.
- **Voice Activation:**
  - **Foreground Tap:** Responsive voice capsule trigger.
  - **Foreground Shake:** Accelerometer listener (`sensors_plus`) active during foreground runtime.
  - *Boundary Rule:* Background continuous microphone listening and system-wide wake gestures are strictly scoped to Phase 2 due to Android Background Activity Launch (BAL) and sensor rate limits.

### 3.2 Native System Control Matrix

| Domain | Action | Implementation Mechanism | Permission / Boundary | Result Type |
| :--- | :--- | :--- | :--- | :--- |
| **Audio** | Adjust/Set Volume | `AudioManager.setStreamVolume` | Standard permission | `success` / `error` |
| **Display** | Set Screen Brightness | `Settings.System.putInt(SCREEN_BRIGHTNESS)` | `android.permission.WRITE_SETTINGS` | `success` / `permission_required` |
| **Do Not Disturb** | Enable / Disable DND | Android 15+ (API 35+): `NotificationManager.addAutomaticZenRule`<br>API 31-34: `setInterruptionFilter` | `android.permission.ACCESS_NOTIFICATION_POLICY` | `success` / `permission_required` |
| **Alarms** | Set Alarm (`hour, min, label`) | `AlarmClock.ACTION_SET_ALARM` with `EXTRA_SKIP_UI = true` | Handed to System Clock app | `handed_off` |
| **Timers** | Set Timer (`seconds, label`) | `AlarmClock.ACTION_SET_TIMER` with `EXTRA_SKIP_UI = true` | Handed to System Clock app | `handed_off` |
| **Alarms & Timers** | View Alarms | `AlarmClock.ACTION_SHOW_ALARMS` | Handed to System Clock app | `handed_off` |
| **Apps** | Launch Application | `PackageManager.getLaunchIntentForPackage` | `QUERY_ALL_PACKAGES` | `success` / `unsupported` |
| **Media** | Skip Next / Prev Track | `KeyEvent.KEYCODE_MEDIA_NEXT` / `PREVIOUS` broadcast | Standard media session broadcast | `handed_off` |
| **System Info** | Time, Date, Battery | Dart `DateTime` + `battery_plus` | Direct read | `success` |
| **Settings Panel** | Airplane Mode / Battery Saver | `Settings.ACTION_AIRPLANE_MODE_SETTINGS` / `ACTION_BATTERY_SAVER_SETTINGS` | Standard intent | `handed_off` |

---

## 4. System Architecture & Component Design

```
+---------------------------------------------------------------------------------+
|                                 ANDROID CLIENT                                  |
|                                                                                 |
|  [Voice Trigger] ---> [On-Device STT] ---> [Intent Router]                     |
|  (Tap / Shake)         (API 31 Recognizer)        |                             |
|                                                   |                             |
|            +--------------------------------------+-------------------------+   |
|            | Offline Intent Match                                           |   |
|            v                                                                v   |
|   [Deterministic Parser]                                           [BYOK Client]|
|            |                                                        (When Online|
|            v                                                        & Frontier) |
|   [Native Platform Bridge]                                                  |   |
|   (Volume, DND, Clock, Apps)                                                |   |
|            |                                                                |   |
|            +------------------------------+---------------------------------+   |
|                                           |                                     |
|                                           v                                     |
|                                 [Typed Command Result]                          |
|                                           |                                     |
|                      +--------------------+-------------------+                 |
|                      v                                        v                 |
|            [UI & Spoken Feedback]                  [Durable Local Outbox]       |
|            - Thinking Orb                          (Persists event_id, status,  |
|            - Border Beam                            telemetry, action payload)  |
|            - Offline TTS                                      |                 |
+---------------------------------------------------------------|-----------------+
                                                                | (Background Sync)
                                                                v
+---------------------------------------------------------------------------------+
|                                SERVERPOD BACKEND                                |
|                                                                                 |
|   [Device Auth Endpoint] <--- Validates client credentials                      |
|   [Outbox Sync Endpoint] <--- Deduplicates by event_id, writes to PostgreSQL   |
|   [Telemetry Endpoint]   <--- Stores battery, volume, DND state                 |
|   [Routine Scheduler]    <--- Serverpod FutureCall triggers automated routines  |
|   [WebSocket Stream]     ---> Opportunistically delivers routines & live events |
+---------------------------------------------------------------------------------+
```

---

## 5. Architectural Safeguards & Data Guarantees

### 5.1 Local Durable Outbox & Sync
- **Event Persistence:** Every executed command is immediately written to local SQLite storage with a UUID v4 (`event_id`).
- **Idempotent Sync:** When network connectivity is re-established, the client flushes pending outbox records to Serverpod. The server deduplicates records using `event_id`.
- **Privacy Boundary:** By default, raw transcript strings remain strictly local on the device. Syncing transcripts to Serverpod requires an explicit user toggle in Settings.

### 5.2 Device Identity & Authentication
- Devices generate and store an encrypted hardware-bound UUID (`device_id`) on initial setup.
- Serverpod issues a device auth session token. Routines and telemetry are strictly authorized by `device_id`.

### 5.3 Scheduled Routines (Serverpod Future Calls + Local Hybrid)
- **The Doze / Network Partition Guard:** Serverpod `FutureCall` executes server-side automation logic. However, because Android Doze mode defers network activity, scheduled device actions must also be mirrored to Android `AlarmManager.setExactAndAllowWhileIdle()` when offline reliability is required.
- **Routine Lifecycle Statuses:**
  `created` $\rightarrow$ `dispatched` $\rightarrow$ `acknowledged` $\rightarrow$ `executing` $\rightarrow$ `completed` / `partial_failure` / `expired`.

### 5.4 Routing Safeguards & BYOK Firewall
- **Local-First Precedence:** Every query passes through the deterministic regex/grammar slot-filler first.
- **No Direct Bridge Invocation from LLMs:** Responses from BYOK frontier models **cannot** arbitrarily execute native device methods. They return conversational responses or structured proposals that require user confirmation.
- **Clarification on Ambiguity:** If a command matches multiple installed apps or ambiguous parameters, the assistant prompts for verbal or touch clarification.

---

## 6. Serverpod Data Schema (YAML Protocol Definitions)

### 6.1 `VoiceCommandLog` (`triage_server/lib/src/protocol/voice_command_log.yaml`)
```yaml
class: VoiceCommandLog
table: voice_command_logs
fields:
  eventId: String, index
  deviceId: String, index
  intent: String
  actionTarget: String?
  resultType: String # success, handed_off, permission_required, ambiguous, unsupported
  executionLatencyMs: int
  executedOffline: bool
  syncedAt: DateTime
  transcript: String? # null unless opt-in
```

### 6.2 `DeviceTelemetry` (`triage_server/lib/src/protocol/device_telemetry.yaml`)
```yaml
class: DeviceTelemetry
table: device_telemetry
fields:
  deviceId: String, index
  batteryLevel: int
  isCharging: bool
  volumeLevel: double
  brightnessLevel: double
  dndEnabled: bool
  updatedAt: DateTime
```

### 6.3 `RoutineSchedule` (`triage_server/lib/src/protocol/routine_schedule.yaml`)
```yaml
class: RoutineSchedule
table: routine_schedules
fields:
  routineId: String, index
  deviceId: String, index
  name: String
  scheduledTime: DateTime
  status: String # pending, dispatched, completed, failed, expired
  stepsJson: String # JSON array of typed action descriptors
  lastAcknowledgedAt: DateTime?
```

---

## 7. User Interface & Aesthetic Design (Libraries.dev Inspiration)

- **Palette:** Luxury dark mode base (`#121212`), high-contrast pure white typography (`#FFFFFF`), subtle border accents (`#262626`).
- **Thinking Orb Widget:**
  - Shader/CustomPainter radial orb with procedural fluid noise.
  - **Reactive States:**
    - `Idle`: Soft pulsing violet/neutral glow.
    - `Listening`: Responsive reactive audio-wave ripple.
    - `Thinking`: Accelerated iridescent rotation.
    - `Success / Handed-Off`: Emerald cyan flare settling back to idle.
    - `Permission / Error`: Soft amber/crimson wave.
- **Border Beam Widget:**
  - Animated traveling gradient tracing the perimeter of active cards and capsules.
- **Auditory Confirmation:** Truthful spoken feedback via offline Android TTS (e.g. *"Set volume to 50%"*, *"Opening YouTube"*, *"Handed timer request to Clock"*).

---

## 8. Staged Build & Implementation Order

### Stage 1: Native Android Subsystem & Verification (Day 1)
- [ ] Implement `TriageNativeBridge.kt`:
  - On-Device STT check (`SpeechRecognizer.isOnDeviceRecognitionAvailable`).
  - Offline TTS initialization and voice check.
  - Direct volume adjustment (`AudioManager`).
  - Brightness adjustment with write settings permission check.
  - DND check and toggle via `NotificationManager`.
  - Clock Intents for Alarms & Timers.
  - Package Manager launch intent caller.
- [ ] Verify functionality directly on attached Android test device.

### Stage 2: End-to-End Local Loop (Day 1 - 2)
- [ ] Build deterministic grammar slot-filler in Dart.
- [ ] Connect Tap trigger $\rightarrow$ On-Device STT $\rightarrow$ Slot-filler $\rightarrow$ Platform Channel $\rightarrow$ Typed Result $\rightarrow$ Offline TTS.
- [ ] Implement local SQLite durable outbox table and repository.

### Stage 3: Serverpod 4.0.4 Backend & Outbox Synchronization (Day 2 - 3)
- [ ] Clean Serverpod project setup with local Docker PostgreSQL container.
- [ ] Define protocol YAMLs: `VoiceCommandLog`, `DeviceTelemetry`, `RoutineSchedule`.
- [ ] Generate Serverpod code and apply database migrations.
- [ ] Implement endpoints: `CommandSyncEndpoint`, `TelemetryEndpoint`, `RoutineEndpoint`.
- [ ] Configure Serverpod `FutureCall` worker for scheduled routines.
- [ ] Implement client-side sync manager: automatic outbox flush on network connectivity.

### Stage 4: BYOK Frontier Gateway (Day 3)
- [ ] Build unified multi-provider HTTP client (`OpenAI`, `Anthropic`, `Gemini`, `Groq`).
- [ ] Secure API key storage using `flutter_secure_storage`.
- [ ] Implement routing firewall: query classification routes conversational queries to BYOK when connected.

### Stage 5: Libraries.dev UI Polish & Shake Gesture (Day 4)
- [ ] Build Flutter custom `ThinkingOrb` and `BorderBeam` widgets.
- [ ] Integrate accelerometer foreground shake trigger (`sensors_plus`).
- [ ] Add settings panel: BYOK configuration, transcript privacy opt-in, permission indicators.

### Stage 6: Hackathon Demonstration Script & Validation (Day 4 - 5)
- [ ] **Scene 1 (Zero-Network Offline Demonstration):** Turn on Airplane mode. Issue commands (*"Set volume to 40%"*, *"Set a timer for 10 minutes"*, *"Open YouTube"*). Show 0 network calls, truthful orb feedback, and local outbox queue.
- [ ] **Scene 2 (Reconnect & Sync):** Turn off Airplane mode. Watch Serverpod instantly receive, deduplicate, and log the actions and telemetry in PostgreSQL.
- [ ] **Scene 3 (Serverpod Future Call Routine):** Trigger scheduled routine from Serverpod, receive WebSocket command on device, execute step, and acknowledge.
- [ ] **Scene 4 (BYOK Conversation):** Ask a complex question, demonstrate frontier model stream with custom API key.
