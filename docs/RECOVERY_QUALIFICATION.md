# Session 2 database and recovery qualification

The subsequent [integration review](RECOVERY_INTEGRATION.md) compares this dated
source with protected main including PR #7 and PR #8. It fixes higher-revision
divergence and adds atomic-fence/restart/retirement and no-skip checks. Original
counts below remain historical evidence.

Branch: `phase0/recovery`, based on committed `57a4494`. Worktree:
`E:\Motion\Daily-Motion-worktrees\recovery`. Investigation began 2026-10-19;
client fixes and final verification continued 2026-10-20. Phase 0 is still in
progress; Phase 1 has not started. Shared phase/status documents are owned by
Session 4 and are intentionally not updated here.

## Independent audit

Reviewed [ROADMAP.md](ROADMAP.md), [phases.md](phases.md),
[SYNC_PROTOCOL.md](SYNC_PROTOCOL.md), [SECURITY.md](SECURITY.md),
[recovery preparation](../infra/RECOVERY.md), the existing SQLite fault tests and
the [Oct 18 restore evidence](evidence/phase0-recovery-and-connection-guards-2026-10-18.json).
The previous source/restored row and metadata fingerprints are identical. That
record demonstrates a successful local logical restore, atomic missing-role and
truncated-archive rejection, and restricted owner isolation. Its explicit limits
are accurate: five empty tables, no restored HTTP retry, no hosted Auth identity,
no retained off-site archive/encryption/expiry and no physical durability claim.
The one-off helper is identified by a hash but is not a repeatable checked-in
test. Existing evidence is retained as historical evidence, not rewritten.

Existing SQLite tests already cover working/outbox/receipt/draft atomicity,
transaction and pager-full faults, migration 1/2 to 3, bootstrap checksum and
activation faults, cursor/page atomicity, deletion, owner switching and hard
process kills. New SQLite tests target disaster rewind behavior rather than
duplicating that suite.

## Confirmed defects and resulting behavior

1. **Reused server cursor timeline:** restoring an old generation and accepting
   a different mutation at a previously used position lets the discarded
   timeline's cursor skip that change. The local PostgreSQL regression reproduces
   this and verifies the [operator fence](../infra/recovery/restore_fence.sql):
   fresh generations and bootstrap watermark, an advanced erasure epoch and
   snapshot invalidation. Historical receipts remain replayable. This is an
   explicit restore procedure; no automatic production restore job is added.
2. **Client trusts revision order across restore generations:** a lower restored
   revision or divergent reused revision was ignored while the coordinator
   reported synchronization. A pending command could then be uploaded against
   a different root with the same revision. The client now compares normalized
   shadows across generations, preserves divergent working state, installs the
   restored shadow, flags a conflict and pauses affected pending commands.
3. **Acknowledged local workout absent from backup was deleted:** bootstrap
   removed the cached session when it had no pending outbox. Generation-change
   bootstrap now retains it as a recoverable conflict. Later local logging does
   not restart upload against an absent/rewound shadow. Retired-ID erasure remains
   authoritative; missing data is not treated as proof of deletion.

Four new behavior regressions failed against the original client; the unchanged
root control passed. A sixth regression covers a downloaded root with no outbox
history, continued logging and reopening. Comparison treats an omitted optional nullable
`correction_reason` like null, so equivalent roots do not acquire false conflicts.
Tests inspect real file-backed SQLite and reopen it to verify conflict, working
observations, shadow and frozen-envelope persistence. The fix uses existing
columns; an internal session-metadata flag persists the restore fence and is
excluded from rendered/domain projections. Historical acknowledged outbox rows
remain unchanged. No Drift/Alembic migration, generated contract or public endpoint changes.
It does not implement Phase 1 conflict-resolution UI. Restored environments remain
closed to ordinary clients until the timeline/deletion/branch checks are complete.

The erasure epoch also needs reconciliation against an independent ledger/high
water mark. Incrementing an older backup's epoch once can still leave it behind
a phone's cached epoch; that phone refuses bootstrap. The one-increment SQL
fixture is verified for its synthetic history and does not establish that all
discarded production timelines can reopen. Production ledger/fence replay stays
a release requirement.

## Qualification method and boundaries

The checked-in [PostgreSQL lab](../services/api/tests/recovery_lab.py) refuses
unqualified Docker sockets and inherited libpq routing overrides. The native
fallback creates a new task-local data directory and random loopback port, with
synthetic trust authentication. Restore destinations are generated names inside
that new cluster. It never reads an existing hosted or local application database.
Cleanup checks the exact generated path/container before removal and verifies it.

The fixture populates **all 11 tables**, including nonempty profiles, observations,
retired IDs, snapshots and account retirements. It preserves corrections, deleted
session receipts and redacted feed entries. Archive content stays in memory;
evidence contains only hashes, counts, timings and classifications. Successful
restores compare row, RLS, policy, constraint, index and grant fingerprints at
Alembic `0003` before mutating any target for an attack.

The interrupted-restore test holds an advisory lock through an event trigger on
a post-data index, waits until `pg_restore` reaches that barrier, then terminates
its backend. It verifies rollback of schema/data and preservation of a preexisting
sentinel; a subsequent clean restore succeeds. Other tests exercise damaged
header/truncation, missing ACL role, irreversible retirement migration refusal,
all-table owner isolation, cross-owner foreign keys/reassignment, receipt
uniqueness, immutable retirement, forced-RLS removal/repair, application receipt
replay/digest binding, pull/bootstrap checksums, account/ID retirement and
uncommitted projection/receipt/feed rollback after backend termination.

PostgreSQL immediate stop/restart exercises WAL recovery of the restored committed
data with durability settings enabled. It is not a host power-cut, storage-device
failure, provider PITR, cross-region disaster or production-size performance test.
The restored HTTP case uses FastAPI TestClient with an explicit synthetic verified
owner dependency. It does not qualify restored Supabase JWT/JWKS/Auth users. The
separate existing connected harness exercises real local HTTP/JWT/Flutter with
a simulated provider identity; it is not hosted evidence.

Docker initialization failed before tests on this host. EDB's portable Windows
17.11 archive was downloaded over HTTPS and used instead, without a service
installation. Its SHA-256 is
`6eabdf00d2893713b75db4336a23c3fdf505f056e217ec6e2e95d901750cfea3`;
this is a recorded download fingerprint, not independent publisher-signature
attestation. Initial native helpers timed out during startup/pipe capture before
database acceptance. The final helper redirects Windows background launcher
handles and verifies query readiness. No Docker reset, factory reset, volume
prune, existing database reset or hosted operation was performed.

The first selected SQLite run passed 100 cases and timed out before one hard-kill
worker reached its boundary. A serial rerun passed all three kill stages. Retain
that initial failure rather than claiming every invocation passed. These are
Windows desktop tests, with no iPhone/Android physical-device inference.

Broader validation caught an overbroad draft restore guard that also paused an
ordinary account-return fixture. That implementation was replaced by the explicit
private marker. An overlapping Flutter invocation hit a native SQLite DLL lock
before acceptance tests; final Flutter validation runs sequentially. The first
full Python run used trust authentication: 176 cases passed, while two real-login
rotation checks correctly exposed the harness's inability to reject passwords.
Those two cases were rerun separately in a fresh lab with SCRAM authentication.
These intermediate failures are not represented as clean full-suite runs.

Final verification passes **24 recovery/target tests**, **178 full Python tests**
including **9 connected Flutter HTTP cases**, and **157 ordinary Flutter tests**
with **12 explicit skips** (9 connected cases run separately, 3 hosted cases not
run). Source fingerprints, synthetic table/metadata hashes, restore timings and
intermediate failures are recorded in
[machine-readable evidence](evidence/phase0-database-recovery-2026-10-20.json).
The connected multi-device harness emits Drift's debug multiple-instance warning;
its synthetic devices use distinct NativeDatabase executors. All nine cases pass.
[Session 4 handoff](SESSION2_RECOVERY_HANDOFF.md) records the implementation commit
and exact remaining approvals.

## Hosted decisions and remaining gates

[HOSTED_RECOVERY_STRATEGY.md](../infra/HOSTED_RECOVERY_STRATEGY.md) supplies the
concrete proposed RPO/RTO, seven-day retention, authenticated export encryption,
separate operator/key custody, alerting, expiry details, costs and isolated restore
sequence. Option B (Pro daily plus independent export) is recommended for
synthetic Phase 0; it remains an unapproved proposal. Prices are dated public
documentation observations, not a funded quote.

Session 4 must obtain **REC-01 through REC-06**: funding/route; accepted recovery
and retention policy; named operators/key custodian/processor reviewer and
approved regions/IAM; exact source/isolated target/export/restore authorization;
outbound-job containment and Auth/config/root-key handling; and signed measured
acceptance after actual custody, decryption, expiry and hosted restoration.
No purchase, retention policy or external processing arrangement is accepted here.

Production deletion-ledger replay/purge remains Phase 1 release work. A nonempty
restored retirement row is preservation evidence, not an external ledger replay.
Physical phone backup/transfer, protected storage and durable-save latency remain
device gates. Hosted Auth UUID recovery, independently retained encrypted backup,
key-loss recovery, real retention expiry and full measured RPO/RTO remain open.
Never reopen a restored real-user environment on the strength of this local lab.
