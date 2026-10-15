# Daily Motion

Daily Motion is a strength and hypertrophy training app for iOS and Android,
built around **Plan → Train → Record → Predict → Learn → Adapt**.

## Project status

**Phase 0 is in progress.** The Flutter logging prototype now connects durable
Drift/SQLite storage to FastAPI/PostgreSQL through foreground synchronization.
Production-shaped Supabase email OTP, protected session persistence and account
lifecycle now connect verified identity to that local-first path. This is a
development foundation, not a public MVP. See
[implementation evidence](docs/IMPLEMENTATION.md) for tested behavior and open gates.

The first public release remains free, adult, English and India-first. Online
email OTP is required before personal training. After verification, local training
continues offline even when cloud credentials expire. Real provider/email delivery,
native secure-storage qualification and public onboarding remain open. Phase 1
has not started.

Windows qualification now includes Android debug/profile compilation and emulator
startup, native clock/backup configuration, real SQLite capacity faults and hard
Windows process-kill recovery. Physical Android/iPhone, hosted
OTP/SMTP, backup transfer, hardware secure storage and phone p95 remain open.
Use [the device qualification procedure](docs/DEVICE_QUALIFICATION.md) for the
prepared native recovery and full durable-save benchmark harnesses. Emulator or
desktop timings do not establish the **physical p95 ≤100 ms** target.

The [Phase 0 evidence audit](docs/PHASE0_EVIDENCE.md) reconciles completed local
foundation work with external hardware/provider/operator acceptance. Routine
editing is available as a separate disposable interaction study:

```sh
cd apps/mobile
flutter run -t lib/qualification/routine_prototype.dart
```

It edits planned prescriptions and immutable workout previews, creates no
personal data or database, and is disabled in release builds. Full routine
features remain Phase 1. Hosted project/region/backup/processor and named review
prerequisites are in [the operator handoff](infra/QUALIFICATION.md).

[Actual CI on `8e5af65`](https://github.com/bluxo1/Daily-Motion/actions/runs/38587594908)
passed all three jobs: **148 ordinary Flutter + 9 live HTTP cases**, **102 Python
including 54 PostgreSQL cases**, Android debug/profile/release and unsigned iOS
debug/release. The ordinary Flutter suite explicitly skipped **10** cases,
including the unqualified hosted staging harness. Hardware and hosted-provider
gates remain open; exact scope is recorded in the implementation evidence.

The continued operator-security fix is committed as `6606db0`: runtime password
DDL uses client-generated SCRAM verifiers. Latest local regressions pass **104
Python / 56 PostgreSQL**, **148 Flutter / 10 skipped**, plus **9 live HTTP cases**.
The deployed source's [existing CI run](https://github.com/bluxo1/Daily-Motion/actions/runs/38710259066)
passed **all three jobs**; its status was rechecked rather than rerun.
The hosted audit confirmed **two retained historical plaintext-password
statements**, using counts only. Affected staging credentials are now rotated;
Render's saved runtime secret was verified after reload and a new process passed
readiness, restricted-role/RLS and owner/pool checks. Deployment **`c5d5414`** is
live, with **6/6 public checks passing**. Historical statistics were not purged.
Real inbox/SMTP and authenticated hosted sync remain unqualified: custom SMTP is
off and Supabase locks code-template editing until it is configured. The checked
blueprint and actual service branch target `main`; Blueprint source-branch
verification is separate. See the
[staging runbook](infra/staging/README.md) for the protected recovery procedure.

## Repository

```text
apps/mobile/      Flutter, Riverpod, Drift, design and workout modules
services/api/     FastAPI commands, PostgreSQL models, Alembic and fault tests
contracts/        Generated OpenAPI and shared synthetic fixtures
infra/            Local PostgreSQL and operator qualification handoff
docs/             Product, architecture and implementation evidence
```

Flutter is pinned to **3.47.7 / Dart 3.13.5** in `.fvmrc`. Python is pinned to
**3.13.14**, with dependencies in `services/api/uv.lock`; the local database uses
**PostgreSQL 17.7**. Mobile dependencies are locked in `pubspec.lock`.

## Mobile development

With the pinned Flutter SDK on PATH:

```sh
cd apps/mobile
flutter pub get --enforce-lockfile
dart run build_runner build
flutter analyze
flutter test
flutter run --dart-define=DM_FOUNDATION_FIXTURE=true
```

The explicit fixture flag enables one synthetic development account and a bench
press session. It supports deliberate set entry, drafts, rest timers, completion,
abandonment and historical corrections. The default build does not permit
unverified workouts. Release builds reject development environment, fixture flags
and synthetic tokens rather than falling back to development authentication.

This workspace also has an ignored SDK at `.tools/flutter`. On this Windows host,
use `.tools\flutter\bin\flutter.bat` from the repository root. The task's Dart
cache and temporary directory are `.tools/pub-cache` and `.tools/temp`, on the
workspace drive; set `PUB_CACHE`, `TEMP` and `TMP` to those absolute paths when
using that SDK here. No global PATH or cache settings were changed.

## Supabase authentication configuration

Configure a separate Supabase project for each environment, asymmetric ES256/RS256
signing keys, six-digit email OTP templates containing `{{ .Token }}`, provider rate limits
and custom SMTP. SMTP credentials, service keys and database credentials stay in
operator-managed secrets; they never enter mobile configuration. Hosted provider
delivery and native storage have **not** been qualified in this workspace.

Run the real application path with client-safe compile-time configuration:

```sh
flutter run --dart-define=DM_ENVIRONMENT=production \
  --dart-define=DM_SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=DM_SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_client_key \
  --dart-define=DM_API_URL=https://your-api.example.com
```

Use `staging` for the staging project. HTTPS is required; only an explicit debug
`development` configuration permits loopback/emulator HTTP. Do not pass
`DM_ACCESS_TOKEN` or `DM_FOUNDATION_FIXTURE` to a release build.

Email verification calls the supported Supabase SDK, then the API initializes the
verified subject's account/profile idempotently. Sessions and the previously
verified local-owner grant use `flutter_secure_storage`: iOS Keychain with
device-only accessibility and Android protected storage. Default Supabase
SharedPreferences persistence is not used. Authentication failure pauses cloud
work; the cached owner's workouts, history and pending outbox remain available.
The production path creates **no personal sample workouts**. Routine/catalog and
new workout authoring beyond the Phase 0 fixture remain later work.

Explicit sign-out locks the owner's SQLite file and removes cloud credentials,
without deleting pending training. Sign in again to the **same verified account**
to recover and synchronize it. Another account opens a separate database, provider
scope and coordinator. Account disable follows the existing authoritative erasure
policy. See [security](docs/SECURITY.md) and [evidence](docs/IMPLEMENTATION.md).

## API and database checks

The requested **Supabase + Render staging** path is prepared in
[render.yaml](render.yaml) and [the staging runbook](infra/staging/README.md).
It uses separate migration/runtime credentials, verified database TLS and a
database/RLS-aware `/readyz` check. Copy only the four client-safe values from
[the mobile example](infra/staging/mobile.example.json) into an ignored staging
configuration file. Staging is deployed: Supabase Mumbai
`https://pulruylvpehwftwqcvct.supabase.co`, Render Singapore
`https://daily-motion-staging-api.onrender.com`, revision `8e5af65`, Alembic `0003`.
Hosted readiness, restricted role/forced RLS and public authentication-denial
checks pass. No real OTP/SMTP or authenticated hosted sync result is claimed:
the two controlled inboxes are now designated and both real email-auth requests
returned HTTP 200, but delivery/verification and custom SMTP remain unqualified.
The observed dashboard requires SMTP before applying the prepared code templates.
See [hosted evidence](docs/evidence/phase0-hosted-staging-2026-10-14.json) and
[DM-018](docs/DECISIONS.md#dm-018--render-staging-provider-qualification)
for the staging hosting exception; production Cloud Run Mumbai is unchanged.

Install [uv](https://docs.astral.sh/uv/) and start the synthetic database using
[infra instructions](infra/README.md). From `services/api`:

```sh
uv sync --frozen --extra dev
uv run --no-sync ruff format --check .
uv run --no-sync ruff check .
uv run --no-sync mypy src
uv run --no-sync pytest -q
```

Set `DM_TEST_ADMIN_URL` to the dedicated test database before running integration
tests. For the local Compose service, the synthetic development value is
`postgresql+psycopg://dm_admin:local-development-only@127.0.0.1:25432/daily_motion_test`.
Tests rebuild only that database's training schema. Without this variable,
PostgreSQL tests are explicitly skipped; unit tests alone do not qualify sync.

For a configured API, copy `.env.example` to an ignored `.env`, apply Alembic with
separate migration credentials, and provision the restricted runtime role's table
grants. Start with `uv run --no-sync uvicorn daily_motion.main:app --no-access-log`.
Unconfigured authentication and unknown/inactive accounts fail closed. Account
initialization derives identity from the verified JWT and confirms current provider
identity before creating the application account. Set `DM_ENVIRONMENT`,
`DM_SUPABASE_URL`, `DM_SUPABASE_PUBLISHABLE_KEY`, `DM_JWT_ISSUER` and
`DM_JWT_AUDIENCE` as shown in [the API environment template](services/api/.env.example).
Migration `0003` adds the minimal profile and irreversible account-retirement
barrier; apply it before enabling initialization. Normal requests require a
non-owner `NOBYPASSRLS` role; do not run the API with migration credentials.

## Connected synchronization development

Run the actual Flutter HTTP client against signed test JWTs and restricted
PostgreSQL, with `DM_TEST_ADMIN_URL` configured and Flutter on PATH:

```sh
cd services/api
DM_RUN_CONNECTED=1 uv run --no-sync pytest -q -s
uv run --no-sync python scripts/export_openapi.py
uv run --no-sync python ../../tools/generate_transport.py
cd ../../apps/mobile
dart format lib/sync/transport_contract.dart lib/sync/transport_limits.dart
```

The live suite starts a loopback API, verifies JWT signatures through a public
test key, and launches Flutter tests. It uses real SQLite and PostgreSQL rather
than an authentication or database bypass. The account case controls the OTP and
provider-user HTTP boundary while exercising real JWT verification, API account
initialization, RLS and A → B → A file-backed recovery. It does not prove hosted
email delivery. Ordinary `flutter test` explicitly
skips these live cases; the Python runner enables and checks them. On PowerShell,
set `$env:DM_RUN_CONNECTED='1'` before running pytest.

To exercise the debug app with a synthetic Android-emulator identity, set
`DM_DEV_ADMIN_URL` to the local Compose **daily_motion** database's admin URL
(separate from **daily_motion_test**), then run from `services/api`:

```sh
uv run --no-sync python scripts/development_identity.py
uv run --no-sync uvicorn daily_motion.main:app --env-file ../../.tools/development-sync/api.env --host 0.0.0.0 --no-access-log
```

From `apps/mobile`, run `flutter run --dart-define-from-file=../../.tools/development-sync/mobile.json`.
The ignored files contain a one-hour synthetic user JWT, the server's public
verification key and separate restricted runtime configuration. Flutter receives
only the user JWT, API URL and fixture identity; it receives no database, admin
or signing secret. Use `--mobile-api-url http://127.0.0.1:8000` for a local desktop
client. HTTP is explicitly restricted to loopback/emulator development addresses;
external APIs require HTTPS. Rerunning setup creates a fresh synthetic owner and
requires an API restart. The API rejects this public-key override outside explicit
`development`/`test`; staging and production use trusted JWKS. Hosted OTP delivery,
native secure-storage and release qualification remain separate gates.

[CI](.github/workflows/verify.yml) defines Linux PostgreSQL and Android checks plus
macOS iOS builds. [Remote CI on the audited code checkpoint passed](https://github.com/bluxo1/Daily-Motion/actions/runs/38454815935):
79 Python cases including nine live Flutter HTTP/PostgreSQL cases; 148 ordinary
Flutter cases on Linux and macOS; Android debug/profile/release and unsigned iOS
debug/release compilation. Hardware secure storage, signed iPhone installation,
physical-device durability/accessibility and phone performance remain open.
Android emulator seed/external force-stop/recover and a 200-sample debug benchmark
harness passed. [Raw evidence](docs/evidence/phase0-windows-native-2026-10-13.json)
explicitly records zero physical samples and no qualifying phone p95.

Native configuration can be checked without a phone:

```sh
python tools/check_native_config.py
python tools/check_docs.py
```

Android builds require JDK 21 and the pinned Flutter SDK's platform 36/tooling.
Task-local Android/JDK/Gradle installations are ignored under `.tools/`; set
`JAVA_HOME`, `ANDROID_HOME` and `GRADLE_USER_HOME` for the command process.
`flutter build apk --release` produces an unsigned qualification artifact until
operator-owned signing is configured. Debug/profile builds are internal tests.
iOS native compilation and signed installation require macOS/Xcode. See the
qualification procedure for exact commands, metadata and evidence boundaries.

## Documentation

Markdown remains the specification source of truth.

| Area | Documents |
| --- | --- |
| Session history | [Chronological project memory](docs/MEMORY.md) |
| Product and delivery | [Product](docs/PRODUCT.md), [PRD](docs/prd.md), [Roadmap](docs/ROADMAP.md), [Phase checklist](docs/phases.md) |
| Foundation | [Architecture](docs/ARCHITECTURE.md), [Data model](docs/DATA_MODEL.md), [API](docs/API.md), [Sync](docs/SYNC_PROTOCOL.md), [Evidence](docs/IMPLEMENTATION.md) |
| Experience | [Design](docs/DESIGN_SYSTEM.md), [User flows](docs/USER_FLOWS.md) |
| Intelligence | [ML roadmap](docs/ML_ROADMAP.md), [Predictions](docs/PREDICTION_ENGINE.md), [Assistant](docs/CHATBOT_ARCHITECTURE.md) |
| Trust and quality | [Health](docs/HEALTH_INTEGRATIONS.md), [Security](docs/SECURITY.md), [Testing](docs/TESTING.md), [Review](docs/ADVERSARIAL_REVIEW.md) |
| Conventions | [Decisions](docs/DECISIONS.md), [Contributing](docs/CONTRIBUTING.md), [Rules](docs/rules.md), [Handoff](docs/prompt.md) |

Deliver and qualify offline logging first. Programs, health, import, billing,
predictions and the assistant remain in their later roadmap phases.
