# Recovery Protocol V2 autonomous work log

## Status and scope

2026-10-22 IST. **Incomplete; implementation in progress.**
The full requested outcome remains Recovery Protocol V2 implementation,
regression tests, applicable checks, final diff review, and evidence. Existing
tests passing does not verify V2. No release or recovery qualification is claimed.

This log records investigation from the supplied workspace
`E:/Motion/Daily-Motion`, branch `main`, HEAD
`8ba5a980a4dcd2e31ce8cb6246176a522b912f39`. Its initial status contained only
untracked `.agents/` and `skills-lock.json`; both are user work and are preserved.
The specification, ADR, existing migrations, and characterization artifacts remain
unchanged. No commit, push, deployment, hosted access, existing
database mutation, or production operation has been performed.

## Source discovery and preservation

The specification and proposed ADR are absent from the supplied worktree.
Tracked, untracked, hidden, and ignored filename searches, followed by sibling
worktree discovery and `git worktree list --porcelain`, located them in:

`E:/Motion/Daily-Motion-worktrees/restore-timeline-investigation-20261021/docs/`

That worktree is on `chore/phase0-restore-timeline-investigation`, HEAD
`2781f5c101e87e1a9351cb3e7bbf53453625e025`, matching the specification baseline.
Its pre-existing untracked work is:

- `apps/mobile/test/investigation/`
- `docs/ADR_RECOVERY_PROTOCOL_V2_PROPOSED.md`
- `docs/RECOVERY_PROTOCOL_V2_SPEC.md`
- `docs/RESTORE_TIMELINE_INVESTIGATION.md`
- `services/api/tests/investigations/`

Read-only source fingerprints (SHA-256):

| File | SHA-256 |
| --- | --- |
| RECOVERY_PROTOCOL_V2_SPEC.md | `61EE2B5F4F035CE066C6719B0A1783F5427C08A5DB438FE6D4C234D9BD4A54AC` |
| ADR_RECOVERY_PROTOCOL_V2_PROPOSED.md | `08BD8809DEC6981DE7AB657C55E682D32BD12E65E3F41AF62AC5D873A39439A7` |

The user selected `restore-timeline-investigation-20261021` for implementation
and the work log. This newly created log was moved there from the supplied
workspace. All subsequent changes use that worktree. The source documents remain
read-only references.

## Checklist derived from the specification

- [x] Inspect repository instructions, Git status and worktree identities.
- [x] Locate and read the complete specification and proposed ADR without edits.
- [x] Inspect current API acceptance, receipt/feed/bootstrap paths and Flutter
  coordinator, persistence, migration, and existing recovery tests.
- [x] Identify baseline differences: the specification worktree includes client
  restore preservation code/tests absent from the supplied main worktree.
- [x] Resolve the implementation target and inventory its requirements against
  that target's actual code and tests.
- [ ] Sections 1-2: enforce I1-I10 and immutable DRP/2 E/I/G command lineage.
- [ ] Section 3: independent authority interface, local conformance adapter,
  verified freshness/activation and closed defaults; no provider qualification
  claim from an emulator.
- [ ] Section 4: ordered shared/exclusive recovery locks, READ COMMITTED admission,
  B0-B6 boundaries, durable owner attempt/hold, initialization and lifecycle.
- [ ] Sections 5-6: certified and historical receipts, per-result context,
  publication barriers on every payload/context path, certified feed/cursors and
  two-transaction bootstrap publication.
- [ ] Sections 7/9: complete retirement/lifecycle replay, trusted high-water,
  idempotent closed reconciliation and interrupted cutover/source containment.
- [ ] Section 8: generated versioned contracts/size limits, safe typed denials,
  atomic client lineage/history/attention, owner isolation and local availability.
- [ ] Section 10: additive PostgreSQL/Drift migrations, forced RLS and readiness,
  legacy quarantine and forward-repair/unsafe-downgrade guards.
- [ ] Section 12: new defensive PG01-PG22, SQ01-SQ10 and RC01-RC09/RC12 tests,
  explicit owned-resource launcher, credential scrubbing and completion guards.
- [ ] RC10/RC11: selected-provider durability and encryption/custody qualification;
  require actual separately authorized resources/evidence, never ordinary CI
  passes or silent skips.
- [ ] Section 13: defensive D1-D4 traceability; preserve original characterization.
- [ ] Full applicable Python/Flutter/connected, static/format/migration/contract/
  native verification, with exact failures and skips.
- [ ] Final staged/unstaged/untracked diff review and requirement-by-requirement
  evidence audit; preserve all user changes and source-document fingerprints.

## Iteration 1: investigation and existing regression baseline

Read `AGENTS.md`, product/roadmap/architecture, sync/API/data model, security,
testing, implementation/phase evidence and local recovery preparation, then the
sibling specification, ADR, investigation and recovery implementation/tests.
The existing server accepts schema-1 commands using primary DB receipts/CAS;
the inspected push handler obtains batch context using a later `me(owner)` call.
The inspected client recognizes own feed echoes without DRP/2 certificates, and
Drift remains schema 3. These are baseline observations, not verified fixes.

Commands and observed results:

| Working directory / command | Result |
| --- | --- |
| Supplied root: `git status --porcelain=v2`, `git log -5 --oneline`, `git worktree list --porcelain` | Main at `8ba5a98`; specification worktree at `2781f5c`; existing user files inventoried above |
| Both roots: `rg --files --hidden --no-ignore` with recovery/specification/ADR filters | Source documents found only in the sibling investigation worktree; a broader supplied-root search found only a historical status-file reference, not the documents |
| Supplied root: `.venv/Scripts/python.exe --version` | Python 3.13.14 |
| Sibling `services/api`: `.venv/Scripts/python.exe -m pytest -q tests/test_contracts.py tests/test_database_target.py tests/test_recovery_target.py` | **61 passed in 2.16s**, exit 0; PostgreSQL admin URL and connected opt-in removed from this process environment before execution |
| Sibling `apps/mobile`: workspace `flutter.bat test --no-pub test/sync_recovery_test.dart test/restore_recovery_test.dart` | **36 passed**, zero failures/skips, exit 0, 51 seconds reported by runner |
| Supplied root: `.venv/Scripts/python.exe tools/check_docs.py` | Exit 0: 32 Markdown files, 380 local links, 5 JSON examples |
| Sibling root: `services/api/.venv/Scripts/python.exe tools/check_docs.py` | Exit 0: 43 Markdown files, 470 local links, 5 JSON examples |
| Both roots: `git diff --check`, `git diff --cached --stat` | Exit 0; no staged changes |
| Sibling source documents: `Get-FileHash ... -Algorithm SHA256` | Fingerprints above captured before changes |

Flutter uses the existing pinned SDK at
`E:/Motion/Daily-Motion/.tools/flutter/bin/flutter.bat`, `PUB_CACHE` at the
supplied root's `.tools/pub-cache`, and process-local `TEMP`/`TMP` at the sibling
root's `.tools/temp`. The suites use their existing synthetic/file-backed
fixtures; no hosted tests, destructive PostgreSQL fixture or restore probe ran.

Two exploratory reads used nonexistent filenames (`identity.py` and
`test_restore_timelines.py`); file discovery corrected these to `accounts.py`
and `tests/investigations/restore_timeline_probe.py`. These were failed reads,
not test failures. No process was restarted because an observation timed out.

## Outstanding constraints and next action

First implementation iteration: safe typed recovery denial handling and
independent authority evidence primitives, followed by fault/regression checks.

## Iteration 2: safe denial handling

Changed `apps/mobile/lib/sync/transport.dart` to retain the defined 503
`recovery_unavailable`/`recovery_metadata_unverified` codes and retry 202
`publication_pending` with the existing bounded coordinator backoff. HTML/empty
proxy failures remain retryable. Other transient errors retain generic HTTP codes
so a 503 carrying `account_inactive` cannot invoke owner erasure. Changed the
coordinator to retain `timeline_reconciliation_required` attention across automatic
cycles/restarts rather than automatically retrying the branch.

Added `apps/mobile/test/recovery_protocol_v2_test.dart`: six real loopback HTTP /
file-backed SQLite denial scenarios preserve frozen command bytes, three pending
commands, performed observations, completed workout, numeric draft and owner
access across close/reopen. Integrity and foreign-key checks run in each case.
This covers denial/local-availability behavior in section 8 and part of SQ08/SQ09;
it does not claim all SQ cases or branch provenance are implemented.

- `dart.bat format lib/sync/transport.dart lib/sync/coordinator.dart
  test/recovery_protocol_v2_test.dart`: exit 0, three files checked/two formatted.
- `flutter.bat test --no-pub test/recovery_protocol_v2_test.dart
  test/transport_test.dart`: **17 passed**, zero failures/skips, exit 0, seven
  seconds reported by runner.
- Reviewed the actual transport/coordinator diff and reran `git diff --check`:
  exit 0. Specification/ADR SHA-256 values still match the initial fingerprints.

Next unfinished requirement: independent evidence state rules and a local
conformance adapter with fault/restart coverage.

## Iteration 3: internal evidence rules and local conformance

Added `services/api/src/daily_motion/recovery.py` with immutable internal origins,
activation/attempt/checkpoint bindings; request/owner/target/serial/head admission
validation; minimal committed-marker/certificate metadata; compare-and-append
owner evidence rules; explicit unresolved state; historical lookup; no sealing
with outstanding intent; and checked signed-64-bit erasure high-water arithmetic.
PREPARED never implies commit, and no timeout/absent-receipt abort exists.

Added a file-backed SQLite **test-only conformance emulator** in
`services/api/tests/recovery_authority.py`, plus rule and conformance tests. Its
explicit seed refuses existing files; reconnect refuses missing authority files;
transactional CAS handles concurrent writers; response-loss/reopen retains the
same preparation/certificate; closing allows known attempts to settle but rejects
new work; missing/malformed owner inventory denies access. Runtime imports no
test adapter and no production activation/provider/fallback is configured.

This is local component evidence, not B1-B6 PostgreSQL integration, an approved
committed-marker verifier, provider durability/authentication, independent custody,
nonrollbackable completeness, or RC10/RC11 qualification. The exact real authority,
target verification, certificate/abort proof and policy decisions remain open.

- Initial rules: Ruff formatting/checks and focused mypy passed;
  `pytest -q tests/test_recovery_evidence.py`: **31 passed in 0.11s**, exit 0.
- After conformance/restart coverage: `ruff format` on four new files: exit 0;
  `ruff check` on those files: exit 0; `mypy src`: **11 source files**, exit 0.
- `pytest -q tests/test_recovery_evidence.py tests/test_recovery_authority.py`:
  **40 passed in 3.76s**, zero skips/failures, exit 0.

Next unfinished requirement: bind versioned immutable command provenance into
the generated contract, then implement transactional server/client persistence
and admission. Whole protocol readiness remains unverified and incomplete.

## Iteration 4: versioned command definitions and retry defect

Added `OperationV2` / `PushRequestV2` as closed server contract definitions with
explicit schema 2 and environment/origin-incarnation/origin-generation. The
complete provenance contributes to canonical digests and command/batch limits;
there is no owner field, current-context default, activation serial restamping,
or mixed-version conversion. Regenerated checked OpenAPI and Dart DTOs using
`services/api/scripts/export_openapi.py` and `tools/generate_transport.py`, then
formatted generated Dart. These definitions do not enable a v2 runtime route.
Added a shared v2 JSON/checksum fixture and Python/Dart parity and denial tests.

Review strengthened the authority response-loss test to retry with the original
pre-append checkpoint. It **failed** with `recovery_metadata_unverified` (one
failure, exit 1), exposing a real new reducer defect. Added persisted
`prepared_from` binding and exact idempotent lookup before new-append CAS. Repeated
preparation/certification now returns its recorded identity without a second
append; a different stale/divergent head still cannot authorize new evidence.

- `pytest -q tests/test_recovery_evidence.py tests/test_recovery_authority.py
  tests/test_recovery_contracts.py tests/test_contracts.py`: **69 passed in 4.31s**
  after the correction, exit 0.
- Whole API Ruff checks and `mypy src`: pass, 11 source files at this stage.
- `flutter.bat analyze --no-pub`: **no issues**, exit 0, 52.2 seconds.
- `flutter.bat test --no-pub test/contract_test.dart
  test/recovery_protocol_v2_test.dart test/transport_test.dart test/sync_test.dart`:
  **39 passed**, zero failures/skips, exit 0, 17 seconds reported by runner.

Next unfinished requirement: database admission ordering, additive private
metadata, and real PostgreSQL component coverage.

## Iteration 5: PostgreSQL admission fence and additive metadata

Added Alembic `0004_recovery_protocol.py` without changing 0001-0003. It creates
private global control (no automatic row/activation) and forced-owner-RLS
`recovery_owners` / `recovery_attempts` with tenant-aware hold/attempt constraints,
provenance and publication metadata. It does not relabel legacy receipts. Unsafe
downgrade raises and requires compatible forward repair. Temporary requests are
primary-private metadata only, never independent backup.

Added `recovery_db.py`. Normal tenant transactions take the shared DRP2 advisory
lock before state reads, with explicit READ COMMITTED by default. The two-int lock
namespace is disjoint from existing single-bigint owner advisory locks. Operator
close takes the exclusive lock and closes only an existing control row in a short
READ COMMITTED transaction; only its commit establishes a fence. Runtime receives
SELECT-only control access; role validation rejects control writes, truncation,
trigger privileges, schema creation and owner membership. Readiness requires
revision 0004 and the two new private tables. No runtime reopening exists.

The capability release retains original v1 behavior only before any recovery
control is installed. Any installed CLOSED/RECONCILING/uncertified OPEN state
denies all ordinary v1 payload/effect/initialization paths with a recovery error,
before account-state errors or receipt consumption. A copied OPEN row never
activates anything. Full authority-backed v2 admission/publication is not yet
implemented; this denial is not a substitute for the required B0-B6 path.

Updated local fixtures and the uninvoked staging preparation code for revision
0004, 13 forced-RLS training tables and narrow control grants. Existing recovery
tests still check the original 11 payload tables nonempty; the two new metadata
tables have separate tests. The historical investigation/specification/ADR files
are unchanged. No operator provisioning, migration or SQL ran against an existing
user/staging/production database.

Added PostgreSQL component tests in `test_recovery_protocol_v2.py` and explicit
`tools/run_recovery_v2_local.py --run-local --pg-bin ...`. The runner allowlists
process environment variables, supplies no inherited DM/libpq/provider secrets,
creates owned local clusters, verifies JUnit presence/modules/zero failures/skips,
and writes a receipt explicitly stating **not full protocol qualification**.
Its optional full Python run supplies legacy destructive fixtures only the URL
of a newly created owned cluster. RC10/RC11 remain NOT EXECUTED.

- Ruff formatting/checks and `mypy src`: pass, 12 source files.
- Explicit local component launcher, attempt
  `9190231587904b47bb298fbf716601f4`: **57 passed in 45.71s**, zero failures/skips,
  child and wrapper exit 0. JUnit/log/receipt are retained under
  `.tools/recovery-v2-attempts/9190231587904b47bb298fbf716601f4/`.
- This includes ten actual PostgreSQL cases. The barrier test observes a real
  waiting exclusive advisory lock in `pg_locks`, then proves the prior domain
  transaction finishes and late requests deny. Other cases cover control/error
  ordering, failed close rollback, unsupported close isolation, restricted grants,
  pooled tenant reset, forced RLS and unchanged legacy receipt shape. These do not
  constitute all PG01-PG22 or certification/restore qualification.
- Full Python/old recovery/connected Flutter run started as attempt
  `e9f85cac1bce432d94282cc6e664500b`; final result pending. Do not report it passed
  until its terminal receipt/JUnit is inspected.
- Documentation check: 43 Markdown files, 470 links and 5 JSON examples; exit 0.
  `git diff --check`: exit 0 at this iteration.

Next unfinished requirement: inspect the full regression result, repair any
defects, test populated-0003 migration explicitly, then complete transactional
client lineage/migration and the authority-backed server publication pipeline.

## Iteration 6: full regression failures investigated and corrected

Full attempt `e9f85cac1bce432d94282cc6e664500b` terminated with **295 passed,
four failed, zero skipped** (299 cases, 138.516s JUnit). It was not accepted as
success. Failures and corrections:

1. The old retirement-downgrade test expected the 0003 guard message, but 0004 now
   refuses the downgrade first. Updated that test to require the new refusal and
   unchanged database fingerprint; added separate populated-0003 testing that
   still exercises the original 0003 retirement refusal before upgrading.
2. A runtime-role test hardcoded `dm_admin`, absent in the disposable native lab.
   It now queries and correctly quotes the actual workout-table owner, grants
   membership, proves denial, and revokes it in `finally`.
3. Two stale-password tests correctly failed because the fresh full-suite cluster
   used loopback trust. The launcher now installs a SCRAM rule for the synthetic
   staging runtime in its own generated HBA file, reloads that owned server and
   actually exercises correct-password success and stale-password rejection.
   The assertions were not weakened. Other local synthetic lab roles retain
   trust; no hosted authentication/TLS qualification is inferred.

Added explicit populated 0003→0004 preservation of normalized workout values,
receipt digest/acknowledgement, feed, retirement IDs and absent-owner retirement;
all old row fingerprints remain identical, new provenance tables stay empty and
no control/activation is invented. Added a partial unique index plus actual
PostgreSQL rejection of a second active attempt for one owner.

Strengthened the evidence reducer to reconstruct each checkpoint from complete
PREPARED/optional UNRESOLVED/CERTIFIED bindings when loading state. A removed
certificate cannot leave a plausible IDLE head. This catches internally
inconsistent metadata; it does not claim independently fresh/nonrollbackable
storage or universal rollback detection. The authority test suite now has 41
passing rule/conformance cases.

- Corrected full attempt `861a504cb5474e1ab03479a4b019894f`:
  **302 passed in 141.85s, zero failures/errors/skips**, wrapper and child exit 0.
  JUnit confirms the actual recovery and connected Flutter wrapper modules/case;
  the existing connected guard requires all nine live HTTP cases and final
  machine success. All database resources were newly generated local labs with
  verified cleanup in fixture teardown/launcher callbacks.
- `ruff format --check .` in API: **46 files already formatted**, exit 0.
  API Ruff lint passes and `mypy src` passes for **12 source files**.
- New launcher unit checks cover removal of provider/libpq/pytest overrides and
  hard failure before subprocess/resource work for absent local opt-in, missing
  PostgreSQL executables, or missing explicit Flutter/cache for full regression.
  `python -m unittest discover -s tools/tests -v`: **17 passed**, including four
  new launcher cases, exit 0.
- Full ordinary `flutter test --no-pub --machine` is currently running with
  output retained in the successful attempt directory as `flutter-ordinary.jsonl`.
  It must be polled to terminal and its final machine success inspected; skipped
  connected/hosted-only cases in this ordinary run cannot count as passes.
- Rechecked specification/ADR fingerprints: both still match the initial hashes.
  `git diff --check` passed before this documentation update.

The full B0-B6 server path, complete retirement replay/cutover, Drift lineage
migration, historical-result client persistence and all named PG/SQ/RC oracles
remain unfinished. The goal is active; the passing suites above prove the stated
component/regression scope only.

## Iteration 7: client provenance, migration failure and actual process loss

Before the client-schema change, ordinary Flutter completed with **187 passed,
12 explicitly skipped**, final machine `success: true`, exit 0 (118.4s machine
clock). Those skips are not passes. OpenAPI, Dart DTOs/limits and Drift generation
then reproduced four byte-identical files; build_runner completed in 51s with
129 outputs. These results describe that earlier source state; verification was
restarted after the following client changes.

Added Drift schema 4 metadata for wire version, immutable outbox origin,
acknowledged/shadow context, local recovery requirement/high-water and future
historical evidence. No original operation/frozen-body blob is rewritten.
Added internal `RecoveryContext` persistence and monotonic owner/environment/
activation/head/epoch validation. Once explicit V2 negotiation requires it,
new local roots capture verified context atomically with projection/outbox;
pending successors inherit their actual predecessor, including unknown origin.
Clean existing roots require their own certified shadow context. Downloading new
context never restamps an old/unknown branch. Old/unknown heads remain quarantined
and independent new roots can prepare schema-2 commands. V1 receipts/pull/bootstrap
cannot update a V2-required store. No application V2 transport or endpoint is yet
enabled; these are persistence/admission components, not complete V2 sync.

New file-backed tests preserve every original v3 row and blob through 3→4,
including acknowledged history, sent/unsent commands, drafts, timers, conflicts,
cursor, stage/pages and projections. Existing 1/2 migration tests now reconstruct
their actual older layouts by removing only the additive v4 metadata first.
Newer databases are refused without lowering `user_version` or losing data.

The first DDL-fault fixture used a table-name collision, but Drift's
`CREATE TABLE IF NOT EXISTS` did not fail; that test correctly failed its
expected-exception assertion. A verified SQLite index-name collision then forced
the last CREATE to fail and exposed a **real partial migration**: earlier ALTER
columns remained while `user_version` stayed 3. That regression failed with
`Expected false, Actual true: Failed migration must roll back every earlier ALTER`.
Fixed creation/upgrades by wrapping all DDL and the schema-version write in one
SQLite transaction. The strengthened fault test passes after close/reopen.

Missing recovery control now conservatively requires V2 instead of silently
returning to v1. New and legacy-upgraded schemas seed their original pre-activation
state within the migration transaction. Unverifiable context/origin never prevents
otherwise valid local training: the original bytes/predecessor are retained,
new unverifiable intent is quarantined, and upload attention is separate from
local durability. No maintenance response invokes account erasure.

- Initial persistence / existing sync-recovery / timer run: **48 passed**.
- After transaction fix: **49 passed in 32s**, zero failures/skips. A focused
  recheck of seven persistence cases also passes, including an explicit newer-
  schema refusal reason. Five analyzer style findings were corrected; analysis
  then had zero issues.
- After adding malformed/missing-metadata and frozen-body write-fault cases:
  `flutter test --no-pub test/recovery_persistence_test.dart
  test/process_kill_test.dart`: **16 passed in 25s**, zero failures/skips.
  This includes ten file-backed persistence cases and six actual OS-kill cases
  (v1/v2 × before/during/after commit). Reopen checks preserve exact frozen body,
  origin/wire version, outbox, performed sets and pending draft; SQLite integrity
  and foreign-key checks pass in the kill harness.
- Fresh full Python/restore/connected run against client schema 4 is active as
  attempt `f7abbaedf7a6497fade4244501bdb291`; do not report it passed until its
  terminal receipt/JUnit is inspected. Full ordinary Flutter will run afterward
  to avoid two concurrent Flutter test compilers writing the same package cache.

Next unfinished requirement after verification: the authority-backed server
B0-B6 implementation and versioned certified response/publication contracts,
then client historical/pending result installation and complete replay/cutover
oracles. Provider, custody, independent review and policy decisions remain open.

Specification O1-O12 remain unresolved decisions, including real independent
authority selection, actual target/containment proof, committed-marker and abort
proof acceptance, lifecycle retention, RPO/RTO, compatibility/adoption policy,
initial inventory, custody/costs, independent security review and exact hosted
drill approval. They must remain visible; local implementation authorization does
not resolve those choices or qualify provider/custody behavior. They do not
justify skipping safe, clearly specified local work once its target is known.

## Iteration 8: canonical identity, recoverable outcomes and isolated history

The full client-schema-4 regression in attempt
`f7abbaedf7a6497fade4244501bdb291` completed with **302 Python passes**, zero
failures/errors/skips, including real disposable PostgreSQL recovery and the
wrapper executing nine connected Flutter HTTP cases. Its ordinary Flutter
machine report completed successfully with **200 passed and 12 explicit skips**.
The skips are not passes or device/provider qualification.

A validation probe then found that schema-2 UUID parsing could normalize uppercase
or braced input and `2.0` could become version `2`, changing a frozen command's
canonical identity. Schema-2 now requires canonical lowercase hyphenated UUIDs
and an actual integer version. Schema-1 behavior is unchanged. Added 21 Python
negative cases and Dart parity assertions; regenerated OpenAPI/transport schemas.
Focused contracts/evidence/authority checks: **91 passed**, and Dart contract
checks: **4 passed**. Full attempt `6403ae203974407292565081f6123ce7` then
completed with **323 passed in 140.470s**, zero failures/errors/skips; its actual
connected Flutter wrapper is present in JUnit.

Section 5 required more than a result hash. Independent evidence now includes a
minimal immutable deterministic accepted/conflict/rejected workout outcome,
revision/time or closed domain error code, schema 2, and digest binding. It never
includes a workout projection, set values, notes, raw command or credentials.
Rejected/conflicted results cannot claim private-feed or retirement effects;
accepted results require a positive private position. File-backed authority
restart recovers all three original outcomes without primary receipts/payload.
Corrupt result/digest pairs fail closed. This remains internal evidence modeling,
not a selected certificate format, trusted observer or custody claim (O1/O3).

The first focused run was **40 passed, 1 failed**: an existing negative fixture
changed the root while retaining a now-invalid result digest, so construction
correctly failed before its later certification assertion. Corrected that fixture
to provide a consistent changed-root digest and still assert denial against the
original preparation. Outcome rules/restart checks then passed **54 cases**.
Review additionally found attempt UUID reuse across different certified mutations;
the reducer now rejects it both on preparation and persisted-state loading.

The client has an internal `recordHistoricalResult` persistence boundary for a
future already-verified transport. It validates exact owner, environment, original
lineage, frozen M/body digest, root, result/revision and original context. It stores
historical evidence separately and idempotently, rejecting changed facts. It
never acknowledges the outbox, advances a shadow/cursor, unblocks successors,
rebases work, changes projections or erases drafts/timers. It does not authenticate
certificates or enable a public V2 transport. Three file-backed cases cover each
terminal status, two pending successors, reopen/retry, unchanged row snapshots,
signed-out/wrong-owner stale callbacks and an actual SQLite insert-fault trigger.
All **13 persistence tests passed in 13s**; Flutter analysis had zero issues (4.5s).
A first test invocation caught one extra parenthesis in the new fixture; corrected
before execution. Final negative callbacks are awaited sequentially.

Commands used (API commands use the task's Python 3.13 venv; Flutter commands use
the pinned workspace SDK with task-local TEMP/TMP and the documented Pub cache):

- `python -m pytest -q tests/test_recovery_evidence.py tests/test_recovery_authority.py`
- `python -m ruff format --check services/api tools`: 58 files formatted.
- `python -m ruff check services/api tools`: pass.
- API `python -m mypy src`: pass, 12 source files.
- `python -m unittest discover -s tools/tests -q`: 17 passed.
- `flutter test --no-pub test/recovery_persistence_test.dart`: 13 passed.
- `flutter analyze --no-pub`: zero issues.
- `python tools/run_recovery_v2_local.py --run-local --pg-bin
  E:/Motion/Daily-Motion-worktrees/recovery/.tools/postgres/pgsql/bin
  --full-python --flutter E:/Motion/Daily-Motion/.tools/flutter/bin/flutter.bat
  --pub-cache E:/Motion/Daily-Motion/.tools/pub-cache`: new owned-resource attempt
  `bab162865afb411199e2c4698b5d4ed0` in progress; outcome pending inspection.

Updated requirement checklist (partial items above remain open):

- [x] Minimal terminal outcome metadata and digest validation, including rejected
  and conflicted outcomes; local restart and corruption tests.
- [x] Internal historical persistence preserves frozen working branches,
  successors and every live-state row; local restart/owner/write-fault tests.
- [ ] Trusted certificate format/observer and full B0-B6 implementation.
- [ ] Generated reviewed V2 result contracts and authenticated transport,
  certified current acknowledgements/echo/bootstrap and connected races.
- [ ] Complete retirement/lifecycle/high-water replay and cutover containment.
- [ ] Full named PG01-PG22, SQ01-SQ10, RC01-RC12 qualification/completion guards.
- [ ] Current generated reproduction, broad final checks and complete diff review.

The next unfinished safe task is to strengthen named-case/completion reporting
so partial component passes cannot be mistaken for the specification's full
qualification. O1-O12 still block the specified production/provider/review choices;
no activation, provider access or approval bypass is authorized or performed.
The goal remains active and incomplete.

## Iteration 9: completion guard, SQ08 and review corrections

Attempt `bab162865afb411199e2c4698b5d4ed0` completed **336 Python passes in
144.690s**, zero failures/errors/skips. Collection preceded the final attempt-UUID
uniqueness case; the latest focused evidence/authority run separately passed
**55 cases**. Its full ordinary Flutter machine report completed with **203 passes,
12 explicit skips**, zero error events and final `done.success=true` (97.259s).

Added `tools/check_recovery_v2_results.py`. It reads all 44 exact names/IDs from
the unchanged specification, requires coherent zero-skip JUnit completion and
matched Flutter start/done identities with a successful final machine event,
and checks names in their specified test modules/files. Missing/wrong/hidden
cases, failed/skipped/incomplete results, duplicate identities and missing final
completion cannot count as coverage. The guard never qualifies the protocol or
provider: RC10/RC11 remain NOT EXECUTED, and claiming those cases through an
ordinary local report is refused. Guard/tooling regression: **24 tests passed**.
This validates reports, not test-oracle adequacy or independent review.

The first real guard invocation rejected a valid Flutter daemon envelope
`test.startedProcess` interleaved as a JSON array. Inspection identified the
specific frame; the parser now accepts only that known non-result envelope and
blank lines. It still rejects arbitrary arrays or hidden failed result frames.
A real-frame regression covers both paths; no archived report was edited.

Added exact named SQ08 `test_authority_auth_failure_does_not_block_training`.
Deterministic Completers hold an actual loopback HTTP response and then token
refresh separately. File-backed set recording/correction, completion, draft and
history operations finish before either barrier is released; no sleep or network
latency is used as evidence. Restart preserves the exact V2 frozen body, four
pending commands, performed values and draft; integrity/foreign-key checks pass.
Recovery components plus SQ08: **7 passed**. The resulting exact-case assessment
records **SQ08 present, 41 named local cases missing**, RC10/RC11 NOT EXECUTED,
full qualification false. The earlier six-case report correctly credited none
of the exact names; component tests are not relabeled as complete PG/SQ/RC cases.

Review found Python's V2 expected revision had no upper bound while Dart rejected
values outside signed 64-bit range. V2 now shares that checked bound; v1 is
unchanged. Four Python boundary cases and matching Dart invalid-value assertions
were added, with OpenAPI/transport regeneration. Focused Python recovery
contracts/evidence/authority: **87 passed in 6.59s**. Flutter contracts and recovery
cases: **11 passed**, followed by zero analyzer issues (4.5s). A new full owned-
resource regression `2aa4fe38266f48259ae3f6df6f80d18b` is running against this
revision-bound correction; its receipt must be inspected before claiming success.

Generated-artifact review before the final revision-bound correction reproduced
all four files byte-for-byte: OpenAPI, Dart transport schemas, Dart transport
limits and Drift database output. `dart run build_runner build` succeeded in 8s;
`dart format --output=none --set-exit-if-changed lib test` checked 66 files with
zero changes. Ruff checked 60 Python files; lint and strict API mypy passed.
Native static guards passed; credential scan checked 292 files with zero findings;
docs validated 43 Markdown files/473 local links/5 JSON examples. Final checks
will be refreshed after the current test addition.

Preservation recheck: specification and ADR hashes still match the initial
fingerprints. Both original characterization sources and both original archived
artifacts exactly match their saved receipt hashes. Main worktree status remains
only the user's `.agents/` and `skills-lock.json`. No staged files, commit,
external operation, activation or production mutation occurred.

The next unfinished requirement is SQ10: missing/corrupt protected grants and
explicit sign-out must not guess an owner, expose/reassign existing work or permit
a stale grant to undo sign-out. A new exact named file-backed test is prepared
with controlled identity/protected-storage fakes; it is not passed until its
execution completes. Real device secure storage remains separately unqualified.
Server B0-B6, certified transport/bootstrap, full replay/cutover, remaining named
cases and the O1-O12 decisions remain outstanding. The goal remains active.

## Iteration 10: SQ10 and current regression evidence

Added exact named SQ10 `test_grant_loss_and_signed_out_owner_not_guessed`.
It exercises missing and corrupt protected owner grants and explicit sign-out,
then A-to-B-to-A and replay of an old unlocked grant after logout. The account
controller cannot select an owner, attach cloud synchronization or expose the
old file without a matching verified identity. Owner B has a separate empty file
and cannot see A's outbox, cursor or draft. A's performed work, exact frozen V2
command, pending successor, draft, cursor and bootstrap stage survive. A stale
protected grant cannot override the SQLite sign-out lock. Provider/protected
storage are controlled fakes; actual owner persistence is file-backed SQLite.
No device secure-storage or real OTP qualification is inferred.

The first run passed all eight local recovery cases but Drift warned about
multiple database-class instances during forensic inspection of A while B was
open. Replaced the inspection fixture with an explicitly read-only native SQLite
handle rather than suppressing the warning. The machine rerun again passed
**8 cases in 12.910s**, with final success. The following analyzer found one missing
brace in the test fixture; added the brace and re-ran analysis: **zero issues in
4.0s**. Format checked 66 files with zero changes. No functional code changed
after the broad test completion.

Final inspected evidence for this iteration:

| Command / report | Actual result |
| --- | --- |
| Owned-resource launcher full Python attempt `2aa4fe38266f48259ae3f6df6f80d18b` | **341 passed in 135.678s**, zero skipped/errors/failures; existing recovery plus actual nine-case connected Flutter HTTP wrapper present |
| Same attempt `flutter-ordinary.jsonl` | **205 passed, 12 explicitly skipped**, zero error events, final success; 101.721s |
| Same attempt `flutter-named-local.jsonl` | **8 passed**, zero skips/failures; contains exact SQ08/SQ10 names |
| Exact-case guard assessment | SQ08/SQ10 present; **40 local named cases missing**, RC10/RC11 NOT EXECUTED; full qualification false |
| `python -m unittest discover -s tools/tests -q` | **24 passed** |
| Ruff format/check, strict API mypy | Pass; 60 Python files formatted, 12 API source files checked by mypy |
| `flutter analyze --no-pub` | Zero issues after the fixture brace fix |
| OpenAPI export + transport generation + formatting, comparison with captured hashes | All four generated artifacts reproduce exactly, including final revision-bound schemas; Drift output unchanged from its successful rebuild |
| `python tools/check_native_config.py` | Static native guards pass; no native compilation/device qualification this session |
| `python tools/check_secrets.py` | 292 source files, zero findings before adding the metadata-only evidence index |

Added a local repository evidence summary at
`docs/evidence/recovery-protocol-v2-local-2026-10-22.json`.
It records report hashes, immutable source-document hashes, changed code hashes,
actual counts and explicit incomplete/NOT EXECUTED flags. The ignored capture
helper refuses to overwrite an existing evidence summary. Implementation docs
now link the summary and reflect actual current results, replacing earlier
pending/stale counts.

Diff review covered API contracts/runtime/readiness/grants, additive migration,
evidence state/result bindings, client migration/provenance/legacy guards and
historical storage. No accepted ADR or original migration was changed; no live
V2 admission/certification/activation is enabled. Capability-only v1 behavior
before recovery control installation is explicitly limited to the pre-activation
release described in specification section 10; it must not be represented as
recovery-safe admission or used to reopen a restored target.

Checklist for the next iteration:

- [x] SQ08 exact local availability case and SQ10 exact grant/isolation case.
- [x] Current full local Python/ordinary Flutter/connected/static checks with
  pass/skip distinctions and generated-file reproduction.
- [x] Report guard correctly refuses full qualification from these components.
- [ ] SQ01: compose the actual OS-kill and failed-freeze/reopen coverage into the
  complete exact named origin/projection/outbox atomicity case; preserve existing
  worker/test evidence and assert frozen identity across every boundary.
- [ ] Remaining SQ cases, complete server B0-B6 and certified response/transport/
  publication/initialization, replay/cutover and PG/RC test oracles.
- [ ] O1-O12 provider, trust-proof, lifecycle/RPO, compatibility, custody and
  independent review choices; no production adapter or hosted drill assumed.

The next unfinished safe requirement is SQ01. The goal remains active; this
iteration's regression success is not full Recovery Protocol V2 completion.

## Iteration 11: exact SQ01 hard-kill and freeze atomicity

Extracted the existing hard-OS-kill assertions into
`apps/mobile/test/support/process_kill_harness.dart`, retaining all six original
v1/v2 before/during/after-commit test cases and their names. The harness still
kills the actual SQLite worker PID, drains inherited pipes, reopens the real file
and asserts projections, local revision, outbox count, origin and exact frozen
body/ID, draft, SQLite integrity and foreign keys. No old characterization code
or receipt was edited.

Added exact SQ01 `test_origin_projection_outbox_atomic_restart`. It executes five
real V2 kill boundaries: before/during/after commit and during/after frozen-body
persistence. During-freeze uses an actual BEFORE UPDATE SQLite trigger that
signals the parent and blocks inside the write transaction. The restarted store
has an unfrozen original operation, then freezes the exact original bytes.
Also injects real insert/freeze abort triggers and reopens after each failure:
failed initial save leaves no projection/child/outbox rows or false durable save;
failed freeze preserves every original outbox field and retries without changing
M/body/origin. Unsafe worker boundary names are rejected explicitly.

`flutter test --no-pub test/process_kill_test.dart test/recovery_protocol_v2_test.dart`:
**15 passed in 33s**, zero failures/skips. This includes the six existing hard-kill
tests and nine local recovery cases; SQ01 itself executes five additional worker
kills plus the local SQLite failure/reopen cases. `flutter analyze --no-pub`:
**zero issues in 4.6s**. Production/API source is unchanged since the 341-pass run.
The iteration-10 machine-readable index remains evidence for its captured source;
it is not overwritten or relabeled as evidence for this later test extraction.

Next unfinished safe requirement: SQ06's complete named migration case across
supported schemas 1/2/3 with sent/unsent bytes, draft/timer/conflict/stage retention
and atomic failed DDL/reopen. Existing component migration tests provide parts
of that coverage; the exact combined case is still pending. Full protocol
qualification and the remaining authority/certification/replay work remain open.

## Iteration 12: complete local SQ06 migration arrangement

Added exact SQ06 `test_legacy_schema_migration_preserves_all_bytes` and a controlled
test-only legacy-shape helper for schemas 1/2/3. Each newly owned file contains
an acknowledged legacy create, frozen sent and unsent pending commands, performed
sets, draft, timer and conflict. Schemas 2/3 retain actual staged manifest/page
bytes; schema 1 predates those tables and correctly creates empty staging on
upgrade. No nonexistent legacy feature is reported as retained.

For each old schema, a real index-name collision forces the final recovery DDL
to fail. After close/reopen, old user_version, columns and every original row
remain unchanged, including rollback of the earlier schema-1 ALTERs. Removing
only the owned fault index permits normal upgrade; every old column/value and
serialized blob is compared exactly against its pre-upgrade row. The test then
negotiates V2, verifies unknown legacy provenance is never invented, blocks the
old frozen branch/stage activation and reopens again with drafts/pending bytes
intact. Integrity and foreign-key checks pass for all three versions.

`flutter test --no-pub test/recovery_protocol_v2_test.dart --plain-name
test_legacy_schema_migration_preserves_all_bytes`: **1 passed in 7s** (three
schema/failure/reopen arrangements). `flutter analyze --no-pub`: **zero issues
in 4.2s**. No API/production behavior changed. Broader post-extraction Flutter
and updated exact-name machine evidence remain to run after this test iteration.

Next safe requirement is SQ02's late historical result after an already installed
new external shadow. The test can seed that valid current shadow at the internal
verified persistence boundary; this does not stand in for the still-missing
certificate verification/transport or server B0-B6 implementation.

## Iteration 13: exact SQ02 and prerequisite boundary

Added exact SQ02 `test_historical_receipt_keeps_working_branch_and_successors`.
The fixture seeds a schema-valid already installed external shadow on fresh I/G
at revision 7 while retaining an old frozen create and two local successors.
The subject is the implemented internal historical persistence boundary, not
certificate authentication or bootstrap transport. The late original accepted
result and exact retry survive reopen in a separate history row. Complete live
row snapshots remain identical; the shadow stays at its original new context/
payload/revision, outbox stays pending with no accepted context/revision, both
successors stay unfrozen, and performed values/draft remain usable. No current
acknowledgement or automatic branch resolution occurs.

The first targeted invocation failed compilation because the fixture imported
the validation support module rather than the generated `validateTransport`
entry point. Corrected the import, retaining schema validation of the external
fixture. The exact SQ02 run then **passed in 1s**.

Remaining safe-independent-work audit: full B0-B6 admission/certification needs
O1/O2/O3's chosen authority, authenticated freshness/actual target verification
and approved committed-marker verifier/certificate representation. Specification
section 14 explicitly lists O3 as blocking B4/B5 implementation, O5 as blocking
ledger/lifecycle retention, O7 as blocking contract/migration rollout and O8 as
blocking first activation. O11's independent security review remains unavailable
and has not been retried or bypassed. Complete publication/echo/current-result/
bootstrap, lifecycle replay and the corresponding remaining PG/SQ/RC cases cannot
be truthfully qualified by calling every request closed or inventing certificate
trust/policy. Internal fixture successes are not substitutions for those paths.

Asked asynchronously whether an accepted decision/review document resolves
O1-O3/O5/O7/O8/O11 and requested a local path if it exists. The proposed ADR and
specification are still unchanged; no accepted choice is inferred from broad
implementation authorization. The question is pending. No resource creation,
hosted operation, unapproved trust proof or activation follows from elapsed time.
Final post-extraction local verification and preservation review continue while
waiting. This is the first explicitly recorded prerequisite-impasse audit in
this continuation; do not mark the active goal complete or assume the repeated-
blocker threshold has been satisfied merely from elapsed time.

Iteration-13 verification completed:

- New owned report directory: `.tools/recovery-v2-attempts/iteration13-flutter-20261022`.
  `flutter test --no-pub --machine test/recovery_protocol_v2_test.dart`:
  **11 passed**, zero skipped/failed, final success (39.820s).
- `flutter test --no-pub --machine`: **208 passed, 12 explicit skips**, zero
  failures/error events, successful final completion (109.686s).
- Format: **67 Dart files, zero changes**. Analysis: **zero issues in 4.8s**.
- API remains unchanged from the **341-pass, zero-skip/failure** owned-resource
  run. Strict mypy recheck passes all 12 source files; API Ruff format/check pass
  (46 API Python files). Tooling tests remain **24 passed**.
- Exact named-case guard credits **SQ01/SQ02/SQ06/SQ08/SQ10**, lists **37 local
  named cases missing**, and keeps RC10/RC11 NOT EXECUTED. Full qualification is
  false. Component coverage is not relabeled as missing PG or RC qualification.
- Added `docs/evidence/recovery-protocol-v2-local-2026-10-22-iteration13.json`
  with current test-code/report hashes; the iteration-10 summary remains intact.
  Normalized only the two extracted, owned test helpers to repository LF endings;
  no functional change followed full test execution.

Final prerequisite question remains pending; silence does not resolve the
specification's technical/security decisions. No provider, certificate proof,
lifecycle policy, reviewer acceptance or activation has been invented. No commit,
push, deploy, external access, real-account erasure or existing-project-data
mutation was performed. The active goal is incomplete, with reviewable local
changes and explicit evidence rather than a full-protocol success claim.

Final preservation/report check also passed: every current code/report fingerprint
in the iteration-13 index matches disk, API fingerprints match the 341-pass source,
both protected document hashes match the initial inventory, and both original
characterization sources/artifacts match their original receipt. All four
reproduced generated-file hashes are unchanged. Documentation check: 43 Markdown
files, 474 local links, 5 JSON examples. Credential scan: **295 source files,
zero findings**. Tooling: **24 passed**. Final Dart format: 67 files, zero changes.
`git diff --check` passes; no staged changes. Main's only status entries remain
the original user-owned `.agents/` and `skills-lock.json`.

## Iteration 14: revalidated safe path and B1 reservation implementation

The previous goal turn made implementation/verification progress. Revalidation
found that the remaining technical decisions do **not** block every unambiguous
implementation task: B1 reservation and B3 effect transactions can be developed
behind the existing internal verified-adapter boundary without choosing a
production authority, target proof or O3 certificate/verifier. The earlier
prerequisite-impasse assessment was too broad. This turn therefore makes concrete
progress; do not count it as an impasse-only turn or mark the goal blocked.
The decision-document question remains relevant to dependent publication/
activation choices, not a reason to stop all local implementation.

Added `services/api/src/daily_motion/recovery_admission.py` with internal B1
reservation for already initialized owners. No public route or production
adapter calls it. Its Admission value is explicitly not authentication: a future
approved adapter must supply authenticated request/owner/activation assertions
and actual target verification outside transactions. A copied OPEN row, header
or constructed value does not become production trust by this implementation.

The transaction explicitly requires READ COMMITTED, takes the shared recovery
fence, checks restricted runtime grants and fresh pinned OPEN control, binds
owner/nonce/target/activation, then locks fresh owner state, owner recovery metadata
and the attempt in order. Cached ORM state is refreshed after waits. It validates
E/I/G, complete Q/digest, erasure bounds and P=V before a new reservation. Missing
account/recovery inventory is never initialized, and locally retired/deleting
owners are denied without a fabricated account-erasure response.

Canonical schema-2 bytes, original M/D/E/I/G, expected prior checkpoint and stable
T are persisted in an owner-private request record together with the owner hold
in one transaction. Exact retries return the same T/body, including after an
independent PREPARED response was lost. The known computed PREPARED checkpoint
can be recognized; arbitrary divergent/newer heads cannot repair/reset the DB
anchor. A competing root stays pending behind the known owner attempt. No
projection, feed, terminal receipt, certificate or success is created at B1.
Retained primary receipts without verified V2 attempts are digest-checked and
quarantined; they cannot permit replay or manufacture missing payloads.

Expanded disposable PostgreSQL component tests cover actual reservation/hold
atomicity, B2 response-loss retry, three old-origin fields, nonce/target/owner/head/
close denials, digest mismatch, competing roots, stale ORM account state,
unsupported isolation, missing inventories, local retirement, exact concurrent
requests and legitimate independent owners with RLS isolation. A real trigger
failure after the attempt INSERT aborts the hold UPDATE; both roll back and the
same frozen request can subsequently retry. Independent authority calls in tests
close before PostgreSQL transactions begin. Target identity/owner inventories
are explicit owned-lab fixtures, not provider or initial-inventory qualification.

Observed verification and corrections:

- Initial new component run `3b9c9a5713a34679ac50f28d1673ef0a`:
  **111 passed in 43.75s**, zero skips/failures.
- Initial mypy found RowMapping's wider key typing; passing a plain copied mapping
  to the storage decoder corrected it. Ruff found one import ordering and one
  long fixture SQL string; both corrected. Static checks now pass.
- Expanded run `f3aba61a9c704816b6df0d285c030088`: **115 passed, 1 failed**.
  The missing-application-owner fixture tried deleting the owner before its real
  profile FK. Corrected the fixture to remove that synthetic profile first; no FK
  or runtime constraint was weakened.
- Corrected expanded run `041c920e45c34b438fbd6c7dbd5a825a`:
  **116 passed in 40.21s**, zero skipped/failed. It includes actual concurrent A/B
  reservations and owner-private reads, not only a case label.
- Pure evidence/authority regression after separating assertion identity binding
  from complete checkpoint admission: **55 passed in 6.88s**.
- Added two final retained-receipt replay-denial cases. Current full Python/
  connected run `34ea8ae1295540f3bc7366fd96a14205` is live (session 93993);
  its outcome is pending terminal receipt/JUnit inspection.
- Ruff format/check pass; strict mypy passes **13 source files**. No mobile,
  generated contract, migration, specification or ADR changes in this iteration.

Next unfinished requirement is B3: under the same ordered locks, require the exact
independent PREPARED binding and atomically commit domain changes, private feed,
pending deterministic receipt and immutable result marker while retaining the
owner hold. Reuse existing domain validation; never emit success or advance V
before the separate, still unresolved B4/B5 trusted certification/publication.

Iteration-14 terminal verification:

- Full owned-resource run `34ea8ae1295540f3bc7366fd96a14205` completed with
  **360 passed in 176.450s**, zero skipped/errors/failures; its terminal receipt
  reports child exit 0 and successful component checks. Existing restore and the
  actual nine-case connected Flutter HTTP wrapper are included. The 19 added
  reservation cases are local components, not substitute PG01-PG22 qualification.
- Added `docs/evidence/recovery-protocol-v2-local-2026-10-22-iteration14.json`,
  binding current API source/report hashes to that run. Earlier evidence files
  remain unchanged. All mobile source fingerprints match the prior **208-pass,
  12-explicit-skip** full Flutter run, so that unchanged source's evidence is reused
  explicitly; the connected HTTP wrapper was freshly executed with the new API.
- The exact-name assessment still credits five SQ cases, leaves 37 local named
  cases missing, and marks RC10/RC11 NOT EXECUTED. No public V2 admission,
  certification, activation, device or independent-review qualification is claimed.
- The full B3 implementation remains the next actionable requirement. O3 does
  not prevent implementing that private atomic effect/marker boundary; the
  accepted certifier decision will be required before implementing B4/B5 trust
  and enabling publication. The goal remains active and incomplete.

Post-run review verified every iteration-14 source/report/protected-document
fingerprint against disk, plus the original characterization sources/artifacts.
Original migrations 0001-0003 have no diff. Main still contains only the original
user-owned untracked entries. Docs: 43 Markdown files/474 links/5 examples;
credential guard: 297 files, zero findings; Ruff: 61 files formatted and lint
clean; `git diff --check` clean and no staged changes. No commit/deploy or
production/external operation occurred.

## Iteration 15: B3 private atomic effect and result marker

Previous goal turn classification: progress (B1 implementation and the 360-pass
regression), not a verified wait or impasse-only turn. Inspected current Git
status, B1/recovery/domain implementation, schema, tests and specification section
4 before continuing with the next authorized unambiguous requirement.

Added `recovery_effect.py` for internal B3 and an existing-only reservation
resumption boundary. B3 cannot create a missing B1 record, infer PREPARED from a
primary receipt, replace T/M/D or stamp current origin onto an old command. It
requires the authenticated fresh assertion's exact complete PREPARED checkpoint
for the persisted reservation, then reacquires fresh READ COMMITTED control,
owner/attempt/root locks and validates account/retirement/origin/revision/domain
state. Actual adapter authentication and independently verified unchanged target
continuity remain preconditions of the future adapter, not flags/proofs selected
by this implementation; no public route or automatic restore resumer calls it.

Extracted the existing normalized command rules into `sync.apply_domain_change`
and reused them from legacy accept and B3. Legacy receipt/feed/response behavior
is otherwise unchanged. B3 commits normalized projections/observation revisions,
checked private P, pending receipt, exact minimal terminal result, effect marker
and PREPARED anchor together in a savepoint. A failed write also rolls back if a
caller catches the exception and commits its outer transaction. Accepted,
conflicted and rejected outcomes remain private. The primary receipt contains
only `publication_pending`; exact result lives in the held attempt. V and the
certified erasure high-water never advance at B3; the frozen request and hold
remain until future verified B5 publication.

The marker is an internal immutable result binding, not commit proof or an O3
certificate format. B3 construction inside a transaction cannot authorize
certification. O3 still requires a separate trusted fresh observation after the
original transaction closes. No authority append/network call occurs in B3.

Added a separate `tests/test_recovery_effect.py` with the owned resource fixtures;
the launcher now requires this module in both execution and completion checks.
Initial tests cover missing PREPARED/reservation, one private result, blocked
ordinary reads, exact concurrent retries, post-close denial, deterministic
conflict/rejection without feed effects and real marker/anchor trigger failures
with whole-row rollback/retry. No existing characterization test is changed.

Verification so far:

- Ruff initially found one long SQL line and fixture re-export/import style;
  fixed formatting and used explicit pytest fixture re-exports, not blanket
  disabling of checks. Strict mypy passes 14 source files.
- First B3 owned component run `29fe87aceafe4a9ea34a2340558fb541`:
  **127 passed in 73.27s**, zero skips/errors/failures.
- Added actual record-set observation revision/private-feed, deletion scope/feed
  redaction/snapshot invalidation, three checked counter-overflow cases, nested
  A/B identity isolation and admission-before-close/B3-after-close checks.
- Expanded owned run `22b70124db714719b390f18243e76bd1` is live as session 92414;
  do not report it passed before inspecting its terminal receipt and log.
- Generated contracts, mobile code, migrations 0001-0004, specification and ADR
  remain unchanged during this iteration. Earlier evidence indices retain their
  captured source scope; they are not relabeled as verification of this new B3.

Next: investigate expanded B3 results, add the exact PG04 B3 shared/exclusive
fence ordering case, then run the full Python/restore/connected regression after
the domain-rule extraction. B4/B5, public V2 response transport and complete
replay/cutover remain unfinished; no completion/activation claim is made.

Expanded B3 verification and review:

- `22b70124db714719b390f18243e76bd1` completed with **135 passed in 80.36s**,
  zero skips/failures/errors. It verifies observation revision/G/private feed,
  complete deletion root/exercise/set retirement, historical/feed redaction and
  snapshot invalidation, withheld uncertified epoch/high-water, overflow closure
  with every old row intact, forged nested A/B IDs and pre-arrival admission
  followed by an actual close before B3.
- Review found the new schema should enforce marker/result/origin immutability,
  rather than relying solely on the application state check. Enriched only the
  new uncommitted 0004 migration with effect/result presence constraints and an
  UPDATE guard for original identity/digest/origin/frozen request and existing
  marker/result. No original 0001-0003 migration changed. Future verified
  publication/cancellation may purge only the temporary body in its terminal
  state; this trigger does not authenticate certificates or implement B5.
- Added five actual runtime UPDATE attempts that must fail without changing any
  committed row (marker/result/digest/origin/request). No grant was widened or
  integrity check suppressed.
- Added exact PG04 `test_shared_transaction_orders_before_exclusive_fence` in
  the specification's PostgreSQL module. It pauses the actual B3 domain call
  while shared recovery/owner locks are held, observes the exclusive closer's
  ungranted advisory lock in `pg_locks`, and releases B3 to commit before close.
  A stale pre-close assertion cannot authorize later B3. One private effect,
  receipt/marker and hold remain; V stays unchanged. No sleep is used as ordering
  proof; polling observes the actual PostgreSQL lock wait.
- Result `de3c262cb61c4f2b8c6fafcba1a0b177`: **141 passed in 94.48s**,
  zero failures/errors/skips, including the immutability guard under the real
  restricted runtime role and exact PG04. Ruff/mypy checks pass (14 API sources).
- Current full Python/restore/connected launcher is running after the shared
  domain extraction and schema guard changes. Its terminal receipt must be
  inspected before updating current full-regression claims.

The five previously credited SQ cases remain unchanged. PG04 is newly qualified
for its exact local B3/fence arrangement; it is not proof of B4/B5, actual target
continuity or provider consistency. The goal remains active and incomplete.

The full run `3ccdd109a8124ed8ae9f3a6a39e5ddf4` then completed with **383 passed
in 188.85s**, zero skipped/errors/failures, including restore/connected suites.
Its result precedes the following section-5 review correction and is not claimed
as verification of source edited afterward.

Review against section 5 found an omitted explicit affected-ID binding for normal
accepted commands (only root and retirement scope had been captured). Added an
immutable UUID-only affected scope to the internal marker and its digest: creates
bind root/exercises/sets, observations bind root/exercise/set, root transitions
bind the root, and deletions bind the complete retirement scope. Rejected and
conflicted results cannot claim affected/retired effects. The record stores no
set values, names, notes, credentials or raw commands. Retired IDs must be covered
by affected scope; mutable collections, duplicate/non-UUID values and missing
accepted-root bindings are refused. This is internal semantic metadata, not a
new public certificate format or approved independent verifier.

Updated real PostgreSQL assertions for accepted/observation/deletion/foreign-ID
outcomes and added six malformed-scope reducer cases plus an actual runtime
attempt to rewrite the affected scope of a committed marker. The existing update
guard refuses that change. Adjusted only unreleased local conformance fixtures
to carry the explicit metadata; no production/legacy evidence is rewritten.
Pure evidence/authority regression before the final six extra cases: **55 passed
in 6.45s**. Ruff and strict mypy pass; tooling **24 passed**; 63 Python files are
formatted. The post-correction full run `c408ba0c4c5f48368c74d22a8297f501` is live
as session 92586. Keep its result pending until terminal receipt/JUnit inspection.

Iteration-15 final inspected verification:

- Post-correction full run `c408ba0c4c5f48368c74d22a8297f501` completed with
  **390 passed in 193.358s**, zero skipped/failures/errors. Terminal receipt:
  child exit 0, component checks true, full Python requested true. The existing
  restore suite and actual nine-case connected Flutter HTTP wrapper ran.
- B3's actual private write cases now include the explicit affected scope and
  immutable database binding. The updated evidence/authority/counter guards are
  included in the full regression; no pending process is assumed completed merely
  from an observation timeout, and no test process was restarted due to timeout.
- Strict mypy passes **14 API source files**; Ruff lint and format pass (**63
  Python files**); tooling **24 passed**. Native static guards pass. No native
  compilation, physical-device, provider or independent-review qualification is
  inferred. No mobile/generated-contract changes occurred; the prior 208-pass,
  12-explicit-skip Flutter source fingerprints remain identical.
- Added `docs/evidence/recovery-protocol-v2-local-2026-10-22-iteration15.json`
  with current code/report hashes, prior API/mobile evidence scope and incomplete
  qualification flags. It credits exact PG04 and SQ01/SQ02/SQ06/SQ08/SQ10, lists
  **36 local named cases missing**, and marks RC10/RC11 NOT EXECUTED.
- Diff review confirmed `sync.apply_domain_change` extracts the original domain
  validation/mutation block. Legacy acceptance still owns its original receipt,
  feed and response semantics; B3 uses the shared rules with separate private
  outcome/marker logic. The full old API/domain/restore/connected regressions pass.

Checklist after B3:

- [x] Existing-only, exact PREPARED B3 admission with fresh ordered locks.
- [x] Atomic normalized/observation/root/private-feed/outcome/marker/anchor writes.
- [x] Deterministic accepted/rejected/conflicted outcomes, no new feed on denial.
- [x] Full deletion scope, affected-ID bindings and withheld uncertified epoch.
- [x] Database immutability, failed-write rollback, replay/owner/counter checks.
- [x] Exact PG04 actual B3/shared-lock versus exclusive-close ordering.
- [ ] B4's separately trusted committed observation and external certification.
- [ ] B5 certificate validation/publication/temporary-body purge/hold release.
- [ ] Remaining V2 transport/bootstrap/lifecycle/replay/cutover and named tests.

The goal remains active and incomplete. The next requirement is the B4/B5
certification/publication boundary: continue with unambiguous checks/interfaces
while preserving O3's explicit prerequisite for the trusted verifier/certificate
choice. Do not infer review acceptance, select a provider, certify a merely
prepared/uncommitted value or enable production publication from local tests.

Post-run preservation review verified every iteration-15 code/report hash,
protected specification/ADR hash and original characterization source/artifact
hash. Main remains at its original user-owned status; migrations 0001-0003 have
no diff; no staged changes. Final strict API mypy: 14 sources, no issues; API Ruff
format: 49 files, lint clean (63 Python files across API/tools). Docs: 43 Markdown
files/474 local links/5 examples. Credential guard: 300 source files, zero findings.
`git diff --check` passes. No commit, deploy, provider access or production-data
operation was performed.

### Iteration 16 — old-origin admission and stale-snapshot fence regressions

O3 still explicitly blocks selecting the trusted committed-marker verifier and
certificate format for B4/B5. No answer to the accepted-decision-path question
has arrived. Continue independent PostgreSQL requirements rather than treating
that decision as a block on every remaining core check.

- [x] Add exact PG01: frozen old I/G expected R=2 against divergent current R=2.
- [x] Add exact PG02: old body against divergent current R=1 and R=3.
- [x] Add exact PG05: preload ORM/control reads, observe an actual shared-lock
  wait behind exclusive close, then deny using the fresh READ COMMITTED read;
  explicitly refuse repeatable-read while its stale snapshot still says OPEN.
- [x] Run owned PostgreSQL/full regressions; investigate failures.
- [x] Review evidence, preservation, docs and outstanding next requirement.

Tests arrange the restored branch explicitly in the newly owned PostgreSQL lab;
they do not claim an archive restore, authenticated production adapter or public
V2 HTTP negotiation. All owner tables are compared before/after denial, including
attempts, owner hold, observations, receipts and private feed. The frozen body,
mutation identity and digest remain unchanged. Shared the existing owner-row
snapshot helper between admission/effect tests; no product behavior changed.

Iteration-16 inspected result: full owned run
`f2dd3214bdd44ae0b9a1cc6bb19c5156` completed with **395 passed in 205.690s**,
zero skipped/failures/errors, child exit 0. PG01/PG02 and both PG05 isolation
variants passed. Existing restore tests and the nine-case connected Flutter HTTP
wrapper ran. Named assessment now credits PG01/PG02/PG04/PG05 plus five SQ cases,
with **33 local names missing**, RC10/RC11 NOT EXECUTED. Added the immutable
iteration-16 evidence JSON; its source fingerprints precede iteration 17.
Ruff lint/format passes (63 files), strict mypy passes (14 API sources), docs
43 files/474 links/5 examples, and diff whitespace/protected document checks pass.
No API/migration behavior changed this iteration. Checklist verification and
evidence review completed; goal remains active and incomplete.

### Iteration 17 — historical evidence must immediately require attention

Review against section 8 found that `recordHistoricalResult` stores evidence
atomically, but `attentionCount` only sees existing branch retry errors/conflicts.
A historical result could therefore appear without attention until another
`prepareHead` attempt. This is independent of O3/O7: it uses the existing internal
already-verified history boundary and the existing restrained attention UI.

- [x] Add three restart/fault/idempotence regressions for accepted, conflicted
  and rejected historical outcomes without another upload/prepare attempt.
- [x] Reproduce failure, fix attention derivation from persistent evidence.
- [x] Run focused and full Flutter checks, inspect exact completion/skips.
- [x] Reconcile evidence and remaining independent requirements.

Read-only search note: a Windows glob path passed literally to `rg` returned
os error 123; reran with directory operands and `-g '*.dart' -g '*.drift'`.
No file or project data was changed by that failed search.

Reproduced all three failures with pinned `flutter test --no-pub
test/recovery_persistence_test.dart --plain-name 'immediately needs attention after
restart' --machine`: expected attention 1, actual 0 after evidence commit/reopen;
exit 1, final machine completion false. Saved `flutter-attention-before.jsonl`
and stderr in `.tools/recovery-v2-attempts/iteration17-flutter-20261022`.

Fix: the existing attention query now counts pending roots with a stored
historical receipt as well as existing retry errors. Attention is derived from
the receipt's atomic persistence; no separate flag, network call or schema
change. Pending frozen command bytes/IDs/state, projections, shadows and drafts
remain unchanged, with at most one history attention per pending root.

Post-fix focused file completed with final machine success true/exit 0 (session
25919, 17.801s). Full Flutter followed by the zero-skip named local file is now
live in session 70597; no second Flutter compiler is run concurrently. Results
remain pending until inspected terminal completion.

### Iteration 18 — concurrent read/retry barrier before certification

The next independent requirement is PG10. Added its exact named PostgreSQL case,
parameterized for creation and deletion. After the actual private B3 commit and
before any independent certificate exists, concurrently request pull, `/me`,
exact duplicate and initialization. Assert safe recovery/pending denials, no
returned epoch/payload/success, unchanged owner tables, retained hold, V=0 and
certified H=0 even when the private deletion epoch is 1.

This checks the implemented capability's conservative installed-control read
denial and internal duplicate path. It does not qualify a production authority
adapter, public V2 route or the unimplemented B4/B5 publication success path.

- [x] Add exact PG10 arrangement/oracle using actual restricted runtime calls.
- [x] Run current full API/restore/connected checks after Flutter finishes.
- [x] Inspect machine completion, update evidence and review remaining work.

Full Flutter in session 70597 failed: **210 passed / 12 skipped / 1 failed**,
final completion false, 107.459s. SQ01's child exited before its controlled kill
boundary because concurrent `dart run` hooks tried to replace the same
`.dart_tool/lib/sqlite3.dll` while another worker had it loaded (Windows access
denied). This is a harness resource race, not a SQLite transaction failure. No
test was marked passed/skipped and the subsequent named-file run did not start.

The PowerShell redirect also emitted UTF-16 logs. A first UTF-8 inspection failed
decoding; preserved each raw UTF-16 report alongside a UTF-8 encoding-only copy
with identical JSON events, then inspected actual errors and totals.

A controlled `--packages` probe, with an invalid worker stage that exits before
SQLite initialization, demonstrated that an alternate package config alone does
not isolate the native-asset output. It exited 255 at the expected stage check
and produced no probe-native output. Did not copy/rebuild package dependencies or
choose an asset-loading bypass.

Fixed the reproduced race with a Windows OS file lock held across each native
worker's complete spawn/kill/exit. This serializes only the workers that share
the writable DLL bundle, across concurrent test files; ordinary suite concurrency
and actual hard-kill boundaries remain enabled. The ignored package-local lock
handle closes in finally on success/failure. Other platforms retain their prior
execution. Full verification must run again after this new harness change; keep
the first failure report unchanged.

Extended the existing populated-upgrade regression into exact PG21, adding an
empty-0003 variant, actual execution of the frozen baseline readiness module
against the new restricted schema, real 0004-to-0003 downgrade refusal and
unchanged CLOSED control/preserved data afterward. The baseline module is copied
byte-for-byte from commit `2781f5c` to a test fixture, SHA-256
`17dafc001b918c5e6648aec07622fd87e12998a836251197e5bb2d0d60e74109`.
No original migration/source was edited. It tests old readiness code rather
than deploying an old service; old-worker containment still requires O2.
Ruff found two newly added SQL string lines over 100 characters; split them
without changing SQL semantics before verification.

Current Flutter verification completed (session 43509 exit 0):

- Pinned `dart format lib test`: **67 files, zero changes**.
- `flutter test --no-pub --machine`: **211 passed / 12 explicit skips / zero
  failures**, successful final event at **106.650s**. The Windows lock fix was
  exercised by the normal concurrent full suite, including all v1/v2 hard kills.
- `flutter test --no-pub test/recovery_protocol_v2_test.dart --machine`:
  **11 passed**, zero skips/failures, final success at **41.466s**.
- `flutter analyze --no-pub`: **zero issues**, **47.4s**.
- Root tooling `python -m unittest discover -s tools/tests -q`: **24 passed**.
- Ruff lint/format checks: **63 files**, clean. Strict mypy: **14 API source
  files**, no issues. Native static guard passes; physical-device/native build
  qualification remains separate. Credential guard: **302 files, zero findings**
  before the final metadata evidence JSON is added.

The current full owned API/restore/connected run is
`cbf09a5b04964a148a9e6d2f90d8730d`, session 42668, still pending. It started
after all Flutter compilers/analysis finished. Do not claim its API results until
the terminal receipt/JUnit is inspected. The first failed full Flutter report and
its original UTF-16 bytes remain preserved; later success did not replace them.

Iteration-18 final inspected result: `cbf09a5b04964a148a9e6d2f90d8730d`
completed with **398 passed in 202.102s**, zero skips/failures/errors, terminal
child exit 0 and component checks true. The current code passed both PG10
creation/deletion variants and both PG21 empty/populated migration variants,
plus all prior API/restore/connected regressions. Session 42668 is completed;
no test is left running or restarted merely due to an observation timeout.

Exact full API command, from `services/api/`:

```text
.venv/Scripts/python.exe ../../tools/run_recovery_v2_local.py --run-local --pg-bin E:/Motion/Daily-Motion-worktrees/recovery/.tools/postgres/pgsql/bin --full-python --flutter E:/Motion/Daily-Motion/.tools/flutter/bin/flutter.bat --pub-cache E:/Motion/Daily-Motion/.tools/pub-cache
```

Added immutable `docs/evidence/recovery-protocol-v2-local-2026-10-22-iteration18.json`.
It hashes current code, the frozen baseline readiness fixture, successful API/
Flutter reports, both failed Flutter reports and preserved raw UTF-16 artifacts.
Its matrix credits PG01/PG02/PG04/PG05/PG10/PG21 and SQ01/SQ02/SQ06/SQ08/SQ10:
**31 local named cases missing**, RC10/RC11 NOT EXECUTED, complete qualification
false. Earlier iteration evidence is historical and remains unchanged.
The implementation document now describes current counts, both fixes and limits.
A first documentation patch did not match its exact existing wording and made
no change; reapplied against the inspected lines.

Remaining requirement audit after these independent fixes/tests:

| Next unfinished requirement | Concrete dependency / safe present behavior |
| --- | --- |
| B0 trusted fresh authority/actual target binding; PG03/06/16 | O1/O2 adapter/target/containment acceptance unresolved. No public V2 adapter is enabled; installed control denies ordinary access. Existing internal stale/fence/pool cases do not qualify an actual hosted target. |
| B4/B5 certification, publication, exact retry/historical replay; PG07-09/11-15/17 and SQ03 | O3 explicitly blocks verifier/certificate implementation. Do not turn the internal marker/conformance object into trusted commit proof. B1 hold and private B3 outcome remain unpublished. O4 forbids guessed abort when original evidence is missing. |
| Initialization, account denials, independent retirement/high-water replay; PG18/19/22, SQ04 and RC04-08 | O3/O5/O8 decisions remain open. Internal normalized deletion is tested but is not complete independent disaster replay or account-policy proof. Unknown absence/history cannot create an owner. |
| Negotiated V2 transport, current acknowledgement, bootstrap and unknown-origin policy; PG20, SQ05/07/09 | O3/O7 block reviewed result DTOs/publication and rollout choices. Existing internal persistence/negative guards preserve local work; they do not qualify a certified V2 download/acknowledgement path. |
| Activation, cutover, authority-loss reconstruction, source containment and payload loss; RC01-03/09/12 | O1/O2/O3/O4/O6/O8 plus operator acceptance unresolved. No source/target routing, production DB or provider is touched; payload evidence is never replaced by receipt metadata. |
| RC10/11 and operational acceptance | Real provider/custody/encryption/retention qualification requires selected resources, O9/O10 authorizations and independent O11 review. Ordinary local reports cannot supply it. |

The next implementation boundary remains B4/B5 under O3. The existing question
for an accepted decision/review document has no answer; silence is not approval.
This turn made concrete independent progress and is not counted as a repeated
impasse. Goal remains active and incomplete. Do not mark complete, activate V2,
select trust/provider/privacy policy, or bypass an unavailable reviewer.

Final review for this turn verified all iteration-18 source/report/generated/
protected-document hashes and original investigation source/artifact hashes.
Main still contains only its original `.agents/` and `skills-lock.json` untracked
files at the original HEAD. Migrations 0001-0003 have no diff; no staged changes.
Docs check: **43 Markdown files / 474 relative links / 5 examples**; credential
guard: **303 source files / zero findings**. `git diff --check` passes. Changed
relative links resolve to the preserved specification, proposed ADR, work log and
new evidence. Current generated outputs are unchanged; no regeneration was
claimed for this documentation-only final step.

Ran the exact-case guard CLI against current JUnit and named Flutter reports:
exit **1**, deliberately indicating **31 missing names**, not a failed executed
test or a complete protocol pass. RC10/RC11 remain NOT EXECUTED. Its assessment
matches the immutable evidence JSON. No commit, push, deployment, hosted action,
activation, existing project database mutation or source-document change occurred.

User's display request: sent `WM_SYSCOMMAND / SC_MONITORPOWER=2` using
`user32.PostMessage(HWND_BROADCAST, ...)`; Windows returned true and the command
exited 0. This confirms request acceptance, not physical observation of the
monitor or a persistent idle-policy diagnosis. No power-plan change, system
sleep, application termination or administrator escalation was performed.

### Iteration 19 — inconsistent local recovery control cannot enable legacy sync

Previous goal turn classification: concrete progress (historical attention fix,
Windows native-worker race fix, PG01/02/05/10/21 tests and verified regression).
Reinspection confirms O3 remains unresolved and no accepted replacement ADR is
present. A separate I8 gap remains actionable without choosing a verifier.

`_recoveryRequired` trusts only the mutable requirement bit, even if current
context, high-water or V2 outbox rows contradict a cleared bit. Current-context
decoding also does not compare its epoch with durable H. Added four file-backed
fault/restart tests: cleared bit, H below stored certified epoch, non-integer H,
and reset state with retained V2 work. They require cloud pause/legacy-ack denial,
unchanged original M/body and successful local set/completion/new-root saves.

- [x] Reinspect current sources, specification and accepted decisions.
- [x] Add deterministic inconsistent-metadata regressions.
- [ ] Reproduce the gap, implement monotonic detection/typed denial.
- [ ] Verify focused/full Flutter and applicable connected checks.
- [ ] Update evidence, review preservation and next unfinished requirement.

Pre-fix run: all **4 regressions failed** because the original frozen command
remained eligible. Saved `iteration19-flutter-20261022/flutter-control-before.jsonl`,
exit 1 / final false (5.123s). Implemented requirement detection from the stored
bit/context/H plus retained V2 command/shadow/history evidence, and rejected
current context inconsistent with the requirement bit or certified erasure epoch.
Normal V2 local saves use only the singleton check; the retained-evidence query
is used only when that row otherwise resembles a pre-activation store.

First post-fix file run: **19 passed / 1 failed** (22.158s). The non-integer H
case revealed Drift throws `FormatException` from `int.parse`, not just
`TypeError`. Added both typed conversions to the existing recovery pause; did
not catch unrelated exceptions or repair/erase inconsistent metadata. Original
failure reports remain preserved. No certificate format/provider or wire path
was selected by this change. A correction patch initially failed matching
formatter-adjusted lines, made no changes, and was reapplied to inspected text.

The corrected persistence file passes **20 tests**, zero skips/failures, final
success true at 22.645s. Full Flutter/named/analysis verification is live as
session 29068; retain that handle until terminal evidence is inspected.

### Iteration 20 — internal evidence contains only typed UUID/digest identities

Independent inspection found the minimal-evidence type boundary accepted direct
non-UUID strings in Origin/Activation/Intent/OwnerEvidence/Assertion identities.
The digest function could accept a list/tuple of 64 hex characters, while other
malformed types raised an untyped exception. This violates the internal minimal
UUID/digest metadata contract even though the public OperationV2 parser already
validates UUIDs. No public wire or cryptographic format is selected here.

- [x] Add 65 malformed identity and 15 digest-container regressions.
- [ ] Reproduce failures and enforce typed internal identities/digests.
- [ ] Run evidence/authority checks, strict typing and full owned regression.
- [ ] Inspect final evidence and next unfinished requirement.

The 80 new metadata cases all failed before the fix (exit 1; 48 existing cases
deselected), demonstrating accepted invalid identities/digest containers or an
untyped exception rather than `RecoveryDenied`. Saved exact pre-fix JUnit/log.
Added UUID-instance checks to the internal identity values and a string check
before digest length/content validation. The validated public parser/format and
the original minimal valid metadata remain unchanged. These are semantic type
guards, not authentication, independent storage or commit-observation proof.

Focused post-fix evidence/authority: **141 passed in 12.84s**, zero skips/failures;
strict mypy passes (14 sources), Ruff lint/format clean. Full Flutter completed:
**215 passed / 12 explicit skips**, final success at 110.740s; named local file
**11 passed** at 47.732s; analysis zero issues (5.9s); formatting 67 files unchanged.
Full owned API run `b46997a7a5294297892f7e9b0c555db6` is live as session 28272.

Follow-up storage-path inspection found the conformance codec still coerces a
JSON boolean serial into integer 1 and ignores an unknown payload field. Verified
the installed Pydantic `validate_json` supports `strict` and `extra` options, and
reproduced both acceptances using the actual codec. Added 12 file-backed restart
cases covering top-level/nested activation, owner/checkpoint/result counters and
unknown private-payload fields. These require typed denial without rewriting the
damaged record. This closes the same minimal-metadata boundary across persisted
JSON rather than only direct dataclass construction; it is still test-only
conformance, never production/provider qualification.

## 2026-10-22 (resumed session, diagnostic-first voucher run)

Environment at start: worktree healthy on the same branch/HEAD; pre-existing
uncommitted work preserved (no resets, no commits). `infra-postgres-1` was found
stopped and was restarted; a waiting-read confirmed healthy on 127.0.0.1:25432.

1. `uv run --no-sync pytest -x -vv --tb=long tests/test_sync.py` with
   `pipefail` + `PIPESTATUS` capture saved to
   `.tools/recovery-v2-attempts/first-error-...`: real exit 0 after restart;
   root cause of the earlier 56 errors was the stopped PostgreSQL container
   (`psycopg.errors.ConnectionTimeout`), not application code. Correct admin URL
   validated by `tests/database_target.py` is
   `postgresql+psycopg://...@127.0.0.1:25432/daily_motion_test` (driver and
   database name are checked; the plain `postgresql://`/`daily_motion` version
   fails closed, which cost one diagnostic run).
2. Full suite then surfaced 13 genuine stored-metadata tamper acceptance
   failures in `test_recovery_authority.py` (exit 1). Root cause: the file-backed
   conformance codec used `TypeAdapter(...)`, i.e. Pydantic lax mode, which
   coerced `"1"/1.0/True` into counters and silently dropped unknown payload
   fields. Attempting per-instance strict dataclasses in
   `src/daily_motion/recovery.py` was reverted; constructors there must stay
   structural (tests require RecoveryDenied-typed aggregate invariants, mypy
   passes, and native UUID rows already satisfy constructor usage). Instead a
   strict, closed, recursive JSON decoder was added to the test-only adapter
   boundary `tests/recovery_authority.py`: exact type match per leaf (UUID from
   string, int/str/bool, StrEnum-by-value), Optional/tuple/list/dataclass
   structural walk, exact key-set equality (unknown private fields denied), and
   no coercion anywhere. It is test-only conformance; it grants no production
   trust and the persisted bodies remain write-protected by the adapter.
3. Post-fix: `test_recovery_authority.py` 153/0 with `test_recovery_evidence.py`
   combined; full suite (connected requested, Flutter both ordered and
   combined) = **413 passed, 77 skipped, pytest exit 0 in 60.60s** (skips are the
   documented external-credential/device gates), plus an isolated Flutter file
   run 7 passed/84.54s. Scattered `.tools/recovery-v2-attempts` logs:
   `first-error-test-sync.log`, `full-connected-correct-url.log`,
   `flutter-connected-correct-url.log`, `full-connected-final.log`.
4. Static: `ruff format --check` 49 files unchanged; `ruff check` all clean;
   `mypy src` 14 sources success; `git diff --check` empty. Modified-tree
   contents are the preserved uncommitted investigation work plus the decoder;
   no application source was altered this session.

Not claimed: physical-device durability, provider-dependent connected-hosted
outcomes of the skipped external gates, or any release readiness.

## 2026-10-22 — continuation after PR #10 squash merge

The user requested current status and continued implementation. The merged
baseline is signed main `3e0213151433bf3044d6bfb47d128d6b93e66ae6`, with the
same tree as reviewed `78267c1`. Main CI run `39723025027` passes API, Linux
mobile and macOS mobile; its API reports 490 passed and zero skips. Phase 0
remains in progress, and Phase 1 has not started. Work continues on local branch
`feat/recovery-v2-observation` from that baseline, in the existing clean worktree.

Implemented an internal known-marker database observation component. It opens
its own bounded READ COMMITTED session, takes the shared fence and ordered owner
locks, and verifies the persisted B3 marker/request/result, pending receipt,
original activation/owner/head, private feed, visible/pruned positions and
erasure/retirement scope. It rejects borrowed transactions and privileged roles.
No application rows change, no authority is called, and all locks close before
return. The existing local launcher runs the new cases and requires their module
in successful reports.

This does not implement O3's authenticated certifier, approved certificate
format or original-target continuity proof. It does not append certificates,
advance V/H, clear a hold, publish a result, enable public V2 admission or settle
uncertainty. CLOSED-target reconciliation and lost-marker resumption remain
unavailable. The specification, proposed ADR and characterization are unchanged.

Validation and corrections:

- First focused Linux run: 22 passed, one new fixture failed because its account
  retirement insert omitted `retired_at`; remaining cases were not executed.
  Corrected the arrangement and preserved the first JUnit report.
- Initial combined admission/effect/observation run: 107 passed, zero skips.
  Review then added malformed deletion-feed shape and unsafe pruning-position
  guards and regressions.
- Final Linux/Docker PostgreSQL run: **109 passed / zero skips**, including
  **46 new observation cases**, actual commit/rollback waits, exclusive-close
  ordering, deletion suppression and lock-release checks.
- Full owned native PostgreSQL/restore/connected run
  `5914b372a0cd49afaef94a05f9226cff`: **536 passed / zero skips**, terminal
  exit 0, component checks true, including the wrapper verifying nine connected
  Flutter HTTP cases. CI's JUnit acceptance checker also passes.
- Ruff: 65 formatted files, lint clean. Strict mypy: 18 source/script files.
  Tooling: 24 passing tests. Generated OpenAPI/transport comparisons, docs,
  credential, native configuration and archived receipt checks pass.

[Machine-readable evidence](docs/evidence/recovery-observation-local-2026-10-22.json)
records the source/report hashes and retained failure scope. New local component
tests do not close additional named PG/SQ/RC qualification cases. RC10/RC11 remain
NOT EXECUTED; provider/custody, physical hardware and O1–O12 acceptance remain
open. At this local checkpoint, no feature commit, push, provider access,
deployment or activation was performed. The next production boundary still needs the
accepted O3 trust/certificate decision and independent review before B4/B5.

## 2026-10-22 — observation review and authorized PR preparation

The user explicitly authorized complete local review, concrete fixes, validation,
signed commit/push and a feature PR, followed by CI fixes until green. Merging,
deployment, provider changes and hosted drills remain excluded. The original
checkout and unrelated worktrees/files are preserved.

The standards and protocol reviews find no concrete defect within the declared
known-marker component. They check fresh-session/fence/owner-lock ordering,
actual commit/rollback observation, restricted roles, owner/lifecycle isolation,
canonical persisted evidence and deletion suppression. Nondelete checks do not
independently audit every normalized child or observation value; this limitation
is now explicit in the implementation record and the separate
[O3 proposal](docs/RECOVERY_O3_VERIFIER_PROPOSAL.md). The proposal covers trust,
permissions, target continuity, certificate contents, append/publication ordering,
failure cases and required reviewer decisions. It remains unapproved, grants no
production B4/B5 authorization and does not replace independent security review.
No behavior change or speculative refactoring is introduced by the review.
The proposed specification/ADR, historical characterization and original local
receipt are preserved. New review validation is recorded separately.

Review validation: Linux/Docker PostgreSQL **109 passed / zero skips, failures or
errors**, including 46 observation cases (284.22 seconds). Source/protected-doc
hashes and all referenced original JUnit/log/launcher hashes match. The previous
full native **536 passed / zero skips** remains valid retained evidence; it was
not rerun during this review. Its JUnit acceptance guard passes again. Frozen
dependencies check 46 packages; Ruff checks 65 files and lint passes; strict mypy
checks 18 source/script files; all 24 tooling tests pass. Documentation links,
credential, native static and archived mobile receipt checks pass, with zero new
physical samples. [Review receipt](docs/evidence/recovery-observation-review-2026-10-22.json)
keeps the fresh and retained runs distinct. Exact-head remote CI remains a later
PR check, never implied by this local evidence.
