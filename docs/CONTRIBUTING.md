# Contributing to Daily Motion

Planning baseline: 2026-10-12. Phase 0 implementation began after the documentation baseline. The repository now contains a development foundation, not a production application. [IMPLEMENTATION.md](IMPLEMENTATION.md) owns current evidence and gaps; root [README.md](../README.md) contains executable setup/check commands. This guide defines contribution and release conventions.

Read [PRODUCT.md](PRODUCT.md), [ARCHITECTURE.md](ARCHITECTURE.md), [DATA_MODEL.md](DATA_MODEL.md) and [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md) before changing workout behavior. [DECISIONS.md](DECISIONS.md) records accepted choices. A requested feature must identify its roadmap phase and user outcome; future AI/ML ambitions do not authorize expanding the MVP.

[prd.md](prd.md) provides testable product requirements; [phases.md](phases.md) tracks execution gates; [rules.md](rules.md) summarizes engineering guardrails; [prompt.md](prompt.md) is a reusable coding-agent handoff. They reference the authoritative specifications rather than creating separate implementation policies.

## Repository and ownership conventions

The intended monorepo is:

```text
apps/mobile/      Flutter phone application and internal modules
services/api/    FastAPI modular monolith, jobs and app-schema migrations
contracts/       OpenAPI contracts, schema fixtures and compatibility cases
infra/           Deployment configuration and operational runbooks
docs/            Markdown product/architecture source of truth
ml/              Added only when reproducible ML experiments begin
```

Do not create empty services/packages to imitate the long-term architecture. Keep shared mobile domain, data and presentation modules inside `apps/mobile/` until genuine reuse warrants a package. The API owns server domain authorization and validation; UI widgets render state and call use cases. An LLM never owns database access or numerical training calculations.

Use clear feature/domain names and distinguish routine, template, program version, workout session, session exercise and set. Preserve original scale/unit/load basis and the difference between planned, observed, inferred and derived values. Never add a convenient `weight` field whose meaning changes by exercise without a domain convention. Times include actual event context and server receipt/revision information as defined in the data/sync documents.

Keep configuration explicit across development, staging and production. No production data in fixtures, screenshots, seed files or ML notebooks. Use synthetic fixtures that cover realistic strength-training cases. Store secrets outside version control; example environment files contain names/placeholders only. Dependency updates include lockfiles, license/provenance review and targeted compatibility checks.

## Branches, commits and reviews

Use trunk-based development with short-lived branches named `feat/…`, `fix/…`, `docs/…` or `chore/…`. Keep changes reviewable, preferably one outcome per pull request. No direct production deployment from an unreviewed working tree. Conventional commit prefixes are encouraged, but meaningful messages and coherent changes matter more than strict formatting. Do not force commits, rewrite shared history or commit another contributor's unrelated work without agreement.

A PR explains the problem, resulting behavior, phase/scope, validation and material limitations. Include screenshots or measured device evidence for interaction changes, migration/rollback details for schema changes, and before/after contract fixtures for API changes. Mention updates to accepted architectural decisions. No claim of tests passing without the actual commands/environment and results.

Reviewers check domain correctness, owner isolation, offline durability, latency, revision semantics, retained history, deletion eligibility, accessibility and failure behavior. A happy-path demo is insufficient for changes to sync or assistant tools. Reviewers should challenge unnecessary abstraction and roadmap creep. For a one-engineer team, use a deliberate self-review plus an independent automated/agent review where available; public release still needs explicit qualification evidence.

## Formatting, static checks and tests

For Dart/Flutter, use `dart format`, `flutter analyze`, unit/widget tests and appropriate integration tests. Keep Riverpod controllers/use cases testable independently from widgets. Run profile/release-mode physical-device benchmarks for workout interaction changes; debug-mode timing is not a release performance result.

For Python, use Ruff formatting/linting, mypy for typed application interfaces and pytest. Use Hypothesis where it can expose meaningful invariants: unit conversion, load semantics, state transitions, operation replay, ordering and sync conflict behavior. Do not add property tests or broad abstraction simply for coverage counts.

Backend tests cover transaction boundaries, idempotency, CAS conflicts and authorization. PostgreSQL tests exercise real constraints/policies rather than substituting SQLite behavior. Contract tests use OpenAPI plus shared JSON fixtures across Python and Dart; generated clients must remain compatible with persisted mobile versions. A schema field rename is a compatibility change even when the server's own tests pass.

Changes require relevant tests and [TESTING.md](TESTING.md) acceptance cases. UI changes include keyboard, screen-reader/large-text and both platform checks. Sync changes include offline process death, retry duplication, concurrent edits, token expiry and deletion against stale devices. Do not add tests that merely repeat constants or snapshot an implementation without verifying behavior. CI checks format/lint/types/tests and documentation links; integration/physical-device suites may run in defined release jobs with stored evidence.

## Architectural proposals and documentation

For material changes, add an ADR entry before or alongside implementation: date/status, decision, alternatives, reasoning, consequences and revisit conditions. Explain the concrete problem that invalidates the previous choice. A proposal to add a service, package, feature store or event-sourcing framework must show an actual scaling/ownership/failure-isolation need.

Markdown is the documentation source of truth. Keep behavior aligned across product, roadmap, data model, sync, API, security and assistant documents. Mermaid diagrams illustrate ownership/data flow but do not override prose constraints. Update documents when code changes public behavior; do not leave “future” features described as already delivered. Check relative links, required files, Mermaid syntax where tooling exists and phase consistency. Documentation changes do not require production scaffolding or speculative endpoints.

## Database, local-storage and contract migrations

Alembic is the single owner for **application-schema** PostgreSQL migrations. It does not manage Supabase's provider-owned authentication schema. Keep migration files immutable once applied to shared environments. Review constraints/indexes/authorization together. Use additive expand/migrate/contract changes, deploy compatible readers/writers first and delay destructive cleanup until supported clients and queued offline operations no longer need the old shape.

Drift owns local migrations. Test upgrades from every supported shipped schema using realistic active sessions, drafts, outbox entries, remote shadows and conflicts. An upgrade must not discard unsynced work. Local schema version and server contract version are different concepts. Account-specific storage must remain isolated through upgrades and sign-out.

Migration PRs document forward changes, data backfill, rollback/forward-fix strategy, locks/performance and tested backup restoration. Avoid a destructive down-migration advertised as safe rollback. Rehearse substantial migrations in staging using synthetic volume. Never rebuild historical sessions from today's routine/program/catalog. Corrections retain historical provenance, while explicit permanent deletion removes payloads and derived eligibility; minimal tombstones/retired IDs exist only to prevent resurrection.

## ML experiments and assistant changes

ML begins in its assigned roadmap phase. Every experiment records code/data revision, as-of dataset construction, consent/eligibility filters, target definition, chronological and held-out-user splits, feature availability times, baseline, seed, metrics/calibration/coverage, subgroup results and artifact identifiers. Track experiments using reproducible manifests and a lightweight registry before adding infrastructure. Do not keep only the notebook that produced the winning chart.

Review target leakage, corrected-history availability, imported-data quality, missing effort/rest and recommendation selection bias. Model acceptance is based on held-out outcomes, not user acceptance of suggestions. Excluded/deleted users leave future datasets; model lineage and retraining decisions follow [ML_ROADMAP.md](ML_ROADMAP.md). Raw imported health data and personal conversations are not an unrestricted training corpus.

Assistant tools require typed contracts, owner checks, bounded context, prediction-result references and audit tests. Writes are limited to confirmed future routine/program proposals; stale/replayed confirmation and injection tests are mandatory. Active substitutions use the normal picker. Update safety/evaluation fixtures with tool or prompt changes, and demonstrate graceful failure when the model/provider is unavailable.

## Release expectations

Every public release needs a reviewed candidate, known supported devices/OS versions, relevant tests, migration/deployment order, monitoring, rollback controls and accurate store/privacy/support disclosures. India-first launch requires a current qualified privacy/security review of purposes, processors, transfers, retention, deletion and incident response. Managed infrastructure does not transfer product accountability to the provider. Flag incomplete intelligence features off; never disable the ordinary logger to compensate for an unavailable model.
