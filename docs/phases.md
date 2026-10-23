# Implementation phases

Updated: 2026-10-22 (IST). This is the execution checklist for the accepted plan. [ROADMAP.md](ROADMAP.md) owns detailed objectives, scope, dependencies, exclusions and acceptance criteria; [TESTING.md](TESTING.md) owns qualification. Update these together if a phase changes.

Protected main `3935d51` is PR #11's signed squash merge; its tree matches reviewed
`266e164`. The observation helper and desktop worker-lock correction are merged.
[Main CI](https://github.com/bluxo1/Daily-Motion/actions/runs/39763668555) passes
all three jobs: **536 Python / zero skips**, **215 Flutter / 12 explicit skips**
on each mobile runner, Android builds and unsigned iOS builds. Earlier main
`3e02131` and its 490-test CI remain historical evidence in IMPLEMENTATION.md.
These results do not qualify independent certification/publication, providers,
operators or physical devices; no additional Phase 0 gate is closed.

The local [O3 design review package](RECOVERY_O3_VERIFIER_PROPOSAL.md) now provides
recommended records/permissions, a decision matrix and 36 future fault cases.
Its separate bounded probe has **25 checks matching expectations / zero skips**;
unsafe controls are explicitly labeled. O3 remains **proposed / unapproved**.
The existing known-marker helper supplies no trusted certification, target-
continuity proof, authority publication or complete recovery. Required backend/
security decisions and explicit authorization precede B4/B5 implementation.

The subsequent [advisory technical review](RECOVERY_O3_TECHNICAL_REVIEW.md)
records concrete corrections and a pending decision for each D1-D11. New evidence
separates a hardened 25-check run, a 23-check existing-component/runner review
and synthetic record sizing from the 36 unexecuted future acceptance families.
No O3/O11 approval or additional Phase 0 acceptance gate is closed.

**Historical Oct 21 checkpoint:** main `5975999` contains merged PR #7 authentication and PR #8 mobile
qualification. Session 2 recovery integration passes **180 Flutter / 12 explicit
skips**, **242 Python / zero skips**, **14 PostgreSQL recovery cases** and
**9 connected Flutter HTTP cases** locally. **All outstanding Phase 0 gates below
stay open.** No hosted restore/provider operation or Phase 1 work is authorized.
[Review, hook audit and remaining recovery limits](RECOVERY_INTEGRATION.md).

**Current state:** Phase 0 is **in progress**. Connected synchronization/authentication, interaction prototypes, Windows fault tests, native qualification harnesses and internal Recovery V2 components are implemented. Recovery certification/publication and its trust decisions remain unfinished. [IMPLEMENTATION.md](IMPLEMENTATION.md) records current counts, historical qualification and earlier runner recovery. The [audited evidence matrix](PHASE0_EVIDENCE.md) separates foundation proof from external acceptance. Trusted-key/provider, managed recovery/operator review, signing, physical secure-storage/backup and device qualification remain open. Phase 1 and later phases are **not started**.

**Historical PR #7 pre-merge checkpoint:** PR #6 was marked merged, then main was reset and
pushed back to healthy `8ba5a98`. [PR #7](https://github.com/bluxo1/Daily-Motion/pull/7)
recovers reviewed auth changes without the bad merge's clock/delay defaults.
Its source `e3da9d0` passes all three [PR CI jobs](https://github.com/bluxo1/Daily-Motion/actions/runs/39306127033):
**204 Python / zero skipped**, including 55 PostgreSQL cases and 9 live Flutter
HTTP cases; each mobile runner passes **161 Flutter / 12 skips**, Android builds
and unsigned iOS debug/release. Local Windows passes 161 Flutter / 12 skips;
local Python passes 148 / 56 database-dependent skips because Docker failed to
start. Existing worktrees/staged changes and main are preserved. This closes
source integration validation, not PR review/merge or any hosted/physical gate.
The failed hosted return-to-A result remains incomplete; Render incident
**215476446235862 remains OPEN**. No provider, OTP, key or deployment action.
No additional Phase 0 checkbox is closed by this recovery.

Mumbai Supabase / Singapore Render **staging was verified on `c5d5414` on Oct 15**, with real
TLS/RLS/readiness evidence after credential rotation. Both earlier controlled inbox
requests returned 200; delivery and verified identity/refresh/sync remain open.
Client-side SCRAM provisioning is fixed in `6606db0` and applied to hosting, with
104 Python / 56 PostgreSQL and 148 Flutter + 9 live HTTP local tests passing.

The 2026-10-15 continuation rotated affected credentials, verified Render's saved
value after reload, deployed **dep-db8efpon74is73epb8ng**, closed remaining runtime
connections and passed fresh **0003 / 11 forced-RLS / owner/pool** probes plus
**6/6 public HTTPS checks**. An earlier saved-value mismatch and failed readiness
deployment were reproduced and repaired. The aggregate audit retains **2 legacy
plaintext statements**, alongside **2 new SCRAM statements**; no historical query
text or verifier was returned and no purge is claimed. SMTP was re-observed **off**;
code templates remain locked/unapplied. The actual service branch is `main`, while
Blueprint source-branch verification remains separate. Real OTP/inbox/refresh and
authenticated hosted Flutter gates remain open.

On 2026-10-16 the operator reports SMTP configured. Saved SMTP and code-template
verification remain pending because native browser navigation returns
`window_not_focused`, including a supported restore attempt; manual foreground
focus was requested. No fresh OTP request or delivery/identity claim is made.
Public HTTPS checks again pass **6/6**; Auth settings return **200** with email
authentication enabled. These do not close SMTP or authenticated-sync acceptance.

At **18:49 IST**, manual foreground and signed-in Gmail were confirmed by the
operator. A refreshed browser reference still returned `window_not_focused` on
its first navigation; the current bridge reports `supports.windows.focus=false`.
Browser actions stopped without restoration. No new provider proof was obtained;
the browser-control connection now requires repair.

On **2026-10-17**, supported page automation bypassed the desktop-focus blocker.
Two authenticated saved-configuration reads returned **200**: SMTP host/user/
password, sender and port are absent; code templates are inactive, with default
confirmation links and no nonempty custom override. Operator SMTP configuration
is required before real delivery/identity qualification. No additional checkbox
is closed. PR #3 is merged and Git main is **c9a8370**; the deployed revision was
not reverified in this continuation.

The later Oct 17 continuation verifies all saved SMTP fields and fixes both
Confirmation and Magic Link code templates, confirmed after reload. Account A's
real OTP request at **15:59:56 UTC** returns **500 / unexpected_failure**; the
correlated Auth event reports Google SMTP **535 / BadCredentials**. Correcting
the saved SMTP login is now the operator boundary. No delivery, verification,
distinct A/B identity or hosted Flutter case is qualified. No rotation/database
verification was repeated. See [new evidence](evidence/phase0-hosted-smtp-delivery-2026-10-17.json).

**Oct 18 IST:** the corrected SMTP login now supports actual recipient OTP
delivery and verification for distinct A/B Supabase subjects. Two targeted desktop
Flutter cases pass against real Supabase/Render: retry/receipt recovery and the
production SDK/controller lifecycle. Refresh, revoked-refresh denial, incorrect
code, immediate resend throttling, file reopening, sign-out with pending work,
A → B → A and cross-owner read/mutation denial pass. Two harness defects were
fixed. Physical Android discovery finds **0 devices / 0 emulators**. Elapsed OTP
expiry is now proven separately below. Signing-key rotation and native/operator
gates remain open; no independent
SQL probe or credential rotation was repeated. See
[functional evidence](evidence/phase0-hosted-auth-flow-2026-10-18.json).

**Later Oct 18 audit:** real 600-second OTP expiry passes after a 610-second hold
and a fresh delivered code succeeds. Hardened assertions and Render-hook source
detection pass their regressions; full local suites pass 108 Python and 151
ordinary Flutter (12 explicit skips), including nine separately enabled live
Flutter HTTP cases. A Render Blueprint sync-hook disclosure in a tool response
requires invalidation; its deleted source branch remains unchanged pending that
containment. Signing-key approval, sender-capacity review and hardware/operator
gates remain open. [Provider audit](evidence/phase0-provider-qualification-2026-10-18.json).

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

- [x] Pin supported stable toolchains; establish Android/Linux and iOS/macOS build paths with actual passing remote compilation on `b8968ca`, `a27dfdd` and `46f5d5a` (supported Intel Mac/Xcode 26.3).
- [x] Implement a small internal light/dark design system and representative one-handed set editor; prove contrast, labeled targets and 320px/200% text/keyboard behavior in widget tests. Physical acceptance remains separate.
- [x] Provide executable onboarding, routine-editing, active-logging and history interaction prototypes. The isolated routine study edits planned values and freezes previews without adding personal routine storage or Phase 1 feature breadth.
- [x] Prove Drift transactions, owner isolation, recoverable drafts, outbox and timer restoration with real file-backed databases, controlled clocks and hard Windows process kills. Phone acceptance remains separate.
- [x] Prove aggregate CAS, exact retry receipts, commit-ordered pull and consistent bootstrap against real restricted-role PostgreSQL and live Flutter HTTP.
- [x] Exercise account-disable races, erased feed/snapshot copies and additive local schema migration against real PostgreSQL/SQLite.
- [ ] Measure durable set-save p95 against the 100 ms target on representative physical devices.
- [x] Record checked OpenAPI/Dart contracts, shared fixtures, four-output reproduction and implementation/fault evidence; no transport version changed.
- [x] Connect foreground Flutter HTTP push/pull/bootstrap to verified test authentication and restricted PostgreSQL; prove receipt, branch, erasure and cursor safety on desktop databases.
- [x] Exercise foundation Drift version 1→3 and 2→3 upgrades with frozen outbox, active workout, timer and draft preserved; test file reopening in pending/conflict/bootstrap/cursor/deletion states.
- [x] Connect the supported Supabase email OTP/refresh API to awaited platform-secure session persistence, verified idempotent application-account initialization and owner-scoped local unlocking; prove expiry/refresh failure, sign-out, restart, stale completions and A → B → A isolation on desktop SQLite/PostgreSQL.
- [ ] Complete provider qualification: real custom-SMTP recipient delivery, A/B verification, immediate resend throttling, incorrect-code denial, refresh, revocation and actual elapsed OTP expiry pass on Oct 18. Trusted signing-key rotation, sender-capacity/operator acceptance and Render hook containment/source-branch repair remain open.
- [x] Prepare native storage/recovery and full caller durable-save benchmark entrypoints; compile Android debug/profile and exercise unconfigured startup on a Windows Android emulator, without claiming physical-device evidence.
- [x] Exercise hard Windows process kills before/during/after real SQLite commits, SQLite capacity failure, additive schema 2→3 timer migration and controlled monotonic/clock-change recovery.
- [x] Compile unsigned iOS debug/release on hosted macOS and Android debug/profile/release on Linux through actual remote CI; this proves compilation only.
- [ ] Install/run signed iOS on hardware; qualify physical Android/iPhone process loss, reboot, suspension, clock/timezone changes, disk-write failures, backup/restoration and native Keychain/protected storage.
- [ ] Qualify hardware VoiceOver/TalkBack, native keyboard/back/sheets, large text and reduced motion; desktop widget semantics complement rather than close this gate.
- [x] Run published remote CI for Linux/PostgreSQL/Android and macOS/iOS; all three jobs passed on `b8968ca`, `a27dfdd`, audit/runner recovery `46f5d5a`, staging preparation `ef025c2` (run 38570967779), deployed `8e5af65` (run 38587594908), operator SCRAM fix `6606db0` (run 38611404742, attempt 2), merged-branch repair `69b929e` (run 38665949212), authorized `d655e1f` (push 39125077861 / PR 39125080814), `a4f0003` (push 39128306625 attempt 2 / PR 39128309352) and `cbacc0a` (push 39130484081 / PR 39130487873). This does not qualify hosted provider behavior.
- [x] Establish CI security basics: credential scan, synthetic-auth release rejection, logging hygiene and per-transaction restricted-role/forced-RLS validation; real PostgreSQL rejects privileged/owner-member roles and missing RLS policies.
- [x] Exercise actual Android emulator protected session/SQLite seed, external force-stop/recover and full caller debug benchmark mechanics; retain raw evidence and exclude this from physical qualification.
- [ ] Provision operator-managed Android/iOS signing and qualify signed installations; no store-ready signing is claimed.
- [ ] Confirm managed backup/recovery and processor arrangements; commission a named India privacy/security reviewer and developer/store accounts. Actual staging Mumbai region is verified; the free project has no managed backups, and restore/contract/reviewer/store acceptance remains unavailable. Preparation is in [the operator handoff](../infra/QUALIFICATION.md).
- [x] Complete public-source region feasibility and backup/processor prerequisite desk review: published Mumbai availability, backup/object/custom-role limits and current DPA/subprocessor source inventory. This is not live project, restore or legal/provider qualification.
- [x] Prepare the requested Supabase/Render staging deployment, separate Alembic/runtime-role setup, verified TLS/readiness guards, OTP template and credential-gated Flutter qualification harness. Local preparation is distinct from hosting evidence.
- [x] Select/configure the actual Mumbai Supabase staging project, deploy Render Singapore, apply Alembic 0003 and verify hosted restricted-role/forced RLS, owner/pool isolation, TLS/readiness and public auth/contract denial. Initial deployment `8e5af65`; continued **c5d5414 / dep-db8efpon74is73epb8ng** passes after actual credential rotation, protected provider read-back and fresh-connection probes. See [hosted evidence](evidence/phase0-hosted-staging-2026-10-14.json) and [rotation evidence](evidence/phase0-hosted-rotation-2026-10-15.json). No personal workout data or admin credentials on the API/mobile app.
- [x] Run real desktop OTP/refresh/account/sync/restart qualification with controlled recipients. Actual A/B delivery and distinct subjects, two hosted Flutter cases, SDK refresh/revocation, pending sign-out, A → B → A, duplicate receipts and hosted API owner denial pass on Oct 18. Code/session values stay in process memory. Native storage/process loss is separate; prior direct SQL RLS evidence was not repeated. Blueprint source-branch and managed backup/restore qualification remain open. [DM-018](DECISIONS.md#dm-018--render-staging-provider-qualification) records the staging hosting exception.

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
