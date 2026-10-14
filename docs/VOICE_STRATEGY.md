# Triage voice output strategy

**Status:** Recommendation, not yet implemented.  
**Reviewed:** 2026-10-13

Triage's assistant currently speaks through Android's on-device Text-to-Speech (TTS) engine. Its offline volume-command loop must continue to give truthful spoken feedback in Airplane mode, without a network round-trip or an API key. A more expressive voice can be added as an optional online feature.

## Recommended voice modes

| Mode | Use | Availability | Trade-off |
| --- | --- | --- | --- |
| Installed Android offline voice | Default for device actions and fallback for all speech | Offline after the voice assets are installed | Fastest path to a reliable, user-selectable voice; quality depends on the installed engine and voice. |
| ElevenLabs | Optional premium voice for conversational answers and selected confirmations | Online, with user-provided API key | More expressive output, but sends the text being spoken to ElevenLabs, consumes credits, and adds network latency. |
| Open-source on-device TTS | Optional future upgrade after testing on a physical phone | Offline after model download | Can improve offline voice quality, but adds model storage, startup, performance, and license considerations. |

### 1. Improve the existing offline voice first

Add a voice picker that lists installed Android voices, permits a short preview, and only offers an offline voice as the assistant's default when `Voice.isNetworkConnectionRequired == false`. Check that the voice assets are installed and preserve the existing missing-assets guidance. Keep spoken outcomes tied to the typed action result, including `handed_off`, `permission_required`, and `error`.

Android documents selecting an embedded voice through `TextToSpeech.getVoices()` and `TextToSpeech.setVoice()` after checking `Voice.isNetworkConnectionRequired()`: [Android TextToSpeech.Engine reference](https://developer.android.com/reference/android/speech/tts/TextToSpeech.Engine).

### 2. Add ElevenLabs as an opt-in online voice

Store the user's API key in secure local storage, allow a voice and model choice, and stream generated audio for online responses. A low-latency Flash model is a sensible first trial. If connectivity, the API, or playback fails, use the selected offline voice and report the failure separately from the underlying device-action outcome. An optional online voice must never delay or block the local action itself.

Clearly disclose that the response text is sent to ElevenLabs when this mode is enabled. Do not send raw transcripts merely to produce a device-action confirmation; send only the final text chosen for speech. Do not put the API key in logs, audit events, or Serverpod records. Recheck current model, voice, and account pricing before choosing defaults.

ElevenLabs documents [streaming TTS](https://elevenlabs.io/docs/api-reference/text-to-speech/stream), [latency guidance](https://elevenlabs.io/docs/api-reference/reducing-latency), and [credit accounting](https://help.elevenlabs.io/hc/en-us/articles/27562020846481-What-are-credits). Based on its published self-serve Flash rate of about 0.5 credit per character, **131,000 credits would correspond to approximately 262,000 generated characters** before any voice-specific multiplier or other usage. This is an estimate, not a quota guarantee.

### 3. Trial open-source offline TTS before bundling it

Test a sherpa-onnx Android TTS engine with a Piper voice on the physical handset and compare it with installed Android voices for pronunciation, time to first audio, memory, battery use, and Airplane Mode behavior. sherpa-onnx also publishes a [Flutter TTS example](https://k2-fsa.github.io/sherpa/onnx/flutter/pre-built-app.html) and [Android TTS-engine builds](https://k2-fsa.github.io/sherpa/onnx/tts/apk-engine.html).

Kokoro is another voice-quality candidate, but the documented English model alone is about 330 MB. Treat a model of that size as an optional download rather than part of the base app until phone testing justifies it. Check the license of the exact model selected; the inference framework and voice model may have different licenses. See the [sherpa-onnx Kokoro model details](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html) and [model-license guidance](https://k2-fsa.github.io/sherpa/onnx/tts/apk.html).

## Suggested rollout

1. Add an offline Android voice picker and preview to the current TTS bridge.
2. Add an optional ElevenLabs adapter for online speech, with secure key storage, streaming playback, cancellation, and immediate offline fallback.
3. Benchmark Piper through sherpa-onnx on the Nothing Phone 2a; only integrate a bundled or downloadable model if it materially improves the offline experience.

This voice work is separate from command understanding: the current offline assistant still uses on-device speech recognition and deterministic intent parsing. The planned BYOK LLM gateway for conversational answers is [Ticket 06](../.scratch/triage-offline-assistant/issues/06-single-provider-byok-gateway-and-routing-firewall.md).
