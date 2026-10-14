# Triage mobile redesign brief

## Goal

Make the hackathon's first screen communicate one promise within five seconds: Triage can perform useful phone actions without a network connection. The current screen is a useful diagnostic prototype, but its oversized orb, large empty gaps, test chips, and developer terminology make it feel unfinished. Keep all existing action, outbox, sync, and routine behavior while replacing the presentation.

## Design direction

Use a calm, precise voice-assistant aesthetic: near-black surfaces, warm white typography, restrained violet for listening and thinking, cyan for verified success, and amber for attention. Borrow the conversational focus and clean spacing of the supplied Pi and Grok references without copying their artwork or layouts. Build an identifiable Triage design system rather than a generic glass dashboard.

Use the **Libraries.dev Ghost BotAvatar** as Triage's primary character in place of the oversized static orb. Show the character near 96 logical pixels on the Assist home screen, still or gently breathing when idle; do not put a second large orb beside it. The Voice Glow remains the visual expression of the user's speech along the listening sheet, while the avatar expresses Triage's state. Map local states to poses: idle = resting, listening = attentive, processing = working, result = brief response, speaking = subtle mouth/eye motion. Keep failure and permission states truthful without cheerful success animation.

The `bot-avatars` npm package is React-only and cannot be installed as a Flutter widget. For Android, port the open-source MIT-licensed 2D canvas Ghost renderer to a Flutter `CustomPainter`/animation controller, preserving attribution and respecting reduced motion; an approved set of exported image frames can be a shorter prototype if the port cannot be completed within the hackathon. Do not embed a React WebView solely for the avatar. Source: https://libraries.dev/bots and https://github.com/Jakubantalik/Libraries.dev/blob/main/packages/bot-avatars/README.md

Use an 8-point spacing rhythm, one type family (existing Inter is fine), and clear type roles. Keep the primary microphone control in the lower thumb zone. The orb should be smaller and more expressive than the current static sphere. Use animation only to communicate real controller states; do not animate a success before the native result arrives. Respect reduced-motion settings.

## Library choice

Evaluate **Forui** as the single component library for navigation, settings, dialogs, sheets, switches, and forms. Its touch-friendly minimal components suit the secondary pages. Check the pinned Flutter SDK against the selected Forui release before adding it; Forui 0.26+ requires Flutter 3.47+. If incompatible, select an older compatible release or use Flutter's built-in Material widgets with the same Triage tokens. Do not mix several complete component systems. Keep the orb, active result, voice capsule, and border light custom Flutter widgets. Do not add charting or desktop UI packages for this pass.

## Information architecture

Four destinations in a persistent bottom navigation:

1. **Assist** — immediate voice action. A compact header shows actual connectivity and sync state. The hero holds a compact reactive orb, one state sentence, and a prominent mic capsule. Below: the latest transcript and truthful result, then a short row of user-selected favorite commands or apps (for example, Open YouTube). A Device / Ask switch can expose conversational BYOK only when configured and online; a failed provider request stays visibly failed.
2. **Activity** — a readable timeline of local actions and outcomes. Each item shows command, time, status, and sync badge. Latency breakdown lives in item details, not on the Assist hero.
3. **Routines** — scheduled routines, next trigger, last execution, per-step result, and connection/local-mirror status. Make any incomplete or permission-required step obvious.
4. **Settings** — offline speech and TTS assets, microphone and native-action permissions, shake sensitivity, favorite apps, BYOK provider/key, privacy opt-in, device registration, and a separate Diagnostics area.

## Assist screen layout

- Header: Triage wordmark, truthful connectivity chip (`Offline` / `Online`), and a small pending-sync indicator. Do not show `100% offline` alongside active 5G; say `Device actions work offline` if that is the intended claim.
- Hero: orb at roughly 140–180 logical pixels, centered but not surrounded by excessive empty space. Short state copy: `Ready to help`, `Listening`, `Working on device`, `Done`, or a precise error.
- Primary CTA: large microphone capsule near the lower half. Tap or an in-app foreground shake starts the same voice flow. Haptic feedback confirms activation.
- Latest result: transcript, action name, typed status, and human explanation. A Clock intent should say `Sent to Clock` until completion can be verified; `handed_off` must not imply the timer was definitely set.
- Favorites: 2–4 personalized shortcuts, including supported installed apps. Actions must use the existing deterministic parser/native bridge and retain typed outcomes.

## Voice states and motion

`idle` = subtle breath; `listening` = audio-reactive ring; `thinking` = tighter motion; `success` = brief cyan flare; `handed_off` = neutral confirmation with destination; `permission_required` = amber with a next-step button; `unsupported` / `error` = concise explanation and retry path. Make state transitions interruptible for cancellation and repeated activation. Target smooth performance on the A015, measured in profile mode, without blocking speech capture or TTS.

### Voice Glow treatment after tap or foreground shake

Use the Libraries.dev Voice effect as a visual reference, not the React `voice-glow` package in Flutter. When listening begins, show a compact voice sheet or capsule with the live transcript and a centered glow blooming from its bottom edge. Map the existing Android `SpeechRecognizer.onRmsChanged` events (`triage.offline_voice_events`, `rms_changed`) to a calibrated 0–1 level, then apply a noise gate plus attack/release smoothing. Use a custom `CustomPainter` or shader in a `RepaintBoundary`; keep the input and transcript readable above the effect. During parsing/native execution, collapse the glow to a narrower traveling beam. Stop it on cancellation, and resolve into the typed action outcome. Keep a restrained idle mode and a reduced-motion static border.

Acceptance: a foreground shake and a mic tap start the same voice sheet; actual speech moves the glow, silence settles it, processing has a visibly different motion, and stale RMS events after cancellation cannot restart it. The visualizer consumes the existing STT level stream and does not open a second microphone session. Reference: https://libraries.dev/voice.html

## Shake scope and Android entry points

- **This ticket:** shake starts listening while any Triage page is visible, not only Assist. Register and remove the accelerometer listener with app lifecycle, debounce repeated shakes, and expose sensitivity in Settings. Preserve tap as the reliable alternative.
- **From the Android home screen or another app:** a normal background Triage process cannot reliably receive continuous accelerometer events. Do not claim global shake activation from a `sensors_plus` listener. Offer a user-initiated Quick Settings tile and launcher shortcut that open the assistant directly. A persistent foreground-sensor service and/or overlay is a separate opt-in feasibility slice, with battery, permission, microphone, and background-activity behavior tested on Android 12–16. Never auto-launch YouTube from an unverified background shake.
- Once Triage is opened by a user-initiated entry point, `Open YouTube` can use the existing local app-launch bridge and return `success` or `unsupported` truthfully.

## Delivery order

1. Freeze the existing spike screen as Diagnostics; do not destroy working actions.
2. Implement navigation and shared tokens, then the Assist page and true result states.
3. Implement Activity, Routines, and Settings using existing data/services.
4. Add favorite app shortcuts, foreground shake across Triage pages, and user-initiated Android entry points.
5. Validate on A015: offline voice action, app launch, permission denial, sync, routine outcome, BYOK failure, text scaling, reduced motion, and performance.

## References and constraints

- F22 Labs Flutter UI library comparison: https://www.f22labs.com/blogs/top-8-flutter-ui-libraries-for-2025-you-must-explore/
- Forui package and SDK requirement: https://pub.dev/packages/forui
- Supplied visual references (access may require Mobbin sign-in): https://mobbin.com/apps/pi-ios-9730b5e1-f375-4473-981f-c5736b97e148/eb8c66e2-9763-4539-899c-173f448fbe2f/screens and https://mobbin.com/apps/grok-bot-ios-c5e50da8-b7fc-423a-a264-5ea9c387d5ad/862b66ab-c959-4a0d-85ec-bdfe42eb2eb5/screens
- Android background sensor restrictions: https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview
- Android background microphone-service restrictions: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
