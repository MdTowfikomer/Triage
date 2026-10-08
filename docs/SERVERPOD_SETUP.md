# Task 3 — Triage backend foundation

## Workspace and versions

The official `serverpod create triage --template server --auth --no-redis --no-website --no-webapp --ide none` scaffold produced a Dart workspace under [triage/](../triage/pubspec.yaml):

- `triage_server`: handwritten YAML models, secure endpoints, generated server ORM, migrations and integration tests.
- `triage_client`: generated shared transport models and typed client methods, including email authentication and JWT refresh.
- The Task 1 Flutter spike and Task 2 resolver remain in `spike/`. Task 4 adds `triage_flutter` to this workspace; no custom authentication endpoint was added.

**Pinned Serverpod CLI/runtime/auth/test version: 4.0.4.** Verified against the live official package registry, using Dart **3.13.5** (minimum package SDK **3.12.2**). The CLI was initially absent from PATH and is now installed in `.spike-cache/pub`, with its matching dependencies recorded in `triage/pubspec.lock`. Flutter is required on PATH by the scaffold even for the server template.

The current official authentication implementation is `serverpod_auth_idp_server` with `serverpod_auth_core_server`, rather than the legacy `serverpod_auth_server` module assumed by the older PRD sample. Auth users have **UuidValue** primary keys. Serverpod 4's `Session.authenticated` is synchronous; its core auth extension is **`authUserId`**, not the sample's `.userId`. Inbox/reminder/recording primary keys and child foreign keys remain **int**. [Official auth setup](https://docs.serverpod.dev/concepts/authentication/setup), [user identity reference](https://docs.serverpod.dev/concepts/authentication/working-with-users).

`configureAuthentication()` is shared by runtime and tests. It configures the official JWT token manager and email provider. `EmailIdpEndpoint` and `RefreshJwtTokensEndpoint` are thin subclasses of the official provider classes; there is no custom `AuthEndpoint`, password hashing, or token validation implementation. The scaffold's cloud email provider logs verification codes locally in development and uses Serverpod Cloud delivery in staging/production. SMTP/custom delivery is an alternative configuration, not implemented authentication logic.

## Models and privacy

Serverpod 4 model inputs use `.spy.yaml`; generated files were produced by `serverpod generate` and were not hand-edited. Models are in [lib/src/models/](../triage/triage_server/lib/src/models/inbox_item.spy.yaml).

| Model | Relations and indexes |
| --- | --- |
| `InboxItem` | `userId: UuidValue` references `serverpod_auth_core_user(id)` with cascade deletion. Inverse nullable `Reminder` and `Recording` relations. Indexes on userId, type, createdAt. All briefing fields are present, including nullable `confidence`. |
| `Reminder` | Integer `inboxItemId` FK to inbox_items, cascade deletion, unique index for one-to-one association. Index on triggerAt. |
| `Recording` | Integer `inboxItemId` FK to inbox_items, cascade deletion, unique index for one-to-one association. Opt-in metadata only. |
| `InboxEvent` | Typed streaming DTO: operation, itemId, optional item, occurredAt. Deletion has an explicit operation and no item body. |
| `TriageException` | Serializable, limited error code/message for invalid input and not-found responses. |

**No originalTranscript field exists in either generated server/client models or database definitions.** The create endpoint whitelists typed fields and reconstructs fresh rows. Unknown raw transcript fields are discarded during typed deserialization and never persisted or returned. Redaction itself is the later on-device Task 5 integration: the server expects the client to submit an already redacted transcript/approved payload.

Audio is disabled by default on create. Recording metadata is accepted only with `allowRecording: true` and a reference shaped as `private://users/<session UUID>/audio/<filename>.wav` (also m4a/aac). Another user's namespace and arbitrary public URLs are rejected. Only private cloud storage is configured. This task defines secure recording metadata; authenticated upload/download endpoints and actual audio transfer are not implemented here.

## Endpoint contract

Every Inbox and Sync endpoint requires login, and handwritten authorization guards also derive the UUID from the session.

| Method | Behavior |
| --- | --- |
| `inbox.createItem(item, allowRecording?, expectedUserId?)` | Ignores submitted owner/primary IDs/completion state/timestamps and nested FK graphs. Stamps session UUID and UTC creation time, resets completion/firing, inserts fresh children and queued reminder work atomically. Optional expected-user precondition rejects account switches; it never assigns ownership. |
| `inbox.listItems(type?, limit?, offset?)` | Always filters by session UUID, including when filtering type. Default limit 50; allowed limit 1–100; offset nonnegative. Stable descending createdAt/id ordering. Includes owned child relations. |
| `inbox.completeItem(itemId)` | Queries and locks only the session-owned row, updates completion fields in a transaction, preserves the original completion timestamp on repeat. Missing/foreign IDs produce the same not_found response. |
| `inbox.updateItem(itemId, title, body, priority, dueDate, tags)` | Task 4 addition: locks a session-owned row and updates only editable fields. Preserves owner/type/lifecycle/transcript. Reminder date changes update the child and replace queued work in the same transaction; invalid dates roll back. |
| `inbox.deleteItem(itemId)` | Locks only the session-owned row, deletes it with cascading children. Missing/foreign IDs both return false. |
| `sync.streamInbox()` | Derives channel `triage.inbox.<session UUID>` server-side and returns `session.messages.createStream<InboxEvent>`. The caller cannot select another user/channel. |

Created/updated/deleted/reminder_fired events are published **after transaction commit** to the stored owner's channel using Serverpod's message system. Two sessions of one user receive the same events; another user receives only their own events. This is live notification, not a durable replay log: clients should subscribe and reconcile via `listItems` after reconnect. Local development/tests use one server without Redis. `MessageScope.auto` supports cluster-wide delivery when Redis is configured; Redis must be enabled for a multi-server deployment. [Server event semantics](https://docs.serverpod.dev/concepts/server-events/).

Validation rejects unknown type/priority/recurrence, blank or overlong titles, excessive text/tags, invalid confidence, missing reminder triggers and non-future reminder times. Confidence is stored as a nullable numeric value, not a schema-validity flag. Date/time values are normalized to UTC; Task 2's client-side resolver remains responsible for resolving relative language before sending.

## Reminder future call

[ReminderFutureCall.fire](../triage/triage_server/lib/src/future_calls/reminder_future_call.dart) is generated/registered automatically by Serverpod 4. It locks the parent, rereads the reminder, and marks isFired only if due, not already fired, and not completed/deleted. Duplicate invocations and stale deleted-row jobs are harmless. Its event uses the owner read from the stored parent, never an unauthenticated future-call session or caller-provided user ID.

In 4.0.4, the typed scheduling facade inserts queue entries using an independent internal session. To commit the reminder and queue entry together, create inserts the same framework `FutureCallEntry` and generated `ReminderFutureCallFireModel` payload inside the application's transaction. Dispatch name `ReminderFireFutureCall` matches the generated registry and is covered by queue-payload/hook tests. Recheck this contract when upgrading Serverpod or renaming the hook. [Official future calls](https://docs.serverpod.dev/concepts/scheduling/future-calls).

The hook manages one due-state transition. `daily`/`weekly` recurrence values are stored, but rescheduling recurrence and delivering client notifications belong to the later notifications integration. No external notification or email was sent during tests.

## Migrations and verification

Migrations:

- `20261007174503974`: scaffold baseline, including official auth/framework modules.
- `20261007180932480`: Triage tables, ownership FK, cascading child FKs and indexes.

Both generated migrations were **applied and verified against an isolated real PostgreSQL database** by the integration-test harness. Each test runs in a transaction rolled back afterward; the group's ephemeral database is dropped on teardown. Tests use Serverpod 4's embedded PostgreSQL under the ignored `.serverpod/test` directory. Docker was installed but initially stopped; it was started during environment assessment, but tests did not require a Docker container. No existing user database was modified. Development/staging/production databases have not been migrated or started by this task; `serverpod start` applies pending migrations in the selected local environment.

Verification covers framework rejection of every unauthenticated CRUD/stream call, session ownership stamping, cross-user list/update/delete isolation, nested graph spoofing, schema/privacy serialization, input validation, relation loading, child cascade deletion, unique/FK constraints, two-session event delivery and isolation, official JWT token validation, and due/early/duplicate/completed/deleted reminder cases.

Security tests use generated endpoint dispatch helpers and real database/message streams. Controlled authentication overrides establish fixture sessions; a separate test uses an identity returned by the real official JWT handler. These are server-level integration tests, not an over-the-network WebSocket test. **Task 4 expanded suite: 41/41 passed (Task 3 baseline: 34). Backend analyzer: no issues.** Client/dispatch code was regenerated for edits and the creation precondition. Models were unchanged; no additional migration was needed.

## Reproduce

With Dart >=3.12.2, Flutter on PATH for CLI setup, and Serverpod CLI 4.0.4:

```powershell
cd triage
flutter pub get
cd triage_server
./tool/init_secrets.ps1
serverpod generate
dart analyze
dart test --reporter expanded
# Run yourself when ready to use the development backend:
serverpod start
```

`init_secrets.ps1` generates random local credentials only if `config/passwords.yaml` is absent. The file is ignored; existing credentials are preserved and values are not printed. Prefer deployment secret management for production. Embedded PostgreSQL downloads its verified platform bundle on first use; subsequent test runs reuse it.

This checkout also has a workspace-local CLI/SDK. Set `PUB_CACHE` to `<repo>/.spike-cache/pub` and prepend `<repo>/.spike-cache/flutter/bin` plus its `cache/dart-sdk/bin` to PATH before calling `.spike-cache/pub/bin/serverpod.bat`. The scaffold's agent guide preserves the normal MCP workflow; Task 3 explicitly requested CLI generation/migration and no Serverpod MCP tools were connected, so those requested commands were used. The standalone application server was not started; only the explicitly authorized test harness ran a test instance.

Scaffold workflow templates are under `triage/.github/workflows`; the test template now initializes ignored auth secrets before testing. GitHub discovers workflows only at a repository's root `.github/workflows`, so these templates become active if the `triage` workspace is published as its own repository, or are adapted into this repository's root later. No remote CI run, deployment or GitHub write was performed.
