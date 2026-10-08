# Triage Flutter client

Custom obsidian inbox, official Serverpod 4 email auth, dynamic voice capsule, on-device Whistle STT/PII filtering, backend action funnel, and device-local drafts/transcripts.

See [FLUTTER_UI.md](../../docs/FLUTTER_UI.md) for setup, theme tokens, verification, screenshots, and privacy/platform limitations.

See [PHONE_DEMO_GUIDE.md](../../docs/PHONE_DEMO_GUIDE.md) for the two-client phone/laptop walkthrough, LAN binding, Android alerts, and the voice-platform boundary.

Android capture uses Whistle-only WASM in a local WebView and `record` for 16 kHz PCM. Needle 3 routing is excluded. Run `./tool/prepare_web.ps1 -DownloadModels` before building; see [ACTION_FUNNEL.md](../../docs/ACTION_FUNNEL.md) for Laya/tool-model configuration and offline/demo behavior.

```powershell
./tool/prepare_web.ps1 -DownloadModels
flutter pub get
flutter run -d chrome --dart-define=SERVER_URL=http://localhost:8080/
# Backend-free, explicitly labeled preview:
flutter run -d chrome --dart-define=TRIAGE_DEMO=true
```
