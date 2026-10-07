# Triage — Product Requirements Document

> **Voice-Driven Smart Inbox & Task Manager**
> Built for the "Build Something Real" Serverpod Hackathon (deadline: Oct 14, 2026)

---

## 1. Elevator Pitch

Speak your thoughts throughout the day. Triage listens, understands, and acts. "Email Sarah about the proposal" drafts an email. "Buy milk on the way home" adds a grocery item. "Meeting with the design team went well — we decided on the blue variant" creates a meeting note with the decision extracted. All speech processing and intent routing happen **on-device** — nothing leaves your phone until you say so.

Triage is a **Flutter app** with a **Serverpod backend**, powered by **Cactus Needle** for on-device tool-calling/extraction and **Desert Ant Labs** models for speech processing.

---

## 2. Problem Statement

People have dozens of micro-thoughts, tasks, and notes throughout the day. Capturing them means:
- Unlocking the phone, opening the right app, typing it out — friction kills most of them
- Existing voice assistants require cloud, are slow, and lack structured follow-through
- Notes end up scattered across 5 apps with no unified view

**Triage eliminates the friction:** one tap, speak, done. The AI figures out what you meant, routes it to the right bucket, and stores it with structure.

---

## 3. Target User

Solo professionals, freelancers, busy parents, students — anyone who has more thoughts than time to organize them. The person who currently texts themselves reminders.

---

## 4. Hackathon Strategy

### Judging Criteria Alignment

| Criterion (Weight) | How Triage Scores |
|---|---|
| **Does it work (30%)** | Core flow is tight: tap → speak → see it routed. One screen, one action. Very demoable in under 2 minutes. |
| **Use of Serverpod stack (25%)** | Auth (email/password), ORM with relations (User → Items with polymorphic types), real-time streams (inbox updates), task scheduling (reminders via future calls), caching, file uploads (voice recordings). |
| **Craft & technical creativity (25%)** | On-device AI pipeline is novel: Desertant speech → Needle tool-calling → structured routing. Privacy-first architecture. No cloud AI dependency. |
| **Usefulness (20%)** | Clear user, clear problem, immediate value from day one. |

### AI Disclosure (required by rules)
All AI tools used in development and in the app itself will be disclosed in the submission text description.

---

## 5. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│                                                                 │
│  ┌──────────┐   ┌──────────────┐   ┌─────────────────────────┐ │
│  │ Record UI │──▶│ Desertant    │──▶│ Cactus Needle           │ │
│  │ (FAB tap) │   │ Pipeline     │   │ Tool-calling & Extract  │ │
│  │           │   │              │   │                         │ │
│  │           │   │ • Clear      │   │ Routes to:              │ │
│  │           │   │   (enhance)  │   │ • add_task              │ │
│  │           │   │ • Voz        │   │ • add_note              │ │
│  │           │   │   (transcr.) │   │ • add_reminder          │ │
│  │           │   │ • Uhm        │   │ • add_shopping_item     │ │
│  │           │   │   (fillers)  │   │ • log_idea              │ │
│  │           │   │ • Redact     │   │                         │ │
│  │           │   │   (PII)      │   │ Extracts:               │ │
│  │           │   │ • Gist       │   │ • title, body, priority │ │
│  │           │   │   (topics)   │   │ • due date, tags        │ │
│  │           │   │ • Emo        │   │ • people, amounts       │ │
│  │           │   │   (emoji)    │   │                         │ │
│  └──────────┘   └──────────────┘   └────────────┬────────────┘ │
│                                                  │              │
│  ┌──────────────────────────────────────────────┐│              │
│  │              Inbox Feed UI                    ││              │
│  │  Tasks | Notes | Reminders | Shopping | Ideas ││              │
│  └──────────────────────────────────────────────┘│              │
└──────────────────────────────────────┬───────────┘              │
                                       │                          │
                          Serverpod Client (generated, type-safe) │
                                       │                          │
                                       ▼                          │
┌─────────────────────────────────────────────────────────────────┘
│                      Serverpod Backend
│
│  Endpoints:
│  • AuthEndpoint        — email/password sign-up & login
│  • InboxEndpoint       — CRUD for inbox items (tasks, notes, etc.)
│  • ReminderEndpoint    — schedule & manage reminders
│  • SyncEndpoint        — real-time stream of inbox changes
│  • RecordingEndpoint   — upload original voice recordings
│  • InsightsEndpoint    — stats (items/day, categories, streaks)
│
│  Data Models (YAML → generated Dart):
│  • User
│  • InboxItem (type, title, body, tags, priority, dueDate, emoji,
│               originalTranscript, createdAt, completedAt)
│  • Reminder (inboxItemId, triggerAt, recurring)
│  • Recording (inboxItemId, storageUrl, durationMs)
│
│  Serverpod Features Used:
│  • ORM with relations & migrations
│  • Authentication module
│  • Real-time data streaming (WebSockets)
│  • Future calls (reminder scheduling)
│  • File storage (voice recordings → S3/GCS)
│  • Caching (daily stats, recent items)
│  • Logging & Insights
│
│  Database: PostgreSQL
│
└─────────────────────────────────────────────────────────────────
```

---

## 6. On-Device AI Pipeline (Detail)

The entire AI pipeline runs **on-device** in the Flutter app. No audio or text is sent to any cloud AI service.

### Step 1: Audio Capture
- User taps the floating action button, speaks, releases
- Raw audio captured via Flutter's audio recorder

### Step 2: Speech Enhancement (Desertant — Clear)
- Clean up background noise, improve clarity
- Studio-quality sound from a noisy environment
- Platforms: Swift (iOS/macOS), Kotlin (Android), JS (Web/Node) — available everywhere

### Step 3: Speech Recognition (Desertant — Voz)
- Transcribe enhanced audio to text
- 10 minutes in ~2 seconds on iPhone
- Returns raw transcript

### Step 4: Filler Word Removal (Desertant — Uhm)
- Detect and strip "um", "uh", "like", "you know"
- Clean transcript for storage and display
- ⚠️ **Swift only** (iOS/macOS) — skip on Android/Web, use raw transcript there

### Step 5: PII Redaction (Desertant — Redact)
- Strip phone numbers, emails, SSNs, addresses before server sync
- Privacy guarantee: PII never leaves the device

### Step 6: Topic Tagging (Desertant — Gist)
- Auto-generate topic tags: "work", "groceries", "health", "finance"
- Used for filtering and insights

### Step 7: Emoji Suggestion (Desertant — Emo)
- Suggest a relevant emoji for the item's display card
- Visual shorthand in the inbox feed

### Step 8: Intent Routing & Extraction (Cactus Needle)
The cleaned transcript is passed to Needle with a defined toolset. Needle determines:
1. **Which tool to call** (what kind of inbox item this is)
2. **Structured arguments** (title, body, priority, due date, people, amounts)

```python
# Needle tool definitions (conceptual — will run on-device via native engine)

@needle.tool
def add_task(title: str, priority: Literal["low", "medium", "high"] = "medium",
             due_date: str = "", assignee: str = ""):
    "Create a task or to-do item with an optional deadline and assignee."

@needle.tool
def add_note(title: str, body: str, topic: str = ""):
    "Save a freeform note, observation, or thought."

@needle.tool
def add_reminder(title: str, remind_at: str, recurring: Literal["none", "daily", "weekly"] = "none"):
    "Set a reminder to do something at a specific time."

@needle.tool
def add_shopping_item(item: str, quantity: int = 1, store: str = ""):
    "Add an item to the shopping list."

@needle.tool
def log_idea(title: str, description: str = ""):
    "Capture a creative idea, feature request, or inspiration."
```

**Examples:**
| User says | Needle routes to | Extracted fields |
|---|---|---|
| "Remind me to call the dentist tomorrow at 3" | `add_reminder` | title: "Call the dentist", remind_at: "tomorrow 3pm", recurring: "none" |
| "Buy eggs and bread from Trader Joe's" | `add_shopping_item` × 2 | item: "eggs" / "bread", store: "Trader Joe's" |
| "Meeting with Sarah went great, we're going with the blue design" | `add_note` | title: "Meeting with Sarah", body: "Going with the blue design" |
| "Fix the login bug by Friday, high priority" | `add_task` | title: "Fix login bug", priority: "high", due_date: "Friday" |
| "What if we made the onboarding a game?" | `log_idea` | title: "Gamified onboarding", description: "Make the onboarding a game" |

### Step 9: Confidence Gating
```
confidence >= 0.7  →  auto-create the item, show confirmation toast
0.1 <= conf < 0.7  →  show the parsed item for user to confirm/edit
conf < 0.1 / empty →  "Couldn't understand that. Try again?"
```

---

## 7. Serverpod Backend (Detail)

### 7.1 Data Models (YAML)

```yaml
# inbox_item.yaml
class: InboxItem
table: inbox_items
fields:
  userId: int
  type: String          # task, note, reminder, shopping, idea
  title: String
  body: String?
  tags: List<String>?
  priority: String?     # low, medium, high
  emoji: String?
  dueDate: DateTime?
  originalTranscript: String
  redactedTranscript: String
  isCompleted: bool
  completedAt: DateTime?
  confidence: double     # Needle's confidence score
  createdAt: DateTime
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
  userId: int
  triggerAt: DateTime
  recurring: String     # none, daily, weekly
  isFired: bool
indexes:
  reminder_trigger_idx:
    fields: triggerAt

# recording.yaml
class: Recording
table: recordings
fields:
  inboxItemId: int
  storageUrl: String
  durationMs: int
  createdAt: DateTime
```

### 7.2 Endpoints

```dart
// inbox_endpoint.dart
class InboxEndpoint extends Endpoint {
  // Create a new inbox item from the on-device AI pipeline result
  Future<InboxItem> createItem(Session session, InboxItem item) async { ... }

  // List items for the authenticated user, with optional type filter
  Future<List<InboxItem>> listItems(Session session, {String? type, int? limit, int? offset}) async { ... }

  // Mark an item as completed
  Future<InboxItem> completeItem(Session session, int itemId) async { ... }

  // Delete an item
  Future<bool> deleteItem(Session session, int itemId) async { ... }

  // Get daily/weekly stats for the insights dashboard
  Future<InboxStats> getStats(Session session) async { ... }
}

// reminder_endpoint.dart
class ReminderEndpoint extends Endpoint {
  // Schedule a reminder using Serverpod's future calls
  Future<Reminder> scheduleReminder(Session session, Reminder reminder) async { ... }

  // Cancel a scheduled reminder
  Future<bool> cancelReminder(Session session, int reminderId) async { ... }
}

// sync_endpoint.dart
class SyncEndpoint extends Endpoint {
  // Real-time stream of inbox changes for cross-device sync
  Stream<InboxItem> streamInbox(Session session) async* { ... }
}

// recording_endpoint.dart
class RecordingEndpoint extends Endpoint {
  // Upload voice recording to cloud storage
  Future<Recording> uploadRecording(Session session, int inboxItemId, ByteData audioData) async { ... }
}
```

### 7.3 Serverpod Features Checklist

| Feature | Usage |
|---|---|
| **Authentication** | Email/password sign-up & login. Session-based. |
| **ORM + Relations** | InboxItem → Reminder (1:1), InboxItem → Recording (1:1), User → InboxItems (1:N) |
| **Migrations** | Auto-generated from YAML model changes |
| **Real-time Streams** | `streamInbox` pushes new items to all connected devices |
| **Future Calls** | Reminders scheduled as future calls, fire push notification |
| **File Storage** | Voice recordings uploaded to S3/GCS via Serverpod's storage API |
| **Caching** | Daily stats cached in-memory, invalidated on new item |
| **Logging** | All endpoint calls logged via Serverpod Insights |
| **Code Generation** | All client calls are generated, type-safe Dart |

---

## 8. Flutter App — Screens & UX

### 8.1 Screens

#### Screen 1: Auth (Login / Sign Up)
- Email + password
- Minimal — just get the user in

#### Screen 2: Inbox (Home)
- **Top:** Filter chips — All | Tasks | Notes | Reminders | Shopping | Ideas
- **Feed:** Scrollable list of inbox items, each card showing:
  - Emoji + Title
  - Type badge (color-coded)
  - Tags as chips
  - Priority indicator (for tasks)
  - Due date (if set)
  - Swipe right → complete, swipe left → delete
- **Bottom:** Floating Action Button (microphone icon)
  - Tap to start recording, release to stop
  - Shows processing animation while AI pipeline runs
  - Confirmation card slides up with parsed result
  - "Save" or "Edit" before saving

#### Screen 3: Item Detail
- Full transcript (original + cleaned)
- Editable structured fields
- Play back original recording
- Delete / Complete actions

#### Screen 4: Insights (optional, stretch goal)
- Items captured today / this week
- Breakdown by type (pie chart)
- Streak counter ("7 days of capturing")
- Most common tags

### 8.2 UX Flow (Core — 3 taps max)

```
Open app → Tap 🎤 → Speak → Release → [processing 1-2s] → Confirmation → ✓ Done
```

### 8.3 Design Language
- Clean, minimal, card-based
- Dark mode default
- Color-coded item types:
  - Tasks: Blue
  - Notes: Green
  - Reminders: Orange
  - Shopping: Purple
  - Ideas: Yellow
- Material 3 / Cupertino adaptive

---

## 9. Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter (Dart) — cross-platform |
| **Backend** | Serverpod (Dart) — full-stack framework |
| **Database** | PostgreSQL (via Serverpod ORM) |
| **Speech Processing** | Desert Ant Labs SDK (JS/Swift/Kotlin) — on-device |
| **Intent Routing** | Cactus Needle — on-device tool-calling (8-29MB) |
| **Structured Extraction** | Cactus Needle — on-device extraction |
| **Auth** | Serverpod Auth module |
| **Real-time** | Serverpod WebSocket streams |
| **Storage** | Serverpod file uploads (S3/local) |
| **Deployment** | Serverpod Cloud (or Docker for demo) |

### Third-Party SDKs & Integration Notes

**Desert Ant Labs:**
- Free up to 100K monthly active devices
- Available SDKs: Swift (iOS), Kotlin (Android), JavaScript (Web/Node)
- For Flutter: use platform channels to bridge to native SDKs, or JS SDK via dart:js_interop for web
- Models needed: Clear, Voz, Uhm, Redact, Gist, Emo (6 models)
- ⚠️ Platform availability varies per model:
  - **Clear**: Swift, Kotlin, JS ✅ (all platforms)
  - **Voz**: Swift, JS only ❌ (no Android native — use JS via WebView or Needle's Whistle as fallback)
  - **Uhm**: Swift only ❌ (iOS/macOS only — skip on Android/Web)
  - **Redact**: Swift, Kotlin, JS ✅
  - **Gist**: Swift, Kotlin, JS ✅
  - **Emo**: Swift, Kotlin, JS ✅

**Cactus Needle:**
- `pip install cactus-needle` for Python, or native engine via `needle build --platform <target>`
- For Flutter: use the native C library (`libneedle.a` / `libneedle.so`) via FFI (dart:ffi)
- Weights: `needle3.cact` (8-29MB depending on layer count)
- Supported: iOS, Android, macOS, Windows, Linux, WASM
- Tool definitions compiled into the app at build time

---

## 10. Integration Strategy for Flutter

### Desertant Models in Flutter
**Approach: Platform Channels → Native SDKs**

Platform availability varies per model — the table below shows what runs where:

| Model | iOS (Swift) | Android (Kotlin) | Web (JS) |
|-------|-------------|-------------------|----------|
| Clear | ✅ | ✅ | ✅ |
| Voz | ✅ | ❌ (use Needle Whistle) | ✅ |
| Uhm | ✅ | ❌ (skip) | ❌ (skip) |
| Redact | ✅ | ✅ | ✅ |
| Gist | ✅ | ✅ | ✅ |
| Emo | ✅ | ✅ | ✅ |

```
Flutter App
    │
    ├── iOS: Swift platform channel → Desertant Swift SDK
    │     Models: Clear, Voz, Uhm, Redact, Gist, Emo (all 6)
    │
    ├── Android: Kotlin platform channel → Desertant Kotlin SDK
    │     Models: Clear, Redact, Gist, Emo (4 of 6)
    │     Transcription: Cactus Needle Whistle (fallback for Voz)
    │
    └── Web: dart:js_interop → Desertant JS SDK (npm)
          Models: Clear, Voz, Redact, Gist, Emo (5 of 6)
```

**Fallback strategy for Android transcription:** Cactus Needle ships Whistle (`needle.transcribe()`), a speech model on the same engine. It covers 7 languages and handles up to 30s clips. For longer recordings, chunk the audio into 30s segments.

### Cactus Needle in Flutter
**Approach: dart:ffi → libneedle native library**

```
Flutter App
    │
    ├── Android: libneedle.so (android-arm64) via dart:ffi
    ├── iOS: libneedle.a (ios-arm64) via dart:ffi
    ├── macOS: libneedle.a (macos-arm64) via dart:ffi
    ├── Windows: libneedle.a (windows-x86_64) via dart:ffi
    └── Web: needle.wasm via dart:js_interop
```

Needle's C API (`needle.h`) exposes the complete/extract functions. We write a thin Dart FFI wrapper.

---

## 11. MVP Scope (Hackathon — 7 days)

### Must Have (P0) — Demo-ready
- [ ] Serverpod project setup with auth, ORM, migrations
- [ ] Data models: InboxItem, Reminder, Recording
- [ ] InboxEndpoint: create, list, complete, delete
- [ ] Flutter app: Auth screen, Inbox feed, FAB record button
- [ ] Audio recording in Flutter
- [ ] Desertant pipeline: Clear → Voz → Uhm (at minimum Voz for transcription)
- [ ] Needle tool-calling: 5 tools, route utterance to correct item type with structured fields
- [ ] Confidence-gated confirmation UI
- [ ] Items saved to Serverpod backend, displayed in feed
- [ ] Type-based filtering in inbox
- [ ] Swipe to complete / delete

### Should Have (P1) — Polish
- [ ] Desertant Redact (PII stripping)
- [ ] Desertant Gist (topic tagging)
- [ ] Desertant Emo (emoji on cards)
- [ ] Serverpod real-time stream (cross-device sync)
- [ ] Reminder scheduling via Serverpod future calls
- [ ] Voice recording upload & playback

### Nice to Have (P2) — Stretch
- [ ] Insights dashboard (stats, charts)
- [ ] Serverpod caching for stats
- [ ] Dark mode
- [ ] Offline queue (process on-device, sync when online)
- [ ] Multiple shopping lists

---

## 12. Day-by-Day Build Plan

| Day | Focus | Deliverable |
|---|---|---|
| **Day 1 (Oct 7)** | Project setup | Serverpod project scaffolded, models defined, migrations run, auth working, basic Flutter shell with navigation |
| **Day 2 (Oct 8)** | Backend endpoints | InboxEndpoint CRUD, ReminderEndpoint, generated client, endpoints tested |
| **Day 3 (Oct 9)** | Flutter UI | Inbox feed, filter chips, item cards, detail screen, swipe actions, FAB button |
| **Day 4 (Oct 10)** | Audio + Desertant | Audio recording, Desertant SDK integration (Voz transcription at minimum, Clear + Uhm if time) |
| **Day 5 (Oct 11)** | Needle integration | Needle native engine in Flutter via FFI, 5 tools defined, routing working end-to-end |
| **Day 6 (Oct 12)** | End-to-end + P1 | Full pipeline working: speak → transcribe → route → save → display. Add Redact, Gist, Emo. Real-time stream. |
| **Day 7 (Oct 13)** | Polish + video | Bug fixes, UI polish, edge cases, demo video recording (<2 min), submission text, build instructions |
| **Oct 14** | Submit | Final submission before 23:59 CEST |

---

## 13. Demo Video Script (< 2 minutes)

```
[0:00-0:10] "This is Triage — speak your thoughts, and AI routes them."
[0:10-0:25] Show sign-in, empty inbox
[0:25-0:45] Record: "Remind me to call the dentist tomorrow at 3pm"
             → Show processing animation
             → Show confirmation card: Reminder, "Call the dentist", tomorrow 3pm
             → Tap save, appears in inbox
[0:45-1:00] Record: "Buy eggs, milk, and bread from Whole Foods"
             → 3 shopping items appear
[1:00-1:15] Record: "The client meeting went well, they approved the Q4 budget"
             → Note with extracted topic tags: "work", "finance"
[1:15-1:30] Show filtering by type, swipe to complete a task
[1:30-1:45] Show the Serverpod backend: real data in Postgres, auth, streams
[1:45-1:55] "All AI runs on-device. No cloud. No subscription. Your thoughts stay yours."
[1:55-2:00] Logo + repo link
```

---

## 14. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Desertant SDK integration with Flutter is complex (platform channels) | High | Start with Voz only (transcription is the critical path). Add others incrementally. Fallback: use JS SDK in WebView. |
| Needle FFI integration is non-trivial | High | Start with Python prototype to validate tool definitions. Then port to native C via dart:ffi. Fallback: run Needle as a local Python sidecar process. |
| Audio recording quality varies | Medium | Clear (speech enhancement) handles this. If Clear integration is blocked, Voz still works on noisy audio. |
| Time pressure (7 days) | High | Strict P0/P1/P2 scope. Cut P1/P2 ruthlessly. A working demo with Voz + Needle + Serverpod CRUD is enough to score well. |
| Cross-platform differences | Medium | Target one platform first (Android or desktop), expand if time allows. |

---

## 15. Success Criteria

For the hackathon submission, Triage is successful if:

1. ✅ A user can sign up, sign in, and have a persistent account (Serverpod auth)
2. ✅ A user can tap a button, speak, and see their utterance processed by on-device AI
3. ✅ The utterance is correctly routed to one of 5 item types with structured fields extracted
4. ✅ The item is saved to the Serverpod backend and appears in the inbox feed
5. ✅ Items can be filtered by type, completed, and deleted
6. ✅ The demo video clearly shows all of the above in under 2 minutes
7. ✅ The README includes build/run instructions
8. ✅ All AI tool usage is disclosed in the submission description

---

## 16. Submission Checklist

- [ ] Working full-stack app (Flutter + Serverpod)
- [ ] Source code in repository (shared with judges)
- [ ] Text description of features, functionality, and how it was built
- [ ] AI tools disclosed (Desertant, Cactus Needle, any coding assistants)
- [ ] Build and run instructions in README
- [ ] Demo video < 2 minutes on YouTube/Vimeo
- [ ] No third-party trademarks or copyrighted music in video
