# Phase 0 implementation evidence

Updated: 2026-10-21 (IST). **Phase 0 is in progress. Phase 1 has not started.**

## Session 2 recovery integration — 2026-10-21 IST

Reviewed `77e5124` plus evidence `ddbd418` against protected main `5975999`, with
merged PR #7 authentication and PR #8 qualification retained. An isolated branch
preserves all seven existing worktrees and historical commits. Recovery retains
acknowledged/missing/divergent local workouts, frozen identities and original
bases, with an upload fence surviving logging/restart. Retirement remains
authoritative. Review reproduced and fixed higher-revision cross-generation
overwrite. No schema, public contract, dependency or ADR changes.

Local Windows, pinned Flutter 3.47.7/Dart 3.13.5, Python 3.13.14 and disposable
native PostgreSQL 17.11: **180 ordinary Flutter passed / 12 explicit skips**,
**9 focused SQLite recovery passed**, **242 Python passed / zero skipped**,
including **14 PostgreSQL recovery cases**, **18 boundary/control guards** and a wrapper
executing **9 live Flutter HTTP cases**. Provider identity is simulated;
HTTP/JWT/SQLite/PostgreSQL are real. Separate validators pass **9 + 4 unittest
cases**. Flutter analyze has zero issues; Ruff and strict mypy pass. Alembic
head/repeated upgrade is `0003`; generated clusters are removed. Required PR CI
remains the authority for the published head's native builds.

The first signed head `4990d36` passed 237 local Python cases but both remote API
jobs failed Docker crash/restart readiness (233 passed, one failed, four errors).
A forward fix makes the lab's loopback binding explicit/stable and retains owned
container/volume identity for failed-start cleanup. Five control regressions and
the full local 242-case rerun pass; real Docker qualification remains gated by
new-head CI. Historical failures remain visible. [Exact follow-up](evidence/phase0-recovery-docker-ci-2026-10-21.json).

The hook audit distinguishes repaired October 17 launch failures from Session 2
automatic security reviews that established no coverage. Independent review and
repository/CI checks gate integration. CI now rejects skipped/incomplete Python
or connected Flutter qualification. All outstanding Phase 0 acceptance gates stay
open, including hosted recovery, deletion-ledger/admission and hardware/operator
work. No provider operation or merge is authorized. [Review and exact limits](RECOVERY_INTEGRATION.md).

## Earlier foundation checkpoint — 2026-10-18 IST

The foundation now includes real hosted SMTP/OTP and authenticated Flutter
functional proof, alongside the earlier Windows/native/fault harnesses.
Physical-device, remaining provider/operator and release gates in
[ROADMAP.md](ROADMAP.md) remain open. Earlier results are retained in [MEMORY.md](MEMORY.md).

## Implemented

- Contract-derived Dart DTOs, closed schema validation and operating limits from
  checked OpenAPI. Command-specific payloads, strict versions, actual UTC instants,
  Unicode code-point limits and shared fixtures are checked. Optional defaults
  populate a separate domain copy; frozen transport JSON stays unchanged.
  Generated validation runs before local acceptance and HTTP send.
- A domain foreground coordinator discovers eligible heads, freezes envelopes,
  packs up to 50 independent roots within 1 MiB, records attempts and sends HTTP.
  Deferred heads remain pending; oversized legacy/corrupt heads need attention
  without starving other roots. Successors use their own predecessor receipts.
- Whole-request timeout, disconnect/lost-response and non-JSON 5xx/429 handling,
  bounded reads, persisted backoff/jitter and explicit retry. Each cycle retains
  one credential; a switched owner cannot acquire the original outbox. Auth
  failures pause cloud work while durable training remains usable.
- Atomic acknowledgements and own echoes, monotonic server shadows, unchanged
  pending working branches and original conflict bases. Conflicts/rejections are
  durable attention states retaining local state, remote shadow, root/mutation
  identity and expected revision. No timestamp ordering or automatic field merge.
- Ordered pull pages install changes and the opaque cursor in one SQLite
  transaction. Repeated requests cannot duplicate work; duplicate/gapped positions
  and malformed echoes fail safely. Pull runs before and after pushes.
- Remote tombstones/redactions retire root/child IDs and remove projections,
  observations, drafts, timers and personal outbox bodies. Epoch changes recover
  through bootstrap; old queued commands cannot recreate retired IDs. Verified,
  matching-owner disable responses purge and persist local account disable.
  Missing account initialization and expired credentials do not imply erasure.
- Bounded snapshot download into durable staging, checksum validation, final
  owner/generation/epoch/expiry validation and atomic shadow/cursor activation.
  Pending branches, local-only roots and work logged during download survive.
  Failed activation leaves the previous database and staging usable. Retired IDs
  survive feed pruning. Snapshot slots are per installation; publication/page reads
  retain the guarded server proof.
- Additive PostgreSQL migration `0002_connected_sync` for retention watermark and
  installation slots. Drift schema 2 adds branch basis, delivery/retry metadata and
  staging. The schema 1 upgrade preserves active work, draft, timer and frozen
  requests. The original server migration remains unchanged.
- Minimal domain/UI status, foreground lifecycle scheduling and a local commit
  duration hook. Network requests never hold a SQLite transaction or run on the
  local save path. A stalled-upload test commits another durable set before the
  upload is released. Observer failures cannot reverse local success.
- Debug-only synthetic identity setup and a live harness verify signed JWTs using
  a public key. Mobile receives a user token/API URL, never an admin, service,
  database or signing secret. Forced RLS remains enabled. Synthetic public-key
  verification requires explicit development/test API configuration and cannot
  silently operate in staging/production.

## Authentication and account lifecycle implemented

- Supported `supabase_flutter` **2.18.3** SDK email OTP request, `OtpType.email`
  verification, resend, refresh and local-scope provider sign-out. Six-digit code
  entry is transient/masked and cleared before verification; request, invalid or
  expired code, throttling, provider/network and application-account failures have
  distinct safe feedback. Resend has a 60-second cooldown; provider limits remain
  authoritative. Request responses do not disclose account existence.
- Explicit, awaited `LocalStorage` session persistence and secure PKCE storage
  backed by `flutter_secure_storage` **11.2.0**. iOS requests non-synchronizing,
  device-only unlocked Keychain items; Android uses protected-storage defaults.
  The supported SDK client/Auth API is used directly with automatic refresh
  disabled. The Flutter wrapper's default preferences/URI login and unawaited
  auth-event persistence are not used. This gives the account controller a single
  fenced persistence authority. No custom OTP HTTP protocol is implemented.
- A domain account controller separates protected verified local-owner grants
  from cloud sessions. Cached unlocked ownership restores the existing private
  SQLite database before any refresh/network call. Expired, missing or corrupt
  cloud credentials leave logging, corrections, completion, history, drafts and
  outbox available. Corrupt owner grants/missing owner files fail closed and
  require verified recovery; they never guess a user or create an unverified store.
- Verified sign-in initializes the API account, checks the returned subject,
  opens/unlocks only that owner's UUID-scoped file and persists the owner grant.
  Project/environment namespaces isolate provider projects; API endpoint rotation
  does not strand the owner's file. Fresh accounts have an empty training store,
  a minimal `kg` profile shell and no personal sample workouts. Existing sessions
  can be bootstrapped/resumed; broader workout/routine/catalog authoring is deferred.
- Explicit sign-out immediately pauses synchronization and invalidates asynchronous
  auth completions, persists a locked marker, drains the original coordinator,
  locks SQLite, closes the owner scope and removes session material. Unsynced
  training stays under its original owner. Returning to that verified account
  unlocks it. Account switching replaces the entire provider/navigation scope and
  coordinator; the next account receives no prior drafts, cursor, conflicts,
  snapshot stage, workouts or outbox. Secure-storage failure still locks SQLite
  and reports attention. Offline cloud logout is not claimed to revoke a session.
- Foreground refresh uses the SDK's refresh grant, awaits rotated-token persistence
  and resumes synchronization with original frozen mutations. Transient refresh
  uses bounded exponential scheduling; repeated rejection of a refreshed token
  pauses for reauthentication rather than hammering the provider. Auth epochs and
  serialized operations fence late verification/refresh/grant writes across logout
  and switching. Credentials structurally bind token subject to the SDK user;
  actual signature/ownership authority remains the API.
- `POST /v1/account/initialize` consumes a generated closed empty request/account
  response. JWT verification is followed by a bounded, non-redirecting HTTPS
  current-provider-user check. Identity comes only from the verified subject;
  unconfirmed, anonymous, banned/deleted or rejected identities cannot initialize.
  Within real PostgreSQL, a per-owner advisory lock and the existing owner guard
  serialize absent creation/retirement and enforce active state. Insert-on-conflict
  preserves one application account/profile, existing generation/feed and history.
- Additive migration **0003** adds forced-RLS profiles and an immutable account
  retirement barrier. It retains the existing `owner_state` account authority.
  Retired subjects cannot recreate a purged application account with an old JWT.
  Matching-owner disable applies the accepted local erasure policy, including
  signed-out stores. Ordinary auth errors never trigger deletion. Final backend
  purge, public lifecycle jobs and restored-backup suppression remain open.
- Release configuration rejects fixture flags, synthetic tokens, development
  environment, insecure external URLs and privileged key formats. Only project
  publishable configuration enters the application. SDK auth logs are disabled;
  safe errors suppress echoed OTP/token/headers. Auth HTTP restricts origin, blocks
  redirects and bounds response size; per-operation clients are disposed/closed.
  Android release Internet permission and iOS Keychain entitlements are configured.

The explicit development fixture remains repetition-only with one synthetic
workout template. The real account path never creates that sample. It adds
no routine/catalog breadth, predictions, ML, assistant, health, broker, CRDT or
framework. It has not been deployed.

## Authentication milestone validation (earlier evidence)

Windows 11; Flutter **3.47.7**, Dart **3.13.5**, Python **3.13.14** and Docker
PostgreSQL **17.7**. All data/credentials are synthetic. Flutter/cache/temp reside
on the workspace drive. No hosted Supabase project, SMTP credentials or phone was
used. Validation uses controlled provider responses and signed synthetic ES256
identities. The live API uses `DM_ENVIRONMENT=test`, a public verification key,
synthetic publishable config and an actual restricted PostgreSQL role. No
production secret was used.

| Check | Observed result |
| --- | --- |
| Flutter analysis | No issues |
| Ordinary Flutter suite | **122 passed, 9 explicitly skipped live cases**; preserves the previous 80 and adds 25 lifecycle, 14 SDK/storage-boundary and 3 widget cases |
| Connected Flutter suite | **9 passed**, actual HTTP, verified ES256 JWT, real SQLite and restricted PostgreSQL; includes account initialization and A → B → A |
| Distinct Flutter cases exercised | **131 passed** across the two runs |
| Python with `DM_RUN_CONNECTED=1` | **70 passed, 0 skipped**; includes the runner asserting all nine live Flutter cases pass |
| Real PostgreSQL | **40 Python integration cases**: previous 19 plus 21 account/auth cases, including live runner, under `NOSUPERUSER NOBYPASSRLS`; CAS, receipts, rollback, forced RLS, tenant reset, locks, concurrent commits, erasure and snapshot invalidation |
| SQLite | Previous **27 file-backed sync recovery cases** retained, plus **21 file-backed account lifecycle cases** for ownership/restart/locking; four other lifecycle cases cover OTP/config/missing-file gates, while SDK timing and native-channel storage adapters are controlled separately |
| Ruff | API/tooling lint and format pass |
| Strict mypy | **11 source/script files**, no issues |
| Dart formatting | **39 files**, zero changes in final check |
| Generated output | Checked OpenAPI, DTOs/limits and Drift regeneration verified reproducible |
| Documentation/whitespace | **26 Markdown files, 238 local links, 5 JSON examples**; UTF-8/newlines/fences and Git whitespace pass |

Commands are in [README.md](../README.md). The live runner fails if requested but
Flutter is unavailable. Ordinary tests' nine skips do not replace the separate
passing live run. PostgreSQL tests never use SQLite/fakes as evidence of server
transactions, RLS or locks. Transport fakes inject timing/failures around real
repositories; loopback HTTP tests cover status, malformed bodies, redirects and
timeouts. The SDK tests execute supported SDK methods against a controlled HTTP
adapter; native method-channel tests verify secure-storage routing/options, not
Keychain/Keystore hardware protection. Provider-user checks are controlled in the
API tests while actual signed-token verification, API, transactions, locks and
forced RLS use real PostgreSQL. No fake substitutes for those database guarantees.

During the final run Docker Desktop was unavailable: **30 Python cases passed and
40 database cases errored during connection setup**. Docker was restarted and the
dedicated service was checked healthy before the complete suite was rerun. That
failed environment attempt is not counted as database evidence. Flutter test runs
and the API harness's nested Flutter run remain serial to avoid a Windows native
SQLite DLL lock. Widget teardown uses the runner's real async context for domain
cleanup, without changing application behavior.

CI installs Flutter in the PostgreSQL job, runs connected tests and checks
transport generation. Remote CI had not run at that earlier milestone. The subsequent native milestone
below installs Android tooling. iOS requires macOS; desktop/emulator results do
not establish phone process-death behavior or **p95 ≤100 ms**.

## Adversarial faults and restart evidence

| Boundary | Deliberate fault and verified result |
| --- | --- |
| Before local outbox creation | SQLite insert trigger aborts; projection/outbox roll back; reopen contains no acknowledged workout |
| After local commit | File reopen restores pending work, observation, timer and draft |
| Before HTTP send | Frozen identity/body retained; offline start/retries leave training usable |
| While sending | Stalled upload permits another local commit; disconnect, timeout and flapping preserve queue |
| Server commit before response | Actual accepted HTTP command with injected lost response; exact replay/own echo avoid duplicate acceptance |
| Response before local acknowledgement | Acknowledgement trigger aborts metadata; reopen retains frozen request and recovers receipt/echo |
| During pull installation | SQLite transaction fault leaves shadow, branch and cursor unchanged |
| Page changes before cursor write | Cursor trigger aborts entire page; reopen confirms old cursor, no partial shadow/ack, successful retry |
| During bootstrap staging | Page insert aborts; reopen retains manifest and no partial page; retry succeeds |
| During bootstrap activation | Cursor trigger aborts; reopen preserves work/staging; retry activates atomically |
| During deletion | Delete trigger aborts retirement/purge; reopen retains payload without partial retirement; retry purges |
| During conflict creation | Conflict trigger aborts shadow/branch/cursor; reopen retains original local values/cursor |

Other cases cover pending successors, late acknowledgements after external state,
clean roots, stale two-device edits, own echoes before/after acknowledgement,
repeated pages, commits between pages, terminal rejection without other-root
blockage, mixed/large packing, retired-ID replay, snapshot checksum/expiry/
generation/capacity bounds, child collisions, partial download/restart, logging
while staging, disable/restart, invalid authentication and unsupported/malformed
contracts.

The earlier synchronization cases use transaction faults and graceful reopening.
The native milestone below adds actual Windows process kills and real SQLite
capacity failures. Phone kills, flash/power-loss behavior and interrupted native
upgrades remain unqualified.

## Defects found and fixed

Self-review and independent read-only adversarial review identified and fixed:

1. Non-JSON proxy 5xx/429 errors looked like permanent malformed data.
2. Unbound/wrong-owner disable responses could purge the original owner's data;
   credentials are now fixed per cycle and disable requires matching verified owner.
3. Missing account initialization was conflated with permanent account disable.
4. Snapshot defaults changed checksum bytes; pages retain exact stored shape and
   only a separate domain copy is normalized.
5. Legacy acknowledgement logic failed to clear resolved branch bases; entry points
   now share the installer.
6. Snapshot child/root collisions and reparented sets could corrupt another branch;
   atomic installation rejects identity collisions.
7. Generic payload parsing missed command-specific fields; generated schemas now
   run before local acceptance/send, preventing stranded accepted commands.
8. Valid omitted defaults and supplementary Unicode names blocked feed reduction;
   normalization/code-point bounds match the server. Blank correction reasons are
   rejected consistently.
9. Duplicate feed positions were skipped; they now reject the page. Snapshot
   cursors beyond committed position/below retention fail safely.
10. Dart normalized impossible dates; actual UTC calendar validation rejects them.
    Server snapshot expiry now emits the protocol's `Z` representation.
11. Snapshot capacity was checked too late; server accumulation/local staging now
    enforce bounded storage before activation.
12. Observer errors could misreport durable success; they are isolated. Disabled
    UI reports erasure accurately, including restart. Foreground cancellation
    cannot claim incomplete bootstrap is synchronized; close drains in-flight work.

No finding justified weakening an invariant or changing an accepted ADR.

Authentication adversarial review additionally found and fixed:

1. A cached cloud session could have bypassed a prior explicit local lock. Restore
   now requires a protected grant and an existing unlocked, matching owner file;
   cached sessions never unlock SQLite. Permanently disabled stores refuse unlock.
2. Sign-out during secure owner-grant persistence could leave an unlocked marker.
   Epoch checks now lock the selected SQLite store and persist a locked marker
   before releasing the canceled selection. Late OTP/refresh completions cannot
   grant access or populate the next account.
3. Protected-storage failure during logout could have left local access enabled.
   The independent SQLite lock now persists even if credential storage fails;
   the UI reports attention instead of successful credential removal.
4. Refresh output could contain an A user object with a B token. Session subject
   binding rejects it before persistence; verified API owner checks remain in force.
5. Reauthentication could join a still-running old-token cycle without starting
   recovery. A forced follow-up now runs with refreshed credentials and the
   original frozen outbox identity/body, including after a committed lost response.
6. Repeated fresh-token rejection could hammer refresh. Foreground backoff and a
   refresh guard now pause for attention; foreground flapping cannot skip backoff.
7. Remote disable during initialization of an already signed-out account could
   leave its locked local payload unprocessed. Verified, matching-owner disable
   now erases that existing store according to the accepted policy, never a
   different account. Retirement survives account-row removal under forced RLS.
8. Auth cancellation during bootstrap/queue preparation could start another HTTP
   operation. Authorization/close checks now fence each next request, retain
   staged pages/local work and allow restart/reauthentication to resume.
9. SDK default PKCE/preferences and exception logging were unsuitable for secrets.
   Both persistence paths explicitly use protected storage; SDK loggers are
   disabled and errors sanitized. Auth transport rejects redirects, wrong origins
   and oversized responses, and disposes timed-out clients.
10. Slow OTP requests left the send button enabled. Explicit requesting state now
    shows progress and disables duplicate submission; a delayed-provider widget
    case verifies it without logging code or token material.
11. Secure logout failure could skip provider logout and race a remote-disable
    transition. Cleanup now drains synchronization before the SQLite lock, still
    attempts provider logout, and reports persistence failures accurately. Remote
    deactivation cancels refresh timers/queued callbacks; failure cannot silently
    leave an authenticated UI state. A file-restart test covers secure storage
    failing during authoritative disable. Sign-out remains busy until its bounded
    provider attempt finishes, so a late logout cannot overwrite new OTP UI state.

Fault tests include lost initialization responses, verified identity before local
store failure, token expiry after server commit/before pull, refresh persistence
failure, refresh failure during active logging, pending-work sign-out, switch
during coordinator wakeup, stale verification/refresh/grant completion, missing or
corrupt session/owner state, account disable under lock, and release dev-auth
misconfiguration. Real SQLite files and PostgreSQL transactions provide persistence
and security evidence; simulated provider failures do not qualify hosted delivery.

## Foundation limitations and later release work

The [Phase 0 evidence reconciliation](PHASE0_EVIDENCE.md) maps these limitations
to the authoritative roadmap. Interactive conflict resolution, public export/
deletion jobs and full production capacity/operations remain Phase 1 release
work, not additional authority to implement Phase 1 during this milestone.
Foundation safety tests do not waive those later requirements.

1. Conflicts/rejections preserve both branches and display attention. Interactive
   comparison/resolution remains open; nothing is silently discarded or merged.
2. Foreground sync only. OTP/refresh/storage adapters and account initialization/
   switching are implemented with desktop evidence. Real Supabase/custom SMTP,
   provider rate/revocation behavior, urgent JWKS rotation, native protected storage
   and recent-auth privacy remain unqualified. Existing bearer JWTs can remain valid
   until expiry after provider sign-out; app disable is separately enforced under
   lock. Provider refresh rotation followed by process death before durable storage
   may require reauthentication; locally cached training remains available.
3. Account disable remains an internal lifecycle primitive with client erasure
   handling. Public erasure/export jobs, final backend account payload purge,
   restore-time suppression, deployment grants and abuse budgets remain open.
4. Feed pruning is implemented/tested; scheduled retention/cleanup remain open.
   Ten-year histories, maximum-volume snapshots/activation latency, incremental
   exercise commands and full capacity qualification remain open. Capacity failure
   retains usable local state and reports attention.
5. Unsigned iOS builds are now qualified by hosted macOS compilation below.
   Qualify physical Android/iPhone storage and backup/privacy,
   keyboard/back, VoiceOver/TalkBack, hard phone kills, full physical storage/power
   loss and interrupted migration. Native configuration and Windows/emulator
   results below only close their own narrower checks. No prior publicly shipped
   local schema exists.
6. Qualify the implemented monotonic timer on physical devices across suspension,
   reboot and clock changes; its countdown estimate is not measured actual rest.
   Measure profile/release
   durable-save p95 on physical phones with sync load. Snapshot activation is atomic
   but large-history transaction latency is unqualified; network independence is
   not the device performance gate.

**No ADR changed. Phase 0 is not complete.**

## Native qualification milestone — 2026-10-13

The user confirmed **no physical Android phone, iPhone, Mac host, hosted Supabase
project or real test inbox** is available. Work proceeds on Windows without
claiming those gates. Procedures and native entrypoints are in
[DEVICE_QUALIFICATION.md](DEVICE_QUALIFICATION.md).

### Implemented and reviewed

- Native clock bridge: Android elapsed realtime includes suspension and combines
  boot count with an installation nonce in no-backup storage. iOS uses continuous
  time with process-scoped continuity. Persisted anchors survive database reopen;
  unknown continuity/reboot uses a clamped wall estimate marked approximate.
  Detected clock divergence is sticky. No notification or tick establishes truth.
- Additive Drift schema **3**, with real schema 1/2 upgrade coverage preserving
  drafts, active work and frozen requests. Timer sampling has a **20 ms** native
  timeout and malformed/unsupported clock fallback; no auth/HTTP call joins set
  saving. Foreground timer display reloads on resume and tolerates closed owners.
- Android cloud-backup/device-transfer exclusion covers nine credential/device
  storage domains; `allowBackup=false` remains. iOS creates/checks a canonical
  application-support directory with backup exclusion before SQLite opens, rejects
  outside paths and applies file protection. Swift is statically reviewed only.
  SQLite remains OS-private, not independently encrypted.
- Predictive-back manifest configuration, large-text/reduced-motion/keyboard and
  Android/iOS navigation widget checks. Native screen-reader/back gestures remain
  hardware gates. Startup errors distinguish unavailable local storage from
  missing auth configuration; the startup theme uses its actual inherited theme.
- Dedicated synthetic native storage seed/recover/cleanup entrypoint, real
  protected-storage adapter/session restoration, frozen checksum and SQLite draft/
  outbox/integrity checks. Qualification Android package uses `.qualification`,
  separate from the normal application. No provider credential enters its report.
- Durable-save benchmark measures the complete `WorkoutController.record` Future,
  including validation/read, native clock, durable SQL and projection refresh.
  Declares 100 history roots, 32 warmups, 200 samples; retains every raw sample and
  uses nearest-rank `ceil(p*n)`. Device/native-source/build metadata, profile/release,
  physical hardware and zero failures are required for a passing claim.
- Android release output is intentionally unsigned pending operator signing,
  rather than silently debug-signed. CI adds native static guards, qualification
  source formatting, debug/profile/release compilation and manual dispatch. iOS
  unsigned build jobs are prepared but have not run remotely.

### Real database and fault evidence

- Three **hard Windows OS process kills** before, during and after local commit.
  A separate Dart process runs real file-backed Drift/WAL `synchronous=FULL`;
  recovery verifies observations, original frozen request, outbox, draft, integrity
  and foreign keys. The interrupted transaction either fully survives or rolls
  back. These are not graceful close tests or phone power-loss evidence.
- Actual **SQLITE_FULL (13)** generated with a pager quota and allocation trigger
  inside the real save transaction. No local acknowledgement fires; the preceding
  observation, pending queue and durable next-set draft survive reopen.
- Real file-backed monotonic anchor/clock-uncertainty persistence and schema 2→3
  upgrade. Previous 27 sync recovery and 21 auth file-backed cases remain covered.
- Controlled timer suspension, wall-clock ±1 hour, timezone, reboot/unknown
  continuity, legacy anchors, malformed/stalled bridge and percentile guard tests.
  Clock/provider injection is explicitly separated from native hardware behavior.

### Native build/runtime evidence boundary

Windows 11 **10.0.26300.9550**, Flutter **3.47.7** / Dart **3.13.5**, Python
**3.13.14**, PostgreSQL **17.7**. Ignored task-local tooling: Temurin
**21.0.12.1+1**, Android command-line tools **15859902**, platforms **36/35**,
build-tools **36.0.0**, NDK **28.2.13676358**, CMake **3.22.1**, Gradle **9.3.1**.
Official JDK/command-tool downloads were checksum-verified. No global SDK settings
or production secrets were changed. SDK XML compatibility warnings were observed.

Android **debug** compilation succeeded (cold `assembleDebug`: 1828.0 s), followed
by successful **profile** compilation (`assembleProfile`: 580.3 s). The normal
debug APK installed/launched on Android **16/API 36**, x86_64 Google APIs
`sdk_gphone64_x86_64`, WHPX/software graphics emulator. The actual unconfigured
application displayed its auth-configuration boundary and offered no unverified
training. Package inspection showed no `ALLOW_BACKUP` flag. This is emulator
compilation/startup evidence, not physical storage/OTP qualification.

Archived interim debug SHA-256:
`FD2408BA79D39C51C4B447657A972FB6902C020AFE92ECAB14AD2A0CBB3BF13B`;
profile:
`98198A9CF2D138EEC729C5F9956EEBD21B02B2916995A508CFC6C57989F8D951`.
These artifacts precede closing clock-parser/theme fixes; final checks and any
additional native results are recorded below. Large cold-build times are build
times, never local-save latency measurements.

### Closing Windows validation (checkpoint `b8968ca`)

| Check | Observed result |
| --- | --- |
| Ordinary Flutter | **143 passed, 9 live cases explicitly skipped**, 192 s; 21 additional ordinary cases beyond the auth milestone |
| Live Flutter HTTP/PostgreSQL | **9 passed** separately; **152 distinct Flutter cases** across both runs |
| Full Python/live runner | **70 passed, 0 skipped**, 61.39 s; includes **40 PostgreSQL integration cases** under restricted runtime RLS |
| New SQLite/native preparation | **3 real Windows hard-kill cases**, **3 additional file-backed timer/capacity/migration cases**, controlled timer/parser/benchmark guards and **3 platform widget cases** |
| Flutter analysis | No issues; native source compilation is a separate check |
| Formatting/lint/type checking | **49 Dart files**, **27 Python files**; Ruff clean, strict mypy clean across **11 files** |
| Generated artifacts | OpenAPI, two Dart transport outputs and Drift schema-3 output: **all four match SHA-256 after regeneration** |
| Static native guards | Android backup/back/network, iOS backup/Keychain/clock and release signing boundary pass; no hardware protection claim |

The resumed host had severe memory pressure. Only task-owned Gradle/emulator
processes were stopped; unrelated applications/containers were preserved. Gradle
now uses a bounded 2 GiB heap and two workers rather than the template's 8 GiB
heap. Interrupted release/emulator attempts are not passing evidence. The release
build and native recovery harness are still being checked at this checkpoint.
One release attempt failed because the agent ran dependency refresh/regeneration
concurrently with native compilation, rewriting the generated registrant with a
dev-only integration-test plugin. The pinned SDK correctly filters that plugin
for release when run serially. Validation commands now run sequentially in this
checkout; no production dependency or generated file is patched to hide it.

### Adversarial defects corrected

1. Wall-only ticking could produce misleading countdowns after clock changes;
   native elapsed anchors now project time independently of UI ticks.
2. Boot count alone could match a different restored Android installation; a
   no-backup installation nonce prevents assuming continuity across that case.
3. iOS private SQLite lacked backup exclusion; the guarded native setup now fails
   closed before opening storage if exclusion cannot be established.
4. Release configuration silently inherited debug signing; the artifact now
   requires explicit operator signing for installation/distribution.
5. A stalled or non-map native clock response could delay/fail local recording;
   bounded type-checked wall fallback preserves logging.
6. Timer reads could finish after owner closure; the display guards concurrent
   reads and handles closure/storage failure without claiming a saved set failed.
7. Inner SQL timing underestimated caller acknowledgement; the benchmark now
   includes the complete caller path and rejects missing metadata/negative samples.

### Explicitly open hardware/provider gates

Physical Android/iPhone qualification, signed iOS installation, actual Keychain/
hardware protected storage, backup/restore/device transfer, VoiceOver/TalkBack,
phone process kills/reboot/suspension/token refresh, full-device disk/power faults,
native keyboard/navigation and physical p95 remain open. **Physical sample count:
0; no physical p95 result.** Hosted Supabase OTP, custom SMTP delivery, publishable
project configuration and controlled-inbox testing remain open. Controlled SDK
tests are not SMTP evidence. Remote main remains at the planning revision;
the qualification branch now has actual passing CI evidence below. Phase 1
remains unstarted. No ADR changed.

### Published checkpoint and actual remote CI

Checkpoint **`b8968ca87dc7412f5a2f6cf3cb845dfb8a00652f`** commits the accumulated
Phase 0 foundation, connected sync, authentication and qualification work. It is
unsigned because the configured signing key requires an unavailable passphrase;
Git signing configuration was not changed. Credential scan found no staged private
keys or privileged provider/GitHub secrets. Generated Kotlin session/cache files
are excluded. No application deployment occurred.

Published branch: `phase0-qualification-2026-10-13`. Actual
[GitHub Actions run 38438667550](https://github.com/bluxo1/Daily-Motion/actions/runs/38438667550)
**passed all three jobs** on that exact checkpoint:

- Ubuntu **24.04** API: **70 Python passed**, 14.78 s, including restricted-role
  PostgreSQL and the live nine-case Flutter HTTP harness; Ruff, strict mypy,
  OpenAPI/transport reproduction, documentation and native static checks pass.
- Ubuntu **24.04** mobile: **143 passed, 9 live skipped**, clean analysis/format,
  reproducible Drift output; Android **debug/profile/release** builds pass.
- Hosted **macOS 26.6.2 (25G83), arm64** mobile: **143 passed, 9 live skipped**,
  clean analysis/format and reproducible Drift; unsigned iOS **debug and release**
  compilation pass. This closes native Swift compilation, not signed installation,
  Keychain/hardware storage, navigation/screen-reader or actual iPhone behavior.

Final serial Windows Android release build also passed (`assembleRelease`: 380.6 s),
**61,512,640 bytes**, SHA-256
`75F1B481840447AC732AE3C134F729B0EF8962801F73BBA4B4BA02ABB5E475C0`.
`apksigner verify` correctly rejects the unsigned artifact. Compilation therefore
does not claim release signing, installation or distribution readiness. The
agent-caused concurrent registrant failure is retained above as a failed attempt;
it is not counted as success.

### Native recovery and performance review follow-up

The real native protected-storage/SQLite entrypoint **passed seed and recover**
on the Android **16/API 36 x86_64 emulator**, debug build, package
`com.dailymotion.training.daily_motion.qualification`. After acknowledged seed,
an external `adb shell am force-stop` at **2026-10-13 17:53:21 UTC** cleared its
observed process ID. Recover used a replacement APK with the same signing identity
and preserved application data. It required the existing database and restored
the recorded set, draft, two pending commands, original frozen checksum and
synthetic session through the actual Android protected-storage plugin; SQLite
integrity was `ok`. Native metadata reports `physical=false`, `backup_allowed=false`.
This proves emulator behavior, not hardware-backed protection or actual restore/
transfer. Backup Manager was disabled; no backup restoration pass is claimed.

The initial high-resolution emulator exhausted available host memory and an ADB
disconnect prevented app launch. It was retried with a dedicated **480×800**
virtual display, **1024 MiB** guest RAM and two virtual cores; no personal device
or unrelated process was changed. Failed/incomplete attempts remain separate.

The first debug benchmark was intentionally interrupted under memory pressure;
it produced no complete 200-sample report and is not counted as a passing run.
Review identified a real read-cost problem: set acknowledgement reloaded history
through a series of queries for each session/exercise, and new-workout validation
loaded all historical exercise/set graphs merely to check active status.
The repository now loads a whole consistent projection with **three table reads**
plus the unchanged owner/account guard, and active-session validation reads only
session metadata under the existing transaction. Session/exercise/set ordering,
working sequences, conflicts and frozen transport are unchanged.

A new real file-backed **100-root** regression (including a multi-exercise root)
compares bulk projections to individual reads, bounds database round trips,
checks active-session exclusion, pending count, sign-out lock/reverified unlock,
frozen request equality and integrity. Its loaded first run failed while the
focused run passed; the sizable file fixture now has an explicit two-minute test
budget. The preserved final full run **passed 144, skipped 9 live**, 131 s. This
test budget and desktop/emulator durations are not physical set-save measurements.
The current formatter checks **50 Dart files**. Further live/native results are
recorded when completed; the physical sample count remains **zero**.

After the read-cost fix, the complete live/API rerun **passed 70 Python, 0 skipped**
in **43.19 s**, including the **40 real PostgreSQL cases and all 9 live Flutter
HTTP cases**. Thus **153 distinct Flutter cases** pass across ordinary/live runs.
File-backed recovery coverage adds the 100-root case to the prior 27 sync, 21
account, three timer/capacity/migration and three hard-kill cases (**55 cases**
in that named recovery/account/fault subset). All four generated outputs remain
unchanged by this read-only optimization. No protocol, owner policy or ADR changed.

### Final qualification results — closing 2026-10-14 IST

Read-cost fix **`a27dfdde77a408008efe1a081c5b4e58450fdce5`** also
[passed actual remote CI, run 38445714228](https://github.com/bluxo1/Daily-Motion/actions/runs/38445714228):
all three jobs succeeded. Linux and macOS each report **144 passed, 9 skipped**,
**50 Dart files formatted with zero changes**, clean analysis and reproducible
Drift. Linux Android debug/profile/release and hosted Mac unsigned iOS debug/
release compile successfully. API reports **70 passed**, 17.81 s, with the real
restricted-role PostgreSQL/live HTTP harness, Ruff, strict mypy, generated contracts,
static native guards and documentation checks passing. Latest local full/live
results remain **144 + 9 Flutter**, **70 Python** (43.19 s), **40 PostgreSQL**.
Remote tests are repeated validations, not additional distinct cases.

The rebuilt debug emulator benchmark on **that exact revision** completed:
**100 history roots, 32 warmups, 200 measured full caller acknowledgements,
0 failures**, 165 s total harness runtime including setup. Native metadata is
Android **16/API 36**, `sdk_gphone64_x86_64`, `physical=false`, `backup_allowed=false`.
Every raw measured/warmup sample and nearest-rank percentile method is preserved
in [the safe machine-readable evidence](evidence/phase0-windows-native-2026-10-13.json).
That file also preserves native seed/recover, external force-stop and APK hashes.
Its filename uses the observed **UTC** date; closing local date is October 14.

`physical_performance_evidence=false` and `target_met=false` correctly exclude
this debug/emulator workload from the phone target. **Physical sample count 0;
physical p95 unavailable.** No phone <=100 ms claim or improvement ratio inferred
from the incomplete pre-fix run. Three native harness invocations passed (seed,
recover, benchmark); each reports one declared case plus an integration-binding
teardown check (`+2`). Native storage and benchmark source revisions are recorded
separately, rather than relabelling the earlier storage binaries as the fix.

Final self-review checks ownership/file boundaries, stale auth events, frozen
retry/receipt semantics, transaction/cursor boundaries, retirement, bootstrap
preservation, logging, native storage/configuration and benchmark provenance.
Confirmed timer/backup/signing/read-cost defects are fixed; physical lifecycle,
backup/transfer, Keychain/protected hardware, phone storage/power failures,
accessibility, signed installs and hosted SMTP/provider gates remain open.
No Phase 1, deployment or ADR change. The task emulator was stopped after evidence
collection; unrelated applications and containers were preserved.
Closing documentation validation: **27 Markdown files, 250 local links, 5 JSON
examples**; native static guards, machine-readable evidence parsing and Git
whitespace checks pass. The final follow-up changes evidence/docs only; native CI
success above belongs to the exact code revision `a27dfdd`.

## Phase 0 evidence audit and remaining local work — 2026-10-14 IST

Audited the clean `phase0-qualification-2026-10-13` branch at `e888571` against
README, phases, roadmap, testing, implementation, chronological memory and actual
source/tests/evidence. The [evidence matrix](PHASE0_EVIDENCE.md) records each
authoritative Phase 0 requirement. Five previously unchecked foundation items
were already proven: internal design/editor, Drift recovery/ownership, PostgreSQL
CAS/receipts/feed/bootstrap, disable/redaction/migration and contracts/fixtures.
They are now checked at their actual evidence level; separate physical acceptance
is still unchecked. The migration row now correctly names schema 1→3 and 2→3.

### Work completed

- Added an executable **isolated routine interaction prototype** at
  `apps/mobile/lib/qualification/routine_prototype.dart`. It edits a bounded
  planned set/rep-range/rest prescription, previews immutable content versions
  and preserves the editor on back. It has no owner, database, outbox, credentials
  or HTTP client, records no performed sets and is disabled in release builds.
  Production routine/catalog persistence remains Phase 1. Existing onboarding,
  active logging and history complete the Phase 0 prototype set.
- Added four Dart cases for immutable prescriptions, invalid/blank inputs,
  320px/200% text with keyboard/back and accessible tap targets, and actual
  light/dark text/action contrast pairs. This is automated desktop interaction
  evidence, not hardware screen-reader qualification.
- Added a CI credential guard over versioned/nonignored source. It rejects
  private keys, non-publishable JWTs and common privileged credential formats;
  only safe path/line/category reaches output. Five Python cases exercise those
  attacks/client-safe keys and settings representation. Database URLs now join
  signing/key material in fields excluded from `Settings` representation.
- Removed the deployment assumption that the supplied API database credentials
  must be restricted. Every tenant transaction checks the actual role and
  training table metadata before setting owner context: superuser/BYPASSRLS,
  membership in table-owner roles or missing enabled/forced RLS returns sanitized
  `503 service_not_configured`. Four **real PostgreSQL** cases use the administrator,
  grant/revoke owner-role membership and remove/restore RLS; corrected settings
  resume use and pooled tenant context stays clear. No credential or owner label
  is accepted from a request to bypass this check.
- Added [operator qualification handoff](../infra/QUALIFICATION.md) for actual
  region, backup, processor, project, SMTP, signing and named review assignments.
  Those are external dependencies, not evidence inferred from local configuration.
  Documentation validation now also covers the new infrastructure Markdown.
- Corrected scope ambiguity in prior remaining-work lists: full public routine
  features, conflict-resolution UI, export/deletion jobs and complete production
  retention/restore/capacity qualification remain **Phase 1 release work** under
  the unchanged roadmap. Their Phase 0 safety primitives are tested. No public
  release requirement, physical gate or accepted invariant was weakened.

### Exact local validation

Environment remains Windows 11 10.0.26300.9550, Flutter **3.47.7/Dart 3.13.5**,
Python **3.13.14** and real Docker PostgreSQL **17.7** in the dedicated
`daily_motion_test` database. Tests use a separate `NOSUPERUSER NOBYPASSRLS` runtime
role; only scoped setup/attack tests hold administrator authority. Other user
applications/containers and the main branch were preserved.

| Check | Actual result |
|---|---|
| Full ordinary Flutter suite | **148 passed, 9 live cases skipped**, 90 s; four new prototype/design cases, previous 144 retained |
| Separate live Flutter HTTP suite | **9 passed**, invoked by the full Python harness; real FastAPI/PostgreSQL, synthetic signed test identity |
| Distinct Flutter cases | **157 passed** across ordinary/live runs; repeated remote validation does not add cases |
| Full Python suite | **79 passed, 0 skipped**, **31.48 s**; previous 70 plus five credential/config and four runtime-guard cases |
| Real PostgreSQL coverage | **44 cases**, independently counted by fixture collection; prior 40 retained plus four role/RLS attacks |
| Named file-backed recovery subset | **55 cases** retained, including **3 hard Windows process kills**, timer/pager-full/migrations and account/sync recovery; no physical evidence inferred |
| Dart format / Flutter analyze | **52 files, 0 changes**; **no issues**, 20.5 s |
| Python format / Ruff / strict mypy | **30 files formatted**, lint clean; **11 source files**, no type issues |
| Generated artifacts | All **4** outputs reproduce byte-for-byte: checked OpenAPI, Dart DTOs/limits and Drift schema; protocol version/fixtures unchanged |
| Native guards / credential guard | Static backup/back/Keychain/clock/signing checks pass; **195 source files, 0 credential findings** |

Logs are retained locally in ignored `.tools/phase0-reconcile-flutter.log` and
`.tools/phase0-reconcile-python.log`. The live two-device tests emit Drift's debug
multiple-instance advisory: each device explicitly uses a **different** real
`NativeDatabase.memory()` executor, so they do not share a database connection.
The restart cases separately use real file-backed SQLite. This advisory is not
suppressed to hide persistence behavior.

### Adversarial review and remaining blockers

Confirmed and fixed: stale unchecked evidence rows; misclassified later-phase
release work; missing routine interaction prototype; no durable CI credential
scan; privileged/RLS-misconfigured API connections depended on operator discipline;
database credentials could appear in settings representation. New widget test
setup initially needed an explicit outer scrollable, scrolling to lazy preview
content and semantics disposal before end-of-test verification; the corrected
tests pass. The production implementation was not changed to accommodate test
timing. Review retained owner/switch/late-callback boundaries, immutable retries,
branch/conflict/echo safety, atomic cursors/bootstrap, retirement/disable,
release-auth guards and benchmark provenance; the complete existing fault suites
pass. No new data-loss, crossover, duplicate or resurrection defect was found.

Only external **Phase 0** acceptance/dependencies remain: physical Android/iPhone
and signed installations; hardware Keychain/protected-storage and backup/transfer;
VoiceOver/TalkBack/native navigation/keyboard and accessibility; phone process,
reboot/suspension/clock/storage/power behavior and physical profile/release p95;
real hosted Supabase/custom SMTP/inbox/publishable-project delivery/rate/revocation;
managed region/backup/processor settings, developer/store/signing credentials and
named operator/privacy/security review appointments. The repository owner is
accountable for commissioning that review; no appointment or approval is invented.
Physical sample count remains **0**, real hosted-provider qualification **0**.

Previous actual remote CI remains green on `a27dfdd`; new remote evidence is
recorded separately after committing this change. The new CI also compiles the
isolated routine prototype as an Android debug target. **No ADR changed. Phase 0
is not complete; Phase 1 has not started.**

### Remote audit checkpoint and runner recovery

Committed/pushed the local audit as **`545a6ec53048b166172f04916c0533ce453b27c8`**.
[Actual run 38451919078](https://github.com/bluxo1/Daily-Motion/actions/runs/38451919078)
passed API and Linux mobile: **79 Python**, 18.15 s; **148 Flutter passed, 9 skipped**,
clean analysis/52-file formatting, all four generated outputs unchanged, **29
Markdown/273 local links/5 JSON**, **195 source files/0 credential findings**.
Android debug/profile/release and the separate routine-prototype debug target
compiled. The macOS job executed **zero steps** and was cancelled after 15 minutes
because GitHub could not allocate a hosted ARM64 runner; the overall run is
therefore **not green**. Prior unsigned iOS proof on `a27dfdd` remains historical
evidence, not a successful new macOS run.

The runner annotation also identified deprecated actions. CI now pins supported
official releases to full commit SHAs (checkout v7.0.1, setup-java v6.0.1,
setup-uv v10.3.0, Flutter composite v2), disables checkout credential persistence,
pins Ubuntu 24.04 and uses the documented supported `macos-15-intel` image with
explicit Xcode 26.3. Flutter/Python/Java/database versions and check scope are
unchanged. Actual replacement-run results follow; runner substitution is compile
infrastructure, never signed iPhone or Keychain qualification.

Completed the additional non-provider-blocked **public feasibility desk review**
in [the operator handoff](../infra/QUALIFICATION.md): verified published Mumbai
region availability, database-backup/PITR and object/custom-role recovery limits,
and current processor-review sources. No live project, backup restoration,
agreement approval, SMTP delivery or legal compliance is claimed. Actual operator
settings/contracts and reviewer appointments remain external. No ADR changed.

### Closing audit evidence — 2026-10-14, 01:17 IST

[Replacement CI run 38454815935](https://github.com/bluxo1/Daily-Motion/actions/runs/38454815935)
**passed all three jobs** on exact source
**`46f5d5a35305c8da51180b195e77b6b6a8df8077`**. Actual evidence:

- API on Ubuntu 24.04: **79 passed**, **18.49 s**, including the real restricted-role
  PostgreSQL/live Flutter harness. Ruff/30-file formatting, strict mypy/11 files,
  generated contracts, native guards and credential guard **195 files/0 findings**
  pass. Source documentation: **29 Markdown files, 275 local links, 5 JSON**.
- Linux mobile: **148 passed, 9 live skipped**, **52 Dart files/0 changes**, clean
  analysis and reproducible Drift. Android app **debug/profile/release** and the
  separate synthetic routine-prototype **debug target** compile successfully.
- Hosted **macOS 15.7.9 (24G830), Intel/x64**, explicitly selected **Xcode 26.3**:
  **148 passed, 9 live skipped**, **52 Dart files/0 changes**, clean analysis and
  reproducible Drift. Unsigned iOS **debug/release** compile successfully; Xcode
  reports **217.3 s / 134.2 s**. These are compiler durations, not set-save latency.

Thus local results remain **157 distinct Flutter cases**, **79 Python**, **44 real
PostgreSQL**, **55 named file-backed cases including 3 hard Windows kills**.
Remote runs repeat those tests rather than increasing distinct counts. All **4**
checked generated artifacts reproduce. Ignored API/Linux/macOS logs are retained
as `.tools/phase0-reconcile-*-recovery-ci.log`. The failed first Mac allocation is
preserved above; the supported Intel runner resolved the CI capacity issue without
weakening checks or adding signing/provider credentials.

All software work within the audited Phase 0 scope is implemented and tested in
the available environments. Only the external acceptance/dependencies listed
above remain; full public feature/operations qualification stays in Phase 1.
**Physical samples 0; real hosted Supabase/SMTP qualifications 0; no physical p95
claim. No ADR changed. Phase 0 is in progress; Phase 1 has not started.**

This closing follow-up changes documentation only. Native/test CI evidence belongs
to `46f5d5a`; final documentation validation is recorded after these edits.

Final follow-up checks: **29 Markdown files, 275 local links, 5 JSON examples**;
native static guards and **195-source-file credential guard/0 findings** pass.
Git whitespace checks are clean. No code, contract, fixture or generated artifact
changed after the successful source CI.

## Supabase + Render staging preparation — 2026-10-14 IST

User explicitly requested a real **staging** Supabase database/Auth project and
Render FastAPI service, without starting Phase 1. Inspected the clean branch at
`dacc803` and README/evidence/memory/phases/security/API/sync documents first.
There is no Supabase/Render process credential or CLI session. The available
automation browser opened **both providers at sign-in**. User-owned login/workspace,
project and inbox configuration is therefore the actual boundary; **no hosted
resource was created or changed**. No production/workout data was used.

### Implemented preparation

- [Render blueprint](../render.yaml): staging-only named service, Singapore,
  free compute, qualification branch, manual deployment, pinned Python **3.13.14** /
  uv **0.13.0**, frozen production dependencies and Uvicorn without access logs.
  Render prompts for values and generates the stable synchronization signing key;
  administrator/migration credentials are absent from the runtime blueprint.
  Validated against the actual public **official Render JSON schema** with
  temporary local tooling. That proves syntax, not provider deployment.
- [Staging runbook](../infra/staging/README.md), six-digit OTP email template and
  four-field client-safe Flutter configuration example. Instructions separate
  default provider delivery from custom SMTP, identify authorized default-delivery
  recipients/limits, preserve email confirmation and asymmetric signing, and keep
  the training schema unexposed through the Data API. No actual URL or publishable
  key was invented. Browser snapshots and real `.env.*` files are now ignored.
- Explicit operator-only `scripts/provision_staging.py` and `daily_motion.staging`:
  project confirmation and verified TLS precede mutations; Alembic runs through
  a supplied administrator connection, not API environment overrides. Provision
  `dm_staging_runtime` as non-owner/non-superuser/non-BYPASSRLS, without database,
  role or replication privileges. Grant the private tables and read-only migration
  metadata; revoke direct training access from PUBLIC/provider roles. No reset,
  personal account seeding, public admin endpoint or credential output.
  Verification uses the runtime connection and rollback-only synthetic owner/RLS
  probes. An initial local test deliberately rebuilt the **dedicated test schema**
  and proved all migrations plus repeated setup with a quoted password safely.
- Hosted configuration requires HTTPS issuer/project agreement, authenticated
  audience, publishable key, bounded signing-key minimum and database
  `sslmode=verify-full` plus root certificate. The session/direct path is port 5432;
  transaction-pooler 6543 is rejected rather than assuming driver compatibility.
  Actual certificate negotiation remains hosted qualification.
- `/healthz` already existed and remains liveness. Added infrastructure `/readyz`
  outside checked transport OpenAPI: actual restricted role, current revision
  **0003**, complete table grants, forced RLS and absent-owner denial are checked
  before reporting ready. Queries/connections/pool waits are bounded. Unexpected
  SQLAlchemy database errors return sanitized 503 responses and engine parameters
  are hidden, avoiding exception/SQL payload leakage. No migration runs at startup.
- Opt-in desktop Flutter `test/hosted_staging_test.dart` receives real short-lived
  staging user credentials through protected process environment, never app
  bundle/defines. Server initialization establishes owner before local access;
  the harness prepares synthetic local work, exact duplicate send/lost local ack,
  A→B→A locked file reopening and resumed synchronization. **Skipped without
  actual credentials**. It does not pretend to prove OTP delivery, SDK refresh,
  native secure storage or provider logout; those use the actual app separately.

### Exact current local results

Windows 11 workspace, Flutter **3.47.7/Dart 3.13.5**, Python **3.13.14**, dedicated
Docker PostgreSQL **17.7**, restricted runtime role. Docker was started for this
task; unrelated containers/workloads were preserved.

| Check | Actual result |
|---|---|
| Full ordinary Flutter | **148 passed**, **10 skipped**, **115 s**: previous 9 local live cases plus 1 explicitly unqualified hosted case |
| Separate actual loopback Flutter/FastAPI/PostgreSQL | **9 passed** through the full Python harness; provider remains controlled/synthetic |
| Distinct executed Flutter cases | **157**; new hosted case is **not** counted as executed |
| Full Python | **99 passed, 0 skipped**, **37.00 s**; previous 79 plus 20 staging/config/readiness/security cases |
| Real PostgreSQL | **51 cases**, independently counted from fixture collection; previous 44 plus seven migration/provision/readiness attacks |
| File-backed recovery/account/fault subset | Existing **55** cases retained, including **3 hard Windows process kills**; no hardware inference |
| Formatting / analyze | **53 Dart files**, no outstanding format changes; analysis clean. **33 Python files**, Ruff clean; strict mypy **13 source files** clean |
| Contracts/artifacts | All **4** checked artifacts reproduce byte-for-byte; no transport schema/version change. `/readyz` is infrastructure only |
| Blueprint / native / secrets | Official Render schema validation and native static guards pass; credential scan **203 files, 0 findings** |

Full logs are ignored `.tools/phase0-staging-flutter.log` and
`.tools/phase0-staging-python.log`. The prepared live hosted harness is unrun;
its skip is explicit. Controlled provider tests/local PostgreSQL do not qualify
Supabase delivery, TLS, pooler behavior or hosted RLS. Current remote validation,
if run after the preparation commit, is recorded separately from these results.

### Adversarial findings fixed

Readiness could previously report process health without checking usable database
configuration. The new guard rejects incomplete migration/grants and privileged
connections. Review corrected an any-privilege check to require each necessary
grant and added role-creation/database-creation/**replication** privilege denial;
actual PostgreSQL attacks cover all three. SQL exceptions could expose connection
or private parameter detail; responses now fail safely with no exception logging.
Provisioning validates all project/runtime/admin identity before changing roles,
uses quoted identifiers/passwords and requires the expected RLS SQLSTATE, rather
than treating any SQL failure as proof of isolation. Browser snapshots and extra
real environment files could have been tracked; they are excluded. The new
qualification harness was corrected during static review for generated DTO map
shape, extension imports, first-owner initialization and safe store closure.
No synchronization/auth invariant was relaxed; existing tests all pass.

### Hosted status and external boundary

| Required evidence | Current status |
|---|---|
| Supabase project / region / PostgreSQL version | **Not created/observed**; intended specific Mumbai `ap-south-1` |
| Render service / region / deployed API revision | **Not deployed/observed**; intended Singapore; no deployed revision |
| Hosted Alembic / runtime role / forced RLS / HTTPS | **Unperformed**; local target/proof is revision **0003**, 11 training tables |
| Real Supabase OTP / inbox / refresh / account qualification | **0 hosted qualification cases**, login/project/test inbox required |
| Custom SMTP | **Not configured; 0 delivered SMTP messages**; operator sender credentials required |
| Hosted Flutter synchronization / restart / account switching | **Unperformed**; prepared guarded harness and app procedure |
| Actual Supabase URL / Render URL / publishable key | **Unavailable**; examples are placeholders only |

To resume, sign in directly to the Supabase and Render dashboards in the available
browser, select the staging organization/workspace and provide two controlled test
inbox addresses (or one for initial delivery). Billing/domain/SMTP secrets remain
operator-owned and must be entered in provider storage, never chat/source/mobile.
The complete provisioning/deploy work is now concrete and reviewable at this
boundary. Physical devices, signed installation, native storage/backup/accessibility,
phone lifecycle/storage/power and physical profile/release p95 still remain open.

**ADR DM-018 added** for the explicitly requested Render Singapore **staging-only**
exception. Production DM-003 Cloud Run Mumbai remains unchanged. Cross-region
processing is disclosed; no residency/compliance assertion. **Phase 0 remains in
progress. Phase 1 has not started.**

Staging preparation closing documentation checks: **30 Markdown files, 294 local
links, 5 JSON examples**; native guards and **203 source files/0 credential
findings** pass. Final Flutter analysis is clean (**13.3 s**); the focused hosted
case explicitly reports **1 skipped, 0 executed** without credentials. All code
changes are recorded as staging preparation, not hosted qualification.

Preparation source committed/pushed as
**`ef025c2552122cb2a3727943f761a1602d5e6c56`**.
[Actual CI run 38570967779](https://github.com/bluxo1/Daily-Motion/actions/runs/38570967779)
completed successfully on that exact source revision: **all three jobs passed**.
The API ran **99 tests, 0 skipped, 18.59 s**, including the restricted PostgreSQL
suite and **9 actual loopback Flutter HTTP cases**. Linux and Intel macOS each ran
**148 Flutter tests, 10 skipped**, format/analyze and Drift reproduction. Linux
compiled Android debug/profile/release plus the separate routine debug study;
macOS/Xcode 26.3 compiled unsigned iOS debug/release. All checked contracts,
documentation, native configuration and credential guards passed remotely.
Ignored logs are `.tools/phase0-staging-api-ci.log`,
`.tools/phase0-staging-linux-ci.log` and `.tools/phase0-staging-macos-ci.log`.
This proves compilation/local-database behavior, not provider deployment or
physical acceptance. The commit contains no real credentials and is unsigned
because the configured signing-key passphrase is unavailable; no signing
configuration was changed. Provider deployment remains blocked on
login/workspace/inbox configuration. Final evidence documentation follows in a
separate commit; the CI source revision remains `ef025c2`.

## Hosted staging provisioned; email boundary — 2026-10-14 IST

User-provided dashboard login enabled actual provider setup. Selected the existing
**empty** project in the Daily Motion organization, verified zero application
tables/auth users before changes, and renamed it `daily-motion-staging`. No personal
workout data was used. [Machine-readable evidence](evidence/phase0-hosted-staging-2026-10-14.json)
contains public configuration and outcomes, never credentials/tokens/inbox contents.

| Resource | Observed configuration |
|---|---|
| Supabase | `pulruylvpehwftwqcvct`, **Mumbai `ap-south-1`**, Free, PostgreSQL **17.11**; `https://pulruylvpehwftwqcvct.supabase.co` |
| Render | `srv-db7p5knavr4c7392dasg`, **Singapore**, Free; `https://daily-motion-staging-api.onrender.com` |
| Deployed API | **8e5af655112123cd9104f4b292e250b791363958**, deployment `dep-db7pugjrjlhs73cjobe0`, observed **Live** |
| Database | Alembic **0003**, **11 forced-RLS tables**, `dm_staging_runtime`, session pooler `aws-0-ap-south-1.pooler.supabase.com:5432` |
| Transport | Actual `sslmode=verify-full` with downloaded CA; server SSL enforcement enabled; Render certificate mounted at `/etc/secrets/supabase-root.crt` |
| Provider auth | Public JWKS **ES256 / 1 key**; verified publishable key returns **200** from real Auth settings; email confirmation required, six-digit OTP, **600 s** expiry, no anonymous/social providers |

Alembic ran through a separate administrator connection. Generated passwords stayed
in temporary authenticated localhost bridge/process memory and provider storage;
no real `.env`, privileged mobile define or secret-bearing output. The runtime role
passed its per-transaction privilege/owner checks. Three successful rollback-only
hosted probe invocations exercised two synthetic owner namespaces, missing-owner
denial, cross-owner insert rejection (42501), all-table forced RLS and pooled-context
reset. The final invocation reads actual migration metadata through the runtime
role; the API's real readiness function also passed on that hosted connection.
Dashboard catalog checks confirm `anon`, `authenticated` and `service_role` have
**no training-schema/table grants**. Disabled the unused Data API; public REST now
returns **401 / Secret API key required**, while Auth settings remain **200**.

Render contains only its restricted connection, provider public identifiers and
generated synchronization signing key; the observed eight variable names contain
no migration/admin or synthetic-key override. Source access logging is disabled.
Inspected startup/deploy output without printing credentials: no known database
passwords were present. This is bounded evidence, not a comprehensive provider log
audit. Temporary bridge credentials are cleared when qualification closes.

### Actual hosted/public checks and limitations

Six actual HTTPS checks pass on the deployed revision: `/healthz` **200**,
`/readyz` **200**, missing authentication **401**, malformed authentication **401**,
a forged ES256 signature using the project's actual public key ID **401**, and
unsupported contract header **426**. The forgery uses a temporary attacker key,
never a real user/session. It does not prove independent wrong-issuer/audience or
expiry claims with valid signatures; existing local JWT/database tests cover those.

**Two real email-authentication requests were accepted (HTTP 200), one each for
the owner-controlled Account A and Gmail plus-alias Account B.** This is public
Auth HTTP evidence, not the Flutter UI, delivered-email evidence or two verified
distinct identities. No delivery, OTP verification, account initialization or
authenticated hosted Flutter synchronization was qualified. Mailbox access and
provider-dashboard control are unavailable in the resumed session. Live Supabase
UI disables subject/body template editing until **custom
SMTP is configured**; the prepared code templates remain unapplied. Do not force
disabled controls, invent users, use admin-generated sessions, add magic-link UI,
or claim fake-provider tests qualify this flow. Default email is limited to team
addresses and provider throttles; SMTP/inbox qualification remains an operator
boundary. [Provider SMTP requirements](https://supabase.com/docs/guides/auth/auth-smtp).
Free-plan managed backups are absent; restore/processor/operator acceptance is open.

### Exact regression/build results

Windows 11, Flutter **3.47.7 / Dart 3.13.5**, Python **3.13.14**, local restricted-role
Docker PostgreSQL **17.7**, plus separately verified hosted PostgreSQL **17.11**.

| Check | Exact result |
|---|---|
| Full ordinary Flutter | **148 passed, 10 skipped**, **136 s**; nine loopback cases run separately, hosted case remains unqualified |
| Separate actual Flutter HTTP | **9 passed** through the real local API/PostgreSQL harness; distinct executed Flutter count **157** |
| Full Python | **102 passed, 0 skipped**, **47.56 s**; includes **54 PostgreSQL cases**, independently collected |
| New adversarial cases | **3 failed before fix**, then focused staging suite **23 passed**; wrong metadata revision, missing metadata grant, restricted public schema |
| Real SQLite recovery subset | **55 retained**, including **3 hard Windows process kills**; all ordinary tests passed |
| Static checks | **53 Dart files** formatted, analysis clean (**35.1 s**); **33 Python files** formatted, Ruff and strict mypy **13 source files** clean |
| Artifacts | **All 4** OpenAPI/DTO/limits/Drift outputs reproduce byte-for-byte |
| Staging Android | Unsigned **release APK, 58.7 MB**, compiled with the actual four client-safe staging defines (**281.3 s** Gradle); signature verification correctly fails for unsigned output |
| Hosted checks | **6/6 public HTTP assertions**, three rollback-only RLS/pool probe invocations, real restricted-connection readiness; authenticated hosted Dart case **0 executed / 1 skipped** |
| Remote CI | [Run 38587594908](https://github.com/bluxo1/Daily-Motion/actions/runs/38587594908) **all three jobs passed** on `8e5af65`: API **102 / 0 skipped / 14.43 s**, Linux/Mac each **148 / 10 skipped**, Android debug/profile/release and routine study, unsigned iOS debug/release |

Local staging file is ignored `.tools/staging/mobile.json`, containing **only**
`DM_ENVIRONMENT=staging`, the public Supabase URL/publishable key and HTTPS API URL.
Its unsigned APK is a compilation artifact, not signed installation, protected
storage hardware evidence or physical durable-save latency. Existing release
synthetic-auth rejection tests pass. Full logs stay in ignored `.tools/phase0-hosted-*`.

### Defects and deployment recovery

The existing verify-only probe returned a constant revision without checking
runtime-readable metadata. It now reads and validates the real head, rejecting
missing grants/stale metadata safely. Provisioning explicitly grants schema usage
for the read-only public migration table; a real restricted-public-schema test
proved the old grant omission. These defects were reproduced before fixing and
the fixes were also applied/verified on hosted PostgreSQL. No schema/transport
version or synchronization semantics changed.

Initial blueprint deployment preceded CA attachment and timed out its readiness
check. A cancellation raced the next queued attempt and canceled that attempt;
explicitly deploying the complete configuration recovered the service. The
runbook now records this initial-deploy boundary. A later operator HTTP read
timeout is recorded; its cause was not established. Bounded warm-up followed by
all six public checks succeeded. Free-service cold starts are not production
availability/latency qualification. Normal training remains network-independent.

**Remaining boundary:** restore provider-dashboard control and mailbox access;
configure a sender through Supabase's protected SMTP settings before applying
code templates and proving delivery. Then execute actual OTP/refresh/restart,
verified account initialization, hosted frozen retry/lost response, sign-out/
pending outbox, disable and A→B→A cases. Hardware, signed installation, native
secure storage/backup/accessibility, phone lifecycle/storage/power, physical p95,
managed backup/restore, named privacy/security reviewer and store prerequisites
remain open. **No new ADR:** DM-018's status reflects observed staging deployment;
production DM-003 is unchanged. Phase 0 remains in progress; Phase 1 has not started.

### Continued inbox checks and credential audit — 2026-10-14, 23:30 IST

The owner designated two controlled inboxes; one actual public `/auth/v1/otp`
request per address returned **200**. Request response bodies and inbox contents
were not recorded. No resend loop ran. The default delivery route, inbox receipt,
alias identity distinction and code verification remain unqualified; request
acceptance must not be inferred to prove those. Custom SMTP/template configuration
has not been re-observed or changed. Dashboard/browser tools from the provisioning
session are no longer available; discoverable Supabase/Render/Gmail connectors
are not connected. No provider session/cookie/secret was recovered from disk.

Adversarial review confirmed that the earlier role provisioner inserted plaintext
passwords into PostgreSQL role DDL. `hide_parameters=True` only protects client
logging, not that SQL. Source **6606db0** now uses libpq's **client-side
SCRAM-SHA-256** verifier generation, independent of server encryption defaults.
Two real PostgreSQL tests observe driver SQL while still executing actual create,
rotation, isolation and login; both fail on the old code and pass on the fix.
The old MD5-default case also fails initial login against SCRAM-required host
authentication; explicit SCRAM fixes that compatibility failure. Unicode rotation
passes after the fix. Stored passwords are SCRAM and replaced passwords cannot log in.
Verifiers themselves are sensitive and are never printed by the operator script.
[PostgreSQL password-DDL warning](https://www.postgresql.org/docs/17/sql-createrole.html),
[supported libpq encryption](https://www.psycopg.org/psycopg3/docs/api/pq.html).

The hosted logging audit observed `log_statement=ddl` and utility-statistics
tracking. Its aggregate-only historical query did **not** produce recoverable
results before browser access was lost. **Historical hosted password retention
has not been ruled out; no credential rotation is claimed.** Restore protected
operator/dashboard access, inspect counts/settings without returning query text,
rotate the staging runtime credential with the fixed provisioner, update Render
secret storage and reverify readiness/RLS. Do not copy credentials or database
logs into chat. The new helper cannot retroactively erase provider logs. Both
temporary localhost bridge listeners are now absent; credentials are unavailable
to this resumed process. Render remains on **8e5af65**: this source-only operator
fix has not been redeployed or reapplied to hosted credentials.

Follow-up full Python: **104 passed, 0 skipped, 152.37 s**, including **56** actual
PostgreSQL cases and **9** live loopback Flutter cases; focused staging suite
**25 passed, 26.81 s**. Collection independently confirms **104 / 56**. Ruff
format/lint (**33 files**) and strict mypy (**13 source files**) pass.
The public hosted suite again passes **6/6**, after two bounded warm-up timeouts;
their cause was not established and no availability qualification is claimed.
First follow-up Flutter run: **147 passed, 10 skipped, 1 failed** at a 90-second
process-worker boundary timeout; isolated hard-kill retry **3/3 passed, 26 s**.
The full repeat with `--concurrency=1` passed **148 / 10 skipped / 0 failed,
144 s**, preserving every test including the three actual hard-kill cases. No
application durability failure was demonstrated by the initial timeout; its
specific cause was not established. All four generated artifacts again reproduce;
final format/analyze/docs checks follow below.

Final local checks: Dart format **53 files / 0 changes**, Flutter analyze clean
(**61.2 s**), Drift regeneration (**29 s / 77 same outputs**) and all **four**
checked artifacts unchanged. Documentation: **30 Markdown / 301 local links /
5 fenced JSON examples**, standalone hosted evidence JSON parsed; native guards,
**204 source files / 0 credential findings** and `git diff --check` pass. The
staging APK hash is unchanged. These are Windows/desktop evidence only.

Source fix **6606db060ec2a82db34d34ce94a92474e97d0bd4** is committed/pushed unsigned
without changing signing configuration. Actual [CI run 38611404742](https://github.com/bluxo1/Daily-Motion/actions/runs/38611404742)
passed its API job. Initial mobile setup failed on **pub.dev HTTP 403 fetching
advisories** and the matrix canceled macOS; no mobile tests/builds ran in that
attempt. Failed jobs were rerun once: **attempt 2 completed successfully in all
three jobs**. API **104 passed / 0 skipped / 19.71 s**, including restricted-role
PostgreSQL and nine live Flutter cases; Linux/Mac each **148 passed / 10 skipped**.
Android debug/profile/release and the routine study, plus unsigned iOS debug/release,
compiled. This source is separate from the **deployed 8e5af65**; compilation does
not qualify physical behavior. Final evidence documentation is committed separately
with CI skipped after local documentation/security checks.

### Hosted authentication qualification checkpoint — 2026-10-15, 00:04 IST

Scope is hosted authentication qualification only; no features or protocol changes.
Working tree was clean on **4798c7f**. Source **6606db0** already contains the
client-side SCRAM operator fix; applying it is a separate protected database
operation, not something proved by deploying or pushing source alone.

This session has no provider/browser control, connected Supabase/Render/Gmail
connector, usable operator credential context or inbox access. Plugin discovery
confirms those integrations are available but not connected. SMTP and prepared
code-template completion have **not** been re-observed. The last observed API
deployment remains **8e5af65**; no new deployment, credential rotation or hosted
runtime-role verification is claimed in this checkpoint.

The requested prerequisite is enforced: **no new OTP request or authenticated
hosted mutation was attempted before the historical log review and credential
rotation**. Earlier plaintext role DDL could have entered provider logs; inspect
protected log/statistics metadata without returning credentials/query text, rotate
potentially exposed credentials, update Render secret storage, then reverify the
restricted runtime role/readiness/RLS before requesting fresh codes. Source
parameter hiding and the SCRAM fix do not retroactively clear historical logs.

Executed now: focused existing staging suite **25 passed / 0 skipped / 15.50 s**
against the dedicated real local PostgreSQL test database; the credential-gated
Flutter hosted harness reports **0 executed / 1 skipped**. No fake credentials
were supplied. The latest full regressions remain the earlier **104 Python /
56 PostgreSQL**, **148 ordinary Flutter / 10 skipped**, and **9 live loopback
Flutter** cases; the full suites were not rerun in this checkpoint. The existing
current-source remote CI result was rechecked: run **38611404742** remains
successful on **6606db0**, with no new remote run triggered.

Hosted deliveries verified **0**, OTP verifications **0**, verified distinct A/B
identities **0**, authenticated hosted sync/account-switch/refresh cases **0**.
Earlier two HTTP-200 OTP requests remain request-acceptance evidence only.
Restore protected provider control and the controlled inbox, and confirm SMTP/
code templates directly in Supabase. No OTP/token/password should be pasted into
chat. All physical/provider Phase 0 gates remain open; no new ADR or Phase 1 work.

### Hosted credential audit continuation — 2026-10-15

PR #2 was merged normally into `main` (`9669fa2`); its original commits/dates were
preserved. Continued on `phase0-hosted-auth-2026-10-15`. No product feature,
authentication model, database schema or synchronization protocol changed.

Native Supabase dashboard access was restored through the existing GitHub session.
An aggregate-only query of hosted `extensions.pg_stat_statements` returned **2
historical runtime-role statements, both containing plaintext password literals**.
The query returned counts only; neither credential values nor historical query
text were retrieved. This confirms retention previously left uncertain. Historical
Render deploy/application logs have **not** been inspected in this continuation.

**Credential rotation is not performed.** Browser keyboard input failed with
`window_not_focused` even after the supported restoration attempt. Manual foreground
focus was requested; no secret was entered and no provider password, environment
variable or deployment was changed. New OTP requests remain paused until the fixed
SCRAM provisioner rotates affected credentials, Render secret storage is updated,
old runtime sessions are closed, and a fresh restricted connection/RLS/pool probe
passes. Provider log retention/purge must not be represented as resolved by a
password change. SMTP/templates and inbox access have not been re-observed.
The unused ephemeral operator context was cleared; its process exited and its
localhost listener was confirmed absent. Resume with a fresh protected context.

Adversarial configuration review found `render.yaml` still pointed at the
qualification branch deleted after PR #2. Commit **69b929e** repairs its linked
branch to `main`; the runbook requires checking both the existing Blueprint source
branch and the service branch. It also distinguishes fresh-connection verification
from a readiness response on an already authenticated old pool. The repair is
committed/pushed, but existing hosted branch settings have **not** been updated or
verified. Last observed hosted deployment is **8e5af65**; redeployment alone does
not apply the operator credential fix.

Windows validation used the pinned Flutter **3.47.7 / Dart 3.13.5**, Python
**3.13.14**, and dedicated local Docker PostgreSQL **17.7**. Docker Desktop was
initially stopped; it was started and only this repository's PostgreSQL service
was explicitly started. No destructive pytest fixture targeted hosted PostgreSQL.

| Check rerun in this continuation | Exact result |
|---|---|
| Full ordinary Flutter, serialized | **148 passed / 10 skipped / 0 failed**, **3 min 18 s**; includes three hard process kills and hosted harness **0 executed / 1 skipped** |
| Python excluding its Flutter subprocess | **103 passed / 1 deselected**, **40.61 s** |
| Separate Python connected case | **1 passed**, **28.86 s**, running **9 actual Flutter HTTP cases** through real local FastAPI/restricted PostgreSQL |
| Combined distinct execution | **104 Python / 0 skipped**, including **56 PostgreSQL cases** independently collected; **157 distinct Flutter cases** executed, **10 ordinary skips** |
| Python static checks | Ruff format **33 files**, Ruff lint and strict mypy **13 source files** pass |
| Dart formatting | **53 files / 0 changes** after formatting the two regenerated transport files |
| Flutter analysis | **No issues**, **57.0 s** |
| Generated artifacts | **All four** reproduce byte-for-byte; forced clean Drift build **55 s / 105 outputs** (initial cached run wrote no outputs, so was not used as regeneration proof) |
| Documentation/security | **30 Markdown / 303 local links / 5 fenced JSON**, **3 standalone evidence JSON**; native guards, **205 source files / 0 credential findings** and whitespace checks pass |
| Captured test-output hygiene | **0 JWT-shaped values** across all three current local test logs; this is a limited scan, not provider-log clearance |
| Hosted public HTTPS checks | **6/6 passed** after **one read timeout** during warm-up; cause not established, no availability claim |
| Render blueprint | Valid against the cached official JSON schema; `main`, staging and manual deployment retained |

Actual [CI run 38665949212](https://github.com/bluxo1/Daily-Motion/actions/runs/38665949212)
passed **all three jobs** on **69b929e**. API **104 passed / 0 skipped / 19.49 s**;
Linux and macOS each **148 Flutter passed / 10 skipped**. Android debug/profile/
release and the isolated routine study compiled; unsigned iOS debug/release
compiled. Job completion was observed before claiming success. GitHub CLI's first
API log retrieval hit an invalid local ZIP cache; direct job-log retrieval recovered
the exact counts without rerunning the passing job. This is not a provider-auth
test or a device qualification. The subsequent evidence-only commit is validated
locally and skips duplicate CI; the remote tested configuration revision is 69b929e.

The previous **55 file-backed recovery cases** remain included in the unchanged
ordinary suite. No phone, physical secure-storage, SMTP-delivery or physical
latency evidence is inferred. Fresh OTP requests **0**, delivered OTP messages
verified **0**, code verifications **0**, distinct verified A/B identities **0**,
authenticated hosted Flutter sync cases **0**. Previous two accepted public OTP
requests remain request-acceptance evidence only.

Manual browser foreground focus is the immediate operator boundary. After it,
complete log review/rotation/runtime verification, inspect actual SMTP/code-template
configuration, obtain controlled inbox access, then run real A/B OTP and the gated
hosted Flutter harness. Hardware/signing/secure storage/backup/accessibility/phone
lifecycle/physical p95, managed backup/restore and reviewer/store gates remain open.
No new ADR; DM-018 and the production hosting decision are unchanged. Phase 0 is
not complete and Phase 1 has not started.

### Hosted rotation, saved-secret defect and recovery — 2026-10-15

The prerequisite credential work is now applied to the actual Mumbai staging
database. A fresh generated administrator password was verified over TLS, and the
fixed client-SCRAM provisioner rotated the runtime role without exposing password
or verifier values. A credential supplied insecurely during the session was
replaced; neither that value nor its replacement appears in repository evidence.
Administrator credentials remain absent from Render and Flutter.

The initial native entry/save action did **not** prove the matching value was
persisted in Render. Protected inspection found correct driver/role/host/TLS
metadata but actual PostgreSQL credential rejection. Explicit deployment
**dep-db8e3s8n74is73eo7000**, source **c5d5414**, built and started but failed
readiness. Two bounded public warm-up runs each had **5 read timeouts**; those
failed runs are retained without claiming every timeout has an established cause.

A protected read-back after another save/reload still differed from the active
rotation. Focusing the exact value field, entering through stdin, triggering its
normal blur, saving and reloading fixed persistence. Protected comparison then
returned **full URL match = true / password match = true**, and the secret display
was hidden again. Only then was the runtime credential applied. This is an
operator/configuration defect and repair, with no application/protocol change.
The runbook now requires provider-persisted comparison before database rotation.

At **14:49:22 UTC**, explicit retry **dep-db8efpon74is73epb8ng** started on
**c5d5414fef28a4a5170d605b61d878797786acbd**. It reached **Live** with startup
and internal readiness passing. This main revision adds only the separately
merged contributor guide to 9669fa2; that work was inspected and preserved.
All three jobs in its existing [CI run 38710259066](https://github.com/bluxo1/Daily-Motion/actions/runs/38710259066)
were rechecked successful, not rerun. PR #3's configuration/evidence branch remains
open and was not merged here. The actual service branch is `main`; Blueprint
source-branch verification remains separate from that observation.

By **14:51:45 UTC**:

- Two runtime-session closure operations each terminated **1 connection**.
  A fresh restricted connection after final closure passed **Alembic 0003, all
  11 forced-RLS tables, owner isolation and pooled owner-context reset**. Across
  this continuation, **3 new hosted probes passed**, each rolling its synthetic
  work back. No destructive local pytest fixture targeted the hosted database.
- Public HTTPS checks passed **6/6**, with first warm-up returning **200**:
  health/readiness, missing/malformed auth, wrong signature using an actual public
  key identifier, and unsupported contract. This does not independently qualify
  valid-signature wrong issuer/audience or revoked-user behavior on hosting.
- Aggregate statistics reported **4 runtime-role statements: 2 legacy plaintext
  and 2 new SCRAM**; the stored runtime verifier is SCRAM and `log_statement=ddl`.
  No historical query text/verifier was returned. Four available historical Render
  deployment views and a seven-day application view showed no matches for the
  checked credential patterns. **No purge or comprehensive log clearance claimed.**
- The ignored Flutter configuration contains exactly **4 client-safe keys**;
  its publishable key reaches real Auth settings with **200**. No mobile token,
  database, administrator or signing secret was added.

Custom SMTP was re-observed **off**. The Magic-link/OTP template explicitly says
custom SMTP is required before editing its subject/body; prepared code templates
remain unapplied. The operator was asked to configure a staging sender directly
in Supabase, without sharing credentials in chat. No new OTP request, inbox receipt,
code verification, distinct A/B identity, refresh or authenticated hosted Flutter
case has been qualified. These remain the immediate external boundary.

The evidence is [recorded separately](evidence/phase0-hosted-rotation-2026-10-15.json)
from the earlier unrotated checkpoint. Real provider configuration, prior failures
and eventual recovery are distinguished from desktop tests. No new ADR, Phase 1
feature or Phase 0 completion claim.

Validation rerun on Windows with Flutter **3.47.7 / Dart 3.13.5**, Python **3.13.14**
and the dedicated local Docker PostgreSQL **17.7** database:

| Check | Exact result |
|---|---|
| Full Python with connected harness enabled | **104 passed / 0 skipped / 79.95 s**, including **56 real PostgreSQL cases** independently collected and **9 actual loopback Flutter HTTP cases** |
| Full ordinary Flutter, serialized | **148 passed / 10 skipped / 0 failed / 133 s**; **157 distinct Flutter cases executed** when combined with the separate HTTP cases |
| Real SQLite recovery | All **55 retained cases** remain in the passing suite, including **3 hard Windows process kills**; hosted case remains **0 executed / 1 skipped** |
| Static checks | Dart format **53 / 0 changes**, analyze **0 issues / 53.1 s**; Ruff format/lint **33 files** and strict mypy **13 source files** pass |
| Generated artifacts | OpenAPI, DTO, limits and Drift reproduce **all 4 byte-for-byte**; clean Drift build **72 s / 105 outputs** |
| Docs/security | **30 Markdown / 306 local links / 5 fenced JSON**, **4 standalone evidence JSON**, native guards, **206 source files / 0 credential findings**, whitespace checks pass |
| Captured test-output scan | **0 JWT-shaped values** in both current test logs; this is not provider-log clearance |

An earlier native diagnostic screenshot captured an occluding window. That
generated file was removed; subsequent sensitive provider checks used protected
helpers with screenshots disabled. No private content is reproduced in evidence.
At **15:18 UTC**, the temporary operator context acknowledged shutdown, its process
exited successfully and its localhost listener was absent. Actual saved
credentials remain in provider storage. Documentation-only changes are
committed separately from the already-green deployed source; no new remote CI or
physical-device evidence is inferred.

### Hosted SMTP continuation — 2026-10-16

Continued on `phase0-hosted-auth-2026-10-15` from **d16eb71**, preserving the
current PR and all application/protocol source. The operator reports staging SMTP
configured. That report is separate from saved-setting, template and actual
delivery qualification: the last successful native observation on 2026-10-15
was SMTP off with code-template editing locked.

The current Brave window was identified without screenshots. Native navigation
returns **`window_not_focused`**, including a supported restore attempt. Manual
foreground focus and the controlled Gmail inbox were requested; no credentials
or codes were requested in chat. No repeated restore loop was used, and no raw
provider snapshot was printed or retained. Saved SMTP configuration and active
subject/body remain unverified.
**No fresh OTP request was sent before those prerequisite checks.**

Fresh real public HTTPS checks pass **6/6** after **2 warm-up read timeouts** and
a successful third warm-up. The real Supabase Auth settings endpoint returns
**200**, with email auth enabled. The ignored Flutter configuration contains
exactly four client-safe staging keys and a publishable key. This proves neither
email delivery nor authenticated account/sync behavior. No hosted role/credential
change or new authenticated hosted database probe occurred in this continuation;
the previous rotation/RLS evidence above remains separate.

Windows regressions rerun against the dedicated local Docker PostgreSQL **17.7**:

- **104 Python passed / 0 skipped / 75.59 s**, with **56 actual PostgreSQL cases**
  independently collected and **9 separate live loopback Flutter HTTP cases**.
- Ordinary Flutter **148 passed / 10 skipped / 0 failed**, runner elapsed
  **03:47**, serialized. Combined with the loopback cases, **157 distinct Flutter
  cases executed**. Slow startup progressed to a passing run; no test failure is
  hidden. The credential-gated hosted case remains **0 executed / 1 skipped**.
- Ruff format/lint **33 files**, strict mypy **13 source files** and native
  configuration guards pass. Current Python/Flutter test logs contain **0
  JWT-shaped values**; no comprehensive provider-log clearance is inferred.
- Dart format **53 files / 0 changed**, Flutter analyze **0 issues / 54.5 s**.
  Application/generated source is unchanged; four-output reproduction was not
  rerun in this documentation-only continuation. No new remote CI was launched.
- Docs validate **30 Markdown files / 309 local links / 5 fenced JSON examples**;
  all **5 standalone evidence JSON** parse. Credential guard **207 files / 0
  findings**, whitespace checks pass.

Confirmed inbox deliveries **0**, successful OTP verifications **0**, verified
distinct A/B identities **0**, real account initializations **0**, hosted Flutter
sync/refresh/sign-out/account-switch qualifications **0**. Wrong-code, resend,
expiry and hosted idempotency/isolation exercises await real provider access and
credentials. Local regression coverage is not substituted for these results.
No new functional defect, architectural decision, Phase 1 work or Phase 0 exit
claim. See [the continuation evidence](evidence/phase0-hosted-auth-2026-10-16.json).

Immediate next action is manual foreground access to the saved Supabase SMTP
page and controlled inbox, followed by code-template verification and actual
delivery/verification. Hardware, signing, native protected-storage/backup,
accessibility, phone lifecycle/storage/p95, managed restore and operator/reviewer
acceptance remain open. SMTP is reported configured, not declared absent.

### Browser reattachment after manual foreground — 2026-10-16, 18:49 IST

The operator confirmed Brave foregrounded on the staging SMTP page and controlled
Gmail signed in. The previous window reference had expired; read-only discovery
identified the current window and refreshed the ignored qualification helper.
Observation succeeded, but its first navigation attempt returned
**`window_not_focused`**. The current Windows bridge explicitly reports
**`supports.windows.focus=false`**. No restore attempt or further browser action
followed that error, as instructed.

No credential rotation, database re-verification, OTP request, inbox/code read or
token handling was repeated. Saved SMTP/templates, delivery, verified distinct
A/B identities and authenticated hosted Flutter/sync remain **unproven**. This
attempt adds a browser-control diagnostic, not hosted-auth qualification. The
manual foreground report did not restore usable automation; the browser-control
connection needs repair before continuing. Application/protocol source is
unchanged, so the earlier regression results above are retained without rerunning
or relabeling them as new results. No Phase 0 gate or ADR changed.

### Authenticated page access; saved SMTP absent — 2026-10-17

Direct observation found PR #3 **merged**, with `origin/main` at **c9a8370**.
Its only additional file relative to the previous checkout is the contributor
guide; application/protocol source is unchanged. The continuation uses a focused
documentation branch from that merged main, preserving the guide.

A supported Playwright page connection is now available and can access the
authenticated staging Supabase dashboard. This **bypasses** the prior desktop
focus blocker; it does not claim to repair native focus support. An initial
fresh-page input probe timed out. Two later explicit authenticated reads of
`GET /platform/auth/pulruylvpehwftwqcvct/config` returned **200**, with only safe
presence/template flags emitted:

- Persisted SMTP host, username, password, sender email/name and port are **absent**.
  The editable form's enabled checkbox or partially populated sender fields are
  not proof of saved provider configuration. No incomplete settings were saved.
- Saved magic-link and confirmation templates contain `{{ .ConfirmationURL }}`,
  lack `{{ .Token }}`, have no nonempty custom overrides and do not match the
  prepared staging subject. OTP/code templates are **not active**.

This materially changes the blocker: browser access works, but a real SMTP sender
must be configured and saved by the operator using provider-managed credentials.
No SMTP credential was supplied to the app, printed or written into evidence.
The ignored current browser artifacts had **14 files / 0 credential-pattern
findings** in a limited scan; no comprehensive log clearance is claimed.

No new OTP request, delivered message, code verification, verified distinct A/B
app owner or authenticated hosted Flutter case was produced. Dashboard operator
access is not app-owner verification. Credential rotation and database probes
were not repeated. Render's deployed revision was not reverified: **c5d5414 on
2026-10-15** remains the last observed deployment, separately from current Git
main. Recheck the actual deployed revision before the eventual hosted auth suite.

No application/source change requires a regression rerun, and earlier test counts
are retained as dated evidence. No new remote CI, hardware result, ADR or Phase 0
exit claim. [Safe provider evidence](evidence/phase0-hosted-smtp-2026-10-17.json).
After SMTP is saved, apply/verify prepared code templates, then qualify real
controlled A/B delivery, identity and the existing hosted Flutter lifecycle path.

Documentation checks pass **30 Markdown files / 311 local links / 5 fenced JSON**;
all **6 evidence JSON** parse. Credential guard passes **209 files / 0 findings**;
whitespace and unchanged application/generated-source checks pass. Full application
tests, artifact regeneration and remote CI were not rerun for this evidence-only
change.

### Saved SMTP and code templates; SMTP authentication rejected — 2026-10-17

Fresh authenticated provider readback verifies saved SMTP fields. Both
Confirmation and Magic Link templates were saved with `{{ .Token }}` and the
prepared staging subject, then verified after reload; OTP remains six digits
with 600-second expiry. These are new configuration results, not delivery proof.

Account A's real request at **15:59:56 UTC** returns **500 / unexpected_failure**.
The correlated Auth event at **15:59:58 UTC** reports Google SMTP **535 /
BadCredentials**, with username/password rejection. The operator must correct
the SMTP login in provider storage. No delivered code, verified A/B identity,
refresh or authenticated hosted Flutter result is claimed. No B request, repeated
credential rotation/database probe, broad test run or app/protocol change occurred.
Phase 0 remains open; Phase 1 has not started.
[Safe new evidence](evidence/phase0-hosted-smtp-delivery-2026-10-17.json).

### Real hosted SMTP/OTP and authenticated Flutter flow — 2026-10-18 IST

After operator credential correction, Account A's single requested retry returns
200 at **23:23:44 UTC**. The initially open Gmail account was the SMTP sender;
its Sent copy was excluded. Operator sign-in and Google verification established
actual recipient-mailbox access. Both designated recipients delivered codes and
verified as distinct, confirmed ES256 Supabase subjects; the aliases share a
mailbox. Both initial sessions also refresh successfully with owner continuity
and rotated refresh tokens. No codes, sessions, credentials or message bodies
were written into evidence.

The credential-gated hosted sync case initially failed twice: the widget binding
intercepted HTTP with synthetic 400s (**53.67 s**), then an incorrect assertion
expected an exact retry to retain `accepted` instead of returning `duplicate`
(**13.99 s**). Removing the unnecessary binding and asserting `accepted` then
`duplicate` with identical remaining receipt fields fixes the harness. Its actual
Flutter → Render → Supabase run passes in **25.06 s**, with pending file-backed
A → B → A recovery and isolated local/feed namespaces.

The new `hosted_auth_lifecycle_test.dart` exercises the production Supabase SDK,
account controller, gateway, coordinator and real SQLite stores. Its first run
passes in **111.96 s**; a further run adds actual immediate-resend throttling,
wrong-code rejection followed by valid verification, and a precise revoked-refresh
error assertion, then passes in **115.03 s**. It proves refresh, controller/file
reopening, provider sign-out with pending work, local lock/credential removal,
A → B → A through fresh actual OTPs, B feed denial, B mutation of an uploaded A
root rejected as `not_found`, and A recovery/upload/bootstrap at revision 3.
These are **two distinct hosted cases**, not ordinary-suite or physical results.
The local operator bridge and `MemoryProtectedStorage` keep codes/sessions in
process memory; no native storage or screen-UI acceptance is inferred.

Render displays **c5d5414** and HTTPS readiness returns **200** after an initial
Windows request timeout. No deployment, credential rotation or independent SQL
RLS probe was repeated; previous direct-RLS evidence remains dated separately.
Current authenticated API tests exercise the guarded runtime and owner denial.
Android discovery finds **0 physical devices / 0 emulators**. Real elapsed OTP
expiry, trusted signing-key rotation, wider sender/rate review, physical/signing,
managed backup/restore and named reviewer/operator gates remain open. No Phase 1.
[Safe functional evidence](evidence/phase0-hosted-auth-flow-2026-10-18.json).

### Elapsed OTP expiry, logging hardening and provider audit — 2026-10-18 IST

Independently reread the Phase 0 roadmap/checklist, evidence, security/testing and
current code/CI. Supported logged-in Playwright provider access remains available.
Saved SMTP/code templates still pass protected presence checks; six-digit OTP
lifetime remains 600 seconds. No SMTP, signing or database setting was changed.

The new opt-in `hosted_otp_expiry_test.dart` requests a real recipient code,
holds it unconsumed for **610 actual seconds after delivery**, then requires
`invalid_or_expired_code`. A fresh delivered code verifies and the session signs
out. The first run passes, with rejection at **07:58:15 UTC** and fresh verification
at **07:59:05 UTC**. No simulated clock or shortened provider setting was used.
The final hardened-source run also passes: a 610-second hold is rejected at
**08:25:04 UTC**, fresh delivered-code verification succeeds at **08:25:17 UTC**,
and provider sign-out succeeds. The temporary code bridge is then shut down.

Adversarial source inspection confirmed that SDK `Session.toString()` includes
tokens, so a failed negative matcher could print an unexpectedly returned session.
The hosted assertions now use `requireAuthRejection`, which checks safe categories
and never formats results or unexpected exceptions. Session-absence assertions
compare booleans. Three synthetic regression tests pass. No actual session dump
from these assertions was observed.

The hardened lifecycle rerun initially fails at **00:30** with API initialization
`timeout` after OTP verification; later readiness is 200. A cold-start cause is
not proven. The harness now permits one existing-controller initialization retry
with the retained verified session, only for pending initialization/timeout.
No timeout was increased and no new code request substitutes for that retry.
The final lifecycle run passes at **02:30**, completing **08:07:43 UTC**, with
refresh/revocation, file recovery, pending logout, A → B → A and owner denial.
This remains desktop memory credential storage, not native/physical evidence.

**Provider findings and incident:** the Render service follows `main`, but the
Blueprint source points to deleted `phase0-qualification-2026-10-13`. During a
branch settings inspection, a generic form-value read returned the private
Blueprint sync hook in a tool response. The credential is absent from repository
evidence; tool-history purge and provider invalidation are not claimed. The UI
exposes no regeneration control; operator/Render support invalidation is requested.
The unsaved source-branch edit was discarded and repair is held until containment.
Subsequent reads use explicit field scopes and nonsecret results only.

Added Render deploy/sync hook credential detection to the repository guard. A
synthetic sample yields **0 findings before / 1 after**; all **9** targeted guard
tests pass, without echoing credential material. This prevents source retention;
it does not invalidate the already disclosed provider hook.

Read-only sender/rate review confirms Gmail mailing/signing and TLS, a 60-second
resend interval, 30-email/hour project budget, OTP/verify refill values 30 and
refresh 150. The 30/hour allowance permits 720/day, exceeding the consumer Gmail
sender's documented 500/day capacity. No quota exhaustion or operator acceptance
is inferred. Current backup UI still indicates Free, an upgrade requirement,
zero scheduled backup rows and no restore control. Public JWKS returns one ES256
key; trusted-key rotation/revocation approval is pending and keys are unchanged.

Validation on the working source:

- API Ruff format/lint and strict mypy (13 source files) pass.
- Full `DM_TEST_ADMIN_URL` / `DM_RUN_CONNECTED=1` pytest: **108 passed, 0 skipped**,
  including the harness's **9 actual loopback Flutter HTTP/PostgreSQL cases**.
- Full serial Flutter: **151 passed / 12 explicit skips**, reporter **02:36**;
  analysis has no issues and formatting is unchanged. Hosted/connected cases are
  run separately, not counted as ordinary passes.
- OpenAPI export, DTO/limit generation plus formatting, and Drift regeneration
  reproduce all **four** checked artifacts. The formatter is part of reproduction.
- Docs, static native guards, source credential guard, evidence JSON/source hashes
  and Git whitespace checks pass; final counts are in the linked evidence.
- Actual baseline CI **38942611206 / c9a8370** remains green. New-source remote CI
  is not claimed before publication/authorization.

No application runtime, contract, schema or ADR changed. Physical hardware/signing,
native protection/backup, accessibility, phone lifecycle/p95, managed recovery,
processor and named operator/privacy/security acceptance remain unavailable.
Hook invalidation, source repair, sender acceptance and approved trusted-key
rehearsal remain provider/operator dependencies. Phase 0 stays **in progress**;
Phase 1 has not started. No final independent release approval is claimed.
[Safe new provider evidence](evidence/phase0-provider-qualification-2026-10-18.json).

### Connection security and isolated recovery preparation — 2026-10-18 IST

The destructive PostgreSQL fixture's string-suffix guard allowed remote hosts,
query suffixes disguising another database and ambient `PGHOSTADDR` routing.
Three regression cases fail before any real engine is opened, then pass after
parsed exact database/driver/loopback validation and query/environment checks.
The same review found hosted API/operator validation accepted libpq overrides;
five operator query variants and an actual changed SQLAlchemy connection-argument
hostname reproduce the mismatch without a connection. Eight initial hosted
regressions fail before the fix. A shared transport validator now permits only
`sslmode=verify-full` and one nonempty `sslrootcert`, with no ambient routing
overrides. Provider configuration, credentials and deployments were not changed.

Final affected validation from `services/api`:

```sh
uv run --no-sync pytest -q tests/test_database_target.py tests/test_auth.py tests/test_credential_guard.py tests/test_staging.py -k "not provision and not readiness and not runtime_probe"
uv run --no-sync ruff check . ../../tools
uv run --no-sync ruff format --check . ../../tools
uv run --no-sync mypy --strict src scripts
```

Results: **59 passed / 0 skipped / 12 database cases deselected**; Ruff passes,
35 files already formatted, strict mypy passes for 13 source files. A preceding
selection had **57 passed / 8 explicit database skips / 4 deselected**. No full
PostgreSQL, Flutter or remote CI rerun is claimed. Explicit authorization was
requested before resetting the existing local synthetic test schema; it remains
pending. Publication/deployment are separately unauthorized.

A real custom-format dump of the existing local synthetic database is restored
into a new network-isolated tmpfs PostgreSQL 17.7 container. All 11 tables,
Alembic `0003`, row/policy/constraint/index fingerprints and forced RLS match.
The fixture contains one workout, three sets, one receipt and one feed change;
empty profile/observation/retirement/snapshot tables provide no nonempty coverage.
Missing ACL role and truncated-archive attempts fail with zero training tables
left behind. Restricted `NOLOGIN` roles preserve own-owner visibility, deny
other/unset owners and owner reassignment; duplicate receipt insertion fails.
The source is unchanged and temporary-container removal is confirmed. The
first helper failure and cleanup-inspection race remain in the evidence.

No hosted archive, Auth restoration, credential restoration, retained/off-site
backup, hardware or operator approval is inferred. [Recovery preparation](../infra/RECOVERY.md)
now provides the concrete approval package. A 30-to-10/hour staging sender limit
reduction was requested as a conservative mitigation; no setting was saved or
operator capacity acceptance claimed. Render incident **215476446235862** remains
OPEN without reinvestigation. No migration, contract or ADR changed. Phase 0
remains **in progress** and Phase 1 unstarted.
[New evidence](evidence/phase0-recovery-and-connection-guards-2026-10-18.json).

The bounded locked-dependency review also completes: OSV returns **0 advisories**
for **47 PyPI / 135 hosted Pub packages**, with exact result counts and complete
pagination. Known affected control versions return **13 PyPI / 2 Pub advisories**.
Both lock hashes are retained; no versions were changed. SDK/native dependency
internals and unknown advisories are outside this result. Final repository checks:
**31 Markdown / 355 local links / 5 fenced JSON**, credential guard **264 files /
0 findings**, new evidence JSON/six tested source hashes and whitespace pass.

### Authorized CI and independent routing review — 2026-10-18 IST

- Published exactly **d655e1f** to existing PR #4 after a **264-file / zero-finding**
  source scan and **46 changed file versions / four commits / zero findings**.
  Workflow inspection confirms disposable job-local PostgreSQL, loopback test
  connection and connected Flutter enabled, with no deployment step.
- Push [39125077861](https://github.com/bluxo1/Daily-Motion/actions/runs/39125077861)
  and PR [39125080814](https://github.com/bluxo1/Daily-Motion/actions/runs/39125080814)
  pass all three jobs. Each API run has **137 passed / zero skipped**; each Linux
  and macOS mobile run has **151 passed / 12 explicit skips**. Android all modes,
  routine build, unsigned iOS debug/release and four-output reproduction pass.
- After that regression checkpoint, independent SQLAlchemy/libpq default analysis
  proves three destination ambiguities without opening connections; startup role
  options also lack rejection. **Six new negative tests fail before the fix**.
  Shared/local guards now reject multiple hosts, omitted database, ambient
  `PGOPTIONS` and inherited `PGPORT` for an omitted port. Positive tests retain
  explicit-port precedence and the clean implicit-port default.
- The Store-backed local Python launcher becomes unavailable before the first
  new tests execute. Recovery installs pinned **3.13.14** separately under ignored
  `.tools/python`, with no bin/registry changes, and frozen dependencies in
  `.tools/phase0-review-env`. The old environment and lockfiles remain intact.
  Local uv is **0.13.1**; remote CI retains its pinned **0.13.0**.
- Follow-up qualification: **67 focused passed / 12 DB cases deselected**; then
  **145 full Python passed / zero skipped**, including the **nine live Flutter
  HTTP/PostgreSQL cases**, in a newly created loopback/tmpfs container. Initial
  emptiness and final removal are verified. No existing local/hosted database was
  reset. Ruff passes for 35 files, strict mypy for 13 source files, and regenerated
  OpenAPI has no diff. No Flutter runtime, migration, protocol, contract or ADR change.
- The new review fix is local and needs its own publication/CI approval before
  deployment selection. [The concise change plan](../infra/staging/PHASE0_CHANGE_PLAN.md)
  defines credential-preserving deployment/code rollback, 30→10/hour sender
  tradeoffs and managed/manual/PITR recovery decisions. This session exposes no
  provider/browser control; fresh preflight readback is not claimed. No staging,
  key, sender, backup or operator acceptance change occurred. Render incident
  **215476446235862** stays OPEN. Physical/native/operator gates remain external;
  Phase 0 stays in progress and Phase 1 unstarted.
  [New evidence](evidence/phase0-ci-routing-review-2026-10-18.json).
- Final repository checks: **32 Markdown / 365 local links / five fenced JSON**,
  **266 source files / zero credential findings**, six tested source hashes and
  retained local-result equality verified, unchanged lockfiles and clean whitespace.

### Wider setup-entrypoint review and follow-up CI — 2026-10-18 IST

- With explicit authorization, published exactly **a4f0003** to PR #4 after a
  clean scan of its **13 committed file versions** and unchanged workflow check.
  PR [39128309352](https://github.com/bluxo1/Daily-Motion/actions/runs/39128309352)
  passes all three jobs: **145 Python / zero skipped**, each mobile job **151
  passed / 12 explicit skips**, Android all modes/routine and unsigned iOS both
  modes. API and Linux also pass in push
  [39128306625](https://github.com/bluxo1/Daily-Motion/actions/runs/39128306625).
  Its initial macOS unsigned debug build fails with Flutter's missing-Development-
  Team fallback; pinned Flutter source shows this can follow an undiagnosed build
  issue. The actual Xcode cause is unconfirmed. Only the failed macOS job is rerun;
  **attempt 2 passes**, including 151 mobile tests / 12 explicit skips and both
  unsigned iOS modes. API/Linux conclusions are inherited, not reexecuted. No
  signing setting, SDK or workflow is changed.
- A wider scan of database entrypoints finds the local development-identity
  script still validates only URL hostname/database. Real SQLAlchemy arguments
  prove a query can replace the accepted loopback destination, with **zero
  connections opened**. New tests fail **14/16 negative cases** before the fix;
  the existing wrong-host/database rejections account for the two passes.
- **cbacc0a** requires the psycopg driver, exact local development database and
  loopback host, rejects queries/startup/destination overrides, and sanitizes
  invalid-port/parse errors before file creation, migrations or engine setup.
  Explicit URL ports retain precedence. Twenty boundary tests and **70 focused
  tests / 12 DB cases deselected** pass. Accepted-input tests stop at the setup
  boundary; the actual development provisioner is not executed.
- **165 full Python tests / zero skipped**, including **nine connected Flutter
  HTTP/PostgreSQL cases**, pass in a fresh local tmpfs database; initial emptiness
  and final container removal are verified. No existing database is reset or
  contacted. Ruff checks/format (36 files) and strict mypy (13 source files) pass.
  No Flutter runtime, schema, lock, contract or ADR changes.
- The code fix is separately authorized and published. Push
  [39130484081](https://github.com/bluxo1/Daily-Motion/actions/runs/39130484081)
  and PR [39130487873](https://github.com/bluxo1/Daily-Motion/actions/runs/39130487873)
  pass all three jobs on **cbacc0a**: **165 Python / zero skipped**, Linux/macOS
  each **151 Flutter / 12 explicit skips**, Android all modes/routine, unsigned
  iOS debug/release and all generated-output checks. CI credential guard checks
  **226 tracked files / zero findings**; local scans include untracked skill files.
  Provider controls remain absent from the session. A credential-free CLI read
  lists Playwright configured but not exposed, and no Supabase MCP entry. A cached
  **0.0.83** server initializes, but its supported Chrome-extension tabs operation
  fails; known default locations have no prior MCP profile. No raw response is
  exposed, provider navigation requested or MCP configuration changed. The owned
  probe process is cleaned up. Authenticated browser restoration is still needed
  before private deployment preflight. No
  deployment, key rotation, sender/backup change or operator acceptance occurs.
  Render incident **215476446235862 remains OPEN**. Phase 0 remains in progress;
  Phase 1 is unstarted.
  [New evidence](evidence/phase0-development-routing-and-ci-2026-10-18.json).
- Final repository checks pass: **32 Markdown / 369 local links / five fenced
  JSON**, **268 local source files / zero credential findings**, two tested source
  hashes, retained full-result equality and whitespace. Source is unchanged from
  the fully qualified `cbacc0a`; the consolidated evidence update is local.

### Authenticated staging deployment preflight — 2026-10-18 UTC

- Restored the supported Playwright extension connection to the signed-in Brave
  Default profile. Inspected only the existing staging service/project; no
  deployment, provider setting, credential, schema, backup or resource change.
- Render confirms Live `c5d5414fef28a4a5170d605b61d878797786acbd` /
  `dep-db8efpon74is73epb8ng`, no active deployment displayed, `main`, Singapore,
  Free, Auto Deploy Off and expected root/build/start/readiness configuration.
  Saved environment values pass private project/runtime/database/verified-TLS
  classifications, with explicit session port 5432, no routing overrides and
  a matching CA secret file. Values were remasked and excluded from evidence.
- Two read-only Supabase catalog queries confirm restricted runtime privileges,
  no training-owner membership, migration `0003`, 11 forced-RLS tables, required
  grants and denial to PUBLIC/API roles. Independent predicate review matches
  all 12 expected owner policies. No user records or password verifiers queried.
- Render lists exact `cbacc0a` separately from the already-merged PR #4 revision.
  Selecting the qualified full SHA enables Deploy commit; Cancel closes the
  dialog without submission. Usage is **2 / 500 included pipeline minutes**.
- A fresh readiness request first times out at transport level; the bounded
  follow-up passes `/healthz` **200**, `/readyz` **200** with expected body and
  unauthenticated `/v1/me` **401** at 16:11 UTC. Timeout cause is unconfirmed.
  No unchanged regression or authenticated-write qualification was rerun.
- Initial tab-list output echoed the supplied browser extension credential in
  its connection URL. Subsequent output is restricted to selected metadata; no
  value is retained in repository evidence, and no revocation or log purge is
  claimed. A bounded scan of 11 new local console files finds no matches for the
  checked token-parameter/database-URL/secret-key/JWT patterns; this does not
  clear conversation or tool history, or constitute comprehensive log clearance.
- The updated plan requires separate explicit approval for exact-SHA deployment,
  targeted controlled-account hosted checks and at most one rollback to captured
  `c5d5414` using current credentials. Render incident **215476446235862 remains
  OPEN**; Phase 0 remains in progress and Phase 1 unstarted.
  [New preflight evidence](evidence/phase0-staging-deployment-preflight-2026-10-18.json),
  [approval plan](../infra/staging/PHASE0_CHANGE_PLAN.md).

### Authorized exact-SHA staging deployment — 2026-10-18 UTC

- Received explicit approval for one exact `cbacc0a` deployment, targeted
  controlled-account qualification and at most one conditional code rollback to
  captured `c5d5414` using current configuration/credentials. Fresh preflight
  reconfirms the same Live baseline, no active deployment, expected saved
  settings/transport and **2 / 500 included pipeline minutes** used.
- Submitted **cbacc0ab74d8d5bf7e54aff7a13d27267bf8cfdd** once at **16:27:59 UTC**
  through the exact-commit selector, creating **dep-dbaf73ijnfac73fg5l20**.
  Render confirms the candidate **Live at 16:31:43 UTC** and displays **1m10s**
  duration. No latest-main substitution, merge, Blueprint or resource operation.
- At **16:32 UTC**, public `/healthz` and `/readyz` return **200**, with expected
  readiness body; unauthenticated `/v1/me` returns **401**. Saved service settings
  pass at **16:44 UTC**; private environment/project/runtime/TLS/CA/query/override
  classifications pass at **16:45 UTC**, and values are remasked. No credentials,
  provider settings, schema, database or backups were changed. Rollback unused.
- The credential-gated hosted Flutter case is **not executed** yet. Existing
  in-memory qualification sessions are unavailable. Before requesting new OTPs,
  recipient identity checks find that the controlled inbox is outside Brave's
  connected Default profile; the user confirms another browser/profile. An
  alternate mail connector returns tool unavailable. Connecting the actual
  recipient profile is the remaining immediate human dependency. No OTP request,
  code, new identity, authenticated-sync success or test failure is invented.
- The four preflight evidence files were staged after documentation/JSON/secret/
  whitespace checks, but Git could not unlock the configured SSH signing key.
  No commit was created and signing configuration was preserved. This does not
  alter the deployed source or authorize an unsigned commit/publication.
  Render incident **215476446235862 remains OPEN**. Phase 0 remains in progress;
  Phase 1 is unstarted.
  [Deployment evidence](evidence/phase0-staging-security-deployment-2026-10-18.json).

### Manual hosted authentication attempt and delivery diagnosis — 2026-10-18 UTC

- Added an ignored local native masked-entry helper around the existing loopback
  qualification bridge. The operator reads email independently; no email-browser
  access is required. Codes are cleared from the input before one-time submission,
  and SDK sessions remain in memory. Local synthetic checks cover masking,
  inactive/invalid input, one-time consumption, duplicate rejection, Origin/Host/
  header rejection and bounded request size. No real codes were entered.
- Extended the hosted lifecycle test to replay the same frozen operation twice,
  check accepted/duplicate receipts, and leave acknowledgements unapplied before
  restart recovery. Targeted Dart formatting and analysis pass. This new assertion
  was **not reached** in the real attempt and is not hosted qualification evidence.
- Render's exact Live `cbacc0a` is reconfirmed at **17:13:57 UTC**. The operator
  starts the lifecycle case; its Account A challenge is recorded at
  **17:20:15.525 UTC**. Supabase's correlated initial `/otp` log at
  **17:20:18 UTC** returns **200** without an error. Its actor matches configured
  Account A. The test's immediate resend returns **429** with
  `over_email_send_rate_limit` and a **56-second** per-user wait. No SMTP
  authentication/transport error appears in these two entries; this is not a
  downstream delivery guarantee or a complete mail-provider audit.
- The case times out after its bounded recipient-entry wait, with **zero codes
  submitted and zero new verified identities**. It does not reach authenticated
  Render synchronization, refresh, restart, receipt replay or A/B isolation. The
  operator reports no received message. All further OTP requests/test restarts
  are stopped while recipient/delivery diagnosis is unresolved; no rollback is
  justified by this pre-verification timeout alone.
- Read-only saved SMTP inspection at **17:40:48 UTC** confirms custom SMTP enabled,
  expected Google host/TLS port, matching sender/login and a masked password
  control; the password value is not read. At **17:42:05 UTC**, the saved Magic
  Link/OTP template contains the literal `{{ .Token }}` marker and expected
  staging-code subject. No provider settings are edited. A read-only local window
  shows the exact recipient privately for operator comparison with All Mail,
  Spam and Trash; its visibility/recipient response remains pending.
- No passing regression or CI rerun, signing bypass, new commit, publication or
  provider mutation. Render incident **215476446235862 remains OPEN**. Phase 0
  remains in progress; Phase 1 is unstarted.
  [Updated deployment evidence](evidence/phase0-staging-security-deployment-2026-10-18.json).

### Manual post-deployment qualification and final-A failure — 2026-10-19 UTC

- The operator confirms Account A's recipient matches the inbox and locates the
  original email. Its old code is not used. An explicitly authorized fresh run
  uses masked native entry with no email-browser access. A manual-mode flag skips
  automatic resend and incorrect-code probes; other lifecycle assertions remain.
  Dart formatting is unchanged and targeted analysis passes with **no issues**
  in **129.2 seconds**. A stub runner verifies manual-mode environment forwarding
  without provider requests. No application/runtime source is changed.
- The real Flutter SDK verifies A at **06:41:16 UTC**, refreshes at **06:41:17**,
  proves accepted/duplicate receipt replay at **06:41:34**, then passes file-backed
  restart and pending-work sign-out/refresh-token revocation. B verifies at
  **06:42:11** as a distinct subject. Its local store and hosted feed exclude A's
  workout; cross-owner mutation returns `not_found` at **06:42:12**. These HTTP
  paths accept only successful status-200 contract responses; no raw auth tokens
  or response bodies are retained in evidence.
- The bridge records **three fresh request completions and three submissions**.
  The third submission is for returning to A. Flutter stops at
  `test/hosted_auth_lifecycle_test.dart:140:15` with the sanitized error
  **`Hosted verification failed: invalid_or_expired_code`**. Final A verification,
  pending recovery and final hosted bootstrap do not pass. This application
  category alone cannot distinguish an incorrect, stale or expired entered code
  from other provider verification rejection; the precise Auth HTTP status/code
  is not yet observed. No inference of an application or deployed-code regression.
- Read-only post-failure public checks pass health/readiness **200** and
  unauthenticated identity **401**. This run uses the existing staging URL; the
  private Live revision was last confirmed as exact `cbacc0a` on Oct 18 at
  **17:13:57 UTC**, and is not freshly rechecked on Oct 19. The provider-log MCP
  connection has not completed despite the operator allowing the connection;
  bounded transport diagnostics stop pending the extension's connection action.
  No email access or provider mutation is attempted.
- Confirmed local harness defect: the final native screen only says "Test stopped
  or failed," hiding the rejected account step and category. A safe local result
  summary and next-window display now identify **step 3/3, return to A,
  verification, `invalid_or_expired_code`**, with preserved passing checkpoints.
  Six parser cases and a stubbed UI check pass, including unknown-text rejection
  and ANSI formatting. These checks make **zero provider requests**; the existing
  failed process/bridge results are preserved. The fix does not restart the run.
- All OTP requests/restarts are stopped at the user's instruction. No signing
  bypass, commit, CI rerun, publication, rollback, provider setting or credential
  change. Render incident **215476446235862 remains OPEN**. Phase 0 remains in
  progress and Phase 1 unstarted.
  [Preserved partial qualification and failure evidence](evidence/phase0-staging-security-deployment-2026-10-18.json).

### Return-to-A harness review and controlled retry preparation — 2026-10-19 UTC

- Preserved the failed hosted run's seven passing checkpoints, final-A failure,
  original source digest and explicit incomplete status. Its transient loopback
  bridge is now unreachable; sanitized repository evidence remains available.
  The existing MCP relay has no established browser connection. No reconnection
  attempt is repeated. Manual read-only Auth-log lookup is requested for Oct 19
  **06:40–06:46 UTC / 12:10–12:16 IST**, selecting the final failed `POST /verify`
  after B's **06:42:11 UTC** success. Only timestamp, HTTP status, `error_code`
  and request ID are requested; no raw request/body or credential disclosure.
- Source review finds both A legs use the same label and frozen configured
  recipient. Successful sign-out clears the session, challenge email and local
  account before the next request; awaited operations serialize account changes.
  A synthetic native UI exercise confirms every new A/B/A challenge clears old
  input, step 3 explicitly says return to A, and submission binds to challenge 3
  with the masked input cleared before sending. The bridge consumes each code
  once. No incorrect-recipient, automatic code-reuse or account-state defect is
  established. The precise earlier provider rejection remains unconfirmed.
- A separate concrete pacing defect is reproduced: the old per-account cooldown
  starts before the request completes. With 15 seconds of simulated latency,
  it waits **46 instead of 61 seconds** after acknowledgement; the A/B/A case
  waits **36 instead of 51**. Both tests fail before the correction. The extracted
  test helper now records successful completion time, retains independent A/B
  clocks, and never retries a failed request. The actual hosted lifecycle uses
  this helper. This is not claimed as the cause of an already-accepted final-A
  challenge's verification rejection.
- All **four** focused scheduling tests pass after the fix, with zero skips or
  provider requests. Formatting passes; targeted analysis of the lifecycle,
  scheduling helper and tests reports **no issues** in **30.7 seconds**. The
  synthetic native UI check also makes zero provider requests. No passing full
  regressions or remote CI are repeated; application/runtime source is unchanged.
- One controlled fresh-OTP A → B → A run is prepared for explicit approval:
  existing staging API, at most three requests, at least 61 seconds after A's
  prior request completion before returning to A, no automatic resends or wrong
  code probes, masked local entry and stop on failure. Each step uses its own
  newly requested message; final A pending recovery and hosted bootstrap must
  pass in the same complete run. No additional OTP has been requested, no new
  run started, and no provider/deployment configuration changed. Existing passes
  do not promote the incomplete post-deployment end-to-end gate to qualified.
  Render incident **215476446235862 remains OPEN**; Phase 0 remains in progress.
  [Review and retry preparation](evidence/phase0-staging-security-deployment-2026-10-18.json).

### PR #6 integration recovery — 2026-10-20 IST

- Remote main is healthy `8ba5a98`. PR #6 remains marked merged at `b2cfee9`,
  but local reflogs show the subsequent reset and non-fast-forward push back to
  `8ba5a98`, not a revert. The original `950a946` passed CI; the merge introduced
  malformed Dart, a fixed clock and no-op delay beyond that tested head. Its
  Linux formatting job failed before Flutter analysis/tests. The initiating
  human/process is not attributed from reflogs. [Audit](INTEGRATION_RECOVERY.md).
- Preserved all five existing worktrees and their HEADs/staged/unstaged patches,
  plus the unrelated untracked skill installation. A separate recovery worktree
  starts on healthy main. `recovery/pr6-bad-merge-20261020` retains the bad merge;
  original auth refs remain. No reset, stash, deletion, main update or force-push
  occurs in this recovery.
- Selectively recovered successful-request cooldown timing, stale-recipient
  invalidation, frozen A/B recipients, bounded pacing, redacted diagnostics,
  operator tools and local JWKS rotation tests. Kept real clock/timer defaults;
  two regressions exercise those defaults. Current main's newer evidence and
  change-plan history are retained rather than replaced from the older branch.
- Adversarial review reproduces another real defect: the original bridge reports
  PASS for a zero-exit child with no challenges/checkpoints. The fix requires
  nine ordered lifecycle events, three submitted/consumed A/B/A challenges and
  successful exit. Twelve new cases challenge skipped, incomplete, reordered,
  extra-event, unsubmitted, unconsumed and failed runs. No live provider is used.
- Local Windows uses pinned Flutter **3.47.7 / Dart 3.13.5**, Python **3.13.14**
  and frozen dependencies in the recovery worktree. **35 targeted Flutter** pass;
  full Flutter **161 passed / 12 explicit skips** in **2:11**, with real SQLite
  recovery and hard process-kill cases. Dart formatting checks **59 files**;
  analysis has **zero issues** in **105.5 seconds**. Focused Python **39 pass**;
  full local Python **148 pass / 56 skipped** in **11.88 seconds**. Docker Desktop
  failed startup: **55 PostgreSQL cases + one connected wrapper are skipped
  locally**, not claimed as passes. No existing database or Docker data is reset.
- Ruff formatting/lint pass for **40 Python files**, strict mypy for **13 source
  files**. OpenAPI, Dart DTOs/limits and Drift reproduce **four byte-identical
  outputs**; Drift generation takes **88 seconds / 116 builder outputs**. Static
  native guards, documentation and credential checks pass.
- Reviewed source **`e3da9d0448fc57215d70b88a9d1e45d410a2af9d`** is published as
  a GitHub-verified signed commit with its tree equal to the reviewed index;
  local signing remains enabled. [PR #7](https://github.com/bluxo1/Daily-Motion/pull/7)
  is open against main. All three [source PR CI jobs](https://github.com/bluxo1/Daily-Motion/actions/runs/39306127033)
  pass without retries: **204 Python / zero skipped**, including **55 real
  PostgreSQL cases** and the wrapper executing **nine live Flutter HTTP cases**;
  Linux/macOS each **161 Flutter / 12 explicit skips**. Android debug/profile/
  release and prototype debug, unsigned iOS debug/release and all generated checks
  pass. CI PostgreSQL is the isolated **17.7** service under restricted runtime
  role; no hosted PostgreSQL/provider action is substituted or performed.
- The Phase 0 matrix is reconciled only after that passing integration. Main
  protection is recommended with required API/Linux/macOS checks, current-base
  review and blocked direct/force updates; repository settings are not changed.
  No schema, API contract, dependency or ADR changes. No OTP requests, provider
  settings, keys or deployments. The Oct 19 hosted return-to-A remains incomplete;
  Render **215476446235862 remains OPEN**. Hardware/signing/native protection,
  managed recovery/processor and named operator/reviewer gates remain open.
  Phase 0 is **in progress** and Phase 1 **unstarted**.
  [Machine-readable results](evidence/phase0-integration-recovery-2026-10-20.json).
