# Voice action funnel

The current app uses **Whistle STT → on-device Desert Ant PII scrub → authenticated Serverpod `voice.routeVoice` → Android app launch or inbox confirmation**. Needle 3 no longer routes or fills slots on the phone. The shared WASM binary still provides Whistle's transcription ABI; the APK bundles only `whistle.cact`, not `needle3.cact`.

## Backend and model services

`VoiceEndpoint` requires login and returns the generated `VoiceActionResult` DTO. Routing itself does not insert a database row, publish a sync event, or execute a device action. Approved inbox records use the existing owner-scoped `inbox.createItem`, PostgreSQL transaction and `sync.streamInbox` path. This transport-only model needs no database migration.

`ActionRouterService` calls Laya's `POST /v1/systemone` for `device_action` versus `inbox_item`, then an OpenAI-compatible `POST /chat/completions` for a typed tool call. Device actions expose only `open_app`; inbox decisions expose the five capture tools. Both stages have bounded HTTP calls. Invalid/unknown/empty model calls and unavailable services return a deterministic populated result from the pure Dart `triage_decision` package. Mixed captures preserve the full utterance in a review card.

The default **combined model-call budget is 180 ms**, with at most 50 ms for Laya. This is a timeout budget, not a verified 33 ms Laya or sub-200 ms phone round trip. `latencyMs` reports server routing time, excluding STT, PII processing, network transit, UI and the countdown. `routingSource` identifies `deterministic`, `laya+deterministic`, `deterministic+tool_model` or `laya+tool_model`; fallback is never reported as measured model inference. Successful two-model results use Laya's `answer_confidence` (or the selected option's probability), which measures domain choice, not slot correctness. Fallback scores are heuristic strengths. Review-required results score 0.05. Mixed, negated, incomplete or unsafe-date captures remain in review even when a provider returns a call.

Configure the following on the **backend**, never in Flutter defines or the APK:

| Environment variable | `passwords.yaml` key in the active mode | Meaning |
| --- | --- | --- |
| `LAYA_URL` | `layaUrl` | Full Laya URL, e.g. `http://127.0.0.1:8000/v1/systemone` |
| `LAYA_API_KEY` | `layaApiKey` | Optional Laya bearer key |
| `VOICE_AI_BASE_URL` | `voiceAiBaseUrl` | OpenAI-compatible base URL ending in `/v1` |
| `VOICE_AI_API_KEY` | `voiceAiApiKey` | Optional provider bearer key |
| `VOICE_AI_MODEL` | `voiceAiModel` | Exact model ID/alias available on that server |
| `VOICE_AI_TIMEOUT_MS` | `voiceAiTimeoutMs` | Combined inference budget, 20–5000 ms; default 180 |

Environment values take precedence. No credentials were added to this checkout. Tests disable external inference in Serverpod's `test` mode and use controlled adapters plus a local HTTP fixture.

For self-hosted Laya, in a dedicated Python environment/terminal:

```powershell
pip install "laya[serve]"
$env:LAYA_MODELS = "english"
$env:LAYA_PRELOAD = "1"
laya-serve
```

Provision a Liquid model on an OpenAI-compatible host such as llama.cpp/vLLM, or select an available hosted model. For a local llama.cpp GGUF deployment, use a model path you have downloaded and verified:

```powershell
llama-server -m "<PATH_TO_LFM_GGUF>" --alias triage-lfm --host 127.0.0.1 --port 8001
```

Then, in the terminal where **you** start Serverpod:

```powershell
$env:LAYA_URL = "http://127.0.0.1:8000/v1/systemone"
$env:VOICE_AI_BASE_URL = "http://127.0.0.1:8001/v1"
$env:VOICE_AI_MODEL = "triage-lfm"
# For hosted Liquid: base URL https://api.liquid.ai/v1 and the model ID from
# your provider; for Groq: https://api.groq.com/openai/v1 and its served model.
# Set VOICE_AI_API_KEY using your normal secret-management workflow.
cd triage
serverpod start
```

Model servers need warming and suitable hardware to fit the default timeout. Increase `VOICE_AI_TIMEOUT_MS` for CPU testing and build the client with `--dart-define=VOICE_RPC_TIMEOUT_MS=3000` if the normal 800 ms RPC deadline is too short. This allows longer latency; it does not meet the 200 ms target. An unavailable model never blocks the deterministic path. Liquid's older `LFM2-1.2B-Tool` is deprecated in its library; use a currently available tool-capable model, for example a supported `LFM2.5-1.2B-Instruct` deployment. Native `tool_calls` and JSON calls wrapped in LFM's special tool tokens are supported; Pythonic call text is never evaluated. [Laya HTTP contract](https://github.com/NandhaKishorM/laya/blob/main/docs/http-api.md), [Liquid tool use](https://docs.liquid.ai/lfm/key-concepts/tool-use), [Liquid model library](https://docs.liquid.ai/lfm/models/complete-library).

## Client and execution

The capture's reference clock is frozen before inference. Original transcripts and pending drafts are journaled in account-scoped SharedPreferences. Desert Ant plus deterministic masking runs **before any routing RPC**; returned title/body/tags are scrubbed again before persistence. Failure in privacy processing keeps the capture local. The change permits a sanitized transcript to leave the device during interpretation, before the user saves; the original transcript and audio stay local. Redaction can miss contextual PII and is not a complete privacy proof.

`open_app` must match an explicit whole command such as “Open WhatsApp” and one of `whatsapp`, `calendar`, `maps`, `mail`, `clock`, `notes`, `browser`. Both Dart and Kotlin enforce the allowlist. The bridge accepts no arbitrary package names, URLs, messages, recipients or alarm extras. Clock opens the alarm creation UI with `EXTRA_SKIP_UI=false`; notes opens Keep or an installed handler for `CREATE_NOTE`. Browser uses Android's recommended selector intent. This opens apps; it does not send messages or silently create alarms. An unavailable app/platform produces a populated review card. [Android selector contract](https://developer.android.com/reference/android/content/Intent#CATEGORY_APP_BROWSER).

Inbox cards always have a title, recognized category and priority. Dates remain optional when none was spoken; missing dates are not fabricated. `DateResolver` resolves spoken anchors against the captured local clock. Date-only default times need confirmation. Confidence ≥0.1, no review reason and valid fields start the existing three-second countdown; Edit, Cancel, backgrounding or an invalid reminder time prevents auto-save. Review mode has one primary **Save** action.

`TRIAGE_DEMO=true` uses the offline deterministic funnel and local demo repository without authentication. To exercise actual backend/model routing and two-client sync, build **without** that define:

```powershell
cd triage/triage_flutter
flutter build apk --dart-define=SERVER_URL=http://<PC_LAN_IP>:8080/
```

## Verification boundary

The requested release demo APK built successfully at `triage/triage_flutter/build/app/outputs/flutter-apk/app-release.apk`: **193.3 MB**, 202,641,012 bytes. ZIP inspection confirms only `whistle.cact`, uncompressed WASM/model assets and an STT wrapper without `needle_complete`. The merged Android manifest includes microphone/alarm permissions and the fixed app-package queries. This artifact is the offline/demo build; use the backend build command above for live model routing and sync.

The Whistle-only prepared Android asset bridge transcribed the prerecorded dentist WAV in headless Chromium without a Needle routing model. **65 backend unit/integration tests and 59 Flutter tests passed; both analyzers report no issues.** Coverage includes provider contracts/timeouts, authentication, owner-scoped persistence/sync, STT dispatch, scrub-before-RPC, raw caching, app authorization/unavailability, cancellation/backgrounding and the save timer. These checks do not establish real Laya/LFM accuracy or physical-phone performance. No Android handset was attached, and no live model-service endpoint was configured in this session. See [PHONE_DEMO_GUIDE.md](PHONE_DEMO_GUIDE.md) for physical acceptance.
