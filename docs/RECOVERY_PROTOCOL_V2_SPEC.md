# Recovery protocol v2: specification for review

2026-10-21 IST. Baseline: `2781f5c101e87e1a9351cb3e7bbf53453625e025`.
**PROPOSED / UNAPPROVED. Specification only.** The MUST/SHALL requirements below
describe a candidate implementation, not current behavior or accepted policy.
No runtime, generated contract, migration, provider or hosted state is changed.
Phase 0 remains open; Phase 1 has not started. See the
[proposed ADR](ADR_RECOVERY_PROTOCOL_V2_PROPOSED.md).

The [unchanged investigation](RESTORE_TIMELINE_INVESTIGATION.md) is the execution
authority: one Python harness, 13 passing Flutter characterization cases, zero
failures/skips. Passing reproduced unsafe behavior; it did not prove this design.
Attempt `20261021T095107Z-cdccc486`, its source/receipt hashes and four findings
D1–D4 remain unchanged. All test definitions in this specification are future
requirements, not executed results.

## 1. Scope, invariants and explicit limits

This proposal extends [the accepted synchronization protocol](SYNC_PROTOCOL.md)
for controlled restore/cutover. It preserves root CAS, per-operation domain
transactions, commit-ordered owner feeds, frozen identities, pending branches,
owner RLS, staged bootstrap and local/cloud authorization separation.

| ID | Invariant |
| --- | --- |
| I1 | Local durable saving never calls Auth, the API or recovery authority; failed cloud work never reverses a successful SQLite commit |
| I2 | A new server effect uses the exact command's known timeline, never a generation attached at send time |
| I3 | After a completed database fence, no old-origin command can commit on that target |
| I4 | Cloud acceptance through any publication path requires independently certified evidence; no cursor skips uncertified effects |
| I5 | Exact retries have one effect within a timeline; rollback never converts a missing receipt into permission to replay historical work |
| I6 | Erased payloads and retired account/root/child IDs cannot reappear through restoration, reads, snapshots, initialization or stale uploads |
| I7 | Receipts, epochs and root revisions do not establish ancestry across different incarnations/generations |
| I8 | Missing, inconsistent or unverifiable recovery evidence denies cloud access without inventing account disable or erasing local training |
| I9 | A/B identities, commands, independent indexes and local stores remain isolated under verified ownership |
| I10 | A receipt proves historical acceptance, not recovery of its workout payload or satisfaction of an unapproved RPO |

Assumptions: trusted domain implementation and scoped operators; authenticated
authority operations; controlled target creation; no direct client training-table
access; every mutation/publication path participates. A compromised DB admin,
authority administrator or malicious authorized client fabricating fresh workout
intent is not solved by a public generation value. A digest binds known bytes;
it is not a signature proving a client's intent.

The supported recovery model is offline, isolated restore and controlled cutover,
not active-active databases. In-place rollback while workers remain connected is
unsupported. Checkpoint mismatches may detect some unannounced rewinds, but no
claim of universal automatic detection is made. Already issued responses/offline
copies cannot be recalled; publication means authorization of a response/artifact,
not the instant its last network byte arrives.

## 2. Versioned identities and separate counters

Protocol identifier: **DRP/2**. Proposed wire command contract: **2**. Neither is
enabled by this document. Exact schemas must later be generated from reviewed
OpenAPI; tables here specify semantics, not a second implemented DTO definition.

| Symbol | Meaning and source |
| --- | --- |
| E | Immutable environment UUID registered independently; staging and production never share it |
| A | Monotonically ordered activation serial allocated by the independent authority, not by restored PostgreSQL |
| I | Fresh target incarnation UUID for each approved restore/activation; bound to E, provider/project/database identity and approved deployment manifest outside the archive |
| G | Owner feed/timeline generation, minted under the recovery protocol; not a timestamp or raw revision |
| R / L | Root server revision / client local sequence; neither substitutes for G, A or authority order |
| P / V | Private committed owner feed position / publicly certified feed position; ordinary publication requires no outstanding owner attempt and P=V |
| Q | Per-owner independent evidence order, including terminal receipt outcomes and recovery fences; never a pull cursor or a PostgreSQL sequence maximum |
| H | Highest independently certified owner erasure epoch, including certified recovery fences |
| M / D | Original mutation UUID / canonical digest of its complete frozen, versioned command |
| T | Server attempt UUID, stable across resumption of M on I; does not replace M |

A DRP/2 command includes immutable E, origin I and origin G in its canonical
digest, together with existing command fields/schema version. Owner comes from
verified credentials, not a client `user_id`. A is admission context recorded in
evidence; an activation refresh that changes only deployment configuration must
not silently change a command's lineage. Any activation that changes data ancestry
MUST mint I and appropriate G values. Generation reuse across restores is forbidden.

The client captures origin atomically with its branch/local outbox creation.
Successors inherit their actual predecessor's lineage and obtain their expected
revision only from that predecessor's context-compatible certified receipt.
Bootstrap, refresh, resend and reauthentication cannot relabel a pending branch.
A new local root created without verified lineage is saved with `origin_unknown`
and remains upload-ineligible. Later delivery needs explicit reviewed adoption;
this specification does not authorize automatic restamping of unknown work.

## 3. Independent recovery authority

The **authority** is a required storage/verification capability, not authorization
to add a microservice, message broker or provider. Implementation/provider choice
is unresolved in O1. It must supply:

1. Authenticated, durable, linearizable compare-and-append and current-head reads.
2. Unique E/A/I activation identities, per-owner ordered evidence, idempotent
   attempt lookup and nonrollbackable completeness/seal checkpoints.
3. Protection against replay of a valid but obsolete prefix, not just signatures
   on individual records. A hash chain without an independently trusted latest
   head cannot prove freshness or completeness.
4. Separate scoped permissions: operators activate/seal; an evidence writer can
   append only allowed records for an existing activation; runtime cannot delete
   history, activate a restored target or decrypt payload backups.
5. Authenticated encryption, availability and retention meeting approved policy;
   identities/checkpoints/retired UUIDs remain sensitive metadata.

Signed immutable records are one possible representation, not a required new
cryptographic format. Use maintained cryptography and managed identity/key custody.
There is no client-held authority secret. API runtime remains a restricted
non-owner/NOBYPASSRLS PostgreSQL role.

### 3.1 Activation and freshness

An activation manifest binds E/A/I, actual target identity, code/schema/contract
compatibility, complete owner inventory/checkpoints, reconciled deletion state,
archive provenance, approved RPO/loss inventory, old-source containment evidence
and operator approval. A restored control row, hostname, env flag or client header
alone is insufficient target identity. How the approved platform verifies actual
target identity is unresolved in O2; inability to verify means no activation.

Before admission or ordinary payload publication, obtain a fresh authenticated
authority assertion outside any DB transaction. Bind it to the requested E/I,
owner, request nonce and current activation/evidence head. Reuse on another
request/owner/target is forbidden. Its validation must not rely only on client or
wall-clock time. No stale cache fallback on authority failure is permitted.

Inside the DB transaction compare that assertion with local pinned activation,
verified target identity and owner evidence anchor. An older assertion than a
durably observed authority serial is rejected. A concurrent advance requires
bounded refetch/retry, not guessed ordering. Server effects always recheck local
admission after waits; a fresh external assertion alone cannot close the race.

Authority assertions are fetched without DB locks. Their potential staleness
between fetch and use is bounded by the database fence and controlled cutover:
new activation cannot open until the old target is closed and contained. No
clock-based lease is substituted for that proof.

### 3.2 Environment state machine

| Authority state | Local target state | Permitted actions |
| --- | --- | --- |
| UNREGISTERED / unavailable | CLOSED | No normal payload, initialization or domain effects |
| PREPARING(A,I) | CLOSED or RECONCILING | Approved isolated validation/replay only |
| ACTIVE(A,I) | OPEN with matching activation | DRP/2 admission and certified reads, subject to owner state |
| CLOSING(A,I) | OPEN until exclusive close completes, then CLOSED | No new independent PREPARED records; settle known attempts only; no new target may open |
| SEALED(A,I) | CLOSED / contained | Immutable historical evidence; no new domain effects or ordinary publication |
| Any mismatch / divergent head | CLOSED | Recovery attention; no default-open repair |

The **database fence** is the commit of the exclusive close transaction (section
4), not declaration of an incident or receipt of an HTTP request. Global admission
reopens only for a verified new activation. Crashes in PREPARING/RECONCILING never
implicitly produce ACTIVE/OPEN.

## 4. Locks, isolation and atomic mutation admission

All domain effect transactions and publication checks use explicit **READ
COMMITTED**. Acquire a transaction-scoped shared recovery lock in a separate
statement, then read fresh control/owner state after any wait. No cached ORM
object, earlier statement snapshot or preflight authorizes an effect. The default
proposal prohibits REPEATABLE READ for effect admission. Bootstrap has its own
read-only snapshot procedure in section 6.

Lock order everywhere: **global recovery lock -> owner initialization/retirement
advisory lock when needed -> owner-state row -> root/receipt/attempt rows**.
The shared/exclusive recovery key must use a documented namespace disjoint from
the existing owner advisory locks. Normal runtime cannot alter control. Operator
fences take the exclusive version of the same lock before changing control.
Timeout/deadlock retry preserves M/D/T and never reports a failed commit as saved.

Per mutation, Tx-RESERVE, Tx-EFFECT and Tx-PUBLISH below are separate transactions.
The actual domain effect, revision, feed and receipt remain atomic in Tx-EFFECT.
No external call or wait for authority/storage is allowed while a DB or SQLite
transaction is open. Publication gating is durable state, not a held network lock.

### 4.1 Owner attempt state machine

At most one active attempt per owner in this conservative v2 proposal. Existing
independent roots can share bounded batches, processed one operation at a time;
other owners remain independent. This adds cloud head-of-line delay, not local
logging latency. Optimizing simultaneous uncertified owner commands is out of scope.

| Local state | Independent state | Meaning / next permitted action |
| --- | --- | --- |
| IDLE | No active attempt | Certified reads and new reservation allowed |
| RESERVED(T) | None yet | Owner publication held; request PREPARED outside DB transaction |
| RESERVED(T) | PREPARED(T) | Intent durable, no proof of a domain commit; perform/resume Tx-EFFECT only under valid admission |
| EFFECT_COMMITTED(T) | PREPARED(T) | DB outcome committed but not independently certified; reads/success held |
| EFFECT_COMMITTED(T) | CERTIFIED(T) | Historical commit evidence durable; publish only if current target/context still valid |
| PUBLISHED / IDLE | CERTIFIED(T) | Normal certified result/echo allowed; exact retry has no new effect |
| Any uncertain or contradictory phase | UNRESOLVED(T) | Owner cloud access held; retain original command and evidence; no inferred abort or success |
| Reservation cancelled with proof | NOT_COMMITTED(T) | No effect; slot may clear; original mutation not consumed by a maintenance rejection |

CERTIFIED refers to minimal metadata independently witnessing a commit on its
named incarnation. It does not mean workout payload is independently backed up.
UNRESOLVED is durable uncertainty, not a terminal command rejection or a deletion.

### 4.2 Exact transaction and external boundaries

| Step | Boundary | Required work and postcondition |
| --- | --- | --- |
| B0 | Outside DB | Verify JWT signature/issuer/audience/expiry and identity; get fresh authority assertion. Account/provider network checks happen here, with application state rechecked under locks later |
| B1 | Tx-RESERVE | Shared recovery lock, fresh OPEN/activation check, tenant context, ordered owner locks. Validate schema/size, known E/I/G, account state and M/D binding. Resolve a certified duplicate/historical result or reserve T and set owner publication hold atomically. Persist required temporary frozen request under owner RLS for resumption. No domain/feed change yet |
| B2 | Outside DB | Authority compare-and-append PREPARED(T,M,D,E,A,I,G,expected prior evidence anchor). It rejects conflicting identity/digest or a closing activation. Exact repeat returns the same preparation |
| B3 | Tx-EFFECT | Reacquire shared recovery and owner locks; reread OPEN/activation/account state, retirement, T and PREPARED binding. Recheck origin, expected revision, nested IDs and domain rules. Commit normalized changes, observation revisions, root revision, private P/feed, pending receipt and immutable effect marker/result binding together. P is not published V. Conflicts/rejections also store their deterministic result pending certification, without advancing the domain feed |
| B4 | Tx-OBSERVE, then external append | A scoped certifier observes the committed marker/result in a fresh short READ COMMITTED DB transaction, closes it, then submits matching evidence to the authority. Authority appends CERTIFIED or reports uncertainty; it never certifies an intent merely because it was prepared |
| B5 | Tx-PUBLISH | Shared recovery lock, fresh OPEN/activation/owner checks and purpose-appropriate account state. Validate certificate, T/M/D/result binding and complete retired-ID/epoch evidence. Advance V to P, bind receipt to certificate, remove temporary request copy and clear publication hold atomically. No second domain effect or revision increment |
| B6 | After B5 commit | Return the exact certified result and its captured context, or allow the resulting echo/bootstrap. Never fetch later `/me` context to relabel an earlier result |

B1's validation can return protocol/authentication/recovery denial without
consuming M. A deterministic domain outcome at B3 is persisted/certified so exact
retries remain deterministic. Malformed requests never create a command receipt.
An existing digest mismatch is rejected without changing its original receipt.
Look up M/D only in the verified owner's namespace before deciding whether
known historical lineage can return historical-only evidence. That lookup never
permits a new effect: B3 requires the exact current origin. An unverifiable legacy
receipt is quarantined, not backfilled with the current incarnation.

Tx-OBSERVE uses the shared recovery lock and purpose-appropriate owner guard to
verify the original target, immutable marker, result, feed/epoch/retirement scope
and PREPARED binding. It may inspect a CLOSED original target for narrowly
authorized reconciliation; it does not authorize ordinary payload access or new
effects. Only the external append happens after that transaction closes. A
certificate submission after closure remains evidence about its original I/G,
never authority to publish on a new target. CLOSING may settle already prepared
attempts; ordinary publication requires ACTIVE plus local OPEN. A sealed
activation cannot accept new certificates beyond its verified completeness seal.

Failure of B2/B4 does not silently clear the owner hold. Only proof of safe
cancellation or same-attempt resumption can clear it. NOT_COMMITTED requires
authority-confirmed preparation absence after admission closure, or a verified
abort on the original unrewound target after excluding an in-flight B3 commit.
An absent receipt in a restored DB is **never** such proof. The concrete
commit-observation/abort proof and resolver implementation are blockers O3/O4.

On an ordinary process crash with independently verified unchanged target and
consistent markers, a bounded same-codebase reconciler may resume the same T/M/D
at the next incomplete boundary. After any known rollback, unknown target
continuity or evidence contradiction, automatic Tx-EFFECT resumption is forbidden.
Use UNRESOLVED and keep cloud access held. Pending-only phone work stays on phone.

### 4.3 Fence ordering and in-flight traffic

An operator close transaction takes the exclusive recovery lock and commits
CLOSED. Every B1/B3/B5 already holding the shared lock commits before exclusivity
or rolls back. A waiter admitted afterward sees CLOSED or a new I/G and cannot
apply an old command. A request received/authenticated before closure has no
special entitlement. The hold and marker make B3-to-B5 uncertainty observable.

A batch has independent per-operation boundaries. If a fence intervenes, prior
certified results retain their original context; remaining operations receive
typed pause/reconciliation outcomes. No batch-wide latest context overwrites
per-result E/I/G/certificate binding. A committed-but-uncertified operation is
pending publication, not a conflict or accepted result.

DB locks cover only that DB. Closing another restored target does not stop old
workers writing the source. Section 9's source containment is mandatory.

### 4.4 Initialization and real account lifecycle

Initialization follows the same hold/certification discipline, without fabricating
a workout/feed event. Verify provider identity outside DB transactions. Obtain
independent proof of no retirement/previous unresolved history before treating
an owner as new. The existing owner initialization advisory lock serializes
absence. B1 may reserve owner-publication metadata before an application owner
row exists; B3 creates the minimal owner/profile, and B5 exposes the certified
initialization. A stable server-created initialization identity is persisted in
B1 and compared with independent history; repeated/lost-response requests reuse
it rather than creating another account or attempt. Normal repeated initialization
of an established certified account is a guarded read, not another profile insert.

An owner missing from the restored DB but known to the authority is not a fresh
account. The recovery manifest must reconcile that owner's identity/data policy
before initialization can succeed. Unknown absence does not authorize creation.

Real account disable/retirement and ordinary effects serialize through the owner
hold/lock discipline. They cannot bypass it as administrative writes. A genuine
security emergency can close admission while earlier attempts are settled; it
does not justify disguising maintenance as account deletion. For B5, normal
commands require active state; a certified lifecycle command instead verifies
its exact expected denying transition and publishes only policy-permitted
minimal lifecycle evidence. Requiring active state after a retirement would
otherwise prevent that retirement from ever being certified/published.

## 5. Receipt and independent evidence semantics

The authority stores minimal owner/M/T/root and affected-ID bindings, schema/D,
origin/accepted E/A/I/G, deterministic result/revision, effect marker, owner evidence
order, feed effect if any, erasure/lifecycle facts and completeness checkpoint.
It stores no set values, notes, token, OTP, raw command body or backup-decryption
material. The temporary B1 request copy stays only in the primary owner-private
DB, is never an independent backup, and follows purge/cleanup policy.

PREPARED is intent only. COMMITTED is a primary DB fact, established by B3's atomic
marker. CERTIFIED is authenticated independent evidence of that specific commit.
PUBLISHED is B5's durable permission to expose it. Response loss is not evidence
that any earlier phase failed. Evidence ordering uses compare-and-append with gap
tracking; `max(sequence)`, device time and cross-owner feed positions are invalid
proofs of completeness.

Exact current-incarnation replay returns the stored certified outcome without
another effect. A still-pending attempt returns only `publication_pending` and
safe retry guidance. Same-identity changed bytes remain a digest mismatch.

A verified older-incarnation receipt is exposed, if account policy permits, as
`historical_result` with its original schema/digest/context and no current effect.
It is not an ordinary accepted/duplicate acknowledgement on the restored timeline.
It cannot update a new shadow, clear a divergent branch, authorize a dependent
successor or certify that erased/missing payload is live. Unknown/unverifiable
old receipts require reconciliation, not a new attempt with guessed provenance.
This applies to accepted, rejected and conflicted terminal receipts, not only
successful operations.

Prepared but unresolved attempts must be accounted for at a cutover seal. The
authority must not declare a prefix complete by omitting them. Its loss or replay
to an old head invalidates recovery authority. A trusted recovery of the authority
itself needs a separately accepted procedure; fallback to application DB receipts
alone is prohibited.

## 6. Publication barrier: all ways clients can learn success

The durable owner publication hold is installed in B1, before any B3 effect.
Every ordinary owner payload/context read, duplicate success, initialization,
job/export publication and snapshot endpoint checks it under ordered recovery/
owner guards. While held, deny those operations with `publication_pending` or
recovery attention. Auth checks, payload-free liveness and tightly scoped internal
reconciliation are not training publication. Readiness fails when activation or
required recovery configuration is unverified.

After credential/tenant validation, check recovery and publication holds before
emitting any application account-state response. An uncertified B3 transition to
`deleting` must not leak as `account_inactive` and prematurely trigger client
erasure. Only a certified purpose-appropriate lifecycle denial is exposed as
such. Internal reconciliation can inspect pending state, never publish it.

| Path | Publication rule |
| --- | --- |
| Push accepted/conflict/rejected result | Result certified and B5 committed; carry original per-result context. Receipt presence alone is insufficient |
| Exact duplicate | Same gate and certification as first success; retry cannot bypass B4/B5 |
| Pull/own echo | Require no hold and P=V in the owner read transaction. Return only certified complete batches. Never skip an unpublished entry and advance the cursor |
| `/me`, profile/account initialization | No uncertified epoch/position/state is exposed. New account creation also checks independent retirement/history before creating a local owner row |
| Bootstrap preparation | Use the snapshot procedure below, not a projection containing hidden effects |
| Snapshot page/validation | Recheck activation, no hold, account state, generation/epoch and token binding before serving any page |
| Jobs/materialized artifacts | Capture certified E/I/G/epoch/evidence anchor; recheck under the publication guard before making payload accessible |

Bootstrap uses two short transactions, no transaction across page HTTP requests:

1. In a read-only REPEATABLE READ transaction, read owner control/hold and certified
   checkpoint in the same snapshot as all root/retirement projections. Require
   no hold and P=V. Materialize bounded private pages tagged with that checkpoint.
   This snapshot never authorizes mutations or proves freshness after waiting.
2. In a new READ COMMITTED transaction, shared recovery lock then fresh owner
   guard; require matching E/I/G, epoch, certified checkpoint, no hold and P=V.
   Publish the manifest/pages only if all match, else discard/retry. Requiring
   the same checkpoint is intentionally conservative during concurrent writes.

Filtering feed rows cannot repair a projection already containing uncertified
effects. This specification blocks owner reads instead. Snapshots issued before
a later ordinary edit may remain valid under existing bounded snapshot rules;
permanent erasure or incarnation change invalidates them. Snapshot tokens/cursors
bind E/I/G, owner and relevant certified checkpoint/epoch. Cached v1 tokens never
cross activation. No feed cursor represents authority Q or private P.

A response authorized before a later deletion/fence may arrive afterward. Its
original context is never restamped. Client installation validates owner, lineage,
epoch and current shadow monotonically in its SQLite transaction; stale context
cannot regress current state or acknowledge a successor on another timeline.

## 7. Deletion reconstruction and erasure high-water

Every real deletion/lifecycle effect uses B1–B5 or an equivalently proved internal
path. Maintenance never uses `account_inactive`, `disabled` or `deleting`.
Account-disable/retirement evidence must preserve security-relevant denials that
could otherwise rewind to `active`; exact lifecycle/retention policy is O5.

A certified deletion includes complete owner/root/child retired-ID mappings and
its committed epoch, plus the scope needed to suppress every materialization.
An account retirement includes owners absent from the selected archive and blocks
initialization even with an old valid JWT. PREPARED deletion intent without commit
proof is not permission to delete. Unknown commit state prevents reopening; it
does not justify either resurrecting or silently deleting the affected workout.

Reconstruction on a CLOSED isolated target SHALL:

1. Verify archive authenticity, independent latest head/seal, complete owner
   inventory and every attempt through the cutover boundary. Reject gaps,
   contradictory digests, incomplete child-ID scope or uncertain deletions.
2. Replay all CERTIFIED committed retirements, even if the original response was
   lost or B5 had not finished. Perform idempotent current/historical projection
   purge, feed payload redaction, snapshot invalidation and job/output suppression.
   Retired IDs cannot become creates or migrate to another root/owner.
3. Reconcile account denials before initialization, reads or ordinary jobs. No
   old provider identity may recreate a retired application account.
4. For every owner choose epoch `max(restored_epoch, H) + 1`, with checked integer
   bounds and no client-supplied high-water authority. H includes independently
   certified deletion, lifecycle and prior recovery-fence epochs, not only epochs
   still present in the archive. Equal integers do not prove equivalent payload.
5. Bind the replay/purge inventory, new epochs, fresh I/G values, data recovery
   checkpoint and any accepted loss inventory into a new independent activation
   record before opening access. Delete staged/transient snapshots and invalidate
   old tokens. Repeat after interruption idempotently; crashes leave CLOSED.

The owner evidence stream continues monotonically across incarnations, but feed
positions/revisions remain interpreted within their own I/G. Never manufacture
missing workout state from receipt metadata or stamp a new feed position onto an
old acknowledgement. If recovered data cannot satisfy the approved payload RPO,
remain CLOSED. No nonzero loss allowance is accepted by this proposal (O6).
Any future approved allowance requires an explicit loss inventory and preserves
affected phones' acknowledged working state as conflicts rather than deleting it.

Independent metadata retention must cover every still-permitted restore/replay
route. [Security policy](SECURITY.md#retention-deletion-and-portability) currently
requires minimal receipts/retired IDs for owner lifetime and backup expiry within
35 days, with narrower account-retirement policy. Expiring backups does not by
itself authorize expiring owner receipts. Account-erasure metadata minimization,
backup descendants, offline-client lifetime and authority key retention need O5;
unbounded metadata retention is not silently approved.

## 8. Version negotiation, safe denial and Flutter persistence

Proposed DRP/2 endpoints use an explicit versioned route/envelope; a header alone
cannot supply lineage. Server capability/readiness states supported command and
response versions, required recovery protocol and immutable size limits. Exact
DTOs/status schemas require the future contract PR. No synthetic credentials or
client-selected owner are introduced. Existing bounds (256 KiB command, 1 MiB
batch, one eligible head per root) remain, including new provenance bytes.

Once DRP/2 recovery admission is activated, **v1 writes are denied**, not stamped
with current lineage. Current/previous released-client support in the accepted
protocol requires an explicit reviewed compatibility/security decision before
activation (O7); this draft does not silently waive it. Prior deployment of v2
readers does not itself authorize unsafe v1 writes on a restored target.

| Proposed status | Remote meaning | Local behavior |
| --- | --- | --- |
| 426 `upgrade_required` | Unsupported/legacy command or response contract | Retain DB/outbox, allow established training, show restrained upgrade requirement |
| 409 `timeline_reconciliation_required` | Known old or missing origin; no new effect/terminal receipt | Preserve M/body/base and block that branch's upload; no automatic rebase |
| 503 `recovery_unavailable` / `recovery_metadata_unverified` | Global closed or authority incomplete/divergent | Pause sync with bounded backoff; no erasure or revision-conflict classification |
| 202 `publication_pending` | Same attempt unresolved/in progress; no authoritative result | Keep pending identity/bytes and safe retry state; no cloud success |
| `historical_result` in v2 result | Verified prior outcome only | Store evidence separately; no current-shadow advance or successor release |
| Existing verified-owner auth/account errors | Genuine authentication/lifecycle policy | Preserve existing owner checks; only actual bound account policy can invoke erasure |

DRP/2 defines per-operation typed outcomes so an earlier certified result in a
batch survives a later pending outcome. A proxy/network failure still leaves
the exact original mutation retryable. Legacy errors must be parseable safe
denials, without sending v2 success into a strict v1 parser. Safe v1 read support
must be explicit; never strip correctness fields merely to make parsing succeed.

Local migration SHALL preserve all original sent/unsent v1 bytes/IDs, projections,
drafts, timer anchors, cursor, conflicts and bootstrap state. Unknown-origin
commands remain quarantined even when not yet sent. No migration, OTP refresh or
account switch converts an old frozen body into v2 under the same M. A reviewed
resolution may create a new ID only after reconciling the old outcome and genuine
retirements; no automatic duplicate creation is authorized.

Store branch origin, acknowledged context and historical receipt evidence apart
from L and working revision. Install each valid pull page/cursor atomically.
Historical evidence/denial must also be persisted atomically with attention state.
An existing matching secure local-owner grant continues to unlock local training
without cloud availability. A missing grant or explicit sign-out still requires
verified unlock; recovery cannot guess ownership. B never reads/uploads A's state.

## 9. Interrupted cutover and authority loss

Order for a future approved cutover:

1. Announce containment; stop new authority PREPARED issuance by moving ACTIVE
   to CLOSING. Suppress external jobs/email/webhooks and isolate candidate ingress.
2. Commit the old DB's exclusive CLOSED fence. Drain/stop old workers, withdraw
   old routing and contain old credentials/endpoints. Verify absence of alternate
   paths/stale pools, not merely the configured primary URL.
3. Settle every previously prepared attempt as CERTIFIED or proved NOT_COMMITTED
   against trusted original commit evidence. If evidence is unavailable, keep
   UNRESOLVED and do not seal/open another target. Clock expiry is not abort proof.
4. Independently seal old activation/evidence heads, including all owner
   inventory and high-waters. No new preparation/certification can extend the
   sealed history; exact retrieval of existing evidence remains possible.
5. Restore only to a new approved isolated target, authenticate all inputs, run
   complete retirement/lifecycle reconciliation and qualify data/receipt recovery.
   Copied OPEN rows/slots never activate it. Runtime connection/identity must be
   verified for that target with restricted grants and forced RLS.
6. Independently register PREPARING(A+1,I_new), verify all acceptance postconditions,
   then authorize the new local OPEN state under exclusive recovery lock using
   matching ACTIVE authority. Any intermediate mismatch fails closed. Opening
   requires explicit operator acceptance; automatic startup cannot activate it.
7. Change approved routing only after source containment and target acceptance.
   Retain redacted evidence and verify cleanup under separately approved scope.

An authority outage holds new work/publication; it does not relax evidence rules.
Loss/divergence of its latest head is a distinct disaster requiring independently
trusted reconstruction, not a reset to Q=0. Key loss, inability to verify target
identity, missing owner inventory or unknown account denial state keeps CLOSED.
The conservative initial design does not partially reopen a restored environment
with unresolved owners. Normal per-owner publication holds do not stop other
owners on an otherwise qualified ACTIVE environment.

If the original DB is inaccessible and PREPARED attempts cannot be resolved from
trusted commit evidence, availability remains blocked. Defining a broader
recovery rule is O4 and needs proof that it cannot resurrect or discard workouts;
no heuristic is authorized here. This is a deliberate safety/availability trade-off.

## 10. Conceptual migration and rollback requirements

No schema below is applied. Exact objects/names must be reviewed in implementation.

- Additive Alembic successor to 0003: private environment recovery control;
  owner-scoped publication/attempt/evidence anchors; receipt provenance/result
  certification metadata; scoped constraints/indexes/grants. No old file edits.
- Keep owner-bearing rows under forced RLS/composite tenant constraints. A global
  private control row has narrow runtime read permission, no runtime activation
  grant. Readiness/runtime-role checks must explicitly validate the new shape.
- Additive Drift successor to schema 3: known/unknown branch origin, certified
  shadow context, historical result and attention metadata, preserving old blobs.
- Bootstrap the independent base from a verified, contained, current source:
  all surviving receipts, retirements, account denials and epochs plus complete
  inventory. Unknown pre-v2 history cannot be retroactively certified from a
  restored DB. No writer may create an unrecorded gap during seeding (O8).
- Roll out capable readers/clients and validate old-client denials before
  enforcing admission. Enabling/activation requires O1–O12 decisions, not an
  environment-variable fallback. Incompatible old binaries fail readiness.
- Before activation, an additive capability-only release may be rolled back
  only with verified unchanged original admission and no v2 writes. After
  activation/certificates, use compatible forward repair with cloud admission
  closed. No downgrade drops provenance/holds or enables legacy acceptance.
- Once a new target accepts work, routing back to an older source requires another
  reconciled cutover. Switching URLs is not rollback. Client downgrade must not
  reinterpret a newer DB; preserve it and deny unsafe opening/export handling.

These are proposed amendments to DM-005/DM-006/DM-012/DM-014 and compatibility
semantics. [Accepted decisions](DECISIONS.md) are unchanged until an approved ADR.

## 11. Threat/invariant matrix

| Threat | Invariants | Required controls | Tests |
| --- | --- | --- | --- |
| Equal revision on discarded history / delayed HTTP | I2/I3/I7 | Frozen E/I/G, fresh under-lock admission and exclusive fence | PG01–PG05, SQ01 |
| Restored OPEN row / stale authority prefix | I3/I8 | Independent latest activation/target binding, no stale cache | PG06, RC01–RC03 |
| Missing or changed receipt | I4/I5/I10 | Same M/D, ordered independent terminal evidence, historical-only results | PG07–PG09, SQ02 |
| Echo/duplicate/bootstrap ahead of certification | I4 | Durable owner hold, P/V publication guard, two-phase snapshot check | PG10–PG14, SQ03 |
| Missing deletion records / epoch regression | I6/I7 | Complete certified replay, trusted H and payload suppression | RC04–RC07, SQ04 |
| Prepared deletion guessed committed/aborted | I6/I8 | UNRESOLVED, trusted commit/abort proof, closed recovery | PG15, RC08 |
| Old source or stale pool still serving | I3/I8 | Source containment, seal, isolated target verification | RC09, PG16 |
| Owner crossover / revoked account restored active | I6/I9 | JWT/RLS, per-owner evidence access, independent lifecycle denial and guarded initialization | PG17–PG19/22, SQ05 |
| Unsafe legacy upgrade / origin restamping | I2/I5/I7 | Explicit version denial and immutable migration/quarantine | PG20–PG21, SQ06–SQ07 |
| Auth/authority/storage failure during training | I1/I8/I9 | Cloud pause separate from local grant/transactions | SQ08–SQ10 |
| Wrong retirement retention / lost keys / unaffordable custody | I6/I8/I10 | Approved lifecycle/custody/budget, measured recovery and expiry | RC10–RC12 |

## 12. Exact defensive test definitions (not implemented or run)

All cases use new disposable PostgreSQL resources and real file-backed SQLite;
never an existing hosted URL. Reuse the reviewed lab containment and no-silent-
skip receipt guards. Use deterministic barriers at named boundaries, not sleeps
as evidence of race ordering. Assert normalized rows, revisions, receipts, feed,
retired IDs, hold state and independent evidence after every fault/restart.
An authority emulator can inject failure deterministically; its success does not
qualify a real storage provider's consistency/durability. That needs RC10.

### PostgreSQL cases

| ID / proposed test name | Arrangement and fault | Exact acceptance oracle |
| --- | --- | --- |
| PG01 `test_old_origin_equal_revision_denied` | G1 expected R=2, restored G2 divergent R=2; send original body | No projection/revision/feed/receipt effect; typed reconciliation; body identity preserved |
| PG02 `test_old_origin_lower_higher_revision_denied` | Parametrize restored R=1,3 with old G1 command | Denial before any new effect at both revisions; not an ordinary revision conflict |
| PG03 `test_buffered_authenticated_request_after_fence` | Buffer before handler, then after JWT; fence before B3 | Both old requests denied; zero accepted receipts/changes |
| PG04 `test_shared_transaction_orders_before_exclusive_fence` | Pause B3 holding shared recovery and owner locks; request exclusive close | Close cannot commit ahead of B3; after release B3 commits first or rolls back; later old B3 denied |
| PG05 `test_pre_wait_snapshot_and_cached_state_do_not_admit` | Preload stale ORM/control state; wait behind close; try unsupported isolation | Fresh READ COMMITTED check denies; repeatable-read effect path explicitly refused/restarted, never accepted using old snapshot |
| PG06 `test_missing_divergent_stale_activation_is_closed` | Parametrize missing row/assertion, copied OPEN, wrong E/I/target, stale Q and authority timeout | No ordinary payload/init/effect; no receipt consumption/account-disable side effect |
| PG07 `test_same_generation_certified_retry` | B0–B6; lose HTTP response; repeat exact M/body | One domain/feed effect; same certified result; changed digest rejected |
| PG08 `test_retained_restored_receipt_is_historical` | Restore retained original receipt/certificate into fresh I | Historical-only result; no effect/current ack or successor basis |
| PG09 `test_missing_restored_receipt_cannot_reaccept` | Accept/certify G1; restore earlier archive; retry M with original body | Independent history found or admission held; never accepted again on G2 |
| PG10 `test_echo_duplicate_and_context_blocked_before_certificate` | Stop after B3 before B4; concurrently pull, `/me`, duplicate and initialize | No accepted/duplicate/echo/new epoch exposed; safe pending statuses, unchanged V |
| PG11 `test_bootstrap_cannot_publish_uncertified_projection` | Materialize before B1 and after B3; attempt publication at both pauses | After B3 hold prevents manifest/page publication; pre-B1 snapshot revalidation rejects changed checkpoint |
| PG12 `test_certificate_then_publish_crash_resumes_once` | Authority cert succeeds; kill worker before/during B5; restart | Hold persists or publication atomically complete; same T/M/D resumes, no second domain effect |
| PG13 `test_cursor_never_crosses_unpublished_effect` | Certified position N; commit private N+1 then fail B4 | Pull denies rather than skipping N+1; V/cursor remain N; eventual certified page includes effect once |
| PG14 `test_batch_fence_preserves_per_result_context` | Two independent roots; fence after first B5 and before second B3, also before response serialization | First retains original certificate/context; second not applied; no later `/me` relabel |
| PG15 `test_prepared_commit_abort_uncertainty` | Crash before/after PREPARED and B3; remove receipt only by archive rewind | Intents never treated as effects; missing restored marker does not prove abort; UNRESOLVED blocks seal/open |
| PG16 `test_fence_failure_role_and_pool_reset` | Roll back/kill exclusive close; reconnect pooled runtime with unset/A/B context | Fence atomic; no widened grants; no tenant setting leakage; actual target verified |
| PG17 `test_authority_receipt_and_nested_id_owner_isolation` | B requests A's M/certificate/root/child; concurrent legitimate A/B uploads | No A metadata/payload/effect under B; legitimate owners each certify independently |
| PG18 `test_retired_owner_absent_from_archive_cannot_initialize` | Provider-valid subject retired after backup; target lacks owner row | Independent retirement denies init; no profile/device/owner recreation |
| PG19 `test_account_denial_races_admission_and_restore` | True disable before B3/B5; restore backup with active row | No normal publication/effect after denial; independent policy preserves denial; maintenance never emits false erasure |
| PG20 `test_contract_sizes_legacy_and_false_fresh_headers` | v1/new unsupported envelopes, v2 max/mixed batches, old body with new header only | Typed safe denial; full provenance counted in bounds; no stamping, starvation or identity rewriting |
| PG21 `test_additive_migration_and_old_binary_denial` | Migrate empty and populated 0003 DBs with live receipts/retirements/owners; run an old binary against the activated schema; attempt unsafe downgrade | Existing payload/digest/identity preserved, unknown provenance not invented; new forced RLS/grants validated; old binary fails readiness and downgrade cannot reopen admission |
| PG22 `test_first_initialization_lost_response_and_concurrency` | Absent owner row; simultaneous verified initialization; fail/restart at each B1–B5 boundary and lose successful response | One minimal owner/profile and stable initialization attempt; no sample workout/feed event; pending init not exposed, exact repeats idempotent |

### File-backed SQLite cases

| ID / proposed test name | Arrangement and fault | Exact acceptance oracle |
| --- | --- | --- |
| SQ01 `test_origin_projection_outbox_atomic_restart` | Kill/fail before/after local commit and freeze; reopen actual file | Either no acknowledged local save, or projection/revision/outbox/origin all present; exact bytes/ID survive |
| SQ02 `test_historical_receipt_keeps_working_branch_and_successors` | Late/historical result after new external shadow; two pending successors; reopen | No shadow regression, pending branch loss or successor rebase; original expected revisions retained |
| SQ03 `test_echo_before_push_response_requires_certificate` | Pending mutation; server stops at PG10; then completes B5 and echo wins race | No early ack; one atomic certified ack after publication; later push result idempotent |
| SQ04 `test_erasure_replay_and_high_water_restart` | Existing client H=3 and fresh file; interrupted bootstrap with stale deleted root | Existing H never lowered; new file never receives erased root; old stage cannot activate; real deletion policy still applies |
| SQ05 `test_account_switch_during_pending_publication` | A pending T/M, sign out, B signs in, stale A callback, then A returns | B cannot inspect/upload A outbox/cursor/conflict/stage; A recovers unchanged M/body |
| SQ06 `test_legacy_schema_migration_preserves_all_bytes` | Every supported old schema with active draft, timer, sent/unsent commands, conflict/stage; interrupt migration | Atomic reopen on old/new version; original frozen blobs/IDs intact, unknown origin quarantined |
| SQ07 `test_bootstrap_cannot_stamp_unknown_or_old_origin` | Download G2 while logging old branch and brand-new unknown-origin root | Logging survives; known-old/unknown commands not made eligible by new metadata |
| SQ08 `test_authority_auth_failure_does_not_block_training` | API/authority outage and token refresh failure during workout | Durable sets/corrections/completion/history continue; outbox pending; local-save latency contains no network await |
| SQ09 `test_local_write_failure_is_not_cloud_failure` | Real SQLite write fault during save/ack/page install; reopen | No false saved state; previous acknowledged work intact; page/cursor and ack metadata atomic |
| SQ10 `test_grant_loss_and_signed_out_owner_not_guessed` | Missing/corrupt secure-owner grant or explicit sign-out with pending work | DB remains locked until matching verified unlock; no erasure/reassignment; no cloud bypass |

### Recovery and custody cases

| ID / proposed test name | Arrangement and fault | Exact acceptance oracle |
| --- | --- | --- |
| RC01 `test_activation_interruption_every_boundary` | Crash at CLOSING, local CLOSED, seal, PREPARING, reconcile and local OPEN | At most one active target; no partial target opens; repeat uses recorded identities/checkpoints |
| RC02 `test_authority_prefix_replay_and_missing_owner` | Validly authenticated but older/truncated head, missing owner inventory or wrong environment | Recovery remains closed; no Q reset or phone-supplied max repair |
| RC03 `test_authority_loss_never_falls_back_to_restored_db` | Authority unavailable/corrupted while old DB receipts look consistent | No activation/publication; local workout remains usable under cached grant |
| RC04 `test_lost_deletion_equal_epoch_fresh_client` | Reproduce D4 backup and equal epoch; replay certified independent deletion | Root/children/history/feed payload absent/redacted before new client access; retired reuse denied |
| RC05 `test_high_water_exceeds_restored_counter` | Restored epoch 0; certified H=3 incl earlier recovery fence | New epoch exactly 4; cached/fresh clients both safe; overflow causes closed recovery |
| RC06 `test_deletion_replay_is_idempotent_and_complete` | Replay duplicate/out-of-order retirement inputs; interrupt each purge step | No access until full verified replay; same final suppression/checkpoint after retries |
| RC07 `test_deleted_account_snapshot_and_old_jobs_do_not_resurrect` | Restore old profile/Auth mapping, snapshots/feed copies and queued publication | Retired owner init denied; all old materializations blocked/redacted; no stale job output |
| RC08 `test_unresolved_deletion_does_not_guess_user_intent` | PREPARED delete, commit evidence unavailable after rollback | Neither synthetic deletion nor data exposure; seal/open blocked pending authorized resolution |
| RC09 `test_old_source_containment_and_routing` | Old worker/pool/alternate origin attempts access after approved close while candidate prepares | Old target refuses effects/publication; candidate stays isolated; test fails if any source path remains reachable for normal work |
| RC10 `test_selected_authority_provider_conformance` | Selected real isolated storage backend: concurrent compare/append, response loss, restart, stale reads, partial records and writer permissions | Actual durability/linearizability/freshness/least privilege meet section 3; emulator result cannot close this case |
| RC11 `test_encryption_custody_retention_and_key_loss` | Approved encrypted archive/evidence route, custodian unavailable, stale key, expiry including versions/copies | No unverified decrypt/restore; measured expiry within policy; recovery access denied until approved keys available |
| RC12 `test_payload_rpo_receipt_difference_and_source_preservation` | Certificate newer than archive; missing acknowledged workout; damaged archive and interrupted restore | Receipt never substitutes for payload; unmet RPO keeps closed; explicit loss inventory if permitted; original source unchanged |

Future test layout: proposed `services/api/tests/test_recovery_protocol_v2.py`
(PG cases), `services/api/tests/test_recovery_protocol_v2_lab.py` (RC cases),
`apps/mobile/test/recovery_protocol_v2_test.dart` (SQ cases), plus a connected
wrapper requiring every named case and successful final machine/JUnit completion.
These files do not exist yet. Their invocation is **not currently runnable**:

```text
python -m pytest -q tests/test_recovery_protocol_v2.py
python -m pytest -q tests/test_recovery_protocol_v2_lab.py
flutter test test/recovery_protocol_v2_test.dart --machine
```

Implementation must provide a new explicit local opt-in/owned-resource launcher,
scrub inherited provider/libpq credentials and hard-fail if required PG/Flutter/
authority qualification is absent. Provider-gated RC10/RC11 remain NOT EXECUTED
until separately authorized; they cannot count as ordinary passing CI. Run full
existing Flutter/Python/connected suites, static/format/migration/contract/native
checks after approved code changes, with exact pass/skip/failure counts.

## 13. Four-defect traceability

| Confirmed finding / saved observation | Protection required | Future regression oracle |
| --- | --- | --- |
| D1 equal revision, `cases[0] equal_fenced`; unfenced control `cases[3]` | I2/I3; frozen origin, B3 under shared fence/fresh state; no context restamping | PG01/02/05/14, SQ01/02: zero stale effects even at equal revision; acknowledged local state retained |
| D2 delayed request, `cases[4] delayed_inflight` | I3; check at B3, exclusive close ordering, old-source containment | PG03/04, RC01/09: pre-arrival/authentication gives no post-fence admission |
| D3 lost receipt, `cases[6] lost_receipt`; retained control `cases[7]` | I4/I5/I10; independent terminal evidence and publication hold; old receipt historical only | PG07–PG13/15, SQ02/03, RC12: no reacceptance after rollback, no early echo, no payload-recovery claim |
| D4 lost deletion, `cases[10/11]`; retained control `cases[12]` | I6/I8; complete independent replay and H, unresolved deletion closure | PG18/19, SQ04, RC04–RC08: erased workout never served to fresh client; high-water never regresses |

The saved 13-case run remains characterization with its original expectations.
New defensive tests must expect rejection/suppression, not bless today's unsafe
acceptance. Do not edit old receipts or relabel their passes as a fix qualification.

## 14. Unresolved decisions and implementation prerequisites

Each item is unresolved. Proposed safe defaults above do not authorize resources,
code or policy changes. User/operator approval is required for scope/cost;
technical/security acceptance requires the named reviewer, not merely approval.

| ID | Question / acceptance needed | Responsibility | Blocks |
| --- | --- | --- | --- |
| O1 | Which independent storage route actually provides section 3 semantics and survives the application's rollback/failure domain? Daily export alone is insufficient for acknowledged metadata coverage | Operator/billing owner + storage engineer, unassigned | Production implementation choice, RC10, activation |
| O2 | How are current authority freshness, actual target identity and old-source containment verified on the chosen platform? No hostname/flag-only proof | Operator + security reviewer, unassigned | Admission/activation implementation acceptance |
| O3 | Which trusted committed-marker verifier and certificate format establish B4 without cross-store atomicity claims or secrets/payload leakage? | Backend owner + security reviewer, unassigned | B4/B5 implementation |
| O4 | What evidence resolves prepared attempts when the original DB/WAL is unavailable? Default is indefinite safe closure, not timeout-based abort | Recovery owner + reviewer, unassigned | Disaster availability and cutover acceptance |
| O5 | Which account denials/retirement facts, metadata windows, key versions and offline-client expiry policies survive account erasure/backups? Reconcile minimal retention with privacy obligations | Privacy/security reviewer + product owner, unassigned | Ledger schema/retention/GC |
| O6 | What payload RPO/RTO and explicit loss policy are accepted? Which backup/WAL route meets them? No nonzero loss is approved here | Product/recovery/billing owners, unassigned | Recovery opening and payload claims |
| O7 | Approve v1 write denial/security exception, v2 negotiation, historical-result UX and explicit unknown-origin adoption; preserve current/previous released-client commitments deliberately | Product/mobile/API owners, unassigned | Contract/migration rollout |
| O8 | How will the initial independent inventory/checkpoint be established without unrecorded legacy writes or falsely certifying missing pre-v2 history? | Recovery/backend owner + reviewer, unassigned | First activation |
| O9 | Name primary/alternate operator, authority custodian, independent key custodian, incident owner and acceptance reviewer; define emergency access and alerts | User/operator, unassigned | Custody and operation |
| O10 | Approve provider/region/processors, encryption implementation and monthly/drill ceilings using a current quote; include independent metadata operations, availability, egress, KMS, backup, restore compute and monitoring | User/billing/privacy owners, unassigned | Resource creation or hosted qualification |
| O11 | Obtain an available authorized independent security review of state machines, trust/abort proofs and implementation/test plan | Security-review owner, unassigned | Security approval; currently unavailable |
| O12 | Approve exact isolated hosted drill source/destination/data/recipients/side-effect containment/lifetime/cleanup after local tests pass; resolve applicable credential containment prerequisites | User/operator + reviewer, unassigned | Any hosted access/restore/deploy/provider action |

The [existing REC-01–REC-06 package](../infra/HOSTED_RECOVERY_STRATEGY.md)
contains proposed backup routes/costs, not purchased resources or current quotes.
Its daily export budget does not price or qualify this independent certification
mechanism. Proposed seven-day backup retention remains subordinate to accepted
policy and actual expiry verification. No additional costs or supplier are approved.

## 15. PR boundaries, review limitation and authorization

1. **Specification PR (this stage, not opened):** this document and proposed ADR;
   preserve historical characterization. Obtain O1–O8/O11 decisions needed to
   remove ambiguity before production implementation authorization.
2. **Server admission/contracts PR:** additive metadata/contract definitions,
   atomic gates, local authority conformance adapter and PG tests. Keep recovery
   reopening unavailable; no claim that an emulator qualifies independent custody.
3. **Client/migration PR:** frozen provenance, historical/pending result handling,
   explicit legacy quarantine, SQ and connected tests. No activation by rollout alone.
4. **Independent durability/publication PR:** approved real adapter, resolver,
   publication barrier, complete ledger/high-water replay and fault evidence.
5. **Recovery qualification PR:** integrated RC tests/operator package, then
   separately approved isolated hosted drill. No automatic merge/deploy/restore.

An independent security-review output was restricted/unavailable. Its recorded
status remains **unavailable; not retried or bypassed**. This specification is the
primary agent's design proposal, not independent approval, proof of correctness
or a successful substitute review. No restricted output was requested/retrieved.

No accepted ADR is superseded, no Phase 0 gate is closed and no Phase 1 work is
authorized. All implementation, commits, PR creation, hosted operations and
activation require separate approval. Preserve the investigation's original
files, hashes, receipts, worktrees and signing protections.
