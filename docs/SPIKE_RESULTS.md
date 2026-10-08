# Task 1 — Critical-path AI spike

**2026-10-07. Outcome: the local pipeline runs; general-purpose automatic routing is not validated.** With the final five-tool schemas, only the reminder emitted an actionable call in the six-input WASM benchmark. Other inputs yielded suppressed or semantically incorrect candidates. Do not commit the PRD's schema-validity-only auto-save architecture on these results.

## Platform and harness

Primary experimental target: **Flutter Web + official Needle WASM**, hosted on localhost. The runner is in [../spike](../spike/README.md). Windows native C FFI was also exercised through the official Python SDK, including the actual `needle.transcribe()` API. It reproduced the routing weaknesses. Flutter Windows UI/`dart:ffi` packaging and Android execution are not validated by that comparison.

The browser implementation calls `needle_transcribe` then `needle_complete` in a serial Web Worker. It accepts microphone audio, synthetic prerecorded WAVs, silent mock PCM, and exact text inputs. Audio is mono, resampled to 16 kHz; the spike caps capture at 30 seconds and explicitly rejects longer injected audio. No backend, persistence, tool execution, utterance splitting, or confidence-trigger override is implemented.

| Artifact | Observed bytes |
| --- | ---: |
| Needle WASM | 923,348 |
| JS wrapper | 63,072 |
| Full Needle 3 weights | 35,335,380 |
| Whistle weights | 16,919,407 |
| Windows native DLL (comparison only) | 1,524,736 |

Models plus JS/WASM total **53.24 MB decimal** before Flutter assets. The complete local Web build is approximately **95.9 MB**, including bundled renderer variants for offline operation. Fetch only the required renderer/model assets in production; do not equate deployment-directory size with bytes fetched in a session. WASM linear memory reached **177,143,808 bytes (~169 MiB)**; this excludes the browser, Flutter, and JS buffers. The engine's negative `peak_ram_mb` values in WASM are invalid measurements, so the report uses actual linear-memory size.

Microphones require localhost/HTTPS and browser permission. The fallback WAV button is independent of microphone permission. Models are downloaded during setup and served from the same origin. The upstream JS wrapper resolves WASM relative to the worker URL, so the harness explicitly supplies `vendor/needle.wasm` bytes. No model-size/WASM-loading blocker was found in the tested local runtime; a platform switch was therefore not needed. Slow initialization and routing remain performance concerns. Browser checks also exposed and fixed a fixture/request-ID collision and a remote Google font fallback for arrow glyphs; the heading now uses plain text. Bundling Flutter renderer assets alone does not disable all font fallback downloads.

## Evidence and method

Primary evidence: [spike/benchmark.json](spike/benchmark.json), with **exact raw engine JSON strings**, parsed envelopes, STT word timestamps, tool/model hashes, CPU information, settings, and controls. [spike/native_benchmark.json](spike/native_benchmark.json) contains the native SDK comparison. These are actual local inference outputs, not expected/mock calls.

Flutter **3.47.6**, Dart **3.13.5**, Node **24.15.0**, Windows x64, Intel Core i5-13450HX. Python SDK **3.1.0**, native engine wheel **3.2.0**. Needle assets are pinned to Hugging Face revision `2ae11323dc000f5e70c49f7403efa6af12ba9e67`; Whistle to `b358ddadd89b7a713b5aa131f23032d3cca1b251`. Setup checks SHA-256 against [runtime.lock.json](../spike/assets/runtime.lock.json).

The final configuration uses `system="locale: en-US"`, no date fact, 512 maximum new tokens, English STT and word timestamps. Each unrelated utterance resets the conversation. The shared [tools.json](../spike/assets/tools.json) defines all five requested signatures; only meaningful required fields are mandatory, with unknown optional values omitted. The model does not reliably emit schema defaults, so absence is preserved in the evidence.

The first run used a chatbot-style system instruction and required every optional field. After checking the [official SDK reference](https://github.com/cactus-compute/needle/blob/7faf26b09e7b7d3595fc73320d2f0be6d63ce0f2/llms.txt), we corrected it to environment facts and optional fields. That changed 0/6 actionable text outputs to 1/6, and shopping enumeration from one grouped candidate to three candidates. The original configuration and evidence remain in [initial_tools.json](spike/initial_tools.json), [initial_benchmark.json](spike/initial_benchmark.json), and [initial_native_benchmark.json](spike/initial_native_benchmark.json).

Audio fixtures are **synthetic Microsoft David Desktop speech**, generated locally with Windows System.Speech, mono 16 kHz/16-bit PCM. This validates the audio interface and exposes transcription effects; it does not establish accuracy on real speakers, accents or noisy microphones. Timings are single exploratory samples on a shared development machine, including concurrent toolchain activity, not percentile/controlled-device performance claims.

## (a) Confidence output

**Yes: Needle returns an actual numeric `confidence` field**, separate from arguments. The final exact-text reminder scored **0.2972** in WASM; its transcribed counterpart scored **0.1566**. The other five exact inputs scored **0.0052–0.0941**. These are envelope-level scores, not a separately calibrated score for each call.

The SDK documents that scores below **0.1** are withheld in `suppressed_calls`, and grounding can also withhold calls. The harness preserves this distinction: a suppressed candidate is not an actionable `function_calls` entry. Locally fine-tuned weights without a trained confidence head can return `null`/`None`; numeric output on this pinned base model does not guarantee numeric output on every model. [Official response/gating reference](https://github.com/cactus-compute/needle/blob/7faf26b09e7b7d3595fc73320d2f0be6d63ce0f2/llms.txt).

## (b) Multiple calls

**Native multi-call structure exists, but correct actionable multi-item routing did not pass.** With the final schemas, “Buy eggs, milk, and bread from Whole Foods” natively generated three shopping **candidates** without client splitting. All were suppressed; every quantity became `"bread"`, and the store was dropped. The mixed utterance generated a task plus shopping candidate, also suppressed, with an incomplete task title.

Client splitting is therefore **not required simply to obtain multiple native calls**. Schema sensitivity and extraction correctness are the immediate problems. If a fallback is added, scope it to recognized shopping enumerations and preserve store/quantity context. Splitting every comma/conjunction would damage the meeting note. Compare the initial grouped candidate with the final three-candidate result before treating native enumeration as reliable.

## (c) Exact-text benchmark

`function_calls` below is the exact emitted list. `suppressed_calls` is shown separately for diagnosis and must not be executed automatically. Empty optional fields/defaults were not inserted by the harness.

| # | Exact input | Confidence | `function_calls` JSON | `suppressed_calls` JSON |
| --- | --- | ---: | --- | --- |
| 1 | Remind me to call the dentist tomorrow at 3pm | 0.2972 | `[{"name":"add_reminder","arguments":{"title":"Call the dentist","remind_at":"tomorrow at 3pm"}}]` | `[]` |
| 2 | Buy eggs, milk, and bread from Whole Foods | 0.0172 | `[]` | `[{"name":"add_shopping_item","arguments":{"item":"eggs","quantity":"bread"}},{"name":"add_shopping_item","arguments":{"item":"milk","quantity":"bread"}},{"name":"add_shopping_item","arguments":{"item":"bread","quantity":"bread"}}]` |
| 3 | The client meeting went well, they approved the Q4 budget | 0.0052 | `[]` | `[{"name":"add_task","arguments":{"title":"Client meeting went well"}}]` |
| 4 | Fix the login bug by Friday, high priority | 0.0941 | `[]` | `[{"name":"add_task","arguments":{"title":"Login bug","priority":"high","due_date":"Friday"}}]` |
| 5 | What if we made the onboarding a game? | 0.0162 | `[]` | `[{"name":"add_task","arguments":{"title":"Onboarding a game","priority":"medium"}}]` |
| 6 | Um, so, email Sarah about the proposal, and oh, grab milk | 0.0438 | `[]` | `[{"name":"add_task","arguments":{"title":"Proposal","priority":"medium"}},{"name":"add_shopping_item","arguments":{"item":"milk"}}]` |

The note and idea never selected their intended tools in this configuration. Row 6 lost the email action/recipient; the audio variant also treated Sarah as an assignee. JSON parseability and schema validity do not catch these semantic failures. See the raw envelopes for reasoning and grounding flags, including reasoning that contradicts the actual call list.

## Audio benchmark and latency

All six WAVs passed through Whistle then Needle; the exact audio-route calls/envelopes are in `rows[].audio.routing` in the primary JSON evidence. The reminder was the only actionable audio result as well.

| # | Whistle transcript | Clip ms | STT ms | Exact-text routing ms | Audio → STT → routing ms |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | Remind me to call the dentist tomorrow at 3 p.m. | 3840 | 2103.9 | 4067.7 | 6618.1 |
| 2 | By eggs, milk, and bread from whole foods. | 4160 | 1889.3 | 5888.0 | 7801.2 |
| 3 | The client meeting went well. They approved the Q4 budget. | 4275 | 2094.3 | 6694.6 | 7575.9 |
| 4 | Fix the login bug by Friday. High Priority. | 3950 | 1547.1 | 7989.5 | 5645.4 |
| 5 | What if we made the onboarding a game? | 2670 | 1119.6 | 3564.8 | 4842.1 |
| 6 | Um, so, email Sarah about the proposal, and oh, grab milk. | 6010 | 2708.6 | 5088.7 | 8168.8 |

Audio pipeline latency excludes recording duration. Its routing is a separate inference on the STT output, so the audio total is not STT plus the exact-text-routing column. Model/WASM loading took **275 ms** from local disk; static tool-prefix initialization added **11,743 ms** for 485 tokens. Browser network loading is a separate measurement. The PRD's sub-second whole pipeline is not established.

Silence produced an empty transcript and skipped routing. An unrelated question produced no actionable calls. The native comparison also yielded only the reminder as actionable; numerical confidence and some candidates differ across native/WASM. Native timings are retained in the evidence but concurrent setup/build activity prevents a fair platform-speed ranking from those samples.

## Recommendations for Task 2 and Task 3

1. **Task 2:** keep date resolution deterministic. Normalize `3pm` / `3 p.m.`; test Friday, tomorrow, timezone and calendar boundaries. Resolve relative phrases from structured fields against a captured device clock/timezone, and retain the local original transcript for review when the model drops or changes a date. Do not guess missing dates from generated reasoning. Do not supply an engine date fact unless deliberately comparing its date repair with the client resolver.
2. **Task 3:** defer automatic-save semantics until routing improves. Treat empty, suppressed and ungrounded responses as confirmation/edit states. Keep confidence nullable and distinct from schema validity. Schema validity alone must not authorize auto-save. Apply documented product defaults on the client, validate resolved reminder timestamps, and preserve one structured item per accepted call. Raw audio/transcripts and diagnostic envelopes stay local; only approved redacted payloads may be synced in the later backend task.
3. **Before Task 4 integration:** tune tool descriptions/schema or evaluate local domain fine-tuning on a held-out Triage corpus. Include note/idea discrimination, enumeration/store retention and mixed intents; repeat with real speakers and noise. Regex triggers can force low-confidence calls, so test them as a separate experiment, not as proof that calibration improved. No paid training or cloud inference is needed for the current harness.
4. **Platform follow-up:** Web is adequate for continued experimentation. Test target Android hardware and real permission prompts before choosing the production platform. Keep model initialization out of the record interaction, measure cold/warm latency on an otherwise idle device, evaluate smaller Needle depths, and replace ScriptProcessor capture with AudioWorklet. Offline reload/model cache, >30-second chunking and cancellation are separate implementation tasks.

## Verification

Completed: Flutter release Web build; Flutter analyzer with no issues; two widget tests for tap-to-toggle/denial recovery; five Node tests for PCM boundaries, invalid WAV/audio, suppressed-call gating, and the fixture/request-ID collision; six real text and six synthetic-audio inferences on WASM and native Windows.

**Actual browser integration passed** with the existing test Chrome **131.0.6778.204**: WASM/model loading, prerecorded WAV, silent mock, prerecorded microphone, offline routing and actual Flutter initialization/fixture controls. All **18** observed requests were local and there were **0** page errors. See [browser_smoke.json](spike/browser_smoke.json) and the visually inspected [runner screenshot](spike/runner.png). Browser initialization took **16,353.7 ms**, including **130.6 ms** for local fetch/WASM setup and **16,223.1 ms** for model/tool-prefix loading. The microphone exposed **48 kHz** audio, resampled to **16 kHz**, and produced a **4,522.7 ms** clip with **7,353.2 ms** processing latency.

The test used Chrome's fake microphone with the local dentist WAV; Chrome loops that file, so its transcript was `"Remind me to call the dentist tomorrow at 3 pm. Remind me to"`. It proves capture/resampling/pipeline integration, not real-microphone recognition quality. Physical microphone/real permission-prompt acceptance remains a manual/device check. The machine's system Chrome stalled under automation; the existing test Chrome worked with `SPIKE_CHROME`. Browser inference is therefore verified on that explicit version, not every installed/current browser. No platform permission/model-loading blocker was observed in the successful test.

Primary upstream sources: [Needle repository](https://github.com/cactus-compute/needle), [SDK/C-ABI behavior](https://github.com/cactus-compute/needle/blob/7faf26b09e7b7d3595fc73320d2f0be6d63ce0f2/llms.txt), [pinned WASM artifacts](https://huggingface.co/Cactus-Compute/needle3/tree/2ae11323dc000f5e70c49f7403efa6af12ba9e67/wasm), [Whistle model](https://huggingface.co/Cactus-Compute/whistle). The separate `cactus` Flutter package's Whisper API is not the Needle/Whistle API used in this spike.
