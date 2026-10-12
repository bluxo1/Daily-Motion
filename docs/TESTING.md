# Testing and release qualification

Planning baseline: 2026-10-12. This is the intended verification strategy for future implementation. The current documentation task can validate Markdown coverage, links, diagrams, and agreement between decisions; it cannot establish application performance, synchronization correctness, model quality, or app-store readiness.

Tests prioritize the core loop in [PRODUCT.md](PRODUCT.md): create routine, start workout, log sets, finish, and inspect history/progress. Test ownership and scope follow [ROADMAP.md](ROADMAP.md). The free MVP has no health integration, prediction service, assistant, imports, billing, or multiweek program UI to qualify.

## Test layers and fixtures

| Layer | Main responsibilities | Execution |
| --- | --- | --- |
| Dart domain/controller unit tests | Set semantics, units, routine/session rules, timer restoration, local command state | Every relevant PR |
| Flutter widget tests | Workout controls, keyboard focus, validation, adaptive navigation, semantic labels | Every relevant PR |
| Repository integration tests | Real Drift transactions, migrations, outbox, shadow/working projections | Every persistence/sync PR |
| Backend/database tests | Real PostgreSQL constraints, transactions, auth, RLS, command behavior, job leases | Every backend/schema PR |
| Contract tests | OpenAPI, mobile DTOs, error/version compatibility, shared numeric fixtures | Every interface PR |
| Device end-to-end tests | Complete training flow, process lifecycle, connectivity, platform permissions | Release candidates and relevant changes |
| Performance/accessibility qualification | Durable logging latency, frame traces, memory, screen reader usability | Foundation spike and releases |
| Future ML/assistant evaluation | Predictive value, leakage, tool authorization, grounding and confirmations | Applicable phase only |

Prefer tests of observable domain outcomes over implementation-shaped mocks. Use controlled clocks, fake network transports, deterministic IDs, and seeded data. Use real SQLite/PostgreSQL for behavior that depends on transactions, locking, foreign keys, RLS, and migrations. HTTP mocks alone cannot prove synchronization correctness.

Fixtures include a new account, sparse history, a ten-year advanced-athlete history, large custom catalogs, unusual units, manually backdated logs, corrected historical sets, incomplete workouts, and multiple devices. Never copy production health records, notes, assistant conversations, or user emails into fixtures. Maintain versioned fixtures in the repository with explicit scenario purpose; generated random tests retain failing seeds.

## Workout and interface behavior

Domain tests cover warm-up versus working sets; planned versus reported performance; top/back-off tags; skipped versus completed sets; optional RIR or RPE; unilateral/load conventions; weighted versus assisted/bodyweight exercise semantics; variants, custom exercises, and substitutions. Basic duration/distance entries work for holds/carries but are excluded from strength forecasting. Missing effort or load must not become zero. Unit conversion round trips preserve canonical values and display intent without repeated rounding drift. Comparing strength across different variants/equipment/load conventions requires explicit comparability rather than matching display names.

Routine changes affect future starts, while an already started session preserves its self-contained plan snapshot; its source routine ID is provenance rather than a required synchronized foreign key. Substitution records performed identity without rewriting the original plan. Supersets preserve observed logger order and its source; do not assert physical execution chronology without instrumentation. Observed rest remains distinguishable from configured rest. Historical corrections append auditable truth and refresh derived eligibility. Explicit deletion removes personal payload and derived eligibility.

Widget tests verify one-handed logging, large readable metrics, validation without losing input, rapid repeated taps, disabled duplicate submission only during the short local transaction, keyboard next/done behavior, unit labels, and optional effort entry. Network failures must not produce a blocking overlay on the active workout. Errors distinguish local-save failure from cloud-sync failure; an unsaved set cannot be presented as durably saved.

Verify prefill precedence and provenance, rep-range fallback, blank actual effort, and unchanged canonical load through display-unit switches. Previously failed/warm-up outcomes cannot silently become completed working-set defaults. Check filled-action text/contrast roles explicitly rather than applying primary text indiscriminately to an accent background.

Platform tests cover iOS navigation/keyboard/sheet conventions and Android back/predictive-back behavior. Back navigation cannot implicitly finish or discard a workout. Screen readers announce exercise, set type, load, reps, effort, and completion clearly. Test at large text sizes, reduced motion, high contrast, and with haptics/notifications disabled. Workout controls provide at least 48 logical pixels of touch area; chart information remains available as accessible text. See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

## Offline, synchronization, and crash fault matrix

Implement a deterministic fault harness around the protocol in [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md). Assert invariants after every step and after recovery, not just the final happy-path screen.

| Scenario | Required result |
| --- | --- |
| No connection after first verified signup; access JWT expires | Start/edit/finish workouts, edit routines, and view local history still work; sync pauses |
| Process killed during local transaction | Entire command is committed with outbox, or neither is; no phantom saved set |
| Process killed after local commit before upload | Restart restores the workout and pending command |
| Server commits but response is lost | Exact retry returns the same acknowledgement; no duplicate session/set |
| Client receives acknowledgement but crashes before persistence | Retry/recovery acknowledges the same mutation safely |
| External pull while a root has pending edits | Shadow advances; working projection and original expected revision remain intact |
| Own acknowledgement arrives after newer external state | Newer shadow is not downgraded; successor uses its own predecessor revision |
| Two devices edit the same session, even different sets | Aggregate conflict preserves both branches for explicit resolution |
| Completion/deletion races child changes | One revision wins; the stale command conflicts without violating lifecycle rules |
| Devices independently create offline workouts | Stable distinct IDs remain distinct; retries do not multiply either workout |
| Pull pagination during concurrent commits | Every committed change is eventually observed; cursor never skips a late commit |
| Snapshot imports while the user logs another set | Staging activation preserves pending commands and local-only creations |
| Snapshot expires, exceeds bounds, or fails checksum | Existing state remains usable; no partially activated bootstrap |
| Snapshot generation races account deletion | Disabled account cannot publish/read a usable snapshot |
| Workout deletion races snapshot/derived-job preparation | Erasure-epoch mismatch rejects late publication even though account remains active |
| Account deletion occurs after request authentication but before owner lock | Under-lock state check rejects later mutation/job/snapshot effects |
| Old cursor/token is used after permanent deletion | Feed redactions and invalidated snapshots cannot return erased values |
| Routine/session command exceeds transport bounds | Shared local validation preserves its draft; adaptive packing never strands an accepted command |
| Feed pruning followed by replay of deleted IDs | Retired IDs prevent resurrection; stale updates cannot become creates |
| Account switch with pending operations | Original operations remain owner-scoped and never upload to the new account |

Add latency, timeouts, connection flapping, duplicate/out-of-order delivery, schema mismatch, disk-full/local DB errors, expired cursor/generation, and interrupted migration to the matrix. Rest timers survive suspension and process restart, use persisted anchors, and handle clock/time-zone changes conservatively. Notification delivery is not a timer-correctness assertion.

Property-based tests generate session commands and transport failures. Assert unique stable identities, monotonic accepted root revisions, idempotent retries, no silent overwrite/rebase, no tombstone resurrection, owner isolation, and convergence after explicit conflict resolution. Do not assert automatic convergence of conflicting branches when the product requires user resolution.

## Backend, database, and security

Exercise domain API behavior with valid, expired, malformed, wrong-issuer/audience, revoked-session, and disabled-account credentials. Test account status checks independently of token expiry. Owner A cannot read/write owner B's roots or nested IDs, use B's prediction identifiers, or download B's snapshot/export. Missing transaction-local tenant context fails closed. Pooled connections cannot leak the previous tenant. Tests run under the actual restricted runtime role, not only the migration owner.

Verify composite owner-aware foreign keys, session CAS, immutable historical corrections, receipt uniqueness/hash binding, retired UUID checks, and atomic feed publication. Deliberately force transaction rollback after intermediate writes. Exercise simultaneous transactions against the per-user feed lock and ensure committed cursor ordering. Validate new/existing migration paths on real PostgreSQL and every supported released Drift schema. [Drift migration testing](https://drift.simonbinder.eu/migrations/)

Job tests cover duplicate execution, crashed workers, lease expiry/renewal, retry exhaustion, deletion racing job completion, and artifact cleanup. Prove ordinary jobs cannot publish after disable while authorized erasure jobs still complete in deleting state. Sensitive-data tests scan logs/crash breadcrumbs and fixtures for token, set payload, note, health, and prompt leakage. Account deletion tests verify immediate access disable, live-store purge, model eligibility exclusion, snapshot/export removal, and documented backup-restore suppression. See [SECURITY.md](SECURITY.md).

## Future prediction, assistant, and health qualification

Phase 3 requires deterministic baseline regression fixtures and cross-language parity for units, rounding, estimated-strength formulas, and eligibility. Test matching-load rep estimates, Epley exclusion for added-bodyweight/assistance/machines, separate top/back-off groups, same-scale effort inequalities, and observed PR direction. Training/evaluation cutoffs use committed visibility fences/source manifests; simulate an early acceptance timestamp with a late commit and prove it is excluded from an earlier snapshot. Later sets, workout totals, corrections, and future readiness cannot leak into features. Include temporal holdouts, user holdouts, cold-start/sparse-data cohorts, calibration, abstention, and baseline comparisons. Evaluate by exercise/load conventions and experience, not only a pooled average. Model release criteria live in [ML_ROADMAP.md](ML_ROADMAP.md).

Phase 4 tests the assistant against mocked tool results and real authorization boundaries: unsupported numerical claims, absent predictions, stale revisions, malicious notes/imported text, oversized context, repeated tool calls, cancellation, and schema-invalid arguments. A future-plan write requires an explicit confirmation bound to its proposal/current revision. Race a local edit/draft against confirmation and prove the client reservation prevents a hidden overwrite without holding SQLite across network I/O. Kill the app after dispatch, lose the response, and reconcile the same receipt before unlocking the affected root. Test unseen pending edits on another device resolve through CAS. No assistant path commits active or historical workouts. Test rejection and expiry as carefully as acceptance. Offline users retain the entire logger when AI is unavailable. See [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md).

Phase 2 optional health export tests app-owned identifiers/versions, lost acknowledgements, corrections, deletions, permission revocation, and designated-device changes. Race an obsolete accepted export with deletion/correction/exporter-generation change, and verify pre-write refresh plus post-write compensation rather than stale record recreation. Phase 6 additionally tests read-permission ambiguity, unavailable providers, history limits, duplicate origins, source deletions, expired change tokens, and local-only data boundaries. Test physical devices; permission mocks are insufficient. See [HEALTH_INTEGRATIONS.md](HEALTH_INTEGRATIONS.md).

## Performance and release gates

Measure durable local set saves from command invocation to committed local acknowledgement with realistic history, in profile/release builds. The target is p95 at most 100 ms on the declared physical qualification cohort, with airplane mode and background sync independently exercised. Record device, OS, build, sample count, percentile method, and traces. Do not subtract inconvenient outliers silently or equate a fast optimistic animation with durable persistence. Test frame pacing, scrolling, memory, and battery during a representative long workout.

The crash-free-session target is 99.9%. Define numerator, denominator, observation window, build, and cohort; report results as targets until measured. A small dogfood sample with no crashes does not demonstrate 99.9% reliability. Public release requires zero known workout-data-loss/tenant-isolation blockers and completed controlled crash/offline qualification even before enough telemetry exists for a stable population estimate.

GitHub Actions runs formatting/linting, scoped unit/widget/backend/database checks, contract validation, and migration tests. Android builds run on Linux; iOS builds/tests require macOS signing infrastructure. Release candidates cover the oldest supported and current OS families, a representative constrained Android phone, and a physical iPhone. Review privacy/store disclosures, in-app deletion, permission text, incident contacts, rollback compatibility, and restoration drills before rollout.

Documentation changes run Markdown-only checks: required files, working relative links, closed fences, Mermaid syntax/render review, phase terminology, and consistency of API/data/sync/ML decisions. Current planning verification must be reported separately from future application checks, with no invented passing test suite.
