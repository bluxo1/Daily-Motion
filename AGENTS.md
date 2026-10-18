# Repository Guidelines

## Project status and source of truth

This repository contains a Phase 0 development foundation for Daily Motion, not a
production-ready public app. Phase 0 remains in progress; remaining provider,
physical-device and operator qualification are open, and Phase 1 has not started. Check
[`docs/phases.md`](docs/phases.md), [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md),
and [`docs/PHASE0_EVIDENCE.md`](docs/PHASE0_EVIDENCE.md) for current evidence and
gaps. Do not infer release readiness from desktop tests or CI compilation.

Before changing product behavior, read [`docs/PRODUCT.md`](docs/PRODUCT.md),
[`docs/ROADMAP.md`](docs/ROADMAP.md), and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
For workout behavior, consult [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md),
[`docs/SYNC_PROTOCOL.md`](docs/SYNC_PROTOCOL.md), and [`docs/API.md`](docs/API.md)
together. [`docs/DECISIONS.md`](docs/DECISIONS.md) records accepted choices;
[`docs/SECURITY.md`](docs/SECURITY.md) governs identity, isolation, deletion, and
data handling.

## Project structure

- `apps/mobile/`: Flutter, Riverpod, Drift, workout domain, UI, and native adapters.
- `services/api/`: FastAPI modular monolith, PostgreSQL models, Alembic migrations,
  and API tests.
- `contracts/`: checked OpenAPI and shared contract fixtures.
- `infra/`: local services, deployment configuration, and operator runbooks.
- `docs/`: product, architecture, qualification, and implementation evidence.
- `tools/`: contract generation and repository checks.

Do not add empty services or shared packages for hypothetical reuse. Add `ml/`
only when the roadmap's reproducible experiments begin.

## Build, development, and validation commands

The pinned Flutter SDK is 3.47.7 / Dart 3.13.5 (`.fvmrc`); this Windows workspace
also has an ignored SDK at `.tools/flutter`. From `apps/mobile/`, use:

```sh
flutter pub get --enforce-lockfile
dart run build_runner build
dart format lib test
flutter analyze
flutter test
```

When using the workspace SDK on Windows, invoke `.tools\\flutter\\bin\\flutter.bat`
from the repository root and set `PUB_CACHE`, `TEMP`, and `TMP` to the task-local
paths documented in `README.md`.

Python is pinned to 3.13.14. From `services/api/`, use:

```sh
uv sync --frozen --extra dev
uv run --no-sync ruff format --check .
uv run --no-sync ruff check .
uv run --no-sync mypy src
uv run --no-sync pytest -q
```

PostgreSQL integration tests require `DM_TEST_ADMIN_URL` for the dedicated test
database; without it, those cases are explicitly skipped. The connected Flutter
HTTP/PostgreSQL harness additionally requires `DM_RUN_CONNECTED=1` and the
documented test setup. Never report skipped cases as passed. For documentation
changes, run `python tools/check_docs.py` and `git diff --check`, and review
changed relative Markdown links.

## Coding and domain conventions

Use standard Dart and Python formatters. Keep domain terms from
`docs/DATA_MODEL.md` precise: a routine, template, program version, workout session,
session exercise, and set are distinct. Keep planned, observed, inferred, and
derived values separate. Widgets render state; domain validation, persistence, and
synchronization remain in their respective layers.

## Testing and evidence

Add deterministic tests for observable behavior. Use real SQLite or PostgreSQL
when transaction, migration, or row-policy behavior matters. Sync changes need
fault/restart coverage; auth and ownership changes need isolation and lifecycle
coverage. Follow `docs/TESTING.md` for the relevant acceptance cases.

Desktop or emulator results do not qualify physical-device durability,
performance, accessibility, native secure storage, or backup behavior. Hosted
HTTP acceptance does not prove real inbox delivery or verified account sync.
Record evidence and limitations in the implementation docs rather than upgrading
a prototype or local result into a release claim.

## Branches, reviews, and security

Keep one coherent outcome per change and use short-lived `feat/`, `fix/`, `docs/`,
or `chore/` branches. Explain scope, roadmap phase, validation and limitations in
reviews. Include migration/rollback details for schema changes and contract
fixtures for API changes. Do not commit, deploy, or publish without authorization.

Keep secrets and production user data out of version control, fixtures,
screenshots, and notebooks. Example environment files contain placeholders only.
Use separate environment credentials and restricted runtime database roles; never
put Supabase service-role, signing, database, SMTP, or admin credentials in mobile
configuration or source control.
