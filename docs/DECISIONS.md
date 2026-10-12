# Architecture decision log

Updated: 2026-10-12. All entries below are **Accepted for planning** on 2026-10-12. They define the implementation baseline, not a claim that feasibility spikes, security qualification or store approval have passed.

Propose a change through a reviewed documentation PR. Record the old decision as superseded and link its replacement; do not erase why a decision existed. Product constraints come from [PRODUCT.md](PRODUCT.md); authoritative behavior lives in the linked domain documents. Operational thresholds are configurable policies to validate, not exercise-science facts.

## Index

| ID | Decision | Primary specification |
|---|---|---|
| DM-001 | Flutter with explicit platform adaptation | [ARCHITECTURE.md](ARCHITECTURE.md), [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) |
| DM-002 | Modular Python API rather than microservices | [ARCHITECTURE.md](ARCHITECTURE.md) |
| DM-003 | Managed PostgreSQL/Auth, India-region default | [ARCHITECTURE.md](ARCHITECTURE.md), [SECURITY.md](SECURITY.md) |
| DM-004 | Durable local SQLite as mobile source of truth | [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md) |
| DM-005 | Aggregate revisions and explicit conflicts | [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md) |
| DM-006 | Commit-ordered owner feed and bounded bootstrap | [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md) |
| DM-007 | Normalized current state plus historical observations | [DATA_MODEL.md](DATA_MODEL.md) |
| DM-008 | Immutable templates/programs and session snapshots | [DATA_MODEL.md](DATA_MODEL.md) |
| DM-009 | Explicit measurement and comparison semantics | [DATA_MODEL.md](DATA_MODEL.md) |
| DM-010 | Dedicated numerical engine before learned models | [PREDICTION_ENGINE.md](PREDICTION_ENGINE.md) |
| DM-011 | Grounded assistant tools with confirmed writes | [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md) |
| DM-012 | Purpose-separated data use and deletion | [SECURITY.md](SECURITY.md), [ML_ROADMAP.md](ML_ROADMAP.md) |
| DM-013 | Staged health/wearable integration | [HEALTH_INTEGRATIONS.md](HEALTH_INTEGRATIONS.md) |
| DM-014 | Required account with email OTP; offline auth separation | [API.md](API.md), [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md) |
| DM-015 | Restrained strength/hypertrophy MVP; free launch | [PRODUCT.md](PRODUCT.md), [ROADMAP.md](ROADMAP.md) |
| DM-016 | Internal modules and generated contracts before shared packages | [ARCHITECTURE.md](ARCHITECTURE.md), [CONTRIBUTING.md](CONTRIBUTING.md) |
| DM-017 | Real-device quality and safety gates | [TESTING.md](TESTING.md) |

## DM-001 — Mobile technology

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Use Flutter, Riverpod for state/dependency wiring, Drift for persistence and internal feature/domain/design modules. Adapt navigation, controls, typography and integrations by platform.

**Alternatives:** React Native; Kotlin Multiplatform with SwiftUI/Compose UIs; separate native apps.

**Reasoning:** Custom workout UI and one primary mobile codebase fit a lean team. Separate native UIs raise recurring implementation and QA cost. React Native is viable, but no current requirement outweighs Flutter's fit.

**Consequences:** Premium UX requires deliberate native conventions, real-device profiling and a macOS/iOS build/test path. Flutter does not guarantee native quality by itself.

**Revisit when:** Foundation spikes cannot meet input, accessibility, lifecycle or performance gates, or unavoidable native screens dominate the product.

## DM-002 — Service architecture

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** One containerized modular FastAPI application with explicit domains. Predictions and assistant orchestration join it later; durable workers use the same codebase.

**Alternatives:** Supabase-only client/RPC/Edge Functions; Node backend plus Python ML; premature domain microservices.

**Reasoning:** Custom sync and domain transactions need a clear server boundary. Python also supports future numerical work without another server language. Separate deployments add operational and consistency work before scale requires it.

**Consequences:** The team must maintain a small API in addition to Flutter. Protect module boundaries and budget inference so optional AI cannot starve core requests.

**Revisit when:** Measured inference memory/latency, independent scaling or organizational ownership justifies extraction. Do not split by feature count alone.

## DM-003 — Database, authentication platform, hosting

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Managed Supabase PostgreSQL/Auth in Mumbai and Cloud Run Mumbai for the API. Start with the managed TLS endpoint. Use app-owned schema migrations, restricted roles and owner policies.

**Alternatives:** Firebase/Firestore; managed PostgreSQL plus a separate identity vendor; self-managed database; server runtime in a distant region.

**Reasoning:** Relational workout history, constraints, revisions and future datasets fit PostgreSQL. Managed operations reduce team burden. Regional proximity helps cloud latency; local logging remains independent.

**Consequences:** Processor/backup geography and costs must be verified; regional selection is not a compliance assertion. The client cannot mutate training tables directly through a second API.

**Revisit when:** Cost, provider availability, support, contractual requirements or measured database/runtime latency fail product needs.

## DM-004 — Offline persistence

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Atomically store each local projection change, revision and outbox intent in SQLite before feedback. Use background database work and restore active sessions before network requests.

**Alternatives:** Network-first logging; optimistic memory with later saves; key/value storage for relational training history.

**Reasoning:** Loss of connectivity or process termination must not lose completed sets. SQL supports constrained transactions and usable local analytics.

**Consequences:** Local migrations, disk failures, pending drafts and outbox recovery become release-critical. Background scheduling is only best effort.

**Revisit when:** A proven synchronization/storage solution preserves all invariants and materially reduces maintenance without weakening local durability.

## DM-005 — Conflict model

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Workout-session root CAS covers every child mutation; routine roots use the same approach. Preserve working/shadow/base state and resolve conflicts explicitly.

**Alternatives:** Device-time last-write-wins; whole-workout overwrites; child/field merges; CRDT collaboration.

**Reasoning:** Session lifecycle and measured outcomes are interdependent. Disjoint same-session conflicts are acceptable while live multi-device editing is excluded.

**Consequences:** Same-session concurrent edits can interrupt backup, but not logging. Independent devices can have independent sessions. Recovery requires clear product UI.

**Revisit when:** Demonstrated demand for collaboration/handoff justifies a formally tested finer-grained protocol.

## DM-006 — Pull ordering and recovery

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Use a transactionally locked per-owner feed counter, opaque generation cursor and bounded materialized consistent bootstrap. Keep minimal idempotency/retired-ID metadata through the account lifetime.

**Alternatives:** Bare sequences, timestamp cursors, unbounded event replay, drifting paginated snapshots, managed changefeed/CDC infrastructure.

**Reasoning:** Allocation order is not commit order. Snapshot consistency and safe old-device recovery are necessary, while CDC infrastructure is premature.

**Consequences:** Owner writes briefly serialize; transient snapshot/receipt storage needs bounds and cleanup. Feed pruning cannot weaken duplicate/deletion protection.

**Revisit when:** Measured owner contention, bootstrap size or metadata cost requires another protocol. A migration must preserve existing offline clients.

## DM-007 — Historical truth

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Maintain normalized current projections and append-only changed-observation revisions, with separate event/recording/acceptance times and committed feed visibility fences for causal reconstruction. Privacy deletion purges payloads, including transport copies.

**Alternatives:** Destructive upserts; immutable full-session blob per change; complete event sourcing with replay-based reads.

**Reasoning:** Corrections and causal model evaluation need old observations, but replay complexity is unnecessary for ordinary screens.

**Consequences:** Analytics use corrected current truth; historical predictions retain their original inputs. Storage and deletion must cover all revision copies.

**Revisit when:** Measured storage or new audit needs warrant optimization that preserves causal reconstruction and privacy obligations.

## DM-008 — Planning versions

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** A routine points to an immutable workout template; future programs publish immutable versions. Sessions copy their own plan and exercise semantics. Source IDs are optional lineage.

**Alternatives:** Sessions join mutable routine rows; mutable program schedules overwrite past intent; separate duplicative routine and template version systems.

**Reasoning:** Future edits must not change what was prescribed or performed, and conflicted routine sync must not block a self-contained workout backup.

**Consequences:** Publish new content versions and manage references explicitly. Already started sessions change only through deliberate session actions.

**Revisit when:** New planning workflows require additional version relationships; never reinterpret past sessions through current templates.

## DM-009 — Measurements and strength comparisons

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Separate prescription/outcome, set class/purpose, load/rep conventions, effort scale, variant/setup, measured rest and logging gaps. Preserve original units and missingness.

**Alternatives:** A universal weight/reps pair; automatic RPE/RIR conversion; exercise-name joins; summed segment loads; inferred exact rest.

**Reasoning:** Advanced training includes assistance, paired equipment, unilateral work, submaximal prescriptions and varied methods. Collapsing these creates expensive historical ambiguity.

**Consequences:** Comparability is explicit; some charts/predictions must decline unsupported data. Advanced segment builders remain deferred.

**Revisit when:** Validated new measurement types or comparison models justify additive semantics, not retrospective reinterpretation.

## DM-010 — Prediction ownership and ML sequence

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** No MVP inference dependency. Begin with numerical references/versioned rules, then validated statistical/global models and hierarchical personalization. An LLM cannot generate numerical predictions.

**Alternatives:** LLM forecasts; immediate deep learning; independent per-user models; on-device learned inference from launch.

**Reasoning:** Sparse prescribed outcomes and unknown effort do not justify capacity claims. Baselines establish useful behavior and evaluation targets cheaply.

**Consequences:** Abstention/reference output is normal. Confidence probabilities require calibration; candidate data thresholds do not guarantee personalization quality.

**Revisit when:** Reliable prospective labels and measured benefit support a more complex model or on-device deployment.

## DM-011 — Assistant authority

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Typed bounded domain tools, trusted owner context, grounded numerical outputs, and explicit version-bound confirmation of future-plan writes. No SQL or administrator credentials.

**Alternatives:** Database-connected general chatbot; direct LLM mutations; conversational assent alone; universal autonomous coach.

**Reasoning:** The assistant should operate product capabilities without acquiring unconstrained data access or editing authority. Prompts do not enforce authorization.

**Consequences:** Proposal/confirmation/audit infrastructure is required. Active substitutions initially route through ordinary UI; historical outcomes and privacy controls are excluded.

**Revisit when:** Audited demand and client-side freshness/confirmation proof justify additional tools; never waive deterministic authorization.

## DM-012 — Data use, consent, retention

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Separate fitness processing, LLM processing, health permissions and voluntary population training. Imported health stays local and outside third-party LLM/global training by default. Enforce deletion across derivatives.

**Alternatives:** Bundled consent; raw history in prompts; treating deidentification as a universal permission; permanent immutable personal data.

**Reasoning:** Privacy controls must govern derived datasets and processors, not just UI switches. Population learning is optional and not needed for MVP.

**Consequences:** Maintain provenance, consent eligibility, processor inventory, retention and model-retraining policy. Do not promise immediate unlearning from trained weights or offline remote erasure.

**Revisit when:** Qualified policy/legal review and explicit consent establish a justified new purpose. Retention authority remains [SECURITY.md](SECURITY.md).

## DM-013 — Health and wearables

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** No MVP health permissions. Optional Phase 2 completed-summary export from one designated phone after cloud acceptance; consented recovery reads and wearables later.

**Alternatives:** Launch recovery dashboard; bidirectional health synchronization; phone/watch concurrent editing; inferred calories/readiness from incomplete inputs.

**Reasoning:** Platform permissions, record identity, missingness and duplicate exports need dedicated qualification. They do not improve the first logging loop enough to justify launch scope.

**Consequences:** Core data remains canonical for sets/effort. Revocation is not erasure; absent reads are not negative health evidence.

**Revisit when:** User benefit and policy/device testing justify broader integrations or managed export-device transfer.

## DM-014 — Account access

**Date:** 2026-10-12. **Status:** Accepted for planning; explicit product preference.

**Decision:** Require online email OTP signup before first training use; subsequently separate cached local identity from cloud authorization. No guest mode or social login in MVP.

**Alternatives:** Guest-first with later ownership transfer; passwords; third-party social identities and linking.

**Reasoning:** The owner chose account-before-workout. OTP limits credential-management and linking scope. Backup, recovery and cross-device services must make the account useful.

**Consequences:** Initial activation depends on email/network availability and store review. Refresh failures must never lock an established athlete out of local training.

**Revisit when:** Measured signup abandonment, delivery problems, accessibility or store feedback justify guest access or additional login methods.

## DM-015 — MVP audience and restraint

**Date:** 2026-10-12. **Status:** Accepted for planning; explicit product preferences.

**Decision:** Advanced strength/hypertrophy, India-first English adults, lean quality-first team, free launch. Routines/logging/history/progress are MVP; billing, import, health, programs and intelligence are phased.

**Alternatives:** Beginner education first; competition powerlifting/peaking; bodybuilding method automation; paid launch; international simultaneous rollout.

**Reasoning:** A credible advanced logger needs strong set semantics, but a lean team cannot ship every specialist workflow or a trusted AI coach immediately.

**Consequences:** Premium refers to design/reliability. Retention and workflow evidence precede monetization and feature expansion.

**Revisit when:** Cohort research changes the core audience, required methods, market or sustainable economics.

## DM-016 — Repository and contract reuse

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Keep app modules internal; use a small monorepo with mobile/API/contracts/infra/docs, adding offline ML work when needed. Share OpenAPI and behavioral fixtures across languages.

**Alternatives:** Packages for every layer; a universal shared-model package; separate repositories; empty service scaffolds.

**Reasoning:** Premature packaging increases release/dependency work without a second consumer. Cross-language contracts need explicit generation and parity tests.

**Consequences:** Extract only demonstrated reuse and avoid independent schema migration authorities. No repository scaffold is necessary for this documentation delivery.

**Revisit when:** A second app/client or independently owned component creates sustained reuse or release needs.

## DM-017 — Release qualification

**Date:** 2026-10-12. **Status:** Accepted for planning.

**Decision:** Gate release on physical-device durability, sync fault tests, accessibility, migration/recovery, tenant isolation and store/privacy readiness. Target durable set completion p95 <=100 ms and >=99.9% crash-free workout sessions with reported cohort evidence.

**Alternatives:** Emulator-only QA; testing only happy-path connectivity; aggregate crash statistics without workout denominator; launch deadlines overriding data-loss findings.

**Reasoning:** A logger's primary trust promise is keeping the work an athlete recorded, immediately and accessibly.

**Consequences:** Budget real iPhone/Android testing, macOS builds and controlled beta. Targets are not measurements already achieved.

**Revisit when:** Actual device/cohort data supports changed thresholds; never replace durability guarantees with favorable engagement metrics.
