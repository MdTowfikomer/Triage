# Triage critical-path spike

Minimal Flutter Web harness: tap to start/stop microphone recording, or inject a locally generated WAV/silent mock, then run Whistle and Needle in a Web Worker. Shows raw engine JSON, confidence, suppressed candidates, schema diagnostics, and measured latency. Tool functions are definitions only; nothing is executed or saved to a backend.

## Run (PowerShell, from the repository root)

Prerequisites: Flutter (verified with 3.47.6 / Dart 3.13.5), Node (verified with 24.15.0), Chrome, and Windows System.Speech for fixture generation. A workspace-local Flutter installation is available at `.spike-cache/flutter/bin/flutter.bat` in this checkout; use that path if Flutter is not on PATH.

```powershell
./spike/scripts/setup.ps1
Set-Location spike
flutter --no-version-check pub get
flutter --no-version-check build web --no-web-resources-cdn
node scripts/serve.cjs
```

Open `http://localhost:4173`, initialize models, and tap Record twice. Allow microphone access when prompted. HTTPS or localhost is required. On denial, use “Inject prerecorded test WAV” or retry recording. Capture stops taking samples and releases the microphone at 30 seconds; tap Stop to process the captured clip. This spike does not implement long-recording chunking.

Models and runtime binaries download only during setup, from pinned public Hugging Face revisions, with SHA-256 verification. They are served from the same local origin. Build with `--no-web-resources-cdn` to keep Flutter renderer assets local too. Once initialization finishes, inference needs no network. Reloading the page offline requires an already cached/locally reachable bundle; offline reload and installable PWA behavior are outside this spike.

## Benchmarks and checks

From the repository root:

```powershell
node spike/scripts/benchmark.cjs
node --test spike/test/engine.test.cjs
Set-Location spike
flutter --no-version-check analyze
flutter --no-version-check test
```

The benchmark executes all six exact text inputs and all six synthetic WAVs. It saves exact engine JSON strings and parsed envelopes to `docs/spike/benchmark.json`, with timings, settings, model/source hashes, voice provenance, silence and unrelated-input controls. It resets conversation state between every input. No comma/conjunction splitting or trigger-based bypass is enabled. Synthetic speech is explicitly identified and must not be interpreted as real-speaker accuracy validation.

For an optional native Windows comparison using the actual `needle.transcribe()` API:

```powershell
./spike/scripts/setup.ps1 -SkipAudio -Native
python -m pip install --target .spike-cache/python cactus-needle==3.1.0
python spike/scripts/native_benchmark.py
```

This uses the official Windows engine through C FFI in the SDK, not a remote Python inference service. It is a comparison runner, not a Flutter Windows UI. Telemetry is disabled before SDK import. The same tools and model archives are used; small numeric differences between native and WASM can occur.

For browser integration verification with a prerecorded microphone (no physical microphone needed):

```powershell
npm.cmd install --prefix .spike-cache/browser playwright
node spike/scripts/browser_smoke.cjs
```

This uses an existing Chrome installation. Override `SPIKE_CHROME` if needed. It verifies actual browser WASM loading, Flutter controls, fixture and microphone pipelines, silence, offline routing and absence of remote requests. Evidence is saved under `docs/spike/`. Benchmark/generated assets are intentionally excluded from Git when large; regenerate with setup. Checked-in JSON evidence and the report remain available.

## Experiment contract

`assets/tools.json` is the shared five-tool definition. Unknown optional information is omitted by the model; schema defaults are not assumed to be emitted. Task 2/3 must apply product defaults separately. `system` contains only `locale: en-US` as Needle expects environment facts, not chat instructions. No date fact is supplied, so relative phrases can be resolved by Task 2 rather than by the engine's date-repair step.

The Web bridge uses Needle's C ABI (`needle_transcribe`, `needle_complete`) exported by its official WASM wrapper; the native comparison also exercises the public Python `needle.transcribe()` method. Keep `function_calls` separate from `suppressed_calls`; candidates withheld by the engine are never promoted. JSON-schema validity does not prove semantic correctness. The worker serializes inference because the engine has process-global, non-thread-safe state. Model archive buffers remain alive for its lifetime; audio allocations are freed after each call.

Audio is captured mono at the device rate and resampled with `OfflineAudioContext` to 16 kHz float PCM. The bare spike uses `ScriptProcessorNode`; replace it with `AudioWorklet` for production. WAV fixtures must be mono 16 kHz signed 16-bit PCM. Unsupported WAV encodings and clips longer than 30 seconds fail explicitly.

See [SPIKE_RESULTS.md](../docs/SPIKE_RESULTS.md) for findings and recommendations. [Needle](https://github.com/cactus-compute/needle), [Needle SDK reference](https://github.com/cactus-compute/needle/blob/main/llms.txt), and [Whistle](https://huggingface.co/Cactus-Compute/whistle) are the upstream sources. Their engine/models use Apache-2.0; downloaded artifacts are excluded from this repository. No paid services or fine-tuning jobs were used.

Task 2's standalone, dependency-free date resolver is at `lib/core/date_resolver.dart`. See [DATE_RESOLVER.md](../docs/DATE_RESOLVER.md) for supported expressions, default-time/past-time flags, timezone semantics, and its unit/browser verification results.
