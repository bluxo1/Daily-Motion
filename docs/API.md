# API and domain interfaces

Status: accepted planning baseline. Updated: 2026-10-13. The Phase 0 service implements scoped workout/sync and account-initialization proofs; [IMPLEMENTATION.md](IMPLEMENTATION.md) and [checked OpenAPI](../contracts/openapi.json) identify its actual surface. Other interfaces/examples below remain planned, not released.

Keep a small versioned HTTP/JSON surface around domain capabilities. FastAPI owns authorization and authoritative cloud mutations; mobile domain controllers own immediate local actions. Numerical prediction and assistant interfaces are planned now but implemented only in their roadmap phases.

## Boundaries and conventions

Process liveness is `GET /healthz`. The staging deployment now also prepares
`GET /readyz` (infrastructure endpoint, outside the versioned transport schema):
verified hosted configuration, restricted database role, current Alembic revision,
required table grants/forced RLS and empty-owner denial must pass. It returns
`{"status":"ready"}` or a sanitized 503 with `service_not_configured`/
`database_unavailable`; no user, token, connection or SQL payload is returned.
Readiness does not qualify email delivery or perform migrations. Unexpected
database errors in domain routes use the same safe 503 response rather than
printing parameter-bearing database exceptions. Current checked contracts are
otherwise unchanged. [Staging deployment](../infra/staging/README.md).

| Domain | Interface responsibility | First availability |
|---|---|---|
| Authentication | Supabase email OTP request/verification/refresh; API verifies JWT and active application account. No custom password store. | MVP |
| Account/profile | Initialize account, preferences, account export/deletion, local-owner lifecycle. | MVP |
| Catalog | Versioned catalog manifest/definitions; private custom movement/variant commands. | MVP |
| Routines | Read current immutable template, create routine, publish revised template, archive/delete with explicit semantics. | MVP |
| Programs | Publish immutable multiweek version, assign slots and explicitly reschedule/skip. | Phase 2 |
| Workouts | Create/start session, record/correct sets, group/substitute, finish/abandon/delete; read current history. | MVP |
| Synchronization | Push typed commands, pull ordered changes and bootstrap consistent current state. | MVP |
| Analytics | Local comparable history/PRs initially; bounded cloud queries with revision/freshness later. | MVP local; Phase 2 richer |
| Predictions | Versioned reference/estimate/unavailable result from dedicated numerical code. | Phase 3 |
| Recommendations | Preview, expose, accept/reject and audit proposed progression or program changes. | Phase 3+ |
| Assistant | Streaming conversation, bounded read tools, future-plan proposals and confirmed commits. | Phase 4 |
| Health | Device adapter/export state first; consented observation processing later. No generic cloud health-ingestion route in MVP. | Optional Phase 2 export; Phase 6 reads |

Use `/v1` for the initial cloud contract, UTC RFC3339 timestamps, UUID strings, explicit units and typed nullable measurements. Decimal mass/distance values are encoded as decimal strings; counts and seconds are integers where applicable. Cursors and confirmation tokens are opaque strings. JSON null retains unknown semantics; omitted patch fields mean no requested change.

The server derives the owner from verified identity. Client-controlled installation IDs and timestamps are provenance only. Never accept an assistant-selected owner or a generic SQL/query endpoint.

Generated OpenAPI, derived mobile DTOs/limits and cross-language fixtures are implementation artifacts under `contracts/` and `apps/mobile/lib/sync/`. Markdown remains the specification source of truth. Command-specific payload schemas are declared in OpenAPI; original validated operation JSON is retained for receipts and own echoes. Optional defaults normalize a separate domain copy without rewriting frozen requests.

## Authentication and account lifecycle

Mobile calls Supabase's supported SDK for OTP and refresh. Configure explicit code emails, production SMTP, verification limits and secure token persistence. After verification, `POST /v1/account/initialize` idempotently creates the app account/profile for the verified subject, validating current provider identity and deletion state. It cannot recreate an erased account using an old JWT.

The implemented initialization request is an empty, closed `{}` object. It accepts
no owner, email, device-selected identity or profile mutation. The API verifies
the JWT, then calls the configured HTTPS Supabase `/auth/v1/user` with the same
token and a publishable key. Current subject, confirmed email and provider account
eligibility must match. Redirects and oversized provider responses fail closed.
Provider unavailability returns a safe 503; invalid identity returns 401, without
creating an application account.

Within one restricted-role transaction, a per-owner advisory lock serializes
absent-account initialization with retirement, the existing `owner_state` guard
validates active state and insert-on-conflict creates a single minimal `profiles`
row with unit `kg`. This uses the existing application-account authority, not a
second user model. Repeated calls retain the generation, feed/cursor position,
profile and training data. It creates no personal workouts or device-ownership
model. The generated response extends `/v1/me` with `profile: {unit: "kg"}`.
Disabled/retired subjects return owner-bound `account_inactive`; an irreversible
retirement marker survives eventual account-row removal. The marker is an internal
erasure prerequisite, not a public deletion API or a completed purge workflow.

Authenticated API calls use `Authorization: Bearer <access-token>`. Signature/key, algorithm, issuer, audience, expiry and account state are checked. Supabase tokens/secret keys never appear in domain payloads or logs.

`GET /v1/me` reports cloud account state and supported contract capabilities. Offline cached identity remains sufficient for local training even when this call cannot succeed. Explicit logout locks the prior owner's local database; it does not silently discard pending work.

Bearer JWTs remain usable until expiry unless the provider rejects them or the
application account is disabled. Normal sync validates JWT claims and guarded
application state; it does not claim immediate refresh-session revocation detection.
Current-provider checks during initialization complement those checks. Account
disable is enforced again under the same owner lock as each mutation/snapshot.

Account export is a durable owner-scoped job returning a short-lived private download when ready. Account deletion requires a deliberate UI action and recent authentication, disables cloud writes immediately, and returns job status. It is not an assistant tool. Export/deletion status routes do not expose another user's jobs.

## Workout and routine commands

All owner-scoped authoritative mutations go through the same command engine and sync feed. Future online facades can call this engine; they must not bypass its receipt/revision checks. A direct mobile Supabase upsert is not an alternative mutation path.

Representative commands:

- `create_routine` and `publish_template`: root metadata and a new immutable template with ordered prescriptions.
- `create_session`: stable session/instance/set IDs and a self-contained plan snapshot, with optional source lineage.
- `record_set`: records actual values for an existing planned set or an explicitly added set, using a stable set UUID.
- `correct_set`: changes previously recorded observations, including reason/provenance; preserves prior values.
- `substitute_exercise`: creates a replacement instance while preserving the intended/original instance and its completed sets.
- `set_group` and `reorder_exercises`: explicit grouping/order changes; measured completion chronology remains separate.
- `complete_session` or `abandon_session`: lifecycle transitions preserving performed work.
- `delete_session`: explicit permanent deletion; no implicit create/upsert of retired IDs.
- `update_profile` and `create_custom_variant`: independent roots with the same owner/idempotency discipline.

Every workout command checks/increments the session root revision, including changes to children. A completed session uses historical correction commands rather than silently reopening. Read endpoints support owner filters, pagination and bounded comparisons; offline screens normally read SQLite instead.

## Sync examples

`POST /v1/sync/push` sends up to 50 eligible head commands from independent roots per request, with a 1 MiB decoded-body operating limit. Each complete command is limited to 256 KiB in the shared canonical UTF-8 representation, including a bounded envelope. Mobile/server serializers enforce the same bound before local acceptance; oversize drafts remain editable. Pack batches adaptively by byte size. Long free workouts use incremental `add_exercise`/set commands rather than an unbounded creation blob. One root's dependents wait for its predecessor acknowledgement before their envelope is prepared. A first `create_*` expects revision zero.

```json
{
  "schema_version": 1,
  "operations": [
    {
      "mutation_id": "3cbb7d94-81e0-4a36-b76f-e6473d85c9b0",
      "installation_id": "c211c4b4-c690-4904-ac66-eae61e7c9f5b",
      "aggregate_type": "workout_session",
      "aggregate_id": "1051c381-c887-419a-9f51-814446d2472f",
      "expected_revision": 7,
      "command": "record_set",
      "occurred_at": "2026-10-12T13:10:00Z",
      "recorded_at": "2026-10-12T13:10:04Z",
      "payload": {
        "session_exercise_id": "0f9ee9be-68d5-4cf0-b40d-51bd1d6d1b36",
        "set_id": "6849f41a-1460-4914-998a-d8084a404a89",
        "execution_status": "completed",
        "actual": {
          "load": {"value": "100.0", "unit": "kg", "basis": "total_external"},
          "reps": 5,
          "rep_convention": "bilateral",
          "effort": {"scale": "rir", "value": "2.0", "source": "self_reported"},
          "duration_seconds": null,
          "distance": null
        },
        "completion_seq": 9,
        "order_source": "logged"
      }
    }
  ]
}
```

The stored prescription for this set is not overwritten by `actual`. A timer observation would identify its measurement kind; it must not masquerade as measured rest.

```json
{
  "results": [
    {
      "mutation_id": "3cbb7d94-81e0-4a36-b76f-e6473d85c9b0",
      "status": "accepted",
      "aggregate_id": "1051c381-c887-419a-9f51-814446d2472f",
      "accepted_revision": 8,
      "accepted_at": "2026-10-12T13:10:05Z"
    }
  ]
}
```

Results are `accepted`, `duplicate`, `conflict` or `rejected`. Independent operations may succeed even if another root conflicts. Endpoint authentication/body-limit failures reject the whole request before domain execution. Exact retries return the original acknowledgement; the same mutation ID with a different validated body is rejected.

```json
{
  "mutation_id": "3cbb7d94-81e0-4a36-b76f-e6473d85c9b0",
  "status": "conflict",
  "aggregate_id": "1051c381-c887-419a-9f51-814446d2472f",
  "expected_revision": 7,
  "current_revision": 9,
  "error": {"code": "revision_conflict", "retryable": false}
}
```

Do not automatically retry that operation against revision 9. Present the preserved working branch alongside authorized server state. Resolution creates new mutation IDs.

`GET /v1/sync/pull?cursor=<opaque>&limit=100` returns ordered change batches, opaque `next_cursor`, explicit `next_position`, `has_more`, verified owner, schema version, generation and erasure epoch. Persist a full page and cursor atomically. The Phase 0 feed uses live `{position, operation, revision}` deltas reduced against the acknowledged shadow, or erased `{position, aggregate_id, redacted, retired_ids}` entries without personal payload. Bootstrap carries current projections. Permanent deletion redacts prior feed payloads while preserving positions and invalidates older snapshot tokens. Sync/snapshot responses are private and no-store.

`POST /v1/sync/bootstrap` prepares a consistent owner snapshot; page reads use the returned token. Bind token expiry, checksum, schema version, captured cursor and owner erasure epoch. Publication/page reads reject stale epochs, including a snapshot prepared before workout deletion but published afterward. Expired cursors/snapshots return typed recovery errors. Never discard pending local work during bootstrap. [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md) defines commit order, materialization and retention.

The implemented request includes `installation_id`, binding a per-device snapshot
slot. The manifest includes verified owner, generation/epoch, installation, captured
position/cursor, page count, checksums and UTC expiry. Pages contain `roots` and
minimal `retired_ids`; checksums cover their exact canonical JSON before defaults.
`GET /v1/sync/bootstrap/validate?token=<opaque>` revalidates immediately before
activation and returns current `/v1/me` context. Activation rejects expiry,
generation/epoch mismatch, incomplete/corrupt pages and unusable retention cursors.
Already-issued responses cannot be recalled; subsequent authenticated contact
enforces newer erasure state before upload.

`/v1/me` advertises command/batch/page/snapshot limits plus `minimum_position` for
pruned feed history. Push responses wrap per-mutation results with owner/version/
generation/epoch context. `X-DM-Contract: 1` is supported; other versions return
`426 upgrade_required`. Cursor/generation expiry returns `bootstrap_required`;
expired/invalidated snapshots require staging recovery. `account_not_initialized`
pauses sync without deletion. `account_inactive` includes verified owner/version;
only a matching-owner lifecycle response permits local account erasure.

## Analytics and predictions

An analytics query names a capability and bounded parameters, such as exercise history, measured PRs or muscle working-set counts. Results include comparison conventions, time range, calculation version, coverage and source revisions. The LLM does not perform its own arithmetic over raw rows.

Local analytics can include unsynced working state and label it accordingly. Cloud analytics/predictions include only acknowledged state. Capture a committed owner-feed `visibility_cursor` in the same consistent read snapshot as server prediction features, with an exhaustive source manifest or manifest reference. Acceptance timestamps alone do not establish visibility when commit is delayed. A server answer cannot claim awareness of newer unsynced sets.

Phase 3 `POST /v1/predictions` requests an explicit task: `expected_reps`, `expected_load`, `next_set`, `session_outcome`, `estimated_strength` or `progression`. The first supported algorithms can return a reference or unavailable result for unsupported tasks. Do not expose a task as a validated estimate just because its enum exists.

Inputs identify the exercise variant/loading convention, prescription, prediction horizon and relevant session/root revision. The service computes trusted historical features. A request cannot insert fabricated outcomes or select another owner.

```json
{
  "prediction_id": "84f9d96f-7322-4e52-b44f-3566e1a3e184",
  "task": "expected_reps",
  "status": "reference",
  "method_version": "last-comparable-v1",
  "generated_at": "2026-10-12T13:12:00Z",
  "input_cutoff_at": "2026-10-12T13:11:58Z",
  "source_scope": "server",
  "visibility_cursor": "opaque-committed-owner-feed-fence",
  "source_revisions": [
    {"aggregate_id": "1051c381-c887-419a-9f51-814446d2472f", "revision": 8}
  ],
  "outputs": {
    "reference_reps": {"value": 5, "unit": "reps"},
    "reference_load": {"value": "100.0", "unit": "kg", "basis": "total_external"}
  },
  "evidence_count": 1,
  "missing_features": ["measured_rest"],
  "interval": null,
  "limitations": ["Historical reference, not a capacity forecast."]
}
```

`status` is `reference/estimate/unavailable`. Numerical output values always use typed value/unit structures; task-specific names distinguish `reference_reps` from `expected_reps`. Local results use `source_scope=local`, `visibility_cursor=null`, applicable `local_seq` alongside acknowledged revision, and a consistent local feature manifest. Statistical intervals remain null until calibrated; evidence counts are not confidence probabilities.

Requests/results are immutable, with explicit invalidation when supporting inputs change. Store method/model and feature versions, captured erasure epoch and whether a suggestion was displayed. Before storing/publishing a derived result, recheck owner access/epoch under the guard; stale work after erasure is discarded/recomputed. The numerical policy is defined in [PREDICTION_ENGINE.md](PREDICTION_ENGINE.md).

## Recommendation and assistant actions

Recommendations separate generation, exposure and acceptance. Rejection/override is a valid outcome, not a service error. `accept` never means a background mutation has already bypassed the normal domain path.

Future assistant tools expose bounded capabilities such as `get_today_plan`, `get_last_session`, `get_exercise_history`, `get_training_balance`, `get_prediction`, `get_progression_recommendation`, `propose_substitution` and `draft_program_change`.

Write flow:

1. A typed tool produces an owner-bound proposal with exact diff, target/base revisions, rationale, limitations and expiry.
2. The client checks for conflicting local pending work/drafts and binds its preview to each affected root's `local_seq`.
3. The user explicitly confirms that diff in UI. The app requests a short-lived owner/diff-bound confirmation capability through a dedicated authenticated UI path excluded from the model's tool allowlist. The server records the confirmation event and issues its opaque capability; no signing secret lives in mobile or model context.
4. Immediately before dispatch, one short local transaction rechecks those sequences/empty affected-root outboxes and durably reserves only those future-plan roots. Do not hold a SQLite transaction across the network. `POST /v1/assistant/proposals/{id}/commit` validates identity, token, diff digest, expiry, current policy/consent, cloud revision and idempotency before calling the same domain command engine; the server cannot observe unsynced client edits.
5. Reconcile the authoritative receipt through sync before releasing the local reservation. A timeout is an unknown outcome, not cancellation: query/retry the same commit identity and preserve the reservation across restart. An expired/stale preview is regenerated and reconfirmed. Record tool/proposal/command audit links. Other offline devices may still have pending edits; later CAS conflicts preserve them rather than silently merging.

The first assistant release commits only future routine/program changes. It can suggest an active-workout substitution, but the user applies it through the ordinary local picker flow. It cannot edit historical outcomes, export private records, delete accounts or change health permissions. Conversation transport can use SSE; reconnects identify a turn ID to avoid generating duplicate commits or treating partial output as confirmation.

Offline users retain all core features. Assistant UI explains unavailable cloud reasoning and offers normal workout controls. Cached responses include their age and data revision. [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md) specifies tool permissions and grounding.

## Health interfaces

Phase 2 adapters export only a designated device's cloud-accepted completed workout summary with a stable session identifier and monotonic version. Before each native write, refresh active account, exporter generation and latest nondeleted completed-session revision; drop obsolete intents. Reconcile again after native acknowledgement and compensate if a correction/deletion raced the write. Record provider ID, export revision/status and retry state. No fabricated energy, heart rate or GPS.

Later health reads are purpose-specific device capabilities with provenance, coverage and consent. Do not introduce an unrestricted upload endpoint or send raw observations into chat context. Permission denial/revocation, availability and deletion differ across platforms; [HEALTH_INTEGRATIONS.md](HEALTH_INTEGRATIONS.md) is authoritative.

## Errors, limits, and compatibility

Errors have `code`, safe `message`, `retryable` and `request_id`; domain conflicts can include authorized target revision. Do not expose credentials, SQL, another owner's existence or raw request payloads.

| Condition | Transport/default behavior |
|---|---|
| Expired/missing cloud credentials | HTTP 401; preserve local work and pause sync. |
| Inactive/deleting account | HTTP 403/410 as appropriate; block upload and apply owner lifecycle. |
| Unauthorized/missing target | Non-enumerating not-found result. |
| Wrong revision/retired ID | Conflict or rejected typed operation; explicit resolution required. |
| Unsupported schema | `upgrade_required`; preserve local/export access and pending bodies. |
| Invalid domain values | HTTP 422 or rejected operation with field codes. |
| Expired cursor/snapshot | `bootstrap_required` / `snapshot_expired`; no local reset. |
| Rate limit | HTTP 429 with bounded retry guidance. |
| Capacity/transient dependency failure | Typed capacity/temporary error; no silent truncation. |

Rate limits are per subject/device/IP as appropriate, with separate stricter OTP, assistant and expensive-export budgets. Production tuning follows abuse/load testing rather than universal guessed requests-per-second values.

Support current and previous released client contracts during rollout. Additive fields, unknown optional output handling and schema-specific validation preserve compatibility; do not silently ignore unknown mutation commands. Pin dependencies and generate clients from reviewed schemas. Contract fixtures cover decimal units, null/zero, root CAS, retries, tombstones, freshness and proposal confirmation. See [TESTING.md](TESTING.md).
