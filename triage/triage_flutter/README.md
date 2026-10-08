# Triage Flutter client

Custom obsidian inbox, official Serverpod 4 email auth, dynamic voice capsule, on-device Needle/Whistle routing, and device-local drafts/transcripts.

See [FLUTTER_UI.md](../../docs/FLUTTER_UI.md) for setup, theme tokens, verification, screenshots, and privacy/platform limitations.

See [PHONE_DEMO_GUIDE.md](../../docs/PHONE_DEMO_GUIDE.md) for the two-client phone/laptop walkthrough, LAN binding, Android alerts, and the voice-platform boundary.

Android APK voice capture uses the bundled Needle/Whistle WASM engine in a local WebView and the `record` plugin for 16 kHz PCM. Run `./tool/prepare_web.ps1 -DownloadModels` before building; see the phone demo guide for APK instructions and physical-device verification limits.

```powershell
./tool/prepare_web.ps1 -DownloadModels
flutter pub get
flutter run -d chrome --dart-define=SERVER_URL=http://localhost:8080/
# Backend-free, explicitly labeled preview:
flutter run -d chrome --dart-define=TRIAGE_DEMO=true
```
