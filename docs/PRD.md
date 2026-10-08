# Triage — Product Requirements Document

> **Voice-Driven Smart Inbox & Task Manager**
> Built for the "Build Something Real" Serverpod Hackathon (deadline: Oct 14, 2026, 23:59 CEST / Oct 15, 03:29 IST)

> **Current architecture update (Oct 9):** the action funnel supersedes the earlier on-device Needle routing plan below. Whistle STT and Desert Ant PII scrubbing stay on the phone; sanitized text goes to Serverpod's Laya/tool-model adapters, with a deterministic offline fallback. Explicit app-opening commands use Android intents. Original transcripts/audio remain local. See [ACTION_FUNNEL.md](ACTION_FUNNEL.md) for the active implementation and verification boundaries.

---

## 1. Elevator Pitch

Speak your thoughts throughout the day. Triage listens, understands, and acts. "Email Sarah about the proposal" prefills a task. "Buy milk" adds a grocery item. "The client meeting went well, they approved the Q4 budget" prefills a note. "Open WhatsApp" launches the installed app on Android.

Speech transcription and PII scrubbing happen **on-device**. Raw audio and original unredacted transcripts stay local. Sanitized transcripts may be sent to the authenticated Serverpod action router during interpretation; approved structured inbox items are persisted and synced after confirmation.

Triage is a **Flutter app** with a **Serverpod backend**, using **Cactus Needle Whistle** for local transcription, **Desert Ant Labs** for on-device privacy scrubbing, and configurable **Laya/tool-model** backend adapters for the action funnel.

---

## 2. Problem Statement

People have dozens of micro-thoughts, tasks, and notes throughout the day. Capturing them means:
- Unlocking the phone, opening the right app, typing it out — friction kills most of them
- Existing voice assistants require cloud connectivity, are slow, leak sensitive personal context, and lack structured follow-through
- Notes end up scattered across 5 apps with no unified view

**Triage eliminates the friction:** tap once, speak, tap to stop. The on-device AI transcribes, routes to the right bucket, extracts structured entities, strips PII before syncing, and stores it in a unified Serverpod backend.

---

## 3. Target User

Solo professionals, freelancers, busy parents, students — anyone who has more thoughts than time to organize them. The person who currently texts themselves reminders or loses fleeting ideas.

---

## 4. Hackathon Strategy

### Judging Criteria Alignment

| Criterion (Weight) | How Triage Scores |
|---|---|
| **Does it work (30%)** | Core flow is airtight: tap $\rightarrow$ speak $\rightarrow$ tap $\rightarrow$ see it parsed & auto-saved with a 3s countdown. Immediate two-client real-time sync demo. |
| **Use of Serverpod stack (25%)** | Built-in Serverpod Auth, ORM with formal relations (`InboxItem` $\leftrightarrow$ `Reminder`, `Recording`, `User`), real-time WebSocket streams (`streamInbox`), task scheduling via future calls, file storage, session-scoped security. |
| **Craft & technical creativity (25%)** | On-device privacy-first AI pipeline: Needle Whistle transcription $\rightarrow$ Needle tool-calling & entity extraction $\rightarrow$ on-device deterministic date resolution $\rightarrow$ PII redaction before server sync. |
| **Usefulness (20%)** | Clear daily utility, immediate friction reduction, production-grade security and privacy. |

### AI Disclosure (required by rules)
All AI tools used in development (coding assistants) and runtime libraries (Cactus Needle, Desert Ant Labs SDKs) are disclosed in the submission documentation.

---

## 5. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│                                                                 │
│  ┌──────────────┐   ┌────────────────────────────────────────┐  │
│  │ Audio Record │──▶│ Cactus Needle Whistle (needle.transcr) │  │
│  │ (Tap-Toggle) │   │ On-device STT (30s chunking if needed) │  │
│  └──────────────┘   └───────────────────┬────────────────────┘  │
│                                         │                       │
│                                  Raw Local Text                 │
│                                         ▼                       │
│                     ┌────────────────────────────────────────┐  │
│                     │ Cactus Needle Tool-Calling             │  │
│                     │ Routes: add_task, add_note,            │  │
│                     │ add_reminder, add_shopping_item,       │  │
│                     │ log_idea                               │  │
│                     │ Multi-call support / client utterance  │  │
│                     │ splitting                              │  │
│                     └───────────────────┬────────────────────┘  │
│                                         │                       │
│                                  Parsed Arguments               │
│                                         ▼                       │
│                     ┌────────────────────────────────────────┐  │
│                     │ On-Device Resolvers & Enhancers        │  │
│                     │ • Deterministic Date Resolver (P0)     │  │
│                     │   ("tomorrow 3pm" → DateTime)          │  │
│                     │ • Desertant Redact (P0 payload sync)   │  │
│                     │ • Desertant Gist / Emo (P1)            │  │
│                     │ • Local secure storage (raw transcript)│  │
│                     └───────────────────┬────────────────────┘  │
│                                         │                       │
│  ┌─────────────────────────────────────▼──────────────────────┐ │
│  │             Inbox UI & Confirmation Card                   │ │
│  │  3-second auto-save countdown (or edit if schema invalid)  │ │
│  │  Tasks | Notes | Reminders | Shopping | Ideas              │ │
│  └─────────────────────────────────────┬──────────────────────┘ │
└────────────────────────────────────────┼────────────────────────┘
                                         │
                         Serverpod Client (Generated Dart)
                         [Syncs ONLY redacted payload]
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Serverpod Backend                          │
│                                                                 │
│  Modules & Endpoints:                                           │
│  • serverpod_auth Module — Built-in auth (email/password)       │
│  • InboxEndpoint         — Session-scoped CRUD (userId inferred)│
│  • ReminderEndpoint      — Schedule server state & future calls │
│  • SyncEndpoint          — Real-time stream (WebSockets)        │
│  • RecordingEndpoint     — Optional opt-in audio upload         │
│                                                                 │
│  Data Models (YAML relations):                                  │
│  • InboxItem (redactedTranscript, tags, priority, dueDate...)   │
│  • Reminder (relation: inboxItem, triggerAt, isFired)           │
│  • Recording (opt-in relation: inboxItem, storageUrl)           │
│                                                                 │
│  Serverpod Features:                                            │
│  • ORM with 1:1 and 1:N relations & migrations                  │
│  • Session-authenticated security scoping                       │
│  • Real-time data streaming (WebSockets)                        │
│  • Future calls (server reminder state)                         │
│  • Local push notifications via flutter_local_notifications     │
│                                                                 │
│  Database: PostgreSQL                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. On-Device AI Pipeline (Detail)

The entire speech-to-intent pipeline executes **100% on-device**. Raw audio files and original unredacted transcripts stay on the local device and are never broadcasted to the backend.

### Step 1: Audio Capture (Tap-to-Toggle)
- User taps the microphone button to start recording.
- Tap again to finish recording (eliminates finger-fatigue and pointer-capture issues across mobile and web).
- Audio is captured in a standard format (e.g. 16kHz WAV/AAC).

### Step 2: On-Device Speech Transcription (Needle Whistle — P0)
- Uses Cactus Needle's built-in `needle.transcribe()` (Whistle) engine across platforms.
- Eliminates brittle per-platform speech SDK bridging during P0.
- Handles utterances up to 30s directly (with automatic 30s chunking for longer notes).
- Yields the local **raw transcript**.

### Step 3: Intent Routing & Extraction (Cactus Needle — P0)
- The raw transcript is passed directly to the Needle tool-calling engine with full entity context intact (e.g. proper names, addresses, contacts).
- Needle matches the utterance to one or more predefined tools:
  - `add_task(title, priority, due_date, assignee)`
  - `add_note(title, body, topic)`
  - `add_reminder(title, remind_at, recurring)`
  - `add_shopping_item(item, quantity, store)`
  - `log_idea(title, description)`
- **Multi-call handling:** Spike tests whether Needle handles multi-calls natively (e.g., "buy eggs, milk, and bread" $\rightarrow$ 3 `add_shopping_item` calls). If unsupported, the client splits composite utterances on conjunctions prior to routing.

### Step 4: Deterministic Date & Time Resolution (P0)
- LLMs/tool callers output relative time strings (e.g., `"tomorrow 3pm"`, `"Friday"`, `"in 2 hours"`).
- An on-device deterministic date resolver parses relative strings into absolute UTC/local `DateTime` instances based on the device's clock and local timezone.
- This ensures reminders and task due dates are valid before persisting.

### Step 5: Privacy Redaction (Desertant Redact — P0 Payload Prep)
- **Pipeline Order Guarantee:** Redaction runs **after** Needle extraction so that Needle has full context to extract names, addresses, and emails into structured fields if needed.
- `Desertant Redact` strips PII (phone numbers, emails, SSNs, credit cards) from the transcript text bound for the server (`redactedTranscript`).
- `originalTranscript` is retained **strictly in local storage** on the device.

### Step 6: Metadata Enrichment (P1)
- **Desertant Gist (P1):** Topic classification for tags (`work`, `groceries`, `finance`).
- **Desertant Emo (P1):** Visual shorthand emoji suggestion.

### Step 7: Schema-Based Gating & Auto-Save Countdown
- Instead of relying on an unverified confidence score float from Needle:
  - **Valid Schema:** If Needle returns a recognized tool name with required arguments successfully parsed $\rightarrow$ Present the parsed confirmation card with an active **3-second auto-save countdown**. The user can tap "Edit" or "Cancel", or let it auto-commit to the inbox.
  - **Invalid / Ambiguous Schema:** If arguments are missing or parsing fails $\rightarrow$ Pause auto-save, display the card in "Edit Required" mode with fields highlighted for manual completion.
  - **Empty / Inaudible:** Display a gentle "Couldn't catch that. Tap to try again." toast.

---

## 7. Serverpod Backend (Detail)

### 7.1 Data Models (YAML with Formal Relations)

```yaml
# inbox_item.yaml
class: InboxItem
table: inbox_items
fields:
  userId: int # Populated strictly on the server from session.authenticated.userId
  type: String # task, note, reminder, shopping, idea
  title: String
  body: String?
  tags: List<String>?
  priority: String? # low, medium, high
  emoji: String?
  dueDate: DateTime?
  redactedTranscript: String # Privacy: only sanitized text stored on server
  isCompleted: bool
  completedAt: DateTime?
  confidence: double? # Optional schema validity / score if available
  createdAt: DateTime
  reminder: Reminder?, relation
  recording: Recording?, relation
indexes:
  inbox_user_idx:
    fields: userId
  inbox_type_idx:
    fields: type
  inbox_created_idx:
    fields: createdAt

# reminder.yaml
class: Reminder
table: reminders
fields:
  inboxItemId: int
  inboxItem: InboxItem?, relation(field=inboxItemId)
  triggerAt: DateTime
  recurring: String # none, daily, weekly
  isFired: bool
  createdAt: DateTime
indexes:
  reminder_trigger_idx:
    fields: triggerAt

# recording.yaml (Opt-in only)
class: Recording
table: recordings
fields:
  inboxItemId: int
  inboxItem: InboxItem?, relation(field=inboxItemId)
  storageUrl: String
  durationMs: int
  createdAt: DateTime
```

### 7.2 Endpoints & Security Scoping

All endpoints require active session authentication (`requireLogin: true`). The server **never** trusts a client-supplied `userId`.

```dart
// inbox_endpoint.dart
class InboxEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  // Create an inbox item; userId is set strictly from session
  Future<InboxItem> createItem(Session session, InboxItem item) async {
    final userId = (await session.authenticated)?.userId;
    if (userId == null) throw EndpointException('Unauthorized');
    
    // Enforce server-side ownership & strip any spoofed IDs
    final secureItem = item.copyWith(userId: userId, createdAt: DateTime.now());
    return await InboxItem.db.insertRow(session, secureItem);
  }

  // List items strictly scoped to the authenticated user
  Future<List<InboxItem>> listItems(Session session, {String? type, int? limit, int? offset}) async {
    final userId = (await session.authenticated)?.userId;
    return await InboxItem.db.find(
      session,
      where: (t) => t.userId.equals(userId) & (type != null ? t.type.equals(type) : Constant.bool(true)),
      orderBy: (t) => t.createdAt,
      orderDescending: true,
      limit: limit ?? 50,
      offset: offset ?? 0,
    );
  }

  // Complete an item belonging to the session user
  Future<InboxItem> completeItem(Session session, int itemId) async {
    final userId = (await session.authenticated)?.userId;
    final item = await InboxItem.db.findById(session, itemId);
    if (item == null || item.userId != userId) throw EndpointException('Not found');
    return await InboxItem.db.updateRow(session, item.copyWith(isCompleted: true, completedAt: DateTime.now()));
  }

  // Delete an item belonging to the session user
  Future<bool> deleteItem(Session session, int itemId) async {
    final userId = (await session.authenticated)?.userId;
    final item = await InboxItem.db.findById(session, itemId);
    if (item == null || item.userId != userId) return false;
    await InboxItem.db.deleteRow(session, item);
    return true;
  }
}

// sync_endpoint.dart
class SyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  // Real-time stream of inbox events for cross-device sync
  Stream<InboxItem> streamInbox(Session session) async* {
    final userId = (await session.authenticated)?.userId;
    // Listen to user-specific session stream
    yield* session.messages.createStream<InboxItem>('user_$userId');
  }
}
```

### 7.3 Reminders & Notifications Architecture
- Serverpod **Future Calls** are utilized to maintain backend schedule states (e.g., auto-marking `isFired = true` or generating server audit events).
- Client-side alerting is executed via `flutter_local_notifications` for high-reliability, native alarms without requiring third-party push notification services during the hackathon.

---

## 8. Flutter App — Screens & UX

### 8.1 Screens

#### Screen 1: Auth (Login / Sign Up)
- Built using Serverpod's `serverpod_auth_email_flutter` UI or minimal clean forms connected to the Serverpod auth module.

#### Screen 2: Inbox Feed (Main Screen)
- **Header:** Filter chips — `All` | `Tasks` | `Notes` | `Reminders` | `Shopping` | `Ideas`.
- **Feed:** Scrollable cards displaying:
  - Emoji badge + Structured Title
  - Item Type pill with color coding
  - Tags as compact chips
  - Due date / reminder time formatted
  - Swipe right $\rightarrow$ Complete; Swipe left $\rightarrow$ Delete
- **Bottom Capture Bar:** Prominent microphone button with **Tap-to-Toggle** interaction:
  - Tap once $\rightarrow$ Recording begins (pulsing indicator).
  - Tap again $\rightarrow$ Processing starts.
  - Confirmation card slides up: Shows extracted fields with an **animated 3-second auto-save progress bar**.
  - User can tap "Cancel" or "Edit" to modify fields before saving.

#### Screen 3: Item Detail
- Local original transcript view (retrieved from local storage) alongside the redacted transcript.
- Editable fields (title, body, tags, due date).
- Action buttons: Delete / Complete / Reschedule.

### 8.2 UX Flow (Frictionless Capture)

```
Tap 🎤 → Speak → Tap 🎤 to Stop → [Processing <1s] → Card slides up with 3s auto-save timer → Auto-commits to feed
```

### 8.3 Visual System
- Dark mode primary.
- Distinct color taxonomy:
  - Tasks: Electric Blue (`#3B82F6`)
  - Notes: Emerald Green (`#10B981`)
  - Reminders: Amber Orange (`#F59E0B`)
  - Shopping: Purple (`#8B5CF6`)
  - Ideas: Sun Yellow (`#EAB308`)

---

## 9. Tech Stack & Integration Surface

| Layer | Technology | Role |
|---|---|---|
| **Frontend** | Flutter (Dart) | Cross-platform client UI & local database |
| **Backend** | Serverpod (Dart 3) | Full-stack server, ORM, migrations, streaming |
| **Database** | PostgreSQL | Relational backend persistence |
| **Transcription (P0)** | Cactus Needle Whistle | Single cross-platform on-device speech engine |
| **Intent Routing (P0)** | Cactus Needle | On-device tool calling & structured extraction |
| **Date Parsing (P0)** | Deterministic Date Resolver | On-device relative-to-absolute DateTime parser |
| **Privacy (P0)** | Desert Ant Labs Redact | On-device PII stripping before server sync |
| **Enrichment (P1)** | Desert Ant Labs Gist & Emo | Auto-tagging & emoji assignment |
| **Notifications (P1)** | `flutter_local_notifications` | Native on-device reminder alerts |
| **Authentication** | Serverpod Auth Module | Built-in email/password authentication |

### Platform Target Strategy
- **Primary Target:** Select **one platform first**.
  - **Option A (Flutter Web):** Uses Desertant JS SDKs + Needle WASM without platform channels or native C compilation. *Must be spiked in Task 1 for model download sizes and browser microphone compatibility.*
  - **Option B (Desktop / Android via dart:ffi):** Native C library binding (`libneedle.so` or desktop library) as an immediate fallback if Web audio APIs or WASM present constraints.

---

## 10. Third-Party Model & SDK Verification Strategy

All third-party SDK and model claims are subject to verification in the **Day 1 Spike** before building dependent architecture:

1. **Needle Whistle (`needle.transcribe()`):** Validate STT latency, memory footprint, and English transcription accuracy across sample test audio.
2. **Needle Tool-Calling Engine:** Validate that tool schemas compile, return valid JSON/arguments, and handle multi-calls cleanly.
3. **Desertant Redact:** Validate that PII is masked cleanly without damaging core sentence semantics.

---

## 11. MVP Scope Hierarchy

### Critical Spike & P0 (Days 1–4) — Demo Foundation
- [ ] Critical path spike: Audio capture $\rightarrow$ Whistle transcribe $\rightarrow$ Needle tool-calling.
- [ ] Deterministic date resolver (converts "tomorrow 3pm", "Friday" $\rightarrow$ `DateTime`).
- [ ] Desertant Redact (strip PII before server sync).
- [ ] Serverpod YAML models with formal relations (`InboxItem`, `Reminder`).
- [ ] Serverpod session-scoped secure `InboxEndpoint` CRUD.
- [ ] Flutter UI: Auth, Inbox feed, Filter chips, Tap-to-toggle record button.
- [ ] Confirmation card with 3-second auto-save countdown.
- [ ] Swipe to complete & swipe to delete.

### Should Have (P1) (Days 5–6) — Polish & Live Sync
- [ ] Serverpod real-time WebSocket stream (`streamInbox`) for multi-device sync.
- [ ] Desertant Gist (auto-tagging topics) & Emo (auto-emoji assignment).
- [ ] Local push notifications via `flutter_local_notifications` for scheduled reminders.
- [ ] Opt-in voice recording upload (`RecordingEndpoint`).

### Nice to Have / Cut (P2)
- [ ] Desertant Clear (speech enhancement) — Cut from MVP.
- [ ] Desertant Uhm (filler stripping) — Cut (Swift-only).
- [ ] Serverpod in-memory stats cache & analytics dashboard.

---

## 12. Day-by-Day Build Plan

| Milestone | Period | Deliverable |
|---|---|---|
| **Days 1–2 (Oct 7–8)** | **Critical-Path Spike** | Bare Flutter app (no backend, no UI polish): record audio $\rightarrow$ transcribe via Whistle $\rightarrow$ Needle returns tool call. Validate (a) confidence/schema validity, (b) multi-call routing, (c) 5 demo utterances. Confirm platform viability (Web vs Desktop/Android). |
| **Days 2–4 (Oct 8–10)** | **Backend & Core UI** | Serverpod models with ORM relations, session-scoped endpoints, migrations, Serverpod auth. Flutter inbox feed, filter chips, item cards, swipe gestures, tap-to-toggle audio capture UI, and deterministic date resolver. |
| **Days 5–6 (Oct 11–12)** | **End-to-End Pipeline & P1** | Connect full pipeline: speak $\rightarrow$ Whistle $\rightarrow$ Needle $\rightarrow$ Date Resolver $\rightarrow$ Redact $\rightarrow$ Serverpod. Add Serverpod WebSocket stream, local notifications for reminders, Gist & Emo. |
| **Day 7 (Oct 13)** | **Polish & Submission Prep** | Bug fixing, multi-client sync verification, record <2-minute demo video, write README with setup instructions, finalize submission text. |
| **Submission Day (Oct 14)** | **Final Submission** | Submit before **23:59 CEST** (which is **03:29 IST, Oct 15** local time). |

---

## 13. Demo Video Script (< 2 minutes)

```
[0:00-0:15] Hook & Concept:
            "This is Triage. An on-device voice inbox that turns speech into structured, actionable items instantly."

[0:15-0:35] Demo 1: Task & Reminder with Date Resolution:
            • Tap mic: "Remind me to call the dentist tomorrow at 3pm"
            • Tap to stop → <1s processing
            • Confirmation card shows: Reminder, "Call the dentist", resolved date tomorrow at 3:00 PM.
            • Auto-save 3-second countdown finishes → Pops into inbox feed.

[0:35-0:55] Demo 2: Shopping Multi-Item Extraction:
            • Tap mic: "Buy eggs, milk, and bread from Whole Foods"
            • Three distinct shopping items appear categorized under "Shopping".

[0:55-1:15] Demo 3: Note with Decisions & Privacy Redaction:
            • Tap mic: "The client meeting went well, they approved the Q4 budget"
            • Note card appears with title and body.
            • Show privacy guarantee: Local client holds raw transcript; Serverpod payload has PII redacted.

[1:15-1:30] Interaction & Organization:
            • Filter feed by "Reminders", swipe right to complete a task, swipe left to delete.

[1:30-1:45] Serverpod Real-Time Live Sync (Two Clients):
            • Record an item on Device A (mobile).
            • Instantly watch it appear on Device B (laptop web tab) via Serverpod WebSocket stream.
            • Highlight Serverpod Auth, ORM relations, and streaming architecture.

[1:45-2:00] Closing:
            • "Zero cloud AI subscriptions. Private on-device processing. Full-stack Dart with Serverpod."
            • Repo URL & Hackathon credits.
```

---

## 14. Risk Assessment & Mitigations

| Risk | Impact | Mitigation Strategy |
|---|---|---|
| Needle Whistle or WASM compilation fails in Flutter Web | High | Spike immediately in Days 1–2. If Web audio or WASM fails, fall back immediately to Desktop (macOS/Windows) or Android via `dart:ffi`. |
| Needle lacks confidence score or returns malformed args | Medium | Gate on strict schema validity (valid tool name, required args present) rather than floating confidence scores. |
| Multi-call routing unsupported in single utterance | Medium | Detect composite conjunctions ("and", "also", comma lists) and split client-side into individual tool calls before dispatching to Needle. |
| Date parsing fails on informal dates ("Friday", "in 2 hours") | High | Build and unit-test a deterministic on-device regex/DateTime resolver (P0) during Days 2–3. |
| Tight 7-day schedule | High | Strict P0 scope. Desertant Clear and Uhm are removed from MVP; focus solely on Whistle + Needle + Serverpod CRUD + WebSockets. |

---

## 15. Success Criteria

1. ✅ Full-stack Flutter + Serverpod working architecture with session authentication.
2. ✅ On-device transcription and tool-calling parses speech into 5 structured item types.
3. ✅ PII redacted on-device prior to Serverpod persistence.
4. ✅ Two-client real-time synchronization demonstrated via Serverpod WebSocket streams.
5. ✅ Strict server-side security (session-scoped ownership on all database operations).
6. ✅ Clear <2-minute demo video demonstrating the full pipeline and real-time sync.

---

## 16. Appendix: Daily Validation Utterances

These six test phrases must be tested against the pipeline daily:
1. `"Remind me to call the dentist tomorrow at 3pm"` $\rightarrow$ `add_reminder` (resolved to tomorrow 15:00)
2. `"Buy eggs, milk, and bread from Whole Foods"` $\rightarrow$ `add_shopping_item` (multi-item)
3. `"The client meeting went well, they approved the Q4 budget"` $\rightarrow$ `add_note`
4. `"Fix the login bug by Friday, high priority"` $\rightarrow$ `add_task` (priority: high, due: Friday)
5. `"What if we made the onboarding a game?"` $\rightarrow$ `log_idea`
6. Messy speech with fillers: `"Um, so, email Sarah about the proposal, and oh, grab milk"` $\rightarrow$ Composite routing

---

### Review & Audit of Task 1 (Critical-Path Spike)

I have reviewed the deliverables:
- **Spike Harness & Documentation**: [spike/README.md](file:///D:/Programming/Experimentation/ServerPod/spike/README.md)
- **Detailed Findings & Diagnostics**: [docs/SPIKE_RESULTS.md](file:///D:/Programming/Experimentation/ServerPod/docs/SPIKE_RESULTS.md)

---

### 1. Verification Against Task 1 Criteria

| Requirement | Status | Audit Notes |
|---|---|---|
| **Platform Selection & Harness** | **PASSED** | Flutter Web + official Needle WASM verified locally with zero remote network requests post-setup. Bundle size (~53.2 MB models/WASM, ~169 MiB linear memory) is manageable locally. |
| **Microphone & Audio STT** | **PASSED** | Needle Whistle (`needle_transcribe`) verified on 16 kHz audio. Resampling pipeline works; STT latency was ~1.5–2.7s for 3–6s clips. |
| **(a) Confidence Head Output** | **PASSED** | **Yes.** Needle exposes a numeric `confidence` score (ranging from 0.0052 to 0.2972). Confirmed that scores below 0.10 are routed to `suppressed_calls`. |
| **(b) Multi-Call Handling** | **PASSED (with caveat)** | Native multi-call exists (3 shopping calls generated), but all were suppressed, collapsed quantity to `"bread"`, and dropped the store name. Client-side extraction or schema tuning will be needed for clean shopping parsing. |
| **(c) Daily Utterances Benchmark** | **PASSED (Crucial Finding)** | Exact JSON outputs captured for all 6 phrases. **Only 1/6 (Reminder)** emitted an actionable, non-suppressed call (`confidence: 0.2972`). Notes and ideas were misrouted as `add_task`. |

---

### 2. Monitor Verdict & Architectural Adjustments

The agent executed this spike with thoroughness and intellectual honesty. The findings prevent a critical demo failure:

1. **Auto-Save Pivot**: We **must not** auto-save on raw schema validity alone. If `confidence < 0.1` or the call is in `suppressed_calls`, the UI must show the **Review / Edit Required** card rather than auto-saving.
2. **Date Resolution is Essential**: Utterance 1 successfully extracted `{"remind_at": "tomorrow at 3pm"}`. Without our deterministic date parser, this string cannot be scheduled into Serverpod or local notifications.
3. **Task 1 is APPROVED**. We are ready for **Task 2**.

---

### 3. Task Briefing for Your Coding Agent: Task 2

Here is the prompt for your coding agent to implement **Task 2 (Deterministic Date Resolver)**:

```markdown
### TASK BRIEFING: Task 2 — Deterministic On-Device Date Resolver (P0)

#### Objective
Build a robust, standalone, deterministic Dart date and time resolution module (`DateResolver`) that converts relative human temporal expressions into exact `DateTime` instances based on the device clock and local timezone.

This module will bridge the output of Needle tool-calling (such as `remind_at: "tomorrow at 3pm"` or `due_date: "Friday"`) into the strict `DateTime` expected by Serverpod and `flutter_local_notifications`.

---

#### Scope & Requirements

1. **Expressions to Support**:
   - **Relative Days**:
     - `"today at 5pm"`, `"today 17:00"`
     - `"tomorrow at 3pm"`, `"tomorrow 3 p.m."`, `"tomorrow 9am"`
     - `"day after tomorrow at 10am"`
   - **Day of Week**:
     - `"Friday"`, `"this Friday at 4pm"`, `"next Monday at 9am"`
     - *(Rule: If today is Wednesday and the input is "Friday", resolve to the upcoming Friday; if the specified time on that day is already past, resolve to next week)*
   - **Relative Durations**:
     - `"in 2 hours"`, `"in 30 minutes"`, `"in 1 day"`
   - **Specific Dates**:
     - `"October 14 at 10am"`, `"14th Oct 3pm"`
   - **Default Time Handling**:
     - When a date is mentioned without a time (e.g., `"Friday"` or `"tomorrow"`), apply a sensible product default (e.g., 09:00 AM or 18:00 PM) and flag it in the returned result.

2. **API Contract**:
   Create a clean, self-contained Dart class (e.g. `lib/core/date_resolver.dart`):
   ```dart
   class ResolvedDate {
     final DateTime dateTime;
     final bool hasExplicitTime; // true if hour/minute was parsed, false if defaulted
     final String matchedText;
     ...
   }

   class DateResolver {
     static ResolvedDate? resolve(String input, {DateTime? referenceTime, String? timeZoneName});
   }
   ```

3. **Deterministic Testing & Safety**:
   - Provide comprehensive unit tests (`test/date_resolver_test.dart`) covering:
     - Edge cases (month boundaries, leap years, year rollover).
     - Normalized variants (e.g. `"3pm"`, `"3 p.m."`, `"3:00 PM"`, `"15:00"`).
     - Exact inputs from the benchmark: `"tomorrow at 3pm"`, `"Friday"`.
     - Invalid / non-date strings returning `null` gracefully without throwing exceptions.

---

#### Deliverables
1. Implementation file (pure Dart, zero unnecessary dependencies, compatible with Flutter Web/Desktop/Mobile).
2. Comprehensive unit test suite with 100% passing tests.
3. Summary of supported patterns and test results.
```

---

Pass this prompt to your coding agent. Once the agent submits the code and test run, we will audit the test coverage and boundary conditions together before approving **Task 3 (Serverpod Backend)**!

---

### Review & Audit of Task 2 (Deterministic Date Resolver)

I have audited the implementation in [spike/lib/core/date_resolver.dart](file:///D:/Programming/Experimentation/ServerPod/spike/lib/core/date_resolver.dart) and its documentation in [docs/DATE_RESOLVER.md](file:///D:/Programming/Experimentation/ServerPod/docs/DATE_RESOLVER.md).

---

### 1. Verification Against Task 2 Criteria

| Requirement | Status | Audit Notes |
|---|---|---|
| **Expressions Supported** | **PASSED** | Relative days (`today`, `tomorrow`, `day after tomorrow`), weekdays (`Friday`, `this Friday at 4pm`, `next Monday at 9am`), durations (`in 2 hours`, `in 30 mins`), and month dates (`October 14 at 10am`) all parse accurately. |
| **Punctuation & Variants** | **PASSED** | STT speech artifacts and clock formats (`3pm`, `3 p.m.`, `15:00`, `3:00 PM`) normalize cleanly. |
| **Default Time & Flags** | **PASSED** | Date-only inputs correctly default to 09:00 with `hasExplicitTime: false` / `usedDefaultTime: true`. |
| **DST & Timezone Integrity** | **PASSED** | Civil calendar arithmetic prevents DST 1-hour offset drift. Rejects ambiguous/gap DST times without throwing. |
| **Zero Dependencies** | **PASSED** | Pure `dart:core` implementation. Zero third-party dependencies, highly portable. |
| **Test Coverage & Safety** | **PASSED** | **164/164 unit tests** passed on Dart VM + **65/65 browser checks** across 5 timezones. Static analyzer clean (0 warnings). |

---

### 2. Monitor Verdict

The `DateResolver` is production-ready, bulletproof, and fulfills the P0 requirement for handling temporal arguments from Needle.

**Task 2 is APPROVED.** We now proceed to **Task 3: Serverpod Backend Scaffolding & ORM Relations**.

---

### 3. Task Briefing for Your Coding Agent: Task 3

Here is the prompt for your coding agent to implement **Task 3**:

```markdown
### TASK BRIEFING: Task 3 — Serverpod Backend Scaffolding, Models with Relations & Secure Endpoints (Days 2–4)

#### Context & Objectives
You are now building the backend foundation for **Triage** using Serverpod.
Refer to `docs/PRD.md` (Section 7) and `docs/PROJECT_PLAN.md`.
Your objectives:
1. Scaffold/initialize the Serverpod project structure (server, client, and shared models).
2. Define the YAML models with formal Serverpod ORM relations and privacy guarantees.
3. Integrate Serverpod Auth (do NOT write a custom AuthEndpoint).
4. Implement session-scoped, secure endpoints for Inbox and Real-Time Sync.

---

#### Scope & Requirements

1. **Serverpod Scaffolding & Version Check**:
   - Verify the installed Serverpod CLI and dependencies.
   - Scaffold the Serverpod project if not already present (e.g., `triage_server`, `triage_client`, `triage_flutter`, or unified workspace structure).
   - Check the `serverpod_auth` module user ID type (`int` vs `UuidValue`) and align all foreign key types accordingly.

2. **Data Models with Relations (YAML)**:
   - **`InboxItem` (`inbox_item.yaml`)**:
     - `userId`: matching auth user ID type.
     - `type`: `String` (`task`, `note`, `reminder`, `shopping`, `idea`).
     - `title`: `String`.
     - `body`: `String?`.
     - `tags`: `List<String>?`.
     - `priority`: `String?` (`low`, `medium`, `high`).
     - `emoji`: `String?`.
     - `dueDate`: `DateTime?`.
     - `redactedTranscript`: `String`.
     - ⚠️ **PRIVACY RULE:** Do **NOT** include `originalTranscript` in the server model. It stays strictly local on the client.
     - `isCompleted`: `bool`.
     - `completedAt`: `DateTime?`.
     - `confidence`: `double?` (nullable, reflecting Spike findings).
     - `createdAt`: `DateTime`.
     - Relations:
       - `reminder`: `Reminder?`, relation.
       - `recording`: `Recording?`, relation.
     - Indexes on `userId`, `type`, `createdAt`.
   - **`Reminder` (`reminder.yaml`)**:
     - `inboxItemId`: `int` (or matching ID type).
     - `inboxItem`: `InboxItem?`, relation(field=inboxItemId).
     - `triggerAt`: `DateTime`.
     - `recurring`: `String` (`none`, `daily`, `weekly`).
     - `isFired`: `bool`.
     - `createdAt`: `DateTime`.
     - Index on `triggerAt`.
   - **`Recording` (`recording.yaml`)** (Opt-in audio storage):
     - `inboxItemId`: `int`.
     - `inboxItem`: `InboxItem?`, relation(field=inboxItemId).
     - `storageUrl`: `String`.
     - `durationMs`: `int`.
     - `createdAt`: `DateTime`.

3. **Code Generation & Migrations**:
   - Run `serverpod generate` to generate Dart model classes and client code.
   - Create initial database migration (`serverpod create-migration`).

4. **Security & Session Scoping (Endpoints)**:
   - **No custom `AuthEndpoint`**: Enable the official `serverpod_auth` module.
   - **`InboxEndpoint` (`inbox_endpoint.dart`)**:
     - Must enforce `requireLogin => true`.
     - `createItem`: **Never trust client-supplied `userId`**. Explicitly extract `userId` from `(await session.authenticated)?.userId` and stamp it onto the item before insertion.
     - `listItems`: Filter strictly by the authenticated `userId`. Support optional `type` filter, `limit`, and `offset`.
     - `completeItem`: Verify item belongs to authenticated `userId`; update `isCompleted = true` and `completedAt`.
     - `deleteItem`: Verify item belongs to authenticated `userId` before deleting.
   - **`SyncEndpoint` (`sync_endpoint.dart`)**:
     - Must enforce `requireLogin => true`.
     - Implement real-time user-scoped streaming (`session.messages.createStream`) to broadcast created/updated/deleted items to all connected client sessions of that user.

5. **Future Calls for Reminders**:
   - Create a future call hook (`ReminderFutureCall`) to manage server-side reminder state transitions (e.g. marking `isFired = true`).

---

#### Verification & Deliverables
1. Generated models and migrations verifying formal ORM relations.
2. Endpoint implementations with zero security leaks (session-scoped ownership verified).
3. Automated integration/unit test suite testing:
   - Unauthenticated access rejection (`requireLogin`).
   - Session-scoped CRUD (User A cannot read, update, or delete User B's items).
   - Server-side `userId` assignment on `createItem`.
   - Real-time streaming message delivery.
4. Summary document in `docs/SERVERPOD_SETUP.md` detailing architecture, endpoints, and migration status.
```

---

Pass this prompt to your coding agent. When the agent completes Task 3, we will audit the security boundaries, ORM relations, and migration consistency together!


---

Here is the prompt for your coding agent to implement **Task 5 (The Final End-to-End Pipeline & Live Phone Integration)**:

---

```markdown
### TASK BRIEFING: Task 5 — End-to-End Pipeline Wiring, On-Device Redact & Live Two-Client Demo (Days 5–6)

#### Context & Objectives
You are building the final technical integration milestone for **Triage**.
Refer to `docs/PRD.md`, `docs/PROJECT_PLAN.md`, `docs/SPIKE_RESULTS.md`, `docs/DATE_RESOLVER.md`, `docs/SERVERPOD_SETUP.md`, and `docs/FLUTTER_UI.md`.

In this task, connect all individual modules into one seamless, working pipeline:
1. Complete Voice Capture → Whistle STT → Needle Tool-Calling → DateResolver → On-Device PII Redaction → Serverpod persistence.
2. Enable real-time WebSocket live sync (`sync.streamInbox`) across two active clients (e.g., Physical Phone + Laptop Chrome tab).
3. Integrate on-device PII redaction (`Desertant Redact` / local PII sanitizer) ensuring the privacy guarantee holds.
4. Schedule local alerts for reminders via `flutter_local_notifications`.
5. Provide turnkey documentation in `docs/PHONE_DEMO_GUIDE.md` for launching the backend and demoing live sync on a physical phone.

---

#### Scope & Requirements

1. **End-to-End Voice Capture Pipeline**:
   - Ensure the live interaction in `triage_flutter` runs the complete chain:
     ```
     Tap Mic → Record Audio → Needle Whistle STT → Needle Tool-Calling 
     → DateResolver (relative time to DateTime) 
     → PII Redaction on server payload 
     → Confirmation Card (3s auto-save if confidence >= 0.1, or Review Required if suppressed) 
     → Serverpod client.inbox.createItem() 
     → Live feed update
     ```
   - Retain `originalTranscript` strictly in local device storage (`SharedPreferences`).
   - Sync only `redactedTranscript` and structured arguments to the Serverpod backend.

2. **On-Device PII Redaction**:
   - Implement the on-device PII sanitizer (`lib/core/redact.dart` / Desert Ant Redact):
     - Masks emails, phone numbers, credit cards, SSNs, and street addresses.
     - **Execution order guarantee**: Runs **after** Needle extraction so Needle retains full contextual ability to extract proper nouns, tasks, and deadlines before the server sync payload is stripped.

3. **Two-Client Real-Time WebSocket Synchronization**:
   - Wire `sync.streamInbox()` in `triage_flutter`.
   - When User A records and saves an item on their Phone, the WebSocket stream must immediately push the typed `InboxEvent` to User A's Laptop browser session, rendering the card in real time without refreshing.
   - Live synchronization must handle item creation, completion (swipe right), and deletion (swipe left).

4. **Reminders & Local Notifications**:
   - Integrate `flutter_local_notifications` for on-device reminder scheduling:
     - When an `add_reminder` item is created with a resolved `DateTime`, schedule a local system alert.
     - Pair with the existing backend `ReminderFutureCall` that marks `isFired = true` in PostgreSQL.

5. **Local Network & Phone Deployment Setup**:
   - Ensure `triage_server` binds to `0.0.0.0` in development so devices on the local Wi-Fi can communicate with it.
   - Support passing the server URL via `--dart-define=SERVER_URL=http://<YOUR_PC_IP>:8080/`.
   - Provide a step-by-step connection guide in `docs/PHONE_DEMO_GUIDE.md`:
     - How to find PC LAN IP.
     - How to start PostgreSQL & Serverpod server (`serverpod start`).
     - How to run or install on the phone.
     - How to log in on two devices with the same account and see live sync in action.

6. **Daily Utterances Verification**:
   - Test and document end-to-end execution for the standard 6 test utterances:
     1. `"Remind me to call the dentist tomorrow at 3pm"` → Scheduled reminder with exact date.
     2. `"Buy eggs, milk, and bread from Whole Foods"` → Shopping review card.
     3. `"The client meeting went well, they approved the Q4 budget"` → Note with local raw vs server redacted text.
     4. `"Fix the login bug by Friday, high priority"` → Task with Friday due date and high priority.
     5. `"What if we made the onboarding a game?"` → Idea card.
     6. `"Um, so, email Sarah about the proposal, and oh, grab milk"` → Mixed capture.

---

#### Verification & Deliverables
1. Full end-to-end pipeline operating in `triage_flutter`.
2. Integration / widget tests verifying:
   - Voice audio → STT → Tool-call → Redact → Serverpod write cycle.
   - Real-time streaming synchronization across two client instances.
   - PII masking on outgoing payloads (no raw PII sent over the wire).
   - Local notification scheduling for resolved reminder timestamps.
3. Turnkey guide in `docs/PHONE_DEMO_GUIDE.md`.
4. All test suites passing with zero analyzer warnings.
```

---

Pass this prompt to your coding agent. Once Task 5 is completed, you and I will verify the live sync across two devices together!
