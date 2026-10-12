# Implementation phases

Updated: 2026-10-12. This is the execution checklist for the accepted plan. [ROADMAP.md](ROADMAP.md) owns detailed objectives, scope, dependencies, exclusions and acceptance criteria; [TESTING.md](TESTING.md) owns qualification. Update these together if a phase changes.

**Current state:** planning documentation is being delivered; every product implementation phase below is **not started**. Writing architecture documents does not complete Phase 0's engineering proofs. The next implementation task is the foundation work, not the assistant or model training.

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

- [ ] Pin supported stable toolchains; establish Android/Linux and iOS/macOS build paths.
- [ ] Implement a small internal design system and representative one-handed set editor.
- [ ] Prove Drift transactions, owner isolation, recoverable drafts, outbox and timer restoration.
- [ ] Prove aggregate CAS, exact retry receipts, commit-ordered pull and consistent bootstrap against PostgreSQL.
- [ ] Exercise account-disable races, erased feed/snapshot copies and local schema migration.
- [ ] Measure durable set-save p95 against the 100 ms target on representative physical devices.
- [ ] Record contracts, fixture evidence and any ADR changes before expanding implementation.

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
