# Implementation phases

Updated: 2026-10-14 (IST). This is the execution checklist for the accepted plan. [ROADMAP.md](ROADMAP.md) owns detailed objectives, scope, dependencies, exclusions and acceptance criteria; [TESTING.md](TESTING.md) owns qualification. Update these together if a phase changes.

**Current state:** Phase 0 is **in progress**. Connected synchronization/authentication, interaction prototypes, Windows fault tests and native qualification harnesses are implemented. Remote Linux/PostgreSQL/Android and macOS unsigned iOS build jobs passed on `b8968ca` and `a27dfdd`; [IMPLEMENTATION.md](IMPLEMENTATION.md) records exact scope. The [audited evidence matrix](PHASE0_EVIDENCE.md) reconciles foundation completion with the separate external acceptance. Hosted OTP/SMTP, managed-provider/operator review, signing, physical hardware secure-storage/backup and device qualification remain open. Phase 1 and later phases are **not started**.

## Phase summary

| Phase | Deliverable | Entry condition | Exit evidence |
|---|---|---|---|
| 0 | Foundations and design system | Accepted product/data/sync decisions | Physical-device logging spike, offline/recovery proof, reviewed contracts/design, CI and security setup |
| 1 | First public workout logger | Foundation gates pass | Reliable routine-to-history loop, fault qualification, accessibility and India/store readiness |
| 2 | Programs, analytics and interchange | Stable logger and user evidence | Immutable program versions, trustworthy analytics, reviewed import; optional health export separately qualified |
| 3 | Deterministic intelligence | Comparable records and validated analytics | Versioned rules, conservative unavailable results, causal provenance and Dart/Python parity |
| 4 | Grounded assistant | Stable tools, numerical engine and provider review | Grounded reads and confirmed future-plan writes with race/timeout qualification |
| 5 | Validated personalized models | Eligible opted-in data and proven baselines | Temporal/cold-start benefit, calibration, shadow/experiment evidence and safe rollback |
| 6 | Health recovery context and wearables | Explicit consent/policy and device protocols | Incremental user benefit, local-only health boundaries and lossless companion workflows |

## Phase 0 — Prove the foundation

- [x] Pin supported stable toolchains; establish Android/Linux and iOS/macOS build paths with actual passing remote compilation on `b8968ca` and `a27dfdd`.
- [x] Implement a small internal light/dark design system and representative one-handed set editor; prove contrast, labeled targets and 320px/200% text/keyboard behavior in widget tests. Physical acceptance remains separate.
- [x] Provide executable onboarding, routine-editing, active-logging and history interaction prototypes. The isolated routine study edits planned values and freezes previews without adding personal routine storage or Phase 1 feature breadth.
- [x] Prove Drift transactions, owner isolation, recoverable drafts, outbox and timer restoration with real file-backed databases, controlled clocks and hard Windows process kills. Phone acceptance remains separate.
- [x] Prove aggregate CAS, exact retry receipts, commit-ordered pull and consistent bootstrap against real restricted-role PostgreSQL and live Flutter HTTP.
- [x] Exercise account-disable races, erased feed/snapshot copies and additive local schema migration against real PostgreSQL/SQLite.
- [ ] Measure durable set-save p95 against the 100 ms target on representative physical devices.
- [x] Record checked OpenAPI/Dart contracts, shared fixtures, four-output reproduction and implementation/fault evidence; no ADR changed.
- [x] Connect foreground Flutter HTTP push/pull/bootstrap to verified test authentication and restricted PostgreSQL; prove receipt, branch, erasure and cursor safety on desktop databases.
- [x] Exercise foundation Drift version 1→3 and 2→3 upgrades with frozen outbox, active workout, timer and draft preserved; test file reopening in pending/conflict/bootstrap/cursor/deletion states.
- [x] Connect the supported Supabase email OTP/refresh API to awaited platform-secure session persistence, verified idempotent application-account initialization and owner-scoped local unlocking; prove expiry/refresh failure, sign-out, restart, stale completions and A → B → A isolation on desktop SQLite/PostgreSQL.
- [ ] Qualify real hosted Supabase/custom SMTP/inbox delivery, publishable project configuration, rate limits, revocation and trusted signing-key rotation; requires the unavailable hosted project/operator configuration.
- [x] Prepare native storage/recovery and full caller durable-save benchmark entrypoints; compile Android debug/profile and exercise unconfigured startup on a Windows Android emulator, without claiming physical-device evidence.
- [x] Exercise hard Windows process kills before/during/after real SQLite commits, SQLite capacity failure, additive schema 2→3 timer migration and controlled monotonic/clock-change recovery.
- [x] Compile unsigned iOS debug/release on hosted macOS and Android debug/profile/release on Linux through actual remote CI; this proves compilation only.
- [ ] Install/run signed iOS on hardware; qualify physical Android/iPhone process loss, reboot, suspension, clock/timezone changes, disk-write failures, backup/restoration and native Keychain/protected storage.
- [ ] Qualify hardware VoiceOver/TalkBack, native keyboard/back/sheets, large text and reduced motion; desktop widget semantics complement rather than close this gate.
- [x] Run published remote CI for Linux/PostgreSQL/Android and macOS/iOS; all three jobs passed on `b8968ca` and the read-cost fix `a27dfdd`.
- [x] Establish CI security basics: credential scan, synthetic-auth release rejection, logging hygiene and per-transaction restricted-role/forced-RLS validation; real PostgreSQL rejects privileged/owner-member roles and missing RLS policies.
- [x] Exercise actual Android emulator protected session/SQLite seed, external force-stop/recover and full caller debug benchmark mechanics; retain raw evidence and exclude this from physical qualification.
- [ ] Provision operator-managed Android/iOS signing and qualify signed installations; no store-ready signing is claimed.
- [ ] Confirm managed Mumbai region, backup/recovery and processor arrangements; commission a named India privacy/security reviewer and developer/store accounts. Preparation is in [the operator handoff](../infra/QUALIFICATION.md); actual project/contract/operator evidence is unavailable.

All remaining Phase 0 rows require external hardware, provider, signing or operator/reviewer resources. Full public routine features, conflict-resolution UI, export/deletion jobs, production retention/restore operations and long-history release qualification remain Phase 1 work under the roadmap; their foundation safety primitives above are exercised. This scope clarification does not close physical Phase 0 acceptance or reduce any public-release requirement.

No production prediction, conversational assistant, health permission, billing or speculative shared package is needed to pass this gate.

## Phase 1 — Deliver the useful MVP

- [ ] Required email OTP signup, minimal profile/units and secure session storage.
- [ ] Curated/custom exercise variants and reusable routines with immutable template content.
- [ ] Start/resume/abandon/finish workouts; warm-up/working, top/back-off and simple supersets.
- [ ] Fast actual set entry, optional RIR/RPE, corrections, substitutions, rest timers and basic holds/carries.
- [ ] Comparable history/progress and measured records with explicit assistance semantics.
- [ ] Complete workouts offline after signup, including expired cloud credentials and process restart.
- [ ] Resolve sync conflicts; provide account export/deletion and permanent workout deletion.
- [ ] Complete security, accessibility, store/privacy, restore and controlled beta qualification.

Launch free in India for English-speaking adults. Programs, historical import, health, predictions, AI and payments are excluded. An empty session is continued, abandoned or discarded rather than falsely completed.

## Phase 2 — Expand planning and interpretation

- [ ] Publish versioned multiweek programs; preserve missed/rescheduled assignments and past intent.
- [ ] Add rebuildable working-volume/muscle summaries with attribution limitations.
- [ ] Add optional manual body measurements with time/unit provenance.
- [ ] Preview and validate CSV imports, preserve unknown fields and prevent repeat-import duplication.
- [ ] If user benefit warrants it, separately qualify one-way completed-workout health export.

Health export is optional and does not block later training-only intelligence. It uses current cloud-accepted completion, a designated exporter generation, pre-write freshness checks and post-write compensation. Recovery reads, automatic missed-session optimization and wearable apps remain excluded.

## Phase 3 — Introduce transparent numerical rules

- [ ] Ship local deterministic baselines with a server mirror and parity fixtures.
- [ ] Add historical references, matching-load median estimates, eligible strength proxies and conservative progression.
- [ ] Preserve committed visibility fences/source manifests and local unsynced provenance.
- [ ] Record recommendation exposure, rejection, override and accepted changes separately.
- [ ] Validate stale/sparse/unsupported fallbacks, progression-group effort gates and possible-plateau limitations.

No learned model or LLM-generated number is required. A reference or unavailable result is a valid outcome. Statistical confidence intervals stay absent until calibrated.

## Phase 4 — Add the product assistant

- [ ] Review provider privacy, quality, latency, cost and user disclosure.
- [ ] Expose bounded authorized history, analytics, catalog and prediction tools.
- [ ] Build grounded answers with source, freshness and missing-data limitations.
- [ ] Draft future routines/programs through deterministic planning tools.
- [ ] Confirm exact diffs with client-local reservation checks, server CAS, expiry and idempotent receipts.
- [ ] Qualify injection, cross-user access, unknown commit outcomes and provider outage.

No active/historical workout commits or privacy/deletion tools are permitted. Active substitutions use the ordinary picker. Optional-service failure never disables training.

## Phase 5 — Earn personalization

- [ ] Collect only separately opted-in eligible first-party logs for population training.
- [ ] Build reproducible as-of datasets, task-specific targets and temporal/user holdouts.
- [ ] Compare regularized/global models against declared simple baselines before personalization.
- [ ] Gate hierarchical effects per user/comparability key/task; data-count thresholds alone do not qualify them.
- [ ] Validate calibrated uncertainty, subgroup behavior, shadow results and controlled user benefit.
- [ ] Enforce withdrawal/deletion lineage, monitoring and fallback; keep training outside request paths.
- [ ] Offer optional first-party readiness self-reports only as a separately evaluated study.

No generic readiness score, per-user neural network from sparse logs, automatic load application or imported-health/global-training assumption is accepted.

## Phase 6 — Add justified recovery and wearable context

- [ ] Explain and request purpose-specific health reads with availability/missingness checks.
- [ ] Keep imported observations local by default, bounded and outside ordinary cloud/LLM pipelines.
- [ ] Prove recovery signals improve a defined decision beyond the training-only baseline.
- [ ] Introduce a useful watch companion only after ownership, disconnection, retries and handoff are designed.
- [ ] Qualify both platforms and accounts with refused/revoked permissions or no wearable.

Medical diagnosis, inaccurate health writes, cross-store health bridging and compulsory health access remain excluded.

## Completion protocol

For each gate, attach the build/code revision, test environment, device/cohort sample, relevant results, unresolved limitations, migration/rollback evidence and approver/reviewer. Mark a checkbox complete only when its evidence exists; a prototype, optimistic animation or proposed test is insufficient.

Use the next phase's specific dependency list rather than assuming every optional feature in the preceding phase is mandatory. Later billing has its own entitlement, restore, offline and store-policy decision and is not a dependency of this sequence.

Re-run the relevant cases in [ADVERSARIAL_REVIEW.md](ADVERSARIAL_REVIEW.md) after changing domain semantics, synchronization, model targets, consent, assistant tools or health behavior. Keep architecture changes in [DECISIONS.md](DECISIONS.md).
