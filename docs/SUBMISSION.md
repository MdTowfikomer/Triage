# Hackathon submission copy

## Copy/paste submission text

```text
Project: Triage
Tagline: Catch the thought. Keep the context private.

Triage is a privacy-first, voice-driven inbox for the tasks, reminders, notes, shopping items, and ideas people capture throughout the day. Tap to speak, review a structured interpretation, and save it to one searchable inbox instead of switching between apps or losing the thought.

The Flutter client uses Cactus Needle Whistle for local transcription, Desert Ant Labs Redact to scrub text before backend routing, and a deterministic Dart date resolver. Serverpod's action funnel has Laya domain-decision and OpenAI-compatible tool-model adapters, with a populated deterministic fallback. Explicit app-opening commands use allowlisted Android intents; inbox captures use the review/save flow. Original transcripts stay in account-scoped device storage and are absent from server models. Serverpod 4 provides official email authentication, owner-scoped endpoints, relational PostgreSQL, typed real-time events and reminder future calls. Android schedules local reminder alerts; scheduled delivery is unsupported on Web.

Triage includes a custom dark inbox, review/edit flow, confidence-gated three-second save countdown, local draft recovery, generated Serverpod client, date tests and backend integration tests. The deterministic fallback prefills all six daily captures; mixed, negated, incomplete and uncertain requests stay in review. The original Needle benchmark is retained as historical evidence for why the routing architecture changed; it is not a measurement of Laya/LFM performance.

Verification: 59 Flutter tests and 65 backend unit/integration tests pass, with clean analyzers. The tests cover both model-adapter contracts, timeout fallback, app authorization, privacy-before-RPC, auth, owner isolation, persistence and same-user event delivery. The Whistle-only Android bridge transcribed prerecorded audio in Chromium without loading Needle 3. The client subscribes to `sync.streamInbox()` and reconciles create/update/delete events across active same-user sessions. Live Laya/LFM accuracy and latency have not been measured; the demo build uses the deterministic offline funnel.

Verification boundaries: no physical Android handset was attached, so live microphone permission, app launching and the phone-to-laptop sync demo remain acceptance checks. Browser Redact initialized LiteRT but its model-host listing returned HTTP 405 in the earlier smoke; it needs an accessible host before filming a privacy save. Routing and saves fail closed on redaction failure. No live model-service endpoint was configured during implementation.

Technology: Flutter and Dart; Cactus Needle / Needle Whistle; Desert Ant Labs Redact; Serverpod 4.0.4 official auth and generated client; PostgreSQL; WebSocket message streams; ORM relations; Serverpod future calls; `flutter_local_notifications` for native local alerts.

AI disclosure: Runtime components are Cactus Needle Whistle (local transcription), Desert Ant Labs Redact (local PII filtering) and configurable Laya/Liquid or OpenAI-compatible backend adapters for decisions/tool extraction. The unconfigured/demo path uses deterministic rules. Earlier Needle 3 spike evidence is retained separately. OpenAI Codex was used as a coding assistant. The team remains accountable for code, outputs, model limitations and submission claims.
```

## Before submitting

- Add the public repository URL and public video URL in their portal fields; confirm the repository includes setup instructions and assets.
- The event listing gives **October 14, 2026** as the submission deadline; check the registered event portal for the exact cutoff time and submission form. [Official event listing](https://luma.com/builde-mked).
- Add every coding assistant/generative tool actually used by the team to the AI disclosure.
- Complete the live-device, redaction-model, and two-client acceptance checks before filming feature claims; see [DEMO_SCRIPT.md](DEMO_SCRIPT.md) and [PHONE_DEMO_GUIDE.md](PHONE_DEMO_GUIDE.md).
