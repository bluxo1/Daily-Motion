# Daily Motion project memory

Created: 2026-10-13 at 12:57 IST (07:27 UTC).
Timezone: Asia/Calcutta, UTC+05:30. Entries run from oldest to newest.

This file records the project context available from the repository and this
implementation conversation. It is a durable handoff summary, not a verbatim
transcript or a substitute for the specifications. Earlier session actions did
not have individual timestamps; their recorded date range and sequence are used
instead of inventing times. Git times below are author timestamps.

For future work, read this file alongside [README.md](../README.md), the
[phase checklist](phases.md) and [implementation evidence](IMPLEMENTATION.md).
Append dated entries after meaningful decisions, implementation, checks or user
direction. Record outcomes, commands, limitations and next work. Preserve earlier
entries; append corrections if a fact changes. Keep credentials, tokens, private
user data and hidden agent instructions out of this file. Current user instructions
and the authoritative specifications take precedence over this historical summary.

## 2026-10-12, 18:33:20 IST — Initial repository commit

- Git commit: `c2556b3`, subject `Initial commit`.
- Workspace: `E:\Motion\Daily-Motion`, with PowerShell on Windows.

## 2026-10-12, 22:51:28 IST — Planning baseline committed

- Git commit: `4a0442e`, subject `docs: add Daily Motion product and architecture planning`.
- The baseline contained root README and 21 Markdown planning documents.
  Application implementation had not started at that point.
- Planning described the product, PRD, architecture, data model, API, sync,
  design system, user flows, security, testing, roadmap, decisions and handoff,
  plus future ML, predictions, assistant and health capabilities.
- The original documentation review reported resolved specification findings.
  That review did not establish application or release correctness.

### Accepted product context

- Build a premium strength/hypertrophy logger for iPhone and Android. Premium
  describes design and reliability; the first public release is free.
- First audience: advanced recreational strength/hypertrophy trainees,
  English-speaking adults in India. Lean team baseline: one to three engineers.
- Initial phone support targets iOS 16+ and Android 10+, subject to qualification.
- Product loop: Plan → Train → Record → Predict → Learn → Adapt.
- Public MVP: create routine → start workout → log sets → finish → history/progress.
- Require an online email OTP account before personal training; no MVP guest mode
  or social login. Established-user training must survive offline use and expired
  cloud credentials. Explicit sign-out locks and retains that owner's pending data.
- Include warm-up/working sets, regular/top/back-off purpose, optional RIR/RPE,
  simple supersets, substitutions, corrections and basic holds/carries in the MVP.
- Programs, CSV import, health, billing, predictions, AI and wearables are later
  work. Training remains central; avoid a speculative AI dashboard.

### Accepted architecture and correctness context

All 17 baseline decisions remain accepted planning choices, with no superseding
ADR introduced during this session. See [DECISIONS.md](DECISIONS.md) for full
alternatives, consequences and revisit conditions.

| Decision | Context to retain |
| --- | --- |
| DM-001 | Flutter with Riverpod and Drift; explicitly adapt platform UX. |
| DM-002 | One modular Python/FastAPI service; no premature microservices. |
| DM-003 | Supabase PostgreSQL/Auth and Cloud Run; Mumbai defaults `ap-south-1` / `asia-south1`, not a residency/compliance claim. |
| DM-004 | SQLite is the local source of truth; commit before success feedback. |
| DM-005 | Session-root revisions cover every child mutation; conflicts are explicit. |
| DM-006 | Owner-lock commit-ordered feed and bounded consistent bootstrap. |
| DM-007 | Normalized current projections plus changed-observation history. |
| DM-008 | Immutable templates/program versions and independent session snapshots. |
| DM-009 | Preserve measurement, comparison, missingness and provenance semantics. |
| DM-010 | Registered numerical methods precede learned models; no LLM-generated numbers. |
| DM-011 | Grounded, bounded assistant tools; exact confirmation for future-plan writes. |
| DM-012 | Separate processing purposes/consents; erasure covers derived and transport copies. |
| DM-013 | Optional health export first, recovery/wearables later. |
| DM-014 | Required email OTP; cached local access separate from cloud authorization. |
| DM-015 | Restrained advanced logger, India-first adult English free launch. |
| DM-016 | Internal mobile modules, generated contracts and shared fixtures; extract packages only for demonstrated reuse. |
| DM-017 | Real-device durability, accessibility, security and release evidence gates. |

Implementation invariants to preserve:

- Widgets present state; controllers/domain functions validate; repositories own
  persistence/sync. Network and optional intelligence never block set logging.
- Atomically commit the working projection, local sequence, observation revision
  and outbox intent. Stable UUIDs prevent duplicate entities and repeated taps.
- Keep local working state, acknowledged server shadow, local sequence and
  server revision separate. Pulls cannot overwrite a pending branch.
- Freeze transport bodies before sending. A dependent uses its own predecessor's
  accepted revision, even after a newer external pull. No timestamp overwrite or
  silent rebase. Late acknowledgements must not downgrade newer shadows.
- Server mutations commit projection, revision, history, ordered feed and receipt
  together. Account disable uses the same owner guard and under-lock recheck.
- Retired root/child IDs prevent resurrection. Permanent erasure purges payloads,
  redacts old transport, invalidates snapshots and advances an erasure epoch.
- Bootstrap stages bounded pages from one consistent snapshot, validates all
  pages before activation and preserves local edits made during download.
- Planned/prefilled values are unperformed suggestions until deliberate entry.
  Unknown is null. Failed zero-rep attempts differ from skipped/pending work;
  RIR zero is a valid self-report. Effort is not automatically copied or converted.
- Retain original decimal units, load basis, rep convention, variant/setup and
  side. Positive assistance is not negative load or a highest-load achievement.
  Warm-ups are not working volume. Logger sequence is not guaranteed physical
  execution order, and timer gaps are not measured actual rest.
- Corrections retain prior observations without reopening completed workouts.
  Empty sessions cannot finish as completed workouts. Enforce one active session
  per device, while preserving distinct sessions started independently offline.
- Shared bounds: 256 KiB canonical UTF-8 commands and 1 MiB push requests;
  oversized rejected edits retain their drafts. Planned snapshot defaults are
  512 KiB pages, 64 MiB total and 15-minute expiry; feed retention is 90 days.
- API identity comes from verified credentials. Private training schema, restricted
  runtime roles, owner-aware foreign keys and RLS defend tenant boundaries.
  Alembic owns server migrations; Drift owns local migrations.
- No AI/health in the MVP. Future numerical features require causal committed
  visibility evidence and conservative unavailable results; global learning needs
  separate consent and evaluation. Assistant authority initially excludes active/
  historical workout commits and privacy actions. Imported health stays local
  and outside ordinary cloud/LLM/global training by default.
- Physical-device p95 durable-save goal: at most 100 ms. Crash-free workout-session
  target: 99.9% with cohort/sample evidence. Neither target has been demonstrated.

### Delivery sequence

Phase 0 foundations/design → Phase 1 public logger → Phase 2 programs/analytics/
interchange → Phase 3 deterministic intelligence → Phase 4 grounded assistant →
Phase 5 validated personalized models → Phase 6 recovery/wearables.
Phases are evidence gates, not calendar promises.

## 2026-10-12 to 2026-10-13 — Implementation authorization and first slice

Exact action times were not recorded. The following events are in session order.

### 1. User direction and scope selection

- User instructed: **“Start Implementing.”** No specific milestone was named.
- Repository inspection found a clean documentation-only baseline and no
  applicable `AGENTS.md` in the inspected workspace/parent paths.
- The handoff's default was Phase 0 foundations only. Work followed that scope;
  later features were not treated as authorized MVP expansion.
- User subsequently said **“Continue”** twice while implementation was underway.
  Both messages continued the existing foundation task.
- No new commits, deployment or publishing were performed.

### 2. Toolchain and local environment setup

- Pinned Flutter **3.47.7**, framework `abaf9c523780a608bd46686fd5e53740a07077f8`,
  with Dart **3.13.5** in `.fvmrc`. SDK lives at ignored `.tools/flutter`.
- Python **3.13.14**, pinned in `services/api/.python-version`; dependencies locked
  in `services/api/uv.lock`. Mobile dependencies locked in `pubspec.lock`.
- Used uv **0.13.0**, Ruff, strict mypy and pytest for the API.
- Started Docker Desktop and local **PostgreSQL 17.7** through `infra/compose.yaml`.
  Development database binds to `127.0.0.1:25432`; tests use the dedicated
  `daily_motion_test` database and a separate restricted runtime role.
- System-drive space interrupted Dart dependency installation. Moved task-local
  `PUB_CACHE`, `TEMP` and `TMP` to `.tools/pub-cache` and `.tools/temp` on E:.
  No global PATH/cache settings were changed. uv cache uses `.tools/uv-cache`.
- `localhost` database connections were slow on this host; `127.0.0.1` resolved
  promptly and is used in setup/test instructions.
- No Android SDK or phones were available. iOS compilation requires macOS.
  Windows desktop/web were not added as product targets.

### 3. API, database and contracts implemented

- Added `services/api/`: FastAPI, Pydantic validation, SQLAlchemy models,
  psycopg, Alembic and pytest suites.
- Added repetition-set commands: create session, record/correct set,
  complete/abandon session and permanent session deletion.
- Added bounded push, ordered pull, consistent bootstrap and authenticated
  snapshot-page routes. Responses use private/no-store caching.
- JWT verification checks allowed algorithms, signature, issuer, audience,
  expiration and UUID subject. Missing configuration and inactive/unknown
  accounts fail closed. Production account initialization is not implemented.
- Added a private `training` schema, composite owner relationships and forced
  RLS. Tests execute ordinary mutations under `NOSUPERUSER NOBYPASSRLS` rather
  than only testing with migration/admin privileges.
- Implemented owner guard, aggregate CAS, frozen-content receipt digests,
  transactional feed positions, retained corrections and rollback boundaries.
  Accepted, conflicted and rejected attempts bind their mutation identity;
  a changed body cannot reuse it.
- Session deletion retires root/child IDs, removes historical observations,
  redacts prior feed bodies and invalidates staged snapshots. Account disable
  shares the guard. Snapshot publication checks captured erasure epoch.
- Added `contracts/openapi.json`, shared synthetic `fixtures/workout.json` and
  `workout.sha256`; Dart/Python canonical serialization is checked against the
  same digest. Output contracts remain provisional, not publicly released.

### 4. Mobile foundation implemented

- Created `apps/mobile/` for Android and iOS with internal domain, data, design
  and feature modules. Android minimum SDK 29; iOS deployment target 16.0.
- Added light/dark themes and Train/History/Progress prototype screens, a set
  editor, optional effort, explicit outcomes, rest countdown, historical
  corrections, completion and abandonment.
- Added real normalized Drift tables for local identity, sessions, exercises,
  prescribed sets, observations, revisions, drafts, outbox, shadows and timers.
  Generated database code is checked in and regeneration is verified.
- Native SQLite runs in a background isolate with WAL, full synchronous
  durability and foreign keys. A successful set save is local and atomic.
- Added owner-bound initialization, explicit sign-out lock and a verified-owner
  unlock primitive. Unlock is not a shipped authentication flow.
- Added duplicate-tap protection, draft recovery, persisted timer deadlines,
  own-predecessor outbox preparation, immutable retries, pending-branch protection,
  late-ack protection and checksum-verified bootstrap activation.
- Default app build does not permit unverified personal workouts.
  `DM_FOUNDATION_FIXTURE=true` explicitly enables a synthetic non-release account
  and a bench-press template; release builds always disable it.
- Prototype remains repetition-only, with one synthetic template rather than
  mutable routine authoring. Original decimal loads/units/bases are retained;
  fixed-point pound-to-kg conversion is tested.
- Android backup exclusion is scaffolded. iOS backup exclusion and native
  privacy/platform qualification remain outstanding.

### 5. Fault tests and self-review corrections

- Fixed Drift generation after a SQL keyword was used as a column name;
  the stored column is now `has_conflict`.
- Fixed enlarged-text test scrolling/layout before tapping and expanded effort
  dropdown layout. Offscreen taps were not counted as successful interaction.
- Replaced an unreliable deletion assertion searching arbitrary UUID text with
  structured payload checks and explicit observation/projection counts.
- Changed controller refresh errors so an already durable set cannot be
  reported as unsaved when a subsequent screen read fails.
- Added live/retired root and child identity collision checks before writes.
- Bound terminal rejected/conflicted command bodies to receipts, requiring new
  mutation IDs for reviewed replacement commands.
- Tested transaction rollback, file close/reopen recovery, duplicate taps,
  owner locking/switch rejection, pending branch preservation, late receipts,
  predecessor revisions, bootstrap checksum rejection and retained corrections.
- Tested real PostgreSQL rollback, root CAS, exact retry, digest mismatch,
  owner isolation/context reset, concurrent writer blocking/feed order,
  account-disable races and deletion during snapshot preparation.
- Tested JWT failures and the default account gate; no production credentials
  or personal workout records were used.

### 6. Tooling and documentation

- Added `.github/workflows/verify.yml`: Linux API/PostgreSQL and Android checks,
  macOS mobile checks/iOS builds, generated-contract checks and documentation checks.
  Remote CI has not run in this session.
- Added ignore rules, line-ending attributes and documentation validation script
  `tools/check_docs.py`. Runtime secrets and local SDK/cache/build outputs are ignored.
- Updated README, roadmap/checklist and affected planning documents to distinguish
  implemented Phase 0 desktop evidence from open release gates.
- Added [IMPLEMENTATION.md](IMPLEMENTATION.md) with coverage, review corrections
  and exact gaps. No ADR was superseded and no Phase 0 checkbox was claimed complete.
- A frozen uv install was exercised in `services/api/.venv`, followed by the
  documented checks. Generated Drift output remained unchanged on regeneration.

## 2026-10-13 — First implementation slice validated and reported

Exact completion time was not recorded. Final observed results:

| Check | Recorded outcome |
| --- | --- |
| Flutter analysis | No issues. |
| Dart formatting | 13 files checked with zero changes in the final check. |
| Flutter/Dart tests | **17 passed**, including domain, controller, real SQLite and widgets. |
| Large-text interaction | Deliberate logging at 320px width and 200% system text scaling passed without a layout exception. |
| API lint/format | Ruff passed; 17 Python files already formatted in the frozen-install check. |
| API typing | Strict mypy passed for eight application source files. |
| Python tests | **38 passed**, including restricted-role real PostgreSQL tests. |
| Contract checks | Shared canonical SHA-256 fixture and checked OpenAPI matched. |
| Documentation at first handoff | 25 Markdown files, 221 local links and five fenced JSON examples validated. |
| Git whitespace | Passed. |

The user was told the first foundation slice was implemented, with production
OTP, connected mobile sync and physical-device qualification remaining open.
These desktop checks do not prove phone process-death durability, the 100 ms p95
target, production JWT revocation behavior or store readiness.

### State to resume from

- **Phase 0 is in progress. Phase 1 and later phases have not started.**
- The first slice is a development foundation, not a public MVP or a personal-data
  build. The working tree contains implementation and documentation changes;
  implementation was not committed, deployed or published.
- Local PostgreSQL was started for tests. Its development volume was retained;
  setup and stop instructions are in [infra/README.md](../infra/README.md).
- Preserve the existing working tree and inspect it before further edits.
  Historical test counts above describe that slice, not an automatic guarantee
  that later edits still pass.

### Next foundation work and remaining gates

1. Wire generated transport DTOs and foreground sync: atomic feed-page/cursor
   installation, own echoes, remote erasure/tombstones, cursor/generation expiry,
   explicit conflict resolution and adaptive bounded batch packing.
2. Complete snapshot cleanup, 90-day feed pruning, per-installation snapshot
   slots, incremental long-session commands and realistic large-history capacity
   qualification. Current server snapshot slots are owner-wide.
3. Add supported local schema-upgrade fixtures and hard process-kill/disk-full
   tests. No previous released local schema exists yet. Add monotonic-clock,
   reboot and clock-change handling; current timer restoration uses a wall-clock
   deadline and must not be called actual measured rest.
4. Qualify Android/iOS builds, platform back/keyboard behavior, both platforms'
   backup/privacy handling, VoiceOver/TalkBack and physical-phone profile/release
   durable-save benchmarks. CI configuration is not evidence that those ran.
5. Implement production Supabase OTP, secure token storage and account
   initialization with current provider identity/revocation checks; complete
   account switching and recent-auth privacy flows. No production Supabase,
   SMTP, processor/region or cloud configuration was set up.
6. Finish runtime-role deployment grants, abuse limits, minimized telemetry,
   account erasure/export jobs and restore-time deletion suppression.
7. Complete canonical measurement persistence, duration/distance and the remaining
   catalog/routine/MVP semantics in their authorized milestone. Do not expand to
   later-phase intelligence to bypass foundation gates.

## 2026-10-13, 12:57 IST — User requested chronological project memory

- User instructed: **“add a memory md too and add all memory in it by time.”**
- Created root `MEMORY.md` with the known repository history, accepted decisions,
  implementation sequence, user continuation instructions, environment workarounds,
  review corrections, completed validation and remaining work.
- Earlier entries use verified Git author times or explicitly approximate session
  date ranges. Individual implementation times were not reconstructed.
- Linked memory from README and the implementation handoff so future work can
  discover it, and included it in the existing documentation validator.
- This request changes project memory/documentation only; application test results
  above remain the earlier observed results.
- Memory-update validation: `python tools/check_docs.py` passed for 26 Markdown
  files, 228 local links and five JSON examples. Ruff lint/format checks for the
  validator and `git diff --check` also passed. Application suites were not rerun
  for this documentation change.

## 2026-10-13, 13:01 IST — Memory moved into docs

- User instructed: **“add that memory md inside docs.”**
- Moved the existing memory to `docs/MEMORY.md`, preserving its chronological
  entries. This is the current location for future memory updates.
- Updated relative links, the README and the implementation handoff. The existing
  documentation validator includes the memory through its `docs/*.md` discovery.

## 2026-10-13, 14:06–14:20 IST — Connected Phase 0 milestone

Times describe the closing evidence window, not reconstructed individual edit
times. User authorized continued implementation of **Phase 0 only**, requested a
real Flutter/API synchronization path and explicit adversarial review, and
required chronological memory to remain in `docs/MEMORY.md`. Existing unrelated
working-tree changes were preserved; no commit, deployment or Phase 1 work occurred.

- Read the authoritative README, implementation, phase/roadmap/rules, architecture,
  data/sync/API/security/testing/decisions/review/contribution documents first.
- Connected foreground Riverpod/domain scheduling to generated contracts, frozen
  outbox packing, authenticated HTTP, atomic receipts/own echoes, committed pull
  pages/cursors, preserved branches and persistent conflict/retry states.
- Connected staged checksum bootstrap, generation/retention recovery and retired
  root/child IDs. Remote erasure purges queued personal payload; matching-owner
  disable persists across restart. Expired authentication preserves training.
- Added additive server migration 0002 and Drift schema 2; tested the previous
  foundation schema upgrade with active work, draft, timer and frozen body intact.
- Added synthetic signed development identity setup. Only setup uses admin
  authority; actual API uses a restricted runtime role. Flutter gets no admin,
  database, service or signing secret. Production OTP/storage remain separate gates.
- Docker Desktop/PostgreSQL 17.7 were started locally. Flutter 3.47.7/Dart 3.13.5,
  Python 3.13.14, ignored SDK/cache and task temp directories on E: were used.
  Default Python lacked dependencies; the existing task venv supplied them.
- The live harness launches actual HTTP with verified ES256 JWTs and restricted
  PostgreSQL. It exercises upload/retry/digests, own echo, two devices/conflicts,
  defaults/Unicode, deletion/redaction/invalid snapshots, expired JWT and SQLite
  restart. No mock substitutes for RLS, CAS, locks, receipts or server transactions.
- Recovery tests inject real SQLite failures before outbox creation, during ack,
  pull/cursor, staging/activation, deletion and conflict creation, reopen files and
  verify preserved state/integrity. Stalled uploads do not block another local save.
- Independent read-only review found further Unicode/local-contract acceptance
  gaps; they were fixed and covered. Self-review also fixed wrong-owner erasure,
  missing-account semantics, HTML 5xx retry, default-induced checksum changes,
  namespace collisions, duplicate positions, impossible dates, UTC expiry output,
  snapshot storage bounds and misleading observer/UI success. Original protocol
  invariants were retained; no ADR was changed.
- Final observed application results: **80 ordinary Flutter passed** (eight live
  cases explicitly skipped in that run); **8 live Flutter passed** separately;
  **49 Python passed**, including **19 PostgreSQL integration cases** and the live
  runner. Flutter analyze is clean; strict mypy checks **10** files. The mobile
  source/test formatting set contains **28** Dart files. Current exact evidence
  and remaining limitations are in [IMPLEMENTATION.md](IMPLEMENTATION.md).
- CI now enables actual connected tests and verifies contract/Drift generation.
  Remote CI, Android/iOS builds and physical-phone qualification did not run.
  The development identity was smoke-tested with verified HTTP 200 and matching
  active owner. Setup outputs remain ignored in `.tools/development-sync`.
- Remaining gates: production OTP/provider identity/token storage/account setup,
  explicit conflict resolution, account export/erasure jobs and restore suppression,
  scheduled retention/abuse budgets, large-history capacity/activation performance,
  native privacy/accessibility/builds, timer clock qualification, hard OS kills,
  disk-full/power loss and physical-device p95 durable-save measurements.
- **Phase 0 remains in progress; Phase 1 has not started.** Reopening/injected
  faults are desktop evidence, not a physical process-death or p95≤100ms claim.

## 2026-10-13, 14:26 IST — Final milestone verification

- Supplementary review tightened snapshot name/lifecycle/load/observation validation,
  shared Unicode whitespace correction-reason semantics and paused-pull status.
  Root revisions remain independent of owner-feed positions.
- Final serial observed suites: **80 ordinary Flutter passed**, **8 live connected
  Flutter passed**, **49 Python passed**, Flutter analysis clean, strict typing
  clean for **10** files and Ruff lint/format clean for **23** Python files.
- All **four** generated artifacts reproduced byte-for-byte: checked OpenAPI,
  mobile DTOs, mobile limits and Drift database output. Dart format checked **28**
  files with **zero changes**. Documentation validated **26** Markdown files,
  **233** local links and **5** JSON examples; Git whitespace passed.
- Real SQLite recovery coverage now includes **27 file-backed fault/restart
  cases**. Actual HTTP/JWT/restricted-PostgreSQL coverage remains eight Flutter
  cases plus the PostgreSQL integration suite; no remote CI or phone claim.
- Learned environment constraint: ordinary Flutter tests and the Python harness
  launching Flutter must run sequentially in the same checkout. Parallel runs
  briefly failed on a locked native SQLite DLL; the serial final runs passed.
- Corrected Unicode loss in newly authored documentation caused by PowerShell's
  stdin encoding; UTF-8 memory history and mathematical/arrow text are intact.
- The transient development API smoke-test process was stopped. Local Compose
  PostgreSQL and ignored synthetic setup files remain available for continuation.
- No ADR, commit, deployment or Phase 1 work. Phase 0 qualification remains open.

## 2026-10-13, 17:39–17:50 IST — Authentication/account milestone closing evidence

Times describe the observed closing validation window, not invented individual
edit times. User requested production-shaped authentication/account lifecycle on
the connected synchronization foundation, while preserving offline training and
keeping Phase 1 unstarted. Existing working-tree changes were retained.

- Re-read the authoritative README, implementation/memory, phase/roadmap, sync,
  API/security/testing/decisions and related product/data/architecture documents.
  The accepted ownership, deletion, revision and synchronization model remains.
- Added supported Supabase Flutter SDK **2.18.3** email OTP request/verify/resend,
  refresh and provider logout. Error codes are sanitized; SDK auth logging is
  disabled. Auth HTTP restricts origin, rejects redirects and bounds responses.
  Each bounded operation disposes its SDK client and underlying HTTP resources.
- Added `flutter_secure_storage` **11.2.0** session/verified-owner storage and
  secure PKCE. The account controller awaits persistence rather than using the
  Flutter SDK wrapper's default preferences/unawaited event writes. iOS requests
  device-only unlocked Keychain items; Android uses protected-storage defaults.
  Native bridge/options and configuration are tested on desktop; no native
  hardware protection, hosted OTP or production SMTP claim is made.
- Added an account-domain lifecycle with epochs/serialization, cached verified
  owner recovery independent of cloud validity, foreground refresh/backoff,
  verified unlock and deliberate sign-out. Expiry/failed refresh preserve active
  logging, corrections, completion, history and original frozen pending mutations.
  Sign-out locks SQLite and removes cloud state while retaining owner data. A → B
  → A uses separate files/coordinators/provider scopes and recovers A's pending work.
- Added generated account contracts and `POST /v1/account/initialize`: real JWT
  verification, current-provider-user validation, per-owner absent-row advisory
  lock, existing active-account guard and idempotent minimal `kg` profile. No
  client-selected owner, duplicate account/profile or sample workout is created.
- PostgreSQL migration **0003** adds forced-RLS profiles and irreversible owner
  retirement markers. Old tokens cannot recreate a purged retired account.
  Under-lock disable remains enforced. Matching-owner disable handles an already
  signed-out local store according to the accepted erasure policy.
- Production/staging API configuration rejects synthetic public-key overrides;
  release mobile configuration rejects fixture flags, synthetic tokens,
  development environment and unsafe/privileged key formats. Mobile carries no
  service, admin, database, SMTP or signing secret.
- Adversarial fixes cover cached-session unlock after sign-out, stale OTP/refresh/
  protected-grant completions, secure logout failure, A metadata disguising a B
  token, swallowed reauthentication during an old sync cycle, refresh hot loops,
  disabled signed-out payload, and new bootstrap requests after auth pause.
  Slow OTP requests now show progress and prevent repeat button submission.
- Validation environment remains Windows 11, Flutter 3.47.7/Dart 3.13.5,
  Python 3.13.14 and Docker PostgreSQL 17.7 with restricted runtime RLS. Controlled
  SDK/provider and secure-channel adapters inject failures; real SQLite files and
  PostgreSQL prove persistence, locking, idempotency, ownership and authorization.
- Full observed API results: **70 Python passed**, including **40 PostgreSQL
  integration cases** (21 new account cases) and **9 live Flutter HTTP cases**.
  The mobile suite contains **121 ordinary cases** (80 retained, 24 lifecycle,
  14 provider/storage-boundary, 3 widgets); nine live cases are explicitly skipped
  in the ordinary run and separately enabled by the API harness. Exact final
  observed results are recorded in [IMPLEMENTATION.md](IMPLEMENTATION.md).
- Flutter analysis and Ruff/strict mypy pass; **39 Dart** and **26 Python** files
  are format-checked, strict typing covers **11** source/script files. OpenAPI,
  generated mobile DTOs/limits and Drift output reproduce byte-for-byte.
- Environment failures were diagnosed separately: Docker Desktop stopped before
  one run (30 unit cases passed, 40 database setup errors); the healthy dedicated
  PostgreSQL service was restored and the full run passed. Flutter widget cleanup
  must use real async teardown outside its fake clock; orphaned test processes
  caused a temporary SQLite DLL lock and were stopped. Keep Flutter test runs and
  the API harness's nested run serial in this Windows checkout.
- No real provider credentials were available. Required operator configuration is
  documented: separate projects, asymmetric JWKS, publishable mobile config,
  OTP email templates, custom SMTP/domain authentication and provider rate limits.
  Secure native storage, OTP/SMTP delivery, revocation/rotation, privacy/recent-auth
  operations, public export/erasure jobs, restored-backup suppression and physical
  device/release/performance/accessibility gates remain open. The production path
  contains no sample workouts; broad authoring stays in its accepted later scope.
- No ADR change, commit, deployment, remote CI or physical-device qualification.
  **Phase 0 remains in progress; Phase 1 has not started.**

## 2026-10-13, 18:04 IST — Final authentication verification

- Final failure-path review found secure logout could skip the provider attempt,
  and remote deactivation needed to cancel refresh/queued callbacks and retain a
  truthful failure state. Fixed cleanup to drain sync before locking, clear memory,
  still attempt bounded provider logout, and fence stale completions. Added real
  file-backed disable/secure-storage-failure restart coverage. Logout stays busy
  until the provider attempt settles, preventing stale logout UI updates.
- The new test initially exposed an authenticated status after failed deactivation;
  the failure state is now installed before epoch-fenced error propagation. The
  corrected complete suite passes. Earlier counts above are historical snapshots.
- Final observed mobile results: **122 ordinary Flutter passed, 9 live cases
  explicitly skipped**; **9 live Flutter HTTP/PostgreSQL passed** separately.
  This is **131 distinct Flutter cases**. New ordinary coverage is 25 account
  lifecycle, 14 supported SDK/storage-boundary and 3 widget cases. Of the lifecycle
  cases, 21 use real account-scoped SQLite files; prior 27 file-backed sync recovery
  cases remain passing. No simulated adapter substitutes for database semantics.
- Final full API/live runner: **70 Python passed, 0 skipped**, including **40 real
  PostgreSQL cases** under the restricted role. The last full run took **28.57 s**;
  ordinary Flutter took **71 s**. Flutter analysis is clean, Dart checks **39 files
  with zero changes**, Ruff checks **26 formatted files**, strict mypy checks
  **11** source/script files. All four generated artifacts match regenerated bytes.
- Documentation validates **26 Markdown files, 238 local links, 5 JSON examples**;
  Git whitespace and static iOS entitlement/Android permission/backup checks pass.
  Evidence, README, security/API, phase checklist and chronological memory are
  updated. Existing CI discovers the new tests; remote CI did not run.
- No real Supabase/SMTP delivery, native builds/hardware storage or physical-device
  p95 qualification. Operator-managed provider setup and the other Phase 0 gates
  recorded in docs/IMPLEMENTATION.md remain open. No ADR, commit or deployment;
  **Phase 0 is still in progress and Phase 1 has not started.**

## 2026-10-13, 22:30–22:50 IST — Windows native qualification checkpoint

This records the observed closing window after resuming interrupted work, not
invented edit timestamps. The user confirmed no phones/Mac or hosted Supabase
project/inbox, authorized all honest Windows preparation, and requested a commit.

- Installed checksum-verified task-local Android tools/JDK, SDK 36/35, NDK and
  Gradle under ignored `.tools/`; Android debug and profile compiled. Normal debug
  installed/launched on API 36 x86_64 emulator and correctly required configured
  authentication. No physical device or hosted OTP was used.
- Added Android elapsed-time/installation/boot continuity and iOS continuous time
  with conservative process continuity, additive Drift schema 3, sticky clock
  uncertainty and a bounded/malformed-safe native bridge. Timer estimates never
  become measured rest; network/auth remains outside local set saving.
- Added iOS guarded backup exclusion and Android explicit backup/transfer domains,
  predictive-back configuration, native protected-storage recovery entrypoint,
  profile caller-acknowledgement benchmark and device procedures. Release signing
  is deliberately operator-managed; no silent debug-key release. Native iOS
  compilation and actual hardware protection/backup remain open.
- Final ordinary Flutter: **143 passed, 9 live skipped**. Separate connected run:
  **9 live Flutter passed** with real HTTP/SQLite/restricted PostgreSQL. Full API:
  **70 Python passed, 0 skipped**, including **40 PostgreSQL cases**, 61.39 s.
  Flutter analysis, 49-file Dart format, 27-file Ruff and 11-file strict mypy pass.
  All four generated artifacts reproduce byte-for-byte.
- New faults: three actual hard Windows worker-process kills before/during/after
  commit, real SQLITE_FULL rollback/reopen, schema 2→3 and timer persistence.
  Controlled clock ±1 hour/timezone/reboot and desktop platform semantics are not
  phone lifecycle/screen-reader evidence. Physical benchmark sample count is zero.
- Memory pressure interrupted native retries. Stopped only task-owned processes,
  bounded Gradle to 2 GiB/two workers, retained user applications/containers and
  resumed release/emulator checks. Their unfinished attempts are not labelled pass.
- Updated implementation/checklist/README/security/testing/device procedure with
  explicit blockers. GitHub repository access permits a qualification-branch CI
  run after the checkpoint commit; no remote result exists at this entry yet.
- No ADR change or Phase 1 work. Physical Android/iPhone, Mac/iOS, Keychain/device
  secure storage, backup/restore, VoiceOver/TalkBack, reboot/process-kill phone
  tests, physical p95 and real Supabase/custom SMTP remain open.

## 2026-10-14, 00:02–00:10 IST — Native qualification and commit closing state

Closing local date crossed midnight; native artifact filenames use the October 13
UTC date. The user asked when to commit and to continue. No Phase 1 work started.

- Committed accumulated Phase 0 implementation as **b8968ca**; signing required an
  unavailable private-key passphrase, so the checkpoint is unsigned without
  changing Git configuration. Staged credential scan found no private/provider/
  GitHub secrets. Ignored transient Kotlin cache/session artifacts. Published
  `phase0-qualification-2026-10-13` for the requested actual remote CI, leaving
  remote main at its planning baseline; no deployment or PR message was sent.
- Actual [first CI run](https://github.com/bluxo1/Daily-Motion/actions/runs/38438667550)
  passed Linux/API/PostgreSQL, Linux/Android and hosted macOS jobs. This supplied a
  real Mac compilation host despite no local Mac: unsigned iOS debug/release and
  Android debug/profile/release compile. It does not qualify iPhone execution,
  signing, Keychain, physical secure storage or screen readers.
- Agent-caused concurrent Flutter dependency refresh rewrote the native release
  registrant and failed compilation. Fixed validation order: run all Flutter/Dart/
  nested live commands serially, regenerate tooling when switching modes, and
  avoid retaining another mode's registrant with `--no-pub`. Serial Windows release
  build passed; `apksigner` confirms deliberately unsigned output. No dev-only
  plugin was moved into production dependencies to conceal the failure.
- Actual Android 16/API 36 x86_64 emulator protected-storage/SQLite seed and recover
  passed on b8968ca. Kept the seed app running, then externally force-stopped its
  observed PID at **2026-10-13 17:53:21 UTC**. Replacement recovery APK retained the
  saved observation, draft, two pending commands, frozen checksum and synthetic
  session. SQLite integrity is `ok`; native metadata says physical=false and
  backup_allowed=false. Backup Manager was disabled, so no restore claim is made.
- High-resolution emulator attempts hit host memory pressure/ADB disconnects and
  were not counted as passes. Used a task-only 480×800 display, 1024 MiB guest RAM
  and two virtual cores. Preserved unrelated user processes and containers.
- Benchmark investigation found excessive history query round trips on caller
  acknowledgement and active-session checks. Committed the fix as **a27dfdd**:
  three bulk table reads in the original guarded transaction, shared projection
  decoder, active validation from metadata. This changes read cost, not protocol,
  ownership, ordering, revisions, frozen commands or conflict/deletion policy.
- New 100-root real-file parity/query-bound test covers a multi-exercise root,
  pending/frozen state, active exclusion and lock/unlock. Focused test passed; the
  loaded full fixture needed an explicit two-minute test budget. Final full local
  results: **144 ordinary passed, 9 live skipped** (131 s), **9 live HTTP passed**,
  **70 Python passed, 0 skipped** (43.19 s), including **40 PostgreSQL** cases.
  Named file-backed recovery/account/fault subset is **55**; Windows hard kills **3**.
- Actual [fix CI run](https://github.com/bluxo1/Daily-Motion/actions/runs/38445714228)
  passed **all three jobs on a27dfdd**: Linux/macOS each **144 passed, 9 skipped**,
  Android all three build modes and unsigned iOS debug/release compile. API **70
  passed**, 17.81 s; 50 Dart/27 Python formatting, clean analysis/Ruff/11-file strict
  mypy, Drift/contract regeneration and documentation/native guards pass.
- Rebuilt benchmark APK carries exact a27dfdd revision. Android debug emulator
  harness completed **100 history roots, 32 warmups, 200 measured saves, zero
  failures** (165 s including setup). Retained all raw samples/nearest-rank method
  in [safe evidence](evidence/phase0-windows-native-2026-10-13.json), alongside seed,
  force-stop, recover, checksums and CI scope. Incomplete pre-fix benchmark is not
  counted; no speedup ratio is inferred. physical_performance_evidence=false,
  target_met=false; **physical sample count 0 and physical p95 unavailable**.
- Each native invocation has one declared assertion case plus the integration
  binding's generated teardown check (+2 reported); three invocations passed.
  The emulator was stopped after collection. Final documentation follows in a
  separate evidence commit; its docs-only checks do not need another native build.
- Real Supabase/custom SMTP/inbox/publishable project setup, physical Android/
  iPhone, signed installations, actual backup/transfer, hardware Keychain/protected
  storage, phone kills/reboot/suspension/clock changes, disk/power failures,
  VoiceOver/TalkBack and physical p95 remain open. Other authoritative Phase 0
  export/erasure/restore/capacity/security gates remain as documented. No ADR changed.

## 2026-10-14, 00:10–00:35 IST — Phase 0 evidence reconciliation

- User requested an audit on `phase0-qualification-2026-10-13` and completion of
  every local Phase 0 task, preserving explicit external blockers and no Phase 1.
  Started from clean `e888571`; reviewed roadmap/checklist/testing/evidence/memory
  against actual source and the passing CI run on `a27dfdd`.
- Reconciled five original unchecked rows already proven by later evidence:
  design/editor, Drift recovery/ownership, PostgreSQL CAS/receipts/feed/bootstrap,
  disable/redaction/migration and generated contracts/fixtures. Physical acceptance
  remains separate. Corrected migration naming to schema 1→3 and 2→3.
- Added [evidence matrix](PHASE0_EVIDENCE.md) and
  [operator handoff](../infra/QUALIFICATION.md). Earlier chronological entries
  called public export/deletion/conflict UI/production restore/retention/capacity
  work Phase 0 gates; **the authoritative roadmap puts production completeness
  in Phase 1**. Those public-release requirements remain open without authorizing
  Phase 1 now. This append clarifies prior status rather than rewriting history.
- Implemented the missing disposable routine interaction study, editing planned
  sets/rep ranges/rest and freezing workout previews. No owner/store/outbox/API,
  no personal sample data, release-disabled. Four new Dart cases cover immutable
  prescription/validation, keyboard/back/large text/semantic targets and contrast.
- Added CI secret scanning and five synthetic scanner/settings-redaction tests.
  Confirmed a database-role configuration assumption during adversarial review:
  tenant transactions now reject superuser/BYPASSRLS, owner-role membership and
  absent enabled/forced RLS. Four actual PostgreSQL attacks and restoration pass.
  Database URL no longer appears in settings representation. No protocol/ADR change.
- Full local results: **148 ordinary Flutter passed, 9 live skipped** (90 s),
  separate **9 live passed**, **79 Python passed, 0 skipped** (31.48 s), including
  **44 real PostgreSQL cases**. Distinct Flutter count **157**. Named file-backed
  recovery/account/fault subset remains **55**, hard Windows kills **3**. Dart
  formatting **52 files/0 changes**, analysis clean; Python formatting **30**,
  Ruff clean, strict mypy **11**; four generated outputs unchanged.
- New prototype test setup failures were corrected (outer scrollable, lazy list
  visibility, semantics disposal). No app data-loss/account-crossover defect was
  exposed by the final full suite. CI/native/document/credential checks are rerun
  after final evidence edits; source revision and actual remote results follow.
- Remaining Phase 0 dependencies are external: phones, signed installation,
  hardware secure storage/backup-transfer/accessibility/process-reboot-storage-
  power/physical p95, hosted OTP/SMTP/inbox/project configuration, operator-managed
  region/backups/processor/signing/store accounts and named review appointments.
  **Physical samples 0; real hosted-provider qualifications 0. Phase 0 remains in
  progress; Phase 1 not started; no ADR changed.**

## 2026-10-14, 00:35–01:00 IST — Audit commit, CI capacity and public desk review

- Committed/pushed **545a6ec** (unsigned, configured SSH signing passphrase
  unavailable; signing configuration unchanged). Actual CI **38451919078** passed
  API **79** (18.15 s), Linux **148 passed/9 skipped**, all Android app modes and
  the separate routine-prototype debug compile. Contracts/Drift, lint/types,
  docs **29/273 links/5 JSON** and credential guard **195/0** pass.
- Overall run **not green**: macOS ARM64 was never allocated, executed zero steps
  and GitHub cancelled it after 15 minutes. Annotations explicitly report hosted
  runner capacity; prior a27dfdd macOS/iOS proof remains historical only.
- Recovered the software build path with supported public `macos-15-intel` and
  explicit Xcode 26.3; pinned Ubuntu 24.04 and current official action commits,
  removed deprecated actions and disabled checkout credential persistence.
  Application SDKs/protocol/domain source unchanged. Replacement CI is run next.
- Public primary-source desk review confirmed Mumbai availability and recorded
  database backup/PITR, omitted object bytes/custom-role reset boundaries and
  DPA/subprocessor review inventory in [the handoff](../infra/QUALIFICATION.md).
  No hosted project, restore, contract approval, real OTP/SMTP or legal conclusion.
  Operator signing/settings/reviewer and physical gates still open. No ADR change.

## 2026-10-14, 01:17 IST — Audit closing CI evidence

- [Replacement CI 38454815935](https://github.com/bluxo1/Daily-Motion/actions/runs/38454815935)
  passed **all three jobs on 46f5d5a35305c8da51180b195e77b6b6a8df8077**.
  Ubuntu API **79 passed** (18.49 s), Linux and Intel Mac each **148 passed/9 live
  skipped**. Separate live Flutter **9** are exercised in the API harness; unique
  Flutter **157**, real PostgreSQL **44**, named file-backed subset **55** with
  **3 hard Windows kills**. Repeated CI runs do not add distinct cases.
- Android app debug/profile/release and isolated routine debug target compile.
  Actual hosted Mac **15.7.9/24G830, Intel x64**, selected **Xcode 26.3**, compiles
  unsigned iOS debug/release (Xcode 217.3/134.2 s, not save latency). Supported
  runner selection resolved the earlier ARM64 capacity cancellation honestly.
- Source46 docs **29 files/275 links/5 JSON**; scanner **195/0**; 52 Dart and 30
  Python formatting, analyze/Ruff/11-file strict mypy and all four generated
  outputs pass. Closing documentation follows separately with no source changes.
- Five lagging original Phase 0 rows reconciled from prior proof; missing routine
  prototype, security guards/CI baseline and public hosting/backup/processor desk
  review completed. Only actual hardware/provider/signing/operator/reviewer
  acceptance remains. Public routine/conflict/export/deletion/production operations
  remain Phase 1 scope, not a reason to start it now. **Physical samples 0, real
  hosted-provider qualifications 0; Phase 0 in progress; no ADR changed.**
- Closing docs-only check: **29 Markdown/275 local links/5 JSON**; native guards,
  credential guard **195/0** and Git whitespace pass. No code/generated changes
  after successful source CI. The evidence follow-up is committed separately.

## 2026-10-14, 18:15–18:50 IST — Hosted staging preparation and login boundary

- User explicitly requested **Supabase staging + Render FastAPI**, real OTP/inbox
  and hosted sync qualification, Phase 0 only. Started clean at `dacc803`; read
  README/implementation/evidence/memory/phases/security/API/sync before edits.
- Available process has no Render/Supabase credentials/CLI session; both browser
  dashboards redirect to **sign-in**. Asked for direct provider login/workspace
  selection and controlled test inboxes. No resources created/deployed, credentials
  read/printed, actual staging URLs invented or provider qualification claimed.
- Prepared [blueprint](../render.yaml), [runbook](../infra/staging/README.md), OTP
  template, four-field client example and credential-gated Flutter hosted harness.
  Render Singapore/free/manual deployment uses pinned Python/uv/frozen lockfile.
  Provider secrets remain outside mobile/source; real `.env.*`/browser artifacts
  ignored. Official Render JSON schema validates the blueprint locally.
- Operator-only staging module/script verifies target before writes, applies
  Alembic through an injected admin connection, provisions restricted runtime
  grants and revokes direct training grants from provider roles. Probe inserts
  synthetic owners only inside rolled-back transactions and tests pool reset.
- Added hosted HTTPS/issuer/audience/publishable/TLS verification checks and
  `/readyz` for revision 0003, grants, forced RLS and missing-owner denial; existing
  `/healthz` remains liveness. SQL failures return sanitized 503 without exception
  payload logging. Fixed any-grant validation and denied CREATEROLE/CREATEDB/
  replication privilege; quoted-password setup and actual database attacks pass.
- Full local **148 Flutter passed/10 skipped** (115 s), separate live **9 passed**,
  **99 Python passed/0 skipped** (37.00 s), **51 PostgreSQL** collected cases.
  Executed Flutter count **157**; hosted harness unrun and not counted. Existing
  named file-backed subset **55**, hard Windows kills **3** retained. Dart format
  **53**, Python **33**, strict mypy **13**; analysis/Ruff clean; four generated
  artifacts unchanged. Native guards and credential guard **203/0** pass.
- Added **DM-018**, explicitly requested Supabase Mumbai / Render Singapore
  **staging-only** exception; DM-003 production Cloud Run Mumbai unchanged.
  Actual regions/project/API revision/URLs, hosted migration/RLS/TLS, OTP/SMTP,
  refresh/account/sync checks remain unperformed until user provider access and
  inbox/operator configuration. Physical gates unchanged. Phase 0 in progress;
  Phase 1 not started. Final docs/commit/remote evidence follows when completed.

## 2026-10-14, 18:53 IST — Staging preparation committed; provider access pending

- Committed/pushed **ef025c2552122cb2a3727943f761a1602d5e6c56** on the qualification
  branch. Commit unsigned because the configured SSH signing passphrase is
  unavailable; signing configuration unchanged. The staged credential guard has
  **203 files/0 findings**. Docs **30 files/294 links/5 JSON**, native guards and
  generated hashes pass; working tree was clean after push.
- [Actual CI run 38570967779](https://github.com/bluxo1/Daily-Motion/actions/runs/38570967779)
  was triggered by the push. API job passed; Linux/macOS mobile jobs were still
  running when this entry was written. Do not treat partial CI as all jobs green.
  Provider dashboards still require login; zero hosted resources/OTP/SMTP/sync
  qualifications. The live staging harness remains explicitly skipped.

## 2026-10-14, 19:06 IST — Staging preparation CI passed; hosted boundary remains

- Actual [run 38570967779](https://github.com/bluxo1/Daily-Motion/actions/runs/38570967779)
  completed **successfully in all three jobs** on source **ef025c2**. API **99
  passed/0 skipped** (18.59 s), including restricted PostgreSQL and **9 real
  loopback Flutter HTTP** cases; Linux and Intel macOS each **148 Flutter passed/
  10 skipped**. Android debug/profile/release and separate routine debug, unsigned
  iOS debug/release, format/analyze, contracts/Drift, native guards, docs and
  credential scan passed. Hosted credentials were absent; the new hosted test
  remains an explicit skip. Unique executed Flutter cases remain **157**.
- Reviewed operator credential separation, verified TLS, readiness/grant/RLS
  enforcement, rollback-only synthetic probes and token-free harness configuration.
  Corrected outdated blanket “no ADR changed” evidence to identify **DM-018**;
  no transport revision or production hosting decision changed.
- Supabase/Render still require login and staging organization/workspace selection;
  test inboxes and optional SMTP configuration remain unavailable. **No project
  created, API deployed, actual staging URL/key assigned or hosted OTP/SMTP/RLS/
  synchronization qualified.** Resume from the staging runbook after direct
  provider login; never request secrets in chat. Physical/operator gates remain
  open. Phase 0 remains in progress and Phase 1 has not started.

## 2026-10-14, 21:11 IST — Hosted staging live; real email/identity boundary

- With user dashboard login, selected the empty Mumbai project, renamed
  `daily-motion-staging`, ref `pulruylvpehwftwqcvct`, Free PostgreSQL **17.11**.
  Applied **0003**, restricted `dm_staging_runtime`, actual verified TLS via
  session pooler 5432 and server SSL enforcement. Three rollback-only owner/RLS/
  pool probes pass; final verifier reads actual head and runtime readiness passes.
  Provider roles have no training grants; unused Data API disabled, public REST
  **401**, Auth settings with real publishable key **200**.
- Render Free **Singapore**, service `srv-db7p5knavr4c7392dasg`, live at
  `https://daily-motion-staging-api.onrender.com`; deployed **8e5af65**, ID
  `dep-db7pugjrjlhs73cjobe0`. Only runtime credentials are on service. Passwords
  remained in temporary authenticated localhost memory/provider storage, never
  real `.env`/mobile defines/logs. Evidence contains public identifiers only.
- Source fix **8e5af655112123cd9104f4b292e250b791363958** committed/pushed unsigned:
  reject missing/stale runtime migration metadata and explicitly grant metadata
  schema usage. **3 adversarial cases failed before fix**, then **23 staging
  tests passed**. All **102 Python / 54 PostgreSQL / 148 ordinary Flutter + 9
  loopback Flutter HTTP** pass, **10 ordinary skips**, 55 file-backed subset,
  3 hard Windows kills. Format/analyze/Ruff/mypy pass, four artifacts unchanged.
- Actual CI [38587594908](https://github.com/bluxo1/Daily-Motion/actions/runs/38587594908)
  **all three jobs passed** on that source: API **102/0 skips** (14.43 s), Linux/
  Mac **148/10 skips**, Android all modes and unsigned iOS debug/release. Local
  unsigned **staging-configured release APK** compiled (58.7 MB), no device claim.
  Actual hosted public suite **6/6 passed**, including known-public-key-ID bad
  signature and unsupported contract; no real user token/session fabricated.
- Initial missing-CA deployment timed out readiness; cancellation raced the next
  queued attempt, then complete configuration redeploy succeeded. A follow-up
  HTTP timeout is recorded without asserting cause; bounded public probes pass.
- **Blocked:** no designated A/B inboxes/mail access. Supabase requires custom
  SMTP before editing code templates; six-digit/600 s settings saved but prepared
  templates unapplied, **0 OTP requests/deliveries/verified accounts qualified**.
  Authenticated hosted Dart case remains **0 executed / 1 skipped**. Free project
  has no managed backups. Resume SMTP/inbox → actual OTP/account/refresh/sync/
  retry/sign-out/disable/A→B→A qualification; never use admin/synthetic identities
  to close these gates. Physical/signing/backup/reviewer/store gates remain open.
  DM-018 status updated, no new ADR. Phase 0 incomplete; Phase 1 not started.

## 2026-10-14, 23:34 IST — Confirmed inboxes, real request acceptance, SCRAM fix

- Owner designated controlled A and Gmail plus-alias B. One real public Auth OTP
  request per address returned **200**. **No delivery/verification/session or
  distinct B identity is qualified**; no code/token/inbox content was retained.
  Custom SMTP/code templates remain open. Provider/browser tools disappeared in
  this resumed environment; Supabase/Render/Gmail connectors are discoverable but
  not connected. Restore dashboard/mailbox access; never paste OTPs/secrets.
- Audit confirmed plaintext runtime passwords entered role DDL. Fixed with libpq
  client-side **SCRAM-SHA-256**, regardless of server default, in unsigned source
  commit **6606db060ec2a82db34d34ce94a92474e97d0bd4**, pushed to the qualification
  branch. Two real PostgreSQL regressions fail before/pass after; they check real
  create/rotation/login, quoted/Unicode passwords, SQL boundary and old-password
  rejection. The old MD5-default case also failed initial SCRAM-required login;
  Unicode password rotation passes after the fix.
- Hosted `log_statement=ddl` was observed, but interrupted aggregate log/statistics
  audit produced no recoverable result. **Historical password retention is not
  ruled out and credentials have not been rotated.** Restore protected operator
  access, inspect sanitized counts/settings, rotate with the fixed provisioner,
  update Render secrets and recheck RLS/readiness. No admin/DB secret is available
  in this resumed process; both temporary bridge listeners are absent. Hosted API
  still runs **8e5af65**; no new deployment is claimed.
- Full local **104 Python passed / 0 skipped / 152.37 s**, including **56 real
  PostgreSQL** and **9 live loopback Flutter** cases; focused staging **25 passed**.
  Full Flutter initial **147 passed / 10 skipped / 1 worker-boundary timeout**;
  isolated hard kills **3/3 passed (26 s)**, full serial repeat **148 passed /
  10 skipped / 0 failed (144 s)**. Unique executed Flutter remains **157**.
  Ruff format/lint and strict mypy pass; regenerated OpenAPI/DTO/limits match after
  required Dart formatting. Real public hosted checks again **6/6**, after two
  bounded warm-up timeouts; no production availability inference.
- Actual [CI run 38611404742](https://github.com/bluxo1/Daily-Motion/actions/runs/38611404742)
  API passed; initial mobile dependency setup received pub.dev **403**, macOS
  canceled by matrix fail-fast. Failed jobs rerun once; final outcome follows.
  Earlier deployed **8e5af65** remains all-green. No new ADR; DM-018 staging scope
  unchanged. Provider identity, hosted sync, managed backup/reviewer, physical
  device and operator-signing gates remain open. Phase 1 not started.

## 2026-10-14, 23:52 IST — Current-source CI green; protected operator boundary

- [Run 38611404742](https://github.com/bluxo1/Daily-Motion/actions/runs/38611404742),
  **attempt 2**, finished **successfully in all three jobs** on **6606db0**.
  API **104 passed / 0 skipped / 19.71 s**, restricted PostgreSQL plus nine live
  Flutter cases; Linux/Mac each **148 passed / 10 skipped**, Android all modes and
  routine study, unsigned iOS debug/release. Initial pub.dev 403/matrix cancellation
  is retained; no gate or dependency lock was weakened to recover.
- Final local Dart format **53 / 0 changes**, analyze clean (**61.2 s**), Drift
  **29 s / 77 same outputs**, all **four** generated artifacts identical. Docs
  **30 files / 301 local links / 5 JSON examples** plus standalone hosted JSON;
  native guards, **204 source files / 0 credential findings**, whitespace and
  unchanged staging APK hash pass. New docs are a separate CI-skipped evidence
  commit; source CI is 6606db0, hosted deployment is still **8e5af65**.
- A/B actual requests accepted **200**, but delivery, verified distinct identities,
  SMTP templates, hosted account/refresh/sync/retry/sign-out/disable remain open.
  Restore protected dashboards/inbox; finish historical credential-log inspection,
  rotate/reapply with fixed operator code, update Render secrets and reverify.
  No user secrets/codes/tokens should enter chat or source. Both temporary bridge
  listeners remain absent. Free managed-backup/restore, review/store, physical
  device/signing/storage/accessibility/lifecycle/p95 gates remain external.
  No new ADR; DM-018's observed staging status is documented. Phase 0 remains in
  progress; Phase 1 has not started.

## 2026-10-15, 00:04 IST — Hosted-auth prerequisite remains blocked

- User narrowed work to real hosted authentication qualification; no new features,
  mocks substituted for hosted evidence, or Phase 1 work. Clean starting revision
  **4798c7f**; SCRAM operator fix is source **6606db0**, last observed hosted API
  **8e5af65**. Pushing/deploying source does not prove credential rotation.
- Discovery confirms Supabase/Render/Gmail connectors are available but not
  connected; provider/browser control, operator credential context and inbox access
  are absent. SMTP/code-template completion is unconfirmed. Asked to restore
  protected access, without requesting codes/tokens/passwords in chat.
- No new OTP or authenticated hosted request was sent. First complete historical
  log review and rotation of potentially exposed credentials, update Render
  secrets, and reverify restricted runtime/readiness/RLS. No rotation/log clearance
  or new deployment is claimed. Prior two accepted requests are not deliveries.
- Existing focused suite **25 passed / 0 skipped / 15.50 s**, using real dedicated
  local PostgreSQL; actual invocation of hosted Flutter harness **0 executed /
  1 skipped** with no fake credentials. Full baseline remains **104 Python /
  56 PostgreSQL**, **148 ordinary Flutter / 10 skipped + 9 live HTTP**; not rerun
  here. Existing CI **38611404742** rechecked green on **6606db0**, not rerun.
- Delivery/verification/distinct A/B/authenticated hosted sync/refresh/account
  switching remain **unqualified**. Restore provider/inbox access and confirm
  SMTP/templates before continuing. No new ADR or completed Phase 0 gate.

## 2026-10-15 — Merged baseline, native audit confirms credential retention

- PR #2 was normally merged to `main` **9669fa2**, retaining original commit dates;
  the old remote qualification branch was deleted. Continued on new branch
  `phase0-hosted-auth-2026-10-15`. Configuration repair **69b929e** is committed and
  pushed: Render blueprint tracks `main`; runbook requires independently checking
  Blueprint/service branches and fresh runtime connections after rotation. Actual
  hosted branch settings were not changed. Last observed deployment **8e5af65**.
- Native Brave/Supabase access recovered via the cached GitHub session. A real
  aggregate-only hosted statistics query confirmed **2 role statements / 2
  plaintext-password statements** for the staging runtime role. No credential or
  historical query text returned. Historical Render application/deploy logs remain
  uninspected in this continuation. **Rotation has not occurred.**
- Browser keyboard input reports `window_not_focused` even after the supported
  restoration attempt. Asked the operator to foreground Brave; stop focus retries
  until that action. No provider credential/environment/deployment changed and no
  fresh OTP requested. Resume: review logs without secret output, rotate affected
  credentials using fixed SCRAM code, update Render secrets, close old sessions,
  verify fresh restricted role/RLS/pool/reset/readiness; then SMTP/template/inbox
  inspection and actual A/B qualification. Do not paste codes or secrets in chat.
  The unused temporary operator context was cleared, its process exited and its
  localhost listener is absent; create a fresh protected context when input works.
- Full ordinary Flutter **148 passed / 10 skipped / 198 s**, including three hard
  OS kills; hosted case **0 executed / 1 skipped**. Python was serialized around
  Flutter: **103 passed / 1 deselected / 40.61 s**, then connected case **1 passed /
  28.86 s** with **9 live Flutter HTTP cases**. Combined **104 Python / 56 real
  PostgreSQL**, **157 distinct Flutter**; dedicated local test database only.
  Ruff format/lint, strict mypy, Dart format and official Render schema pass.
  Current three test logs have **0 JWT-shaped values** (not provider-log clearance).
- Analyze clean **57.0 s**, Dart format **53 / 0 changes**; clean Drift rebuild
  **55 s / 105 outputs**, all **four artifacts byte-identical**. Docs **30 files /
  303 links / 5 JSON examples**, **3 standalone evidence JSON**; native guards,
  **205 source files / 0 credential findings**, whitespace checks pass. The first
  cached Drift run wrote nothing; forced clean regeneration provided actual proof.
- Hosted public checks **6/6**, after one unclassified warm-up read timeout. No
  delivery, verification, refresh, distinct A/B identities or authenticated hosted
  sync is qualified. SMTP/templates have not been re-observed. Actual source CI
  [38665949212](https://github.com/bluxo1/Daily-Motion/actions/runs/38665949212)
  passed all three jobs on **69b929e**: API **104 / 0 skipped / 19.49 s**,
  Linux/Mac each **148 / 10 skipped**, Android all modes/routine study and unsigned
  iOS debug/release. Evidence-only follow-up skips duplicate CI after local checks.
  No Phase 0 gate/ADR change
  or Phase 1 work. All previously open physical/provider/operator gates remain.

## 2026-10-15, 19:54 IST — Rotation applied; Render deployment in progress

- At **09:16:47 UTC**, a fresh TLS administrator connection verified a newly
  rotated staging database administrator password. At **09:24:18 UTC**, the fixed
  SCRAM provisioner rotated the restricted runtime credential and verified hosted
  **0003 / 11 forced-RLS tables / owner isolation / pooled owner reset** with its
  synthetic probe fully rolled back. No password/verifier was printed or committed.
- A replacement runtime URL was entered in Render's protected `DM_DATABASE_URL`
  field; the save form closed, but correct persistence was not yet verified.
  The next checkpoint records the failed read-back and repair. **One old runtime database connection was
  terminated.** Render's linked service branch was observed as `main`; Blueprint
  source-branch verification remains separate. Four available deployment log
  views plus the seven-day application-log view had no matches for the checked
  credential patterns. This is a bounded inspection, not historical-log purge.
- The user interrupted before deployment was confirmed. The temporary operator
  context has since expired; its localhost listener is absent. Do not try to
  recover passwords from process memory, query history or chat. New credential
  material remains in provider storage. No OTP request was sent.
- On continuation, five bounded `/healthz` warm-up probes timed out; cause is not
  established and service recovery is not yet proven. Native desktop focus was
  changing during pointer actions; avoid background pointer input. One supported
  focus restoration after a new focus error recovered the Render menu.
- At **14:24:43 UTC**, Render showed **Building** for explicit deployment
  **dep-db8e3s8n74is73eo7000**, revision **c5d5414fef28a4a5170d605b61d878797786acbd**.
  All three jobs in existing main CI **38710259066** were rechecked successful.
  This main revision adds only the separately merged contributor guide to 9669fa2;
  that work is preserved. Local PR #3 remains open (now marked ready by the owner),
  with configuration/evidence commits **69b929e / d15c1da**; it was not merged here.
- **Next:** confirm this exact Render deployment reaches Live and `/readyz`
  succeeds on the new process, then inspect actual Supabase SMTP/code templates
  and controlled inbox access before real A/B OTP/refresh/hosted Flutter tests.
  No real delivery, verified identity or hosted-auth qualification is claimed.

## 2026-10-15, 20:21 IST — Saved-credential defect repaired; staging recovered

- The protected saved-setting check proved valid URL/role/host/TLS metadata but
  actual **credential rejection**. First deployment **dep-db8e3s8n74is73eo7000**
  failed readiness. Two bounded public warm-up runs each had five read timeouts;
  do not attribute every timeout to a proven cause or suppress those failed runs.
- A fresh generated administrator credential was verified after an operator
  credential was shared insecurely; no supplied/replacement value is recorded.
  Keep replacements in provider storage, never chat/source/logs. The first Render
  save/read-back still did **not** match the current rotation. Focusing the exact
  value field before entry, triggering its normal blur, saving and reloading fixed
  persistence. Protected comparison then proved both full URL and password match;
  the displayed secret was hidden again. Only then was runtime rotation applied.
- At **14:44:34 UTC**, the fixed SCRAM provisioner passed the actual hosted
  **0003 / 11 forced RLS / owner isolation / pooled reset / rolled-back probe**.
  At **14:49:22 UTC**, explicit retry **dep-db8efpon74is73epb8ng** started on
  CI-green **c5d5414**. It reached **Live**, with startup and readiness passing.
- At **14:51:45 UTC**, one remaining runtime session had been terminated and a
  fresh restricted probe again passed. Public HTTPS checks passed **6/6**, with
  first warm-up returning 200. Aggregate audit: **4 runtime-role statements = 2
  retained historical plaintext + 2 new SCRAM**, stored runtime verifier is SCRAM,
  `log_statement=ddl`. No historical query text or verifier returned; no purge
  claimed. The two session-closure operations each terminated one connection.
- Real SMTP UI is **off**. Magic-link/OTP template says custom SMTP is required
  to edit subject/body; prepared code templates remain unapplied. Asked the owner
  to configure SMTP directly in the provider page without pasting credentials.
  No fresh OTP request, inbox receipt, verified A/B account, refresh or authenticated
  hosted Flutter qualification is claimed. Client-safe four-key configuration and
  its real Auth settings request pass (200). Regression results follow separately.

- Final regressions: **104 Python / 0 skipped / 79.95 s**, independently collected
  **56 real PostgreSQL** cases, including **9 live loopback Flutter**. Ordinary
  Flutter **148 passed / 10 skipped / 0 failed / 133 s**, yielding **157 distinct
  executed Flutter cases**. All **55 retained SQLite recovery** cases and **3 hard
  OS kills** remain covered. Actual hosted auth case is still **0 executed / 1 skipped**.
- Format **53 Dart / 33 Python**, analyze **0 issues / 53.1 s**, Ruff and strict
  mypy **13 files** pass. Four generated outputs reproduce byte-for-byte; clean
  Drift **72 s / 105 outputs**. Docs **30 / 306 local links / 5 JSON examples**,
  **4 evidence JSON**, native guards, **206 source files / 0 credential findings**
  and whitespace pass. Current Python/Flutter logs contain **0 JWT-shaped values**.
- One native diagnostic screenshot caught an occluding window; its generated file
  was removed. Sensitive provider operations subsequently used protected
  no-screenshot helpers. No unrelated content is reproduced in repository evidence.
  Next human boundary is actual SMTP setup in Supabase, then controlled inbox/code
  templates and real hosted qualification. No ADR or Phase 1 change.

## 2026-10-15, 20:48 IST — Operator context cleared; provider boundary preserved

- Protected operator shutdown returned `cleared`, the process exited successfully
  and its localhost listener was absent. No replacement credential is retained in
  ordinary application configuration, repository evidence or this memory file.
  Runtime credentials are saved in Render; administrator credentials stay off the
  service and mobile app.
- SMTP setup remains the next operator action. Keep the credential-gated hosted
  Flutter case skipped until real inbox delivery and verified identities are
  available. Existing deployed-source CI was rechecked, not rerun; the current
  changes record operational evidence and strengthen the staging rotation runbook.

## 2026-10-16, 04:45 IST — SMTP reported configured; native verification blocked

- Continued the existing PR branch from **d16eb71**. The owner reports SMTP
  configured in staging. Keep that report distinct from observed saved settings,
  active code templates, actual delivery and verified identity; none is newly
  proven. Do not repeat the prior off-state as a current observation.
- Native Brave navigation returns `window_not_focused`, including its supported
  restore attempt. Requested manual foreground focus and the controlled Gmail
  inbox. No screenshots, raw provider snapshots, OTP requests or secret entry
  occurred. Do not retry window restoration in a loop or ask for OTPs in chat.
- Public hosted checks **6/6 pass**, after **2 warm-up read timeouts**; real Auth
  settings **200**, email auth enabled, four-key client-safe staging config valid.
  Previous hosted rotation/RLS remains separate; no new authenticated DB probe.
- Fresh local results: **104 Python / 0 skipped / 75.59 s**, independently collected
  **56 PostgreSQL** cases; **148 Flutter passed / 10 skipped / 0 failed / 03:47**,
  plus **9 live loopback Flutter** cases (**157 distinct executed**). Actual hosted
  case still **0 executed / 1 skipped**. Ruff **33**, strict mypy **13**, native
  guards pass; current test logs have **0 JWT-shaped values**.
- Dart format **53 / 0 changed**, analyze **0 issues / 54.5 s**. No new remote CI
  or artifact regeneration; application/generated source is unchanged. Corrected
  the security note to distinguish completed rotation from retained historical
  statements; no purge claim or policy change.
- Docs **30 / 309 links / 5 JSON examples**, **5 standalone evidence JSON**,
  credential guard **207 / 0 findings** and whitespace checks pass.
- Next: verify saved SMTP and both relevant code templates, establish actual
  controlled inbox delivery, verify A/B, then run hosted credentials through the
  existing Flutter harness. No app/protocol change, new ADR or Phase 0 gate closed.
