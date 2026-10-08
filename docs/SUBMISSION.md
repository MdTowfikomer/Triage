# Hackathon submission copy

## Copy/paste submission text

```text
Project: Triage
Tagline: Catch the thought. Keep the context private.

Triage is a privacy-first, voice-driven inbox for the tasks, reminders, notes, shopping items, and ideas people capture throughout the day. Tap to speak, review a structured interpretation, and save it to one searchable inbox instead of switching between apps or losing the thought.

The Flutter client uses Cactus Needle / Needle Whistle for on-device speech transcription and tool calling, a deterministic Dart resolver for relative dates, and Desert Ant Labs Redact to sanitize data locally before sync. The original transcript stays in account-scoped device storage and is deliberately absent from the Serverpod model. Serverpod 4 provides official email authentication, ownership-scoped endpoints, relational PostgreSQL models, typed real-time inbox events, and a reminder future-call hook. The Android shell can schedule native local reminder alerts; scheduled delivery is not supported by the selected notifications plugin on Web.

Triage includes a custom dark inbox, review/edit flow, confidence-gated three-second save countdown, local draft recovery, generated Serverpod client, deterministic date tests, backend integration tests, and the original Needle benchmark evidence. Suppressed or incomplete model calls stay in review rather than being silently promoted. In the pinned six-utterance benchmark, the dentist reminder was actionable; the other five were suppressed or misrouted, so the app keeps a manual review path instead of claiming reliable autonomous routing.

Verification: 46 Flutter client tests pass and the Flutter analyzer is clean; 41 Serverpod integration tests cover auth, user isolation, and same-user event delivery. The Flutter Web build and Needle browser inference harness have been verified. The Android release APK includes the voice models and passed a prerecorded-audio bridge smoke in Chromium; physical Android microphone/permission behavior remains to be checked. The client subscribes to `sync.streamInbox()` and reconciles create/update/delete events across active same-user sessions.

Verification boundaries: the physical phone-to-laptop WebSocket demo has not yet been run in this checkout. Browser Redact initializes LiteRT, but its model-host listing request returned HTTP 405 in the latest smoke test; model-backed browser redaction must be revalidated on an accessible host before filming a successful privacy save. The client fails closed when redaction fails. Android currently supports typed/manual capture and local notifications; native Android Needle voice inference remains follow-up work.

Technology: Flutter and Dart; Cactus Needle / Needle Whistle; Desert Ant Labs Redact; Serverpod 4.0.4 official auth and generated client; PostgreSQL; WebSocket message streams; ORM relations; Serverpod future calls; `flutter_local_notifications` for native local alerts.

AI disclosure: Runtime AI/model components are Cactus Needle / Needle Whistle (on-device transcription and tool calling) and Desert Ant Labs Redact (on-device PII filtering). OpenAI Codex was used as a coding assistant. The project team reviewed and remains accountable for the code, generated outputs, test evidence, model limitations, and submission claims.
```

## Before submitting

- Add the public repository URL and public video URL in their portal fields; confirm the repository includes setup instructions and assets.
- The event listing gives **October 14, 2026** as the submission deadline; check the registered event portal for the exact cutoff time and submission form. [Official event listing](https://luma.com/builde-mked).
- Add every coding assistant/generative tool actually used by the team to the AI disclosure.
- Complete the live-device, redaction-model, and two-client acceptance checks before filming feature claims; see [DEMO_SCRIPT.md](DEMO_SCRIPT.md) and [PHONE_DEMO_GUIDE.md](PHONE_DEMO_GUIDE.md).
