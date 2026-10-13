# Phase 0 implementation evidence

Updated: 2026-10-14 (IST). **Phase 0 is in progress. Phase 1 has not started.** This
milestone adds Windows-executable native qualification, fault tests and device
harnesses to the connected synchronization/authentication foundation.
Physical-device, hosted-provider delivery and release gates in
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
