# Triage Serverpod Cloud deployment runbook

## Current position (2026-10-14)

- **Deployed:** Cloud project `triage` is linked through `triage/triage_server/scloud.yaml`. The deployment record reports a successful rollout and HTTP 200 health response from `https://triage.api.serverpod.space/` on 2026-10-14. Check current health before a release.

- The hackathon welcome PDF offers **one month of Serverpod Cloud hosting**. Official Serverpod documentation describes a one-month free trial for the first project with no credit card required. This is a **trial**, not a confirmed permanent free tier.
- Published Starter pricing after the trial is **$5/month**. Starter has a managed small database and **Future Calls disabled**. Growth supports Future Calls and has different pricing. Verify the specific hackathon entitlement in the Cloud console before choosing a plan.
- `serverpod_cli 4.0.4` is installed at `%LOCALAPPDATA%\Pub\Cache\bin\serverpod.bat`; the Flutter and Dart SDK `bin` directories may need to be prepended to PowerShell PATH. The Cloud CLI is installed and the local server package is linked.
- The backend uses PostgreSQL models and migrations. Cloud supplies the database password, service secret, JWT keys, email pepper, and email-service key as platform-managed secrets. Do not upload local database credentials or manually copy `config/passwords.yaml` into source control.

## Readiness work before the first production phone demo

1. The consumer Settings screen now links to Serverpod email sign-in, registration, verification, and reset. `DevAuthEndpoint.authenticatePilotUser` intentionally rejects production. Check that Cloud email delivery and JWT secrets are configured before testing a real account.
2. The 4-tab consumer UI is selected by `TRIAGE_VOICE_SPIKE=true` (the current default); Diagnostics is nested in Settings.
3. For a **Starter trial** demo, showcase authenticated registration, PostgreSQL outbox sync, and telemetry. Cloud Future Calls are disabled, so the connected routine scheduling control is hidden and production scheduling rejects requests. Use the phone's local exact-alarm routines for scheduling. Only set `TRIAGE_CLOUD_ROUTINES_ENABLED=true` on a Future Calls-enabled Cloud plan after validating dispatch.
4. Complete the usual server analysis/tests and review the deployment package with `serverpod cloud deploy --wet-run --show-files` after the first project has been linked.

## First deployment from Windows PowerShell

Run from `D:\Programming\Experimentation\ServerPod\triage\triage_server`:

```powershell
cd D:\Programming\Experimentation\ServerPod\triage\triage_server
& "$env:LOCALAPPDATA\Pub\Cache\bin\serverpod.bat" cloud launch
```

The command installs/updates the Cloud CLI if needed, guides sign-in and Cloud project creation, creates `scloud.yaml`, and deploys. Select a plan after reading its console terms and **enable the database**. The Cloud CLI offers to copy selected passwords from `config/passwords.yaml`; copy only production/shared values actually needed. Review the displayed project ID and API URL.

Subsequent deploys:

```powershell
& "$env:LOCALAPPDATA\Pub\Cache\bin\serverpod.bat" cloud deploy
& "$env:LOCALAPPDATA\Pub\Cache\bin\serverpod.bat" cloud status deployment show
```

Cloud's API URL takes the form `https://<project-id>.api.serverpod.space/`. Build/run the phone client against it from `triage\triage_flutter`:

```powershell
& 'D:\Android\flutter\flutter\bin\flutter.bat' run -d A015 --dart-define=SERVER_URL=https://triage.api.serverpod.space/
```

The app defaults `SERVER_URL` to `https://triage.api.serverpod.space/`; local development can override it with `--dart-define=SERVER_URL=http://localhost:8080/`. After deploying, verify a real production sign-in, device registration, one offline action, reconnection sync, and the corresponding Cloud database/log record. Verify telemetry separately. Test routine delivery only if the selected Cloud plan actually runs Future Calls.

## Official references

- First deployment and trial: https://docs.serverpod.dev/deployments/deploy-to-serverpod-cloud
- Cloud CLI first launch: https://docs.serverpod.dev/cloud/getting-started/launch
- Pricing and Future Calls by plan: https://serverpod.dev/pricing
- Deployment URLs, status, and wet run: https://docs.serverpod.dev/cloud/concepts/deployments
