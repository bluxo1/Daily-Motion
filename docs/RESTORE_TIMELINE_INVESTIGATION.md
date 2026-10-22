# Restore-timeline investigation: confirmed findings and proposed design

2026-10-21 IST. Baseline protected main:
`2781f5c101e87e1a9351cb3e7bbf53453625e025`.
**Uncommitted review draft. No production fix is implemented or authorized.**
Phase 0 remains in progress; Phase 1 has not started. No hosted database, provider,
OTP, deployment, key rotation, account destruction outside disposable resources,
commit or merge was performed. This finalization uses existing completed output;
it does not rerun the expensive probes.

## Outcome and evidence boundary

One Python harness passed in **231.16 seconds** (JUnit: 231.157), executing
**13 Flutter characterization cases, zero failed, zero skipped**. Passing means
the recorded behavior was reproduced, including unsafe behavior; it does not mean
recovery is safe. Four confirmed scenarios are documented as D1–D4. D1 and D2
share the missing atomic timeline-admission cause; D3 additionally demonstrates
receipt loss, and D4 demonstrates missing independent deletion recovery.

The run used Windows, Python **3.13.14**, Flutter **3.47.7** / Dart **3.13.5**,
native PostgreSQL **17.11**, actual `pg_dump`/`pg_restore`, signed synthetic ES256
JWTs, the unchanged FastAPI/domain implementation and its restricted non-owner
runtime role/forced RLS. Drift used real file-backed SQLite with WAL,
`synchronous=FULL`, integrity/foreign-key checks and explicit close/reopen.
The local lab's synthetic PostgreSQL trust authentication is confined to its new
loopback cluster; it is not hosted authentication or TLS qualification.

The harness restores archives into newly generated disposable databases and
switches the test API's runtime connection to the restored target. It does not
restore an existing/shared database in place. A test-only checkpoint controls
when the unchanged coordinator sends; a test-only ASGI gate delays one fully
received HTTP body before the production application receives it. Production
source, contracts and migration history are unchanged. The seed/template
database fingerprint stayed unchanged; disposable cleanup completed and its lab
directory was absent on subsequent read-only inspection.

This proves the local scenarios, not physical power failure, an already locked
transaction racing a new admission implementation, hosted cutover, independent
backup custody or production recovery. No full regression/native build suite was
rerun during finalization. Prior baseline CI remains a separate dated result.

## Preserved artifacts and hashes

Attempt **`20261021T095107Z-cdccc486`**, abbreviated **A** below, is stored at
`.tools/timeline-attempts/20261021T095107Z-cdccc486/` in this investigation
worktree. These are existing, ignored local artifacts, not published Git evidence.
No original artifact is rewritten by this report. Archive bytes were held in
memory during execution and are no longer retained; their digests identify the
actual restored archives but do not provide a downloadable backup. Reproduction
creates new synthetic UUIDs/archives and therefore different run hashes.

| File relative to worktree, or artifact within A | SHA-256 |
| --- | --- |
| `services/api/tests/investigations/restore_timeline_probe.py` | `ae50665b95d26bbc3ea33f0659dd563bd8f653a85e56523ccff38e001e66b114` |
| `apps/mobile/test/investigation/restore_timeline_probe.dart` | `4f9361768b2548aa8b7ee706d12b0983bb6ac0f4cfe312c8be5648b3436d60b5` |
| `.tools/run_timeline_probe.py` (task-local runner) | `7e94ea9323bdddb46abb73f21ba2bc9843e0bae428b6afdd5c278d6bcb80ce56` |
| A / `receipt.json` | `6d1f5433418d31aba9f4cbe750deb5012a50c696596f41fa0619ae1e727a56c5` |
| A / `restore-timeline-observations.json` | `7d0786a9ea4555173463fb38ef2a998eb99222968eb6d4cc0df4b99ae2a044f4` |
| A / `timeline-flutter-machine.log` | `1257f53f71f501dcb530a10b9313cffff4e3c716533dfcee217081292ba8a1ec` |
| A / `pytest.xml` | `049aca1ea0861879049de7d3696c6122e0160b57d56053b6655d91b07673067c` |
| A / `python.log` | `d4ee116e8a3301652ced0329e3fd4a11b172501b43d97cd4e8a17162c1ab0e57` |

The baseline archive used by the rewind cases has digest
`c5ea4aafa3fd503d505b7f4e0ffa8fff1306313a4de2d69c5cf68b05dd932d4b`.
Receipt-retention control archive:
`2ae06bb25bd01bd870815ca2d3471b2255c7cc6e298bad9c4157970d3fe1b605`.
Deletion-retention control archive:
`e30a5a8974d5e30e5ed1f593c33517ab6947f5f495e8d4f417e8f7d593b40173`.

`receipt.json` records exit zero and the two probe source hashes. JUnit records
one harness test, no errors/failures/skips. The Flutter machine log records all
13 visible successful unskipped cases and a successful final `done` event.
Observations include each frozen operation's mutation ID/SHA, restore archive
SHA, before/after state, generation, receipt result and client state. Those
synthetic identifiers need not be copied into ordinary logs. Publication of a
portable redacted evidence package would require separate authorization; local
ignored paths should not be represented as accessible to a fresh Git checkout.

## Exact reproduction commands

**C1 — the command actually used**, from this existing investigation worktree's
repository root, with its pinned virtual environment and retained task-local
runner:

```powershell
.\services\api\.venv\Scripts\python.exe -X utf8 .tools\run_timeline_probe.py
```

It creates a unique new attempt directory, strips inherited `DM_*` and `PG*`
settings, supplies only synthetic test configuration and task-local paths, and
runs the following repository-local probe explicitly. Do not invoke C1 merely to read
this report; it would rerun all 13 cases. It does not overwrite A. The runner is
ignored/local; another checkout must prepare an equivalent reviewed invocation.

Canonical inner command, from `services/api`, after frozen dependency setup and
configuration of the pinned Flutter SDK/local caches:

```powershell
$env:DM_RUN_TIMELINE_INVESTIGATION = '1'
$env:DM_FLUTTER_CMD = 'ABSOLUTE_PINNED_FLUTTER_EXECUTABLE'
# Windows native backend used in A; use approved portable local binaries only.
$env:DM_RECOVERY_PG_BIN = 'ABSOLUTE_LOCAL_POSTGRESQL_BIN_DIRECTORY'
python -m pytest -q -s --tb=short tests/investigations/restore_timeline_probe.py --junitxml=NEW_OWNED_OUTPUT_DIRECTORY/pytest.xml
```

Use a fresh ignored output directory and task-local `TEMP`/`TMP`/`PUB_CACHE`.
Remove unrelated inherited application/libpq overrides before launching. The
probe consumes no supplied database URL: it creates a new local cluster and
generated targets. Without `DM_RECOVERY_PG_BIN`, the existing lab selects a
validated local Docker socket and cached PostgreSQL 17.7 image; **that backend
was not executed in A**. Explicit opt-in/Flutter absence fails rather than skips.
See the [Python probe](../services/api/tests/investigations/restore_timeline_probe.py)
and [Flutter probe](../apps/mobile/test/investigation/restore_timeline_probe.dart).

The harness runs cases in a fixed sequence; there is no independently qualified
per-case CLI selector. Each defect below references C1 and its exact case name/
JSON path instead of inventing a filter that bypasses setup. The child command
is `flutter test test/investigation/restore_timeline_probe.dart --machine`;
running it alone without the disposable server/control process is not a valid
reproduction. Both probes are outside default test-file discovery.

## Common initial state

Two synthetic owners A/B have distinct roots and verified test JWTs. The backup
contains A's root at revision 1 with no observed sets. The discarded live timeline
G1 accepts A's first set at revision 2, observed reps `[5, null, null]`. Flutter
bootstraps/pulls that actual state into its owner-scoped SQLite file. It records
the second set as 7 reps, expects revision **2**, and persists the frozen command
and stable mutation ID. Local observations are `[5, 7, null]`.

A restored copy of the older archive is advanced through actual domain commands
to a divergent revision 2 with `[9, null, null]` where applicable. The documented
[restore fence](../infra/recovery/restore_fence.sql) executes in one operator
transaction on that new target: new owner generations, `minimum_position=position`,
epoch increment and snapshot removal. This is G2, not ancestry of G1 merely
because its numeric root revision is also 2. Account status remains active;
account disable is never used as maintenance.

## D1 — Equal revision permits a stale-generation commit

- **Initial state:** the common G1 baseline, frozen command expecting revision 2;
  the restored archive has no receipt for that mutation.
- **Restore boundary:** after the coordinator's successful preflight/pull, before
  its HTTP send. The target is G2, revision 2, `[9, null, null]`, with the documented
  restore fence applied.
- **Observed server:** `accepted`, revision **3**, `[9, 7, null]`. Exact retry is
  `duplicate` without another database effect. A real receipt exists for the
  prepared mutation in the restored database.
- **Observed client:** acknowledgement installation reports `bootstrap_required`
  because generation changed. SQLite retains the pending frozen body and its
  acknowledged first-set value **5**. This local refusal cannot undo the server
  commit. The test stops automatic subsequent turns to inspect that boundary.
- **Affected invariant:** a command based on discarded history must not mutate a
  restored timeline merely because the numeric CAS revision matches. Local
  acknowledged work was preserved in this case; universal server preservation
  is not established.
- **Receipt reference:** A / observations `cases[0]`, case `equal_fenced`, including
  `restored_state_before_upload`, `client.server_before_repeat`, `server`;
  machine-log test `equal_fenced`.
- **Exact reproduction:** C1:
  `.\services\api\.venv\Scripts\python.exe -X utf8 .tools\run_timeline_probe.py`.

The `equal_unfenced` control (`cases[3]`) is worse: without generation/epoch
fencing the same divergent commit is locally marked **acknowledged**, with server
first-set reps 9 versus local 5 at the inspected boundary. No subsequent full
convergence behavior was tested; do not infer it from this immediate observation.

## D2 — A delayed received request survives the restore boundary

- **Initial state:** the same G1 revision-2 prepared command and client state.
- **Restore boundary:** the HTTP request body has fully arrived at a test-only
  gate; its handler has not yet entered production API authentication or mutation
  admission. Restore/fence G2 is installed, then the request is released.
- **Observed server/client:** `accepted`, revision **3**, `[9, 7, null]`; repeat
  `duplicate`; client `bootstrap_required`, pending frozen bytes unchanged and
  acknowledged local first set still 5. Evidence explicitly records
  `request_arrived_before_restore=true`.
- **Affected invariant:** old in-flight traffic must be rejected at the actual
  mutation boundary, not considered safe because a preflight or HTTP arrival
  preceded recovery.
- **Receipt reference:** A / observations `cases[4]`, `delayed_inflight`, and its
  machine-log test; before/after records and arrival boolean.
- **Exact reproduction:** C1:
  `.\services\api\.venv\Scripts\python.exe -X utf8 .tools\run_timeline_probe.py`.

This does **not** demonstrate a transaction that already held the owner lock
crossing a new implementation's fence. That ordering remains an acceptance test
for the proposed fix, not a confirmed result from this run.

## D3 — Rewound receipts permit acceptance on two timelines

- **Initial state:** the frozen mutation is first accepted on G1 at revision 3.
  The test deliberately withholds local acknowledgement installation, closes/
  reopens SQLite and confirms the exact frozen body survives.
- **Restore boundary:** restore the earlier archive, where that receipt is absent,
  produce divergent revision 2, and apply the fence. The diagnostic explicitly
  resends the saved envelope to test server admission.
- **Observed server:** the same mutation is **accepted again** on G2, producing
  revision 3 and `[9, 7, null]`; later retry is `duplicate`. SQLite remains pending.
- **Affected invariant:** a restored server cannot infer “never accepted” from a
  receipt missing in its rewound database. Cross-disaster idempotency needs an
  independent authority or conservative denial.
- **Receipt reference:** A / observations `cases[6]`, `lost_receipt`:
  `discarded_timeline_outcome=accepted`, absent restored receipt, new accepted
  receipt and repeat result; corresponding machine-log test.
- **Exact reproduction:** C1:
  `.\services\api\.venv\Scripts\python.exe -X utf8 .tools\run_timeline_probe.py`.

This is an explicit stale-envelope server probe, **not** evidence that the
current coordinator normally skips preflight on restart. The separate restart
case observed zero pushes. It also does not show unlimited duplicates in one
target: within G2, the retained new receipt prevents further effects.
The consistent `retained_receipt` control (`cases[7]`) restores revision 3 with
its receipt and `[5, 7, null]`; both retries return `duplicate`, unchanged.
A retained historical duplicate is not itself evidence of corruption.

## D4 — Epoch increment cannot restore missing deletion records

- **Initial state:** after common setup, a real synthetic workout deletion is
  accepted on G1. The current root disappears, IDs are retired, and the established
  SQLite client receives deletion/bootstrap state before close/reopen.
- **Restore boundary:** restore the earlier live-root archive, which lacks those
  retirements, then apply the documented fence. In `deletion_equal_epoch`, both
  the phone's cached deletion epoch and restored epoch equal **1**.
- **Observed:** the established client refuses the erased payload with
  `erased_payload`; a **new file-backed client receives the deleted root** at
  revision 1, epoch 1. The restored server has zero retirement rows for A.
- **High-water variant:** `deletion_regressed_epoch` performs three real synthetic
  deletions before recovery. The established client retains epoch **3** and reports
  attention / `malformed_response` against restored epoch **1**. A fresh client
  still receives the deleted root. Raising a counter once neither replays deletion
  nor makes the server trustworthy to a client that observed a higher epoch.
- **Affected invariants:** deleted identifiers/payload must not reappear; new
  clients cannot depend on old phones carrying the only tombstones; recovery
  must reconcile acknowledged high-water rather than lower client safety state.
- **Receipt references:** A / observations `cases[10]` / `deletion_equal_epoch`
  and `cases[11]` / `deletion_regressed_epoch`, including accepted deletion epoch,
  pre-restore absence, fresh-client result and restored retired count; both named
  machine-log tests.
- **Exact reproduction:** C1:
  `.\services\api\.venv\Scripts\python.exe -X utf8 .tools\run_timeline_probe.py`.

The `deletion_retained_control` (`cases[12]`) restores a post-deletion archive:
five retired IDs survive, the root stays absent, and the fresh client receives
no deleted workout at epoch 2. This proves preservation when records exist in
the archive, **not** an independent ledger. Account-retirement loss, cross-store
ledger failure and production backup erasure were not executed in this run.

## All thirteen observed cases

| Case / observations index | Observed result |
| --- | --- |
| `equal_fenced` / 0 | Stale command accepted into G2; duplicate retry; local ack rejected |
| `lower_fenced` / 1 | Revision 1 versus expected 2: conflict, repeat conflict, no observed-set mutation |
| `higher_fenced` / 2 | Revision 3 versus expected 2: conflict, repeat conflict, no extra mutation |
| `equal_unfenced` / 3 | Divergent stale command accepted and locally acknowledged at inspected boundary |
| `delayed_inflight` / 4 | Fully received/pre-admission request accepted after restore/fence |
| `same_generation` / 5 | Legitimate command accepted, duplicate retry; `[5,7,null]`, acknowledged locally |
| `lost_receipt` / 6 | Accepted on original timeline and again on restored timeline; target retry duplicate |
| `retained_receipt` / 7 | Duplicate only, restored receipt/state preserved |
| `restart_preflight` / 8 | Real reopen/coordinator bootstrap: zero pushes, local conflict and frozen bytes retained |
| `owner_isolation` / 9 | A command under B yields conflict without changing A; B cannot read A's root and B's own fresh upload succeeds |
| `deletion_equal_epoch` / 10 | Existing client refuses erased payload; fresh client receives deleted root |
| `deletion_regressed_epoch` / 11 | Cached epoch 3 refuses restored epoch 1; fresh client receives deleted root |
| `deletion_retained_control` / 12 | Retired IDs survive; fresh/established clients receive no deleted root |

No local acknowledged-observation loss was observed in the timeline cases.
Frozen bodies stayed unchanged; repeated sends did not create repeated effects
within one target. The defects concern unsafe admission and recovery truth,
not failure of ordinary same-generation CAS/RLS/receipt transactions.

## Source explanation and additional unexecuted risks

[Operation/PushRequest](../services/api/src/daily_motion/contracts.py) at baseline
lines 158–224 has no expected generation. [accept](../services/api/src/daily_motion/sync.py)
(260–285) locks current owner state, then checks receipt/digest, retirement and
numeric revision without comparing a request timeline. [Local ack installation](../apps/mobile/lib/data/sync_repository.dart)
(114–137) checks generation/epoch after server execution. The local command
transaction preserves a revision basis but not its generation provenance
([workout_repository.dart](../apps/mobile/lib/data/workout_repository.dart),
345–408). These source facts explain D1–D3.

The [receipt model](../services/api/src/daily_motion/models.py) (102–108) stores
digest/acknowledgement without accepted generation. Current
[push handling](../services/api/src/daily_motion/main.py) (148–154) commits each
operation separately, then reads `me()` for response context. A fence between
operations or between final commit/context could mix timeline interpretation.
**That batch/context race is a source-derived risk, not executed evidence here.**

[Deletion](../services/api/src/daily_motion/sync.py) (228–256), account retirement
and epoch state share the application backup's fate. [Bootstrap](../apps/mobile/lib/data/sync_repository.dart)
(641–644, 704–706) correctly refuses a regressive epoch, but a new client has no
independent deletion knowledge. Current SQL adds one to the restored counter;
it supplies neither a complete ledger nor upload admission.

## Recommended architecture — proposal, approval required

### 1. Explicit recovery admission, separate from account lifecycle

Introduce durable recovery states such as `closed`, `reconciling`, `open`, with
a fresh recovery incarnation and verified activation/checkpoint reference.
Place environment-wide control in a separately private schema with narrow runtime
read permission; retain owner-specific generation and isolation. Migration/operator
authority alone changes recovery control. No runtime admin/BYPASSRLS grant or
public cache/gate reset endpoint is needed.

Restored control rows can themselves rewind. **An `open` row copied from a backup
is insufficient:** an independently retained activation record must bind the new
target, fresh incarnation, verified ledger/receipt checkpoint and approved
deployment configuration. Missing/mismatching activation closes access; there
must be no default-open startup path. This record is control integrity, not a
client-selected owner or a secret that grants training access.

All payload reads, initialization, pushes, snapshots and ordinary job publication
must honor recovery containment, not just writes. The runtime must remain
non-owner/NOBYPASSRLS. Owner-free `restore_fence.sql` can affect zero rows under
forced RLS: a future operator procedure must verify authority, exact expected
owners/affected counts and postconditions rather than treating SQL success as
proof. Do not elevate the API role to run an all-owner fence.

### 2. Immutable generation provenance and atomic acceptance

Propose a version-2 operation carrying an immutable `origin_generation` and
recovery-incarnation provenance bound into its canonical digest. Capture that
provenance with the command/working projection/outbox in the **local transaction**
where its branch starts; successors inherit their actual predecessor's origin.
Do not attach the latest `/me` generation during upload or after bootstrap.
Retain generation and revision together on acknowledged shadows/branch bases.

For each server mutation transaction, use a fixed lock order:

1. Acquire a shared transaction-scoped recovery lock, then read/validate recovery
   control and independent activation identity. A fixed application advisory-lock
   namespace is one candidate, avoiding UPDATE grants on global metadata merely
   to take row locks. The exact locking choice needs implementation review.
2. Establish verified owner context and take existing initialization/owner locks
   in a consistent order. Recheck genuine account state independently of recovery.
3. Resolve the same-owner mutation receipt/digest against verified receipt
   coverage. Reject changed identity/body binding. A verified historical receipt
   yields historical-only information, not a new mutation.
4. For any new effect, require request origin/incarnation to equal the active
   owner timeline under these same locks. Missing/unknown origin cannot be guessed.
   Then perform retired-ID checks, CAS and domain validation.
5. Commit projection, observation revision, feed and current-generation receipt
   together. Preserve existing same-generation exact retry behavior.

Specify transaction isolation as part of this protocol. With `READ COMMITTED`,
acquire the recovery lock in its own statement, then read control/current owner
state in subsequent statements after any lock wait. Do not reuse an ORM-cached
control object or a snapshot established before the fence. A repeatable-read
transaction begun before waiting can otherwise inspect obsolete admission state;
its use needs a separately proved restart/serialization rule. Add a deterministic
snapshot-before-wait test rather than assuming advisory locks refresh snapshots.

The operator fence takes the corresponding **exclusive** recovery lock and
rotates generations/activation while access is closed. A request admitted before
the fence either commits before the fence obtains exclusivity or rolls back;
one reaching admission afterward observes the new state and cannot apply an
old-origin mutation. Never hold SQLite/server locks across network calls.
Validate every mutation path, not just request middleware or `/me` preflight.

These database locks serialize one database, not two independently running
restore targets. Whole-environment cutover additionally requires approved ingress
closure, draining/stopping old workers, old-source access fencing, isolated new
target validation and removal of stale pool/routing paths. A deployment env flag
or copied control row alone does not prevent split-brain old writers. This
proposal assumes a controlled offline restore/cutover, not seamless active-active
recovery; that operational guarantee remains unqualified. An unannounced rollback
that bypasses containment/activation invalidation is outside this guarantee and
must not be represented as automatically detected or safe.

### 3. Batch and response context

Preserve the existing bounded, independent per-operation transaction model unless
an ADR deliberately changes it. Check recovery/origin on **each operation**.
If a fence intervenes, earlier old-generation results remain historical and later
old-origin commands are paused without effects. Record accepted generation,
incarnation and relevant position in each result/receipt; do not relabel them
using a later `me()` response. Define partial outcomes explicitly in version 2.

The client must recognize an old-generation accepted result as historical evidence
requiring reconciliation, not current shadow authority or a successor's new basis.
It keeps the working branch/frozen body and installs only context-compatible
results atomically. A single-transaction whole-batch alternative could simplify
context but changes transaction/rollback/lock duration semantics; it is not the
recommended unreviewed shortcut.

### 4. Receipt recovery is not payload recovery

Independently retain the minimal acceptance evidence needed across rollback:
owner/mutation/root IDs, canonical digest and contract version, origin and
accepted generation/incarnation, result/revision/position and a verifiable
completeness checkpoint. Retain no copied workout/note payload in this index.
Never reclassify “absent from the restored receipt table” as “never accepted.”

After recovery:

- A verified current-generation receipt returns its exact result with no effect.
- A verified older receipt returns an explicit historical acceptance/denial with
  old context and no effect. It cannot advance the new shadow, manufacture branch
  ancestry or authorize a successor. Genuine account retirement still denies
  ordinary access; a receipt is not proof that an erased root is live.
- Unverifiable/conflicting digest or incomplete coverage pauses recovery. No
  terminal command receipt should consume a mutation merely because admission
  metadata was unavailable or its old generation needs reconciliation.
- A missing old receipt never permits automatic replay into a new timeline.
  Preserve the exact original ID/body for investigation. Explicit user-reviewed
  reconciliation may create a distinct new command/ID; reauthentication alone
  must not rewrite identities or content.

Minimal receipts cannot recreate a lost acknowledged workout's observations.
Qualified WAL/data backup recovery and the accepted RPO remain necessary.
Surviving local branches can support explicit review but are not a replacement
for server backup, and cannot recover a lost phone's pending-only work. Do not
promise zero acknowledged cloud-data loss from generation admission alone.

### 5. Independently durable deletion and high-water authority

The deletion authority must survive rollback of application tables, including
their outbox. Retain authenticated, access-controlled, minimally scoped events
for account/root/child retirement and their owner mapping, deletion outcome,
published erasure epoch, generation/incarnation and ordered checkpoint. Include
all published recovery/erasure fences in the independent high-water, not only
workout deletions. Otherwise a phone may have observed a legitimate higher epoch
that another recovery cannot reconstruct.

Completeness matters as much as individual event authenticity. Require a trusted
checkpoint covering every acknowledged deletion/acceptance through the recovery
boundary, verifiable ordering/gaps, version/integrity and custody outside the
restored snapshot. An arbitrary phone's reported maximum is not authoritative.
Account retirements must cover owners absent from the restored backup and must
be enforced before initialization or Auth-to-training owner recovery.

Choose and qualify the durability boundary before implementation:

- A verified independent WAL/log route covering every acknowledged effect could
  reconstruct receipts and deletions. Ordinary asynchronous archival with an
  unmeasured gap does not meet that guarantee.
- Alternatively, a reviewed independent intent/commit-certificate protocol can
  delay cloud success until both the DB commit and independently durable evidence
  are known. States must distinguish prepared, commit-verified and unresolved
  outcomes. A crash after DB commit but before independent confirmation is an
  uncertain commit, not a clean rejection; retries retain the same identity.
  Even an existing receipt's replay must not bypass required independent
  publication before reporting authoritative success.

Neither option is implemented. Two unrelated writes are not magically atomic.
The chosen approach needs failure/retry and privacy review, a completeness proof
for acknowledged results, custody/availability costs and explicit approval.
Independent service failure may pause cloud success; it must not block local
set commits or hold a local SQLite transaction across network work.

Restore/reconcile while all target access remains closed:

1. Authenticate the archive and independent checkpoint; verify completeness and
   old/new target identities. Missing, divergent, stale, truncated or unavailable
   authority stops recovery.
2. Replay account/root/child retirement idempotently. Suppress current projections,
   observation history, feed payload copies, snapshots and other materializations
   before reads, jobs, bootstrap or initialization. Preserve only policy-allowed
   minimal receipts/retirement metadata.
3. For each owner, establish an epoch **strictly above the maximum of the restored
   epoch and verified independently published high-water**, with overflow checks.
   Advance the independent fence/checkpoint before opening access. Raising the
   integer without replay is insufficient, as D4 proves.
4. Reconcile receipt history and working-branch policies, invalidate snapshots,
   create fresh generations/incarnation and validate forced RLS, owner mappings
   and receipt/purge postconditions. Publish activation only after independent
   operator/reviewer acceptance; crashes leave the target closed.

Public deletion jobs/full independent replay remain separately scoped release
work under [the roadmap](ROADMAP.md) and [security policy](SECURITY.md#retention-deletion-and-portability).
Deferral does not authorize opening a real-user restored environment without
these guarantees. A synthetic Phase 0 drill must state its narrower scope.

### 6. Fail-closed behavior and local availability

| Condition | Proposed remote behavior | Required client behavior |
| --- | --- | --- |
| Recovery closed, metadata absent/unverifiable, incomplete ledger or activation mismatch | Typed recovery/maintenance denial before payload/effects; bounded retry guidance, no mutation receipt consumption | Pause sync with safe status; retain working state, draft, frozen outbox and cached owner; local logging/corrections/completion/history remain available where already unlocked |
| Old/missing operation origin | Typed upgrade/reconciliation requirement, not ordinary root revision conflict or guessed rebasing | Preserve original identity/body/basis; quarantine affected branch and keep training available |
| Valid same-generation request, verified recovery state | Existing CAS/receipt/domain checks and authoritative commit/result | Normal acknowledgement/echo behavior |
| Verified historical receipt | Historical-only context with no new effect | Preserve local branch; no automatic current-shadow/successor rebase |
| Actual verified account retirement/disable | Existing purpose-appropriate account policy | Apply real lifecycle policy; do not confuse maintenance with erasure |

Candidate errors/statuses (`recovery_required`, `recovery_metadata_unverified`,
`historical_acceptance`, contract upgrade) require contract review. Do not assume
v1 clients can parse new fields. Unknown/malformed data must fail safely without
clearing local training. In particular, do not emit `account_inactive` or set
`deleting` to implement maintenance: current matching-owner handling intentionally
purges local sessions/outbox and locks the owner.

## Required changes, not applied

| Area | Proposed scope and compatibility requirements |
| --- | --- |
| Protocol/ADR | Review DM-005/DM-006 implications and approve versioned admission, historical receipts, failure states and durability acknowledgement boundary before code. No ADR changed here |
| Server schema | Additive successor to Alembic `0003`: private recovery control/checkpoint references, receipt generation/incarnation/version metadata and needed indexes/grants. Exact migration/version/name is a proposal. Existing 0001–0003 files stay immutable; unproven legacy receipts cannot be backfilled as current-generation proof |
| Contracts | Version-2 operations/results/errors and generated DTO/fixtures; preserve bounded batching and explicit same-generation exact replay. v1 StrictModel/schema constant cannot silently accept added fields. Keep safe supported v1 read shapes if needed; reject unsafe legacy writes explicitly rather than treating client version headers as provenance |
| Drift/client | Additive local schema successor to version 3, preserving every existing projection/outbox/identity/frozen byte. Capture new branch generation at local creation; inherit successors; persist recovery attention/historical results. Legacy sent/unsent commands with unknown origin remain quarantined, not rewritten under the same ID. A genuinely new root needs an explicit known/unknown-origin policy; training may save locally while authorization remains unresolved |
| Migration rollout | Deploy compatible server readers and capable clients before enabling enforcement under an approved window. Verify old-client denial preserves local training. Never auto-stamp the new generation onto a legacy branch or mutate a frozen v1 envelope into v2 under its old ID |
| Operations | Independent custody/checkpoints, isolated target/ingress/job containment, source fencing, scoped operator authority, expected-owner counts, secret-safe configuration, process/pool replacement and measured recovery acceptance. No hosted operation authorized by this document |

Generation provenance is not authorization: JWT identity, active account checks,
CAS, nested-ID validation and RLS remain mandatory. A public generation value or
client version header is not a secret granting access. The design prevents stale
honest-client replay and verifies retained known mutation bindings; it does not
claim to infer user intent from a malicious authorized client forging a new
command. Reconciliation must remain explicit.

## Acceptance tests for a future approved implementation

These are required future tests, **not results from the 13-case characterization**.

| ID | Negative/positive cases | Required outcome |
| --- | --- | --- |
| T1 | Same-generation first upload, exact retry, changed digest, multiple roots | First accepted once, exact result replay, digest mismatch denied; no extra observations/feed/receipts |
| T2 | Divergent equal/lower/higher restored revisions with old/missing origin | No stale-generation effects at any matching numeric revision; original pending branch/bytes preserved |
| T3 | HTTP buffered before admission; request already authenticated; mutation holding shared recovery/owner locks; snapshot/ORM state created before a lock wait | Post-fence stale request denied using fresh admission state; pre-fence transaction completes before exclusive fence or rolls back; deterministic barriers, not sleeps |
| T4 | Fence between batch operations and between final commit/response context | Partial outcomes explicitly retain their accepted timeline; no old result relabelled as current and no later stale operation committed |
| T5 | Lost response, receipt retained/restored/missing, verified old receipt, changed digest, incomplete independent receipt checkpoint | Same-generation exact replay works; historical result has no new effect; missing/unknown old acceptance quarantined, never blindly reapplied |
| T6 | SQLite restart around command/origin/freeze/ack/activation persistence; legacy sent/unsent outbox and dependent successors | Atomic local capture, identical IDs/bytes after restart, no guessed provenance, historical receipt cannot silently advance a successor basis |
| T7 | Owners A/B, nested IDs, absent initialization, pooled/unset context, old-source/new-target routing | No crossover; both legitimate owners work in their qualified current timeline; stale source/pool cannot keep accepting traffic after cutover |
| T8 | Missing control row, stale restored open row, divergent activation, gate/replay crash, independent authority outage | Reads/writes/init/jobs fail closed to maintenance; no account erasure, no current success claim, bounded retry |
| T9 | Active workout during maintenance/auth failure; secure cached owner versus missing grant | Durable sets/corrections/completion/drafts/history continue for established unlocked owner; no owner guessing or data deletion |
| T10 | Ledger gap/truncation/tamper/staleness, duplicate/out-of-order replay, crash/retry, retired owner absent from archive | Target stays closed until complete verified replay; idempotent retirement/purge; initialization cannot recreate erased accounts |
| T11 | Cached high-water above backup; equal integer without retirement; fresh client, feed/snapshot/historical copies | New and established clients never receive erased data; reconciled authoritative epoch does not regress or loop; no payload in minimal receipts |
| T12 | Independent publication fails before/after DB commit and before response/replay | Acknowledgement/completeness boundary remains provable; uncertain outcomes retain identity and cannot become duplicate effects after another restore |
| T13 | Additive server/Drift migrations, old contract denial, control grants/RLS, owner-free operator fence | No dropped pending work or widened runtime privilege; verified affected-owner counts; missing/unsafe configuration denied |

Run future tests against real disposable PostgreSQL and file-backed SQLite;
transport timing fakes may control boundaries only. Require full format/analyze/
typing, actual connected suites, contract reproduction and exact-head CI after
approved code changes. A production fix must change D1/D2/D3/D4 expectations to
defensive outcomes; do not keep today's unsafe-result assertions as its safety
acceptance tests. Device/hosted and independent review gates remain separate.

## Review limitation, effort and approval

An independent security-review output was unavailable because of a security
content restriction. The saved receipt explicitly says **“unavailable; not
retried or bypassed.”** This report does not claim that the restricted review
passed, was completed, or approved the architecture. No attempt is made to
retrieve, rephrase around or otherwise bypass that restriction. The proposed
security-sensitive architecture still requires an available, authorized
independent review and operator decisions before implementation/acceptance.
Probe success is execution evidence, not a substitute for that review.

Planning effort, assuming one engineer, available reviewer/tooling and no new
defects: admission/protocol specification **1–2 engineer-days**; scoped server/
client/contract/migration implementation and regressions **3–6 additional days**;
independent deletion/receipt acknowledgement/custody design **2–4 days**. Full
independent durability/replay implementation cannot be estimated responsibly
until route, acknowledgement semantics, RPO/RTO, custody and budget are accepted.
Hosted/device qualification and provider/reviewer waiting time are excluded.

Recommended next authorization is **review and approve the versioned admission,
maintenance and historical-receipt specification**, with explicit acceptance
tests and independent durability decision. Keep restored environments closed
while these guarantees are missing. This report does not authorize applying
that design, buying resources, changing providers or performing a hosted drill.
The [existing recovery integration](RECOVERY_INTEGRATION.md),
[sync protocol](SYNC_PROTOCOL.md), [recovery runbook](../infra/RECOVERY.md) and
[recovery decision package](../infra/HOSTED_RECOVERY_STRATEGY.md) retain their
current accepted semantics until separately reviewed changes are approved.

## Finalization validation and preservation

Only this uncommitted report was created during finalization. Read-only checks
against the saved attempt confirmed its Python harness result and all thirteen
Flutter successes; no PostgreSQL/Flutter probe was rerun.

- Documentation validation: **41 Markdown files, 461 local links, 5 JSON examples**.
- Credential guard: **271 source files checked, zero findings**. This automated
  result is not a provider/log inspection or a proof against every possible secret.
- All **eight** source/runner/artifact SHA-256 values above match their retained
  files, and the source/artifact values recorded inside A's receipt also match.
- All **nine pre-existing worktrees** match the preservation snapshot in HEAD,
  porcelain status, staged/unstaged binary-diff hashes and nonignored untracked
  file hashes. No existing evidence, staged work or signing protection was changed.
- Investigation HEAD remains the baseline above, its index is empty and
  `commit.gpgsign=true`. Tracked production source/contracts/migrations have no diff.

The report's whitespace and UTF-8 check includes this untracked file explicitly;
`git diff --check` alone does not inspect untracked files. These finalization
checks do not replace full application regressions after any future approved fix.
