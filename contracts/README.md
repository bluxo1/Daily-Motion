# Phase 0 contracts

`openapi.json` is generated from FastAPI. `fixtures/workout.json` is the shared
synthetic command tested in Dart and Python. Decimal measurements use strings;
canonical JSON sorts object keys and uses compact UTF-8 without ASCII escaping.

```sh
cd services/api
uv run --frozen --extra dev python scripts/export_openapi.py
uv run --no-sync python ../../tools/generate_transport.py
cd ../../apps/mobile
dart format lib/sync/transport_contract.dart lib/sync/transport_limits.dart
```

This spike supports repetition sets and create/record/correct/complete/abandon/
delete commands. Unknown commands and extra correctness fields fail validation.
`unicode_workout.json` checks code-point text limits across both reducers.
Generated mobile DTOs, schema validators and operating limits derive from checked
OpenAPI. Command-specific schemas are named by `x-command-schemas`, while original
operation JSON is retained for receipt and own-echo identity. Optional defaults
are installed only in a separate domain copy, never in frozen retry bytes.

`POST /v1/account/initialize` accepts a closed empty request and returns the
generated account response (`/v1/me` context plus minimal profile unit). Verified
JWT/provider identity establishes ownership. Dart consumes this generated DTO;
account initialization does not accept a client-selected user/owner.

Duration/distance, incremental exercise authoring and routine commands remain
future work. This contract has no previous publicly released version; unsupported
versions fail explicitly. It is not a production API qualification claim.
