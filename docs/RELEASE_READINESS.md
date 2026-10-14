# Release readiness

## Android release setup

The Android application ID is `app.triage.mobile`. Confirm it is available to
your publisher account before the first store upload; an application ID cannot
be changed after publishing without creating a separate app listing.

Create an upload keystore and keep it outside the repository. Create
`triage/triage_flutter/android/key.properties` locally with these entries:

```properties
storeFile=C:/secure/path/triage-upload.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=triage
keyPassword=YOUR_KEY_PASSWORD
```

`key.properties` and common signing key formats are ignored by Git. Never put
these values in source control, screenshots, or build logs. Release builds fail
until signing is configured; debug signing is not used for release builds.

Build a Play upload bundle from `triage/triage_flutter`:

```powershell
flutter pub get
flutter build appbundle --release --dart-define=SERVER_URL=https://triage.api.serverpod.space/
```

The API URL is the Serverpod Cloud endpoint documented in
`SERVERPOD_CLOUD_DEPLOYMENT.md`. The runbook records a successful HTTP 200
health check on 2026-10-14; check current service health and authentication
configuration before publishing. Override `SERVER_URL` for local development
with `--dart-define=SERVER_URL=http://localhost:8080/`.

## Public repository checklist

- Review all tracked files and the full Git history for credentials and private
  data. The local source scan is not a history audit.
- Confirm ownership and license compatibility for illustrations, fonts, audio,
  models, and other bundled assets. Third-party font license files are kept
  alongside the font assets.
- Confirm the application ID, store listing, signing key backup, privacy policy,
  and data safety disclosures before store submission.
- Configure private vulnerability reports on the hosting provider.
- Confirm backend secrets and email delivery are configured in Serverpod Cloud;
  do not copy local `config/passwords.yaml` into a public repository.
- Build and test the signed bundle on supported Android versions and a physical
  device, including permissions, voice, offline actions, and reconnect sync.

The repository license covers project code. It does not grant endorsement or
trademark rights to the Triage name or logo.
