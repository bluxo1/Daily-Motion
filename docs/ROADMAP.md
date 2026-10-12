# Daily Motion development roadmap

Planning baseline: 2026-10-12. Phases are evidence gates, not calendar promises. The intended team is one to three engineers using managed infrastructure. The first public release is a free, adult, English, India-first strength/hypertrophy logger for iOS and Android. An account is required before the first workout. [PRODUCT.md](PRODUCT.md) defines scope; [TESTING.md](TESTING.md) defines detailed qualification.

[phases.md](phases.md) provides the execution checklist. Every implementation phase is not started in this documentation-only repository; this roadmap remains the detailed scope authority.

## Phase 0 — Foundations and design system

**Objective:** establish a buildable, testable offline foundation before feature breadth.

**Features:** executable interaction prototypes for onboarding, routine editing, active logging and history; token-based light/dark themes and accessible numeric/set controls.

**Technical work:** initialize `apps/mobile/`, `services/api/`, `contracts/` and `infra/` only when implementation begins. Use Flutter/Riverpod/Drift internal modules and a FastAPI modular monolith; Supabase-managed PostgreSQL/Auth and Cloud Run in Mumbai. Pin stable SDKs; verify region, backup and processor arrangements. Establish account-scoped local storage, aggregate-revision CAS sync, outbox/shadow/working-copy recovery and additive API contracts. Alembic owns application database migrations; Drift owns local migrations. CI includes formatting, static checks, tests, documentation checks and security basics.

**Acceptance:** on physical iPhone and Android qualification devices, prove local set durability during airplane mode and process death, duplicate-operation idempotency, stale-revision conflict preservation, and login expiry that pauses sync without locking local training. Demonstrate platform back behavior, large text and keyboard-safe one-handed entry. Record benchmark methods before declaring the 100 ms p95 local-commit goal met.

**Tests:** schema/migration tests, isolation/authorization, contract fixtures, sync fault injection, accessible widget prototypes and physical-device performance measurements.

**Dependencies:** approved documentation baseline, developer/store accounts, managed-provider region feasibility and India launch privacy/security review ownership.

**Excluded:** production feature completeness, shared-package extraction, separate ML deployment, feature-store infrastructure, health permissions, chat and billing.

## Phase 1 — Core logger: first public MVP

**Objective:** deliver Create routine → Start workout → Record sets → Finish → History/progress with high reliability.

**Features:** required online email OTP onboarding, units/focus, curated/custom variants, routines with targets/rest and simple supersets, empty workouts, warm-up/working classes, top/back-off purpose, optional RIR or RPE, basic holds/carries, notes, substitutions, timer/reminders, resume/abandon/finish, retained corrections, measured records and comparable load/reps charts. Include account export/deletion and workout permanent deletion.

**Technical work:** complete local-first use cases, immutable workout-template publication and self-contained session snapshots, child-edit/session-root revisions, idempotent sync, conflict UI, caching, derived-record invalidation and privacy-safe observability. Sign-out locks and retains pending owner data. Set support defaults to iOS 16+/Android 10+, phones; verify pinned toolchain compatibility at release.

**Acceptance:** the entire loop works offline after account setup with no lost acknowledged sets. Cold relaunch restores the workout and drafts. An expired account token does not stop cached routine editing/history/logging. Fault suites produce zero unintended duplicates/resurrections and no silent overwrite. Qualification covers accessibility, representative long sessions, kg/lb and load conventions. Local set commit meets the measured p95 100 ms goal. Public beta establishes activation/retention baselines and a meaningful crash-free workout-session sample against the proposed 99.9% target.

**Tests:** domain/UI/backend/database/contract/E2E coverage, schema upgrades, token expiry, simultaneous independent sessions, correction/deletion, repeated taps, device clock changes, notification denial, poor networks and physical-device release qualification.

**Dependencies:** Phase 0 durability and native-behavior gates; seeded catalog rights/quality; reviewed store disclosures, deletion/support channels and incident procedure.

**Excluded:** multiweek program UI, CSV import, estimated strength or other prediction, deterministic progression suggestions, AI, health integration, learned models, payments and wearables.

## Phase 2 — Programs, richer analytics and controlled interchange

**Objective:** make longer training plans and historical interpretation useful without automatic adaptation.

**Features:** versioned multiweek programs/templates, explicit rescheduling, working-set volume and muscle-balance summaries with stated attribution limits, optional manually entered body measurements, controlled CSV import, optional one-way export of completed Daily Motion workout summaries to HealthKit/Health Connect.

**Technical work:** publish/draft program versions and snapshot lineage; build rebuildable analytics; preview/validate/dedupe imports with provenance. Add provider export adapters, stable IDs/revisions and retry state. Export only cloud-accepted completed revisions from one designated phone. No fabricated energy expenditure, imported-record health bridge or raw health reads.

**Acceptance:** publishing a new program never rewrites prior sessions; missed sessions are explicit. Analytics distinguish working/warm-up sets and incompatible variants. Re-importing the same file does not duplicate workouts. Export retries/corrections do not create duplicate health records; unavailable/denied health access leaves the logger fully useful.

**Tests:** version-snapshot integrity, import round trips and adversarial rows, projection rebuild equivalence, health export IDs/revisions/revocation and platform integration on physical devices.

**Dependencies:** stable Phase 1 data/sync; user evidence supporting added analytics/program complexity; provider permission/policy review.

**Excluded:** automatic missed-session optimization, numerical predictions, recovery ingestion, assistant writes, native wearable applications and mandatory health access.

## Phase 3 — Deterministic training intelligence

**Objective:** establish transparent numerical baselines before learned models.

**Features:** restricted-domain estimated strength, conservative comparable load/repetition expectations, progression proposals and explicitly defined plateau/performance-change flags. Show insufficient-data outcomes rather than always producing a number.

**Technical work:** implement local deterministic modules with a server mirror and cross-language parity fixtures. Add applicability checks, evidence IDs, committed visibility fences, conservative fallbacks and quality/limitation reporting; statistical intervals remain absent until calibrated. Record input-time context, outputs, exposure and accept/reject outcomes. Reuse ordinary domain change interfaces; avoid a separate microservice without operational need.

**Acceptance:** frozen chronological holdouts beat or match declared simple comparators for the stated tasks; valid-domain rules and sparse-data fallback pass regression tests. No estimate uses future observations or silently treats missing RIR/rest as known. Human review verifies that warnings do not imply diagnosis or a universal readiness score.

**Tests:** deterministic fixtures, property tests for invariants/units, leakage audits, abstention and prediction regression, correction/deletion invalidation, staged feature flags and monitoring.

**Dependencies:** sufficient comparable recorded data and validated analytics; [PREDICTION_ENGINE.md](PREDICTION_ENGINE.md) evaluation gates.

**Excluded:** learned/global models, automated program execution, clinical/injury conclusions, unnecessary health features and LLM-produced numbers.

## Phase 4 — Grounded conversational assistant

**Objective:** make existing training evidence and future-plan proposals accessible through conversation.

**Features:** authorized history/analytics/prediction queries, contextual explanations and confirmed changes to future routines/programs only. Active substitutions open the normal picker UI.

**Technical work:** add allowlisted domain tools, least-privilege context, source/recency display, prompt-injection defenses, proposal preview, cloud CAS, client-local freshness/reservation checks, confirmation binding and uncertain-commit receipt recovery, bounded execution and action audits. Keep the LLM isolated from direct SQL and health-store access. Model-provider retention/training terms and user disclosure are launch gates.

**Acceptance:** evaluation proves no cross-user access, no fabricated prediction references and no write without valid confirmation. Stale proposals cannot overwrite revised plans. Pending local data is disclosed as a grounding limitation. An assistant outage leaves all training functionality intact.

**Tests:** tool contracts, unauthorized targets, stale/replayed confirmations, injection through notes/catalog/imported text, fabricated result IDs, partial failures and evaluation-set regressions.

**Dependencies:** stable domain APIs and Phase 3 evidence surfaces; consent/provider/policy review; [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md).

**Excluded:** active-workout writes, recorded-set changes, deletion tools, autonomous training changes, raw health sharing and general-purpose coaching chat.

## Phase 5 — Validated global and personalized ML

**Objective:** improve defined predictions demonstrably over deterministic baselines.

**Features:** gated global/hierarchical models, user-specific adaptation where eligibility and held-out evidence justify it, calibrated uncertainty and conservative fallback. Optional first-party pre-session readiness self-reports can enter a separately evaluated study; they are never mandatory or medical clearance.

**Technical work:** introduce `ml/` when experiments begin; reproducible datasets with as-of revisions, label eligibility, chronological splits, experiment manifests and model registry. Train outside request paths; serve versioned artifacts initially through the monolith unless compute/operations justify isolation. Separate product-service processing from optional cross-user training consent and deletion eligibility.

**Acceptance:** prespecified error/calibration/coverage gates pass, including cold users and held-out-user slices; personalized variants improve over global/baseline comparators at validated thresholds. Shadow deployment precedes controlled online experiments. Corrections, withdrawals and deletion remove future dataset eligibility, with artifact lineage and retraining policy documented.

**Tests:** leakage and selection-bias review, reproducibility, feature/label drift, missingness/out-of-domain behavior, model fallback, outcome-versus-acceptance evaluation and operational rollback.

**Dependencies:** enough quality data, consent and validated targets; [ML_ROADMAP.md](ML_ROADMAP.md). No promised minimum date or universally valid set-count threshold.

**Excluded:** a separate model per sparse user, on-device inference without demonstrated benefit, foundation-model training and unsupported causal fatigue claims.

## Phase 6 — Recovery and wearable intelligence

**Objective:** add optional signals only when they improve validated training decisions.

**Features:** staged sleep/body-mass/resting-heart-rate observations, carefully validated readiness/fatigue support, then wearable session companions and later source-specific HRV use.

**Technical work:** granular consent, provider/source attribution, coverage/missingness, retention/revocation, source deletion and independent wearable/phone identities. Design wearable synchronization and battery/background limits before accepting live logging. Imported health remains excluded from third-party LLM context and global training unless a separate policy and consent review permits a defined use.

**Acceptance:** health-denied/unavailable devices retain full training functionality; unknown data never becomes poor readiness. Signal additions outperform no-health baselines in appropriate evaluation. Wearable disconnection/reconnect cannot lose or duplicate sets; platforms need not expose identical signals.

**Tests:** availability/feature/permission matrix, timezones and sleep overlap, stale/duplicate sources, revocation/deletion, locked-device restrictions, watch/phone disconnection, battery and recovery recommendations.

**Dependencies:** stable Phase 5 evaluation/monitoring where ML is used, provider/policy review and evidence of user benefit. Wearables may remain deferred if these gates are unmet.

**Excluded:** medical diagnosis, inaccurate health writes, cross-platform imported-health bridging, obligatory wearables and blanket sensor-based readiness claims.

## Release discipline and monetization

Each gate requires evidence recorded with the release candidate; new capabilities ship behind reversible flags. Re-run relevant adversarial cases after domain, schema, sync or tool changes. Freeze unsupported claims in store copy. Billing may be considered after repeat-use/retention evidence and before a paid launch; it is independent of the phase sequence and requires its own entitlement, restore, offline and store-policy design. No launch may hold a user's existing workout history hostage to subscription changes.
