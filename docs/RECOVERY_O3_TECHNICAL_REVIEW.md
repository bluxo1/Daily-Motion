# O3 advisory backend/security review and D1-D11 decision record

2026-10-22. **ADVISORY / PROPOSED / UNAPPROVED.** This is an automated technical
review, not required backend/security acceptance, independent O11 approval or
authorization to implement B4/B5. All required reviewers remain unassigned;
there is no explicit approval reference for any D1-D11 decision. Phase 0 remains
in progress; Phase 1 has not started. Blocking platform/privacy decisions remain.

Baseline is signed main `3935d5186a8797693413379271b97df614666102`, tree matching
`266e164`; [main CI](https://github.com/bluxo1/Daily-Motion/actions/runs/39763668555)
is complete and green in all three jobs. The eight-file uncommitted revision-2
package matched its recorded hashes before review and was copied to an ignored
local checkpoint. This review changes only documentation/experiments. Runtime,
migrations, protected protocol/ADR/characterization and historical receipts are
preserved. The [new evidence receipt](evidence/recovery-o3-advisory-review-2026-10-22.json)
records original/final hashes, reports, validation and limits separately from
the [original receipt](evidence/recovery-o3-design-review-2026-10-22.json).

## Concrete findings and local corrections

Severity here describes a design/evidence defect if carried into implementation,
not an exploit in a deployed O3 service. High blocks a claimed recovery path;
Medium affects a contract, assurance boundary or acceptance oracle. Locations
labeled **before** refer to the preserved revision-2 package, not shifted lines
in revision 3; the new receipt retains those original hashes and excerpts.

### F1 — High: unresolved-head observation path was missing

**Before:** RECOVERY_O3_RECORDS_PROPOSED.md:116,169 and acceptance P02. The record
allowed an UNRESOLVED append predecessor but described settlement principally
as a CLOSING/CLOSED extension, without defining its different observation check.
After a real B3 commit/local Qp, authority UNRESOLVED advances to Qu. Calling the
current [observer](../services/api/src/daily_motion/recovery_observation.py#L235)
with the genuine fresh head fails ordinary
[exact-equality admission](../services/api/src/daily_motion/recovery.py#L143).
Replacing that head with Qp would fabricate an assertion; waiting/retrying the
same helper cannot settle this valid committed attempt.

The advisory probe executes this arrangement on the original owned target and
gets the expected denial with unchanged rows. The pure reducer can later certify
an unresolved intent, but that is not committed observation or authentication.
Protocol section 4.2 requires separate committed observation and permits scoped
existing-attempt settlement; it never permits invented admission or B3 replay.

**Correction:** the [observation matrix](RECOVERY_O3_RECORDS_PROPOSED.md#observation-head-and-state-matrix)
now specifies a future purpose-specific same-intent observation validator for
ACTIVE/OPEN+Qu as well as CLOSING/OPEN-or-CLOSED settlement. Normal admission
remains exact equality. P02 requires both observation and publication proofs.
This corrects the design; that observer is not implemented or approved.

### F2 — Medium: deletion completeness needed an explicit trust qualification

**Before:** proposal:61,315 and L03. The limitation named nondelete child auditing,
while deletion text could be read as independent proof of complete retired scope.
The [observer](../services/api/src/daily_motion/recovery_observation.py#L97)
checks listed IDs, row suppression and redacted-feed consistency. It cannot
reconstruct the pre-delete child set from already purged rows. Actual
[B3 erasure](../services/api/src/daily_motion/sync.py#L225) enumerates root,
exercises and sets before purge; that trusted enumeration is essential to I6.

In the disposable administrator control, omitting a child in the immutable marker
while leaving feed metadata intact is denied. Coherently rewriting marker and
feed to omit that child is accepted by the observer, even though a retirement
row for the omitted child remains. The experiment intentionally bypasses the
immutable-binding trigger as administrator; the restricted reader cannot do so.
It demonstrates an excluded trusted-writer/administrator assumption, not a
restricted-role exploit or an observed defect in B3's actual enumeration.

**Correction:** proposal, records' trust boundary and L03 distinguish consistency
of listed scope from independent completeness. Future L03 captures the pre-delete
inventory and compares exact B3 output. D1/D9 require acceptance of trusted B3
completeness or a different independent witness; no post-delete hash fills that gap.

### F3 — Medium: an absent certificate lookup had no valid record shape

**Before:** records:234 allowed null only for preparation/inventory queries;
R04 tested only response loss after a durable append. If the append request was
lost before persistence, an authorized exact lookup must represent absence while
the original preparation/hold remain. Current
[test authority lookup](../services/api/tests/recovery_authority.py#L207) and
the advisory experiment return None for this real prepared-but-uncertified state.
It is neither an authenticated denial nor evidence that B3 aborted.

**Correction:** explicit certificate=null/absent is valid only for a complete
authenticated exact lookup. Unknown inventory/anchor failure remains unknown
or denial. workout_publish requires a nonnull matching certificate. A not_requested
classification separates no lookup from proved absence. R04 now covers loss before
append, after append/before anchor and after anchor, including T/ID-unknown lookup.
No absence permits replay, NOT_COMMITTED, hold clearance or owner initialization.

### F4 — Medium: the bounded probe's success gate accepted incomplete inventories

**Before:** recovery_o3_local_probe.py:419-421 used all(passed) and cleanup only.
An empty check list or a successful partial list can satisfy that expression.
The original executed report really contains all 25 checks; its evidence remains
valid for that run. The defect was a future false-green path in the probe runner,
not a retroactive failure of those 25 executed checks.

**Correction:** an explicit 25-name inventory, exact cardinality, no duplicates/
unknown names and exact boolean pass values are now required. Seven new runner
controls cover valid, empty, missing, duplicate, unknown, failed and truthy-valued
lists. A separate control reproduces the old empty-list predicate; it executes
no SQL and is labeled unsafe. The hardened probe then executes all 25 checks
successfully on a new owned cluster. Historical source/report hashes are retained.

### F5 — Medium: oversize oracle incorrectly prohibited already-required head movement

**Before:** S01:98 said no head advance on an oversized certificate. B2 has already
recorded PREPARED before B3 discovers the committed retirement scope, and an
UNRESOLVED event may also exist. A test forbidding all such movement would reject
the required protocol history or encourage rewinding it. The cap also needed to
cover the full current-view response containing the certificate, not only its
inner object.

**Correction:** compare Q/H immediately before the attempted oversized append;
deny an additional CERTIFIED transition, preserve existing preparation/uncertainty
and private effect/hold. S01 now specifies complete-body byte/depth boundaries.
The separate shape measurement resolves current DTO cardinality locally: 50
exercises × 100 sets plus root gives 5,051 IDs; the conservative compact publication
view is 399,365 bytes. This is a sizing result with deliberately invalidated old
example hashes, not a valid certificate, decoder test or execution of S01.

## D1-D11 recommended dispositions

Every row has **acceptance: NONE; reviewer: unassigned; approval reference: NONE**.
“Retain” means an advisory recommendation conditional on the listed decision.
“Amend” means the local proposal was corrected, not accepted or implemented.
Nothing here closes O1-O12 or grants implementation permission.

| Decision / recommended disposition | Supporting code/evidence | Unresolved dependency | Required reviewer and precise decision |
| --- | --- | --- | --- |
| D1 — Retain with explicit trust/revocation conditions | Admission is an untrusted internal dataclass; owner/assertion binding precedes private reads. Existing auth.py validates mobile identity, not verifier workload identity. F2 and the unsafe scope control bound what B3 trust means | Workload federation, current principal/deployment policy, revocation ordering, trusted B3 completeness; no IAM experiment | Backend + security: accept that TCB and distinct verifier audience/subject/manifest policy, deny API impersonation, define append-versus-revocation ordering and enforcement bound; or request a stronger witness |
| D2 — Retain candidate grants, not role acceptance | db.py:35 checks runtime metadata, not an exact verifier grant/policy allowlist. Old 20 SQL checks; new five existing observer outcome branches work with 12 training-table/column reads plus control; six denied reads/DML | Dedicated readiness, role/policy/function/membership drift, hosted pooler behavior, successor-schema grants | Backend + security: approve exact SELECT/lock grants, restrictive policy and callable-function/membership allowlist; require readiness to reject removal/escape, without reusing CRUD readiness |
| D3 — Blocked on platform proof | Activation/Admission compare supplied digests; Engine ownership only separates transactions. Neither current code nor either probe binds a physical connection to unchanged ancestry | Independent immutable resource registry, actual-connection proof covering whole transaction, restore/failover revocation/drain and containment | Platform/operator + security: supply an enforceable connection/lifecycle contract and its failure evidence, including mid-transaction changes and pool reconnection, or keep this path unavailable |
| D4 — Retain online authenticated record; amend absent lookup | OwnerEvidence/ConformanceAuthority supply pure/local state semantics only. F3 fixes null/absence. Existing marker/envelope digests are content references, not authentication | Authenticated authority transport/authorization, rooted complete inventory and scoped lookup; no real authority | Backend + security + storage: accept online retrieval/fail-closed availability and exact absence/unknown/inclusion semantics; define authenticated adapter construction and authorization policy |
| D5 — Amend settlement/publication contracts; preserve core bytes | F1, ordinary equality denial, direct and UNRESOLVED reducer paths, existing canonical_json, source/existing example hash checks | Strict new parser and purpose validators; prior/prepared anchor retention; additive certificate-present/immutable binding | Backend + security: approve each exact head/state proof and golden encoding/counter rules. Do not weaken validate_admission or insert nonce/provenance into current event hashes |
| D6 — Candidate architecture, blocked on O1 | No production authority adapter exists; tests/recovery_authority.py is local SQLite only. Root/anchor CAS ordering is a proposed contract, not evidence. R07 remains future | Atomic complete-inventory schema, independently administered nonrollbackable anchor, root-publisher custody, one-pending-root backpressure/cost | Storage + security + operator: accept or replace this concrete ordering; prove both crash windows and new-worker stale-prefix denial. Approve global pause/throughput tradeoff and separately authorize any RC10 work |
| D7 — Conditional concurrency interpretation, not approval | recovery_db.py:13 shared fence; close_admission takes exclusive lock; separate fresh READ COMMITTED statements. Current observer is not B5 | Authority ACTIVE read can precede CLOSING while SQL publication precedes CLOSED; no cross-store instantaneous ACTIVE proof | Backend + security + recovery operator: explicitly accept fresh-read/shared-fence cutoff, or require redesigned coordination. State permitted two race outcomes before implementing P06 |
| D8 — Retain safe closure; amend known-commit resumption | Stable reservations/frozen digest; no missing-row replay; current observer refuses unknown/closed and Qu head. F1 adds design for known-marker settlement | Source-unavailable abort/commit proof remains O4; no NOT_COMMITTED resolver, no timeout proof; O5 retention conflict | Recovery owner + backend/security: accept closed availability default, specify exact original-source proof and in-flight exclusion for cancellation; authorize no replay/abort from absence |
| D9 — Blocked lifecycle/privacy; clarify completeness/cleanup | accounts.py uses real retirement/initialization barriers; installed recovery control denies v1. Observer supports active known owners only. 0004 allows terminal body null but lacks CERTIFIED_HELD and certificate-required PUBLISHED | Lifecycle variants without dummy root; retained minimal prior anchor; erasure obligations for uncertain body; account/offline/key horizons | Privacy/security + product + backend: accept B3 retirement enumeration or require independent scope evidence; define lifecycle records, cleanup states and deadlines/backups separately, before schema/GC implementation |
| D10 — Retain candidate bound with local sizing evidence | CreateSession max 50; ExerciseSnapshot max 100; _erase includes root/children. Three compact shape measurements below 1 MiB; F5 corrects oracle. No decoder or paging implemented | Complete-body/depth/parser limits; legal admitted variants, future lifecycle growth and untrusted whitespace/depth. No new workout-size policy | Backend + security + product: approve 1 MiB complete-body/depth-16/Reference bounds and current coverage calculation; require new variant sizing and no-truncation handling before expanded scope |
| D11 — Retain custody direction, blocked operation | Online records avoid new client authority-signing secrets; code/probes establish no KMS, encryption, expiry or loss recovery | Identity/root-publisher and anchor custody, key/version retention, availability, independent recovery and current pricing | Operator/custodian + privacy/security + billing: name owners/alternates, revocation/recovery and separation of restore/reset powers, approve retention/region/cost and exact later RC11 scope; no provider selected |

Actual source boundaries were checked in recovery_admission.py (stable B1/
resume_prepared), recovery_effect.py (atomic B3), recovery_observation.py,
recovery.py (pure reducer/protocol), recovery_db.py/db.py, migration 0004,
accounts.py/auth.py/sync.py/models.py and the test authority/lab. There is no
production B4/B5/authority-root implementation to approve. Existing v1 denial
when recovery control is installed must remain until all integration gates pass.

## What the experiments establish

| Original 25-check group | Executed result supports | It does not establish |
| --- | --- | --- |
| Five pure reducer checks | Deterministic event paths, exact-equality denial, sealed existing lookup and changed hash preimage | Database commit, workload authentication, authority storage, rollback resistance or complete inventory. Activation/digests/marker are constructed fixtures |
| Nine locking/policy controls | SELECT-only and READ ONLY cannot lock; column UPDATE plus restrictive false check permits locks and denies tested updates; permissive denial is unsafe | Full helper query compatibility, immutable production policy or a compromised-credential tenant boundary |
| Five verb/DDL denials | The specific tested statements receive 42501 | Every function/view, role-switch or future migration path |
| Two tenant/GUC controls | Missing/reset context hides rows; the same login can intentionally set another owner | Authenticated owner identity from SET LOCAL |
| One runtime metadata guard check | Existing guard accepts that restricted role | Exact read/update policy allowlist or policy-drift detection |
| Two contention/release checks | A real administrator locking transaction conflicts and then succeeds after release | An effect-runtime DML execution, fairness, crash/power durability or hosted pooler behavior |
| One XID/WAL control | XID allocation/WAL insertion can accompany rollback | Independent commit proof or unchanged target ancestry |

The new advisory probe has **23 checks matching expectations**: 14 real
PostgreSQL component/permission controls, one existing test-authority absence
lookup and eight runner controls (including the intentionally unsafe old gate).
It exercises all five existing observation outcome branches under the candidate
read/lock role. The local cluster uses loopback trust authentication; real LOGIN
sessions exercise SQL privileges, not credential or federated IAM security.
Synthetic Admission/test authority/activation do not become trusted platform proof.
The coherent administrator corruption control explicitly encodes an excluded
threat assumption. Its acceptance is not a defensive security pass.

There are two advisory executions with 23 matching checks each: the first retains
an intermediate source hash with one remaining line-length lint finding; the
second follows the formatting-only correction and matches final source. The
hardened original probe has one fresh 25-check execution. No failed SQL probe,
skipped check or hidden retry is reported. Ruff's initial line-length findings
and both advisory reports are recorded separately. The original revision-2
25-check receipt is retained; it is not counted as another new execution.

## Deterministic audit of all 36 future case families

Every row below was reviewed, **not executed as future B4/B5 acceptance**.
The acceptance plan retains the 36 family IDs; each listed branch must become
an explicit named deterministic subcase, not one opaque test with early returns.
No family passes until all its implemented required subcases and external parts
have qualified. AUTH fakes can test branching only; EXT requirements stay pending.

| Family | Required deterministic arrangement/oracle after review |
| --- | --- |
| V01 | Pin test issuer/clock/key policy; separate invalid signature/algorithm/issuer/audience/time, wrong workload/purpose and challenge replay. Barrier orders fresh principal revocation versus append; denied identity causes zero private reads/writes |
| V02 | Distinct A/B login requests and known owner fixtures; count private reads, not only response denial. Reuse one actual pooled connection across commit/rollback/cancellation and assert cleared context |
| V03 | Execute all observer SQL branches under real login; remove each policy/grant or add escape membership/function separately. Future dedicated readiness must deny unsafe drift; current metadata guard is insufficient |
| V04 | Establish pg_locks/pg_stat_activity wait before close/deletion; release at a hook and assert fresh state plus unchanged held rows. Bound deadline, no sleep-based claim |
| V05 | Instrument SQL/SQLite transaction lifetimes and authority/registry/anchor calls; force attempted I/O while locked and assert refusal plus lock release on timeout |
| V06 | Hold actual B3 transaction before commit; observer must demonstrably wait. Commit/rollback/process-exit branches verify marker visibility, no second effect and no certificate on rollback |
| V07 | Inject different physical checkout after approved factory setup; require independent resource/channel binding failure before private work. Fake asserted booleans never qualify EXT |
| V08 | Separate owned target with copied SQL metadata; omit/forge independent registry evidence. Denial must persist despite equal SQL diagnostics; provider continuity remains EXT |
| V09 | Barrier both before checkout and during observation; actual lifecycle mechanism must drain/revoke/fence before ancestry change. Reconnect cannot retain old proof |
| V10 | Make original evidence inaccessible with an existing preparation; absence never creates NOT_COMMITTED/new T or B3 replay. Assert seal/open remains unavailable |
| R01 | Enumerate fixed golden vectors and Counter lexical/type boundaries; reject duplicate keys, invalid UTF-8/surrogates, unknown fields, ambiguous/overlong references and depth. Canonical arrays/timestamps remain exact |
| R02 | Independently mutate one identity/digest/result/binding at a time; retain original complete record/head and sanitized owner-scoped denial. Include same-ID changed provenance |
| R03 | Two real verifier processes at durable-append barrier; one event for same T, reject different owner-slot attempt. A different owner's progress is conditional on the environment anchor progressing |
| R04 | Three explicit loss windows and restart from disk; complete lookup absence, pending unanchored record and first anchored record must differ. Retry new nonce/key preserves T/core/first ID |
| R05 | Force both seal/append orderings, including pending root anchoring. Seal inventory contains prior durable evidence; no append after seal; authorized retrieval changes no head |
| R06 | CLOSING before new PREPARED versus before existing settlement; explicit denial/success by purpose, no ordinary payload publication. Exact old lookup is not new append |
| R07 | Persist journal/store/anchor independently in harness; kill before/after CAS, restore only store to old prefix, start new worker with empty cache. Mismatch/missing witness remains closed |
| R08 | Omit one owner or unresolved attempt and corrupt equal-order digest or ancestry; verify full inventory/root coverage, not max(sequence) or a caller's included boolean |
| P01 | Real B3 commit and exact Qp->Qc; assert only publication metadata changes. Original ordinary-admission predicate must still reject unequal heads |
| P02 | Start from real marker/local Qp, then authority Qu; current helper denial is a prerequisite control. Future settlement and B5 each validate their exact path, with no invented assertion/B3 replay |
| P03 | Table-drive every binding/H/retired-scope mutation, including caller-constructed certificate/root objects and cross-owner lookup; zero writes/hold clearance on denial |
| P04 | Enumerate every future statement fault hook and before/after-commit kill; reopen both stores. Compare complete before-image and certificate count; body purge rolls back with hold/V/H |
| P05 | Commit B5 then lose response; later valid owner mutation and old exact retry, followed by changed I/G. Preserve original result/context without counters/restamping or successor acknowledgment |
| P06 | Prove shared/exclusive contention and both D7-approved orderings; paused stale response cannot publish after CLOSED/new binding. Until D7 accepted, expected policy remains blocked |
| P07 | Explicit route/artifact inventory, no missing endpoint placeholders. Compare A hold-denial before state/payload/context output with normal B behavior and post-B5 publication |
| P08 | Materialize real RR pages then change hold/epoch/fence before fresh guard; serve nothing stale and keep interrupted SQLite page/cursor install atomic |
| L01 | Actual denying transition before/after observer/owner-lock barriers; normal workout evidence cannot stand in for lifecycle evidence or expose premature account_inactive |
| L02 | Keep old verified identity while owner is absent/retired independently; initialization must not invent a new account or Q=0. Unknown inventory denies |
| L03 | Capture pre-delete children before purge; exact B3/retired/feed equality plus each corrupted copy. Coherent administrator omission is a trust-limit control, never complete-scope qualification |
| L04 | Capture materialization input then delete/change epoch/activation; finish publication afterward. No stale artifact becomes accessible and rollback cannot revive erased values |
| L05 | Populate current 0004 rows, apply future additive schema, fault each certified-held cleanup write and retry. Minimal prior anchor/marker/cert/hold survive body purge; V/H unchanged, no bodyless B3 |
| L06 | Inject clock relative to explicit permanent-deletion request; seven-day live-payload and separate backup ceilings. Exact cleanup oracle is BLOCKED until O5 policy, not a passing “alert emitted” test |
| K01 | Separate expiry, key rotation and subject revocation at authorization/append barriers. Current valid identity retrieves first record; a signature-valid revoked subject cannot rely on a cached role |
| K02 | Independently remove authority/anchor/key/custodian; no cache/primary fallback. Local-training SQLite writes still persist independently; real custody recovery remains EXT |
| S01 | Exact encoded body cap-1/cap/cap+1 and depth-1/depth/depth+1; bounded read before allocation, complete-view size, no truncation. Compare pre-append Q/H, retain earlier PREPARED/private effect |
| S02 | Enumerate each SQL/external boundary, actual process exit and cancellation while waiting; observe lock release/deadline, stable T/M/D and unchanged hold on uncertainty |

## Required handoff before further implementation

Backend/security must decide F1's new observation proof, F2's B3 completeness
trust, F3's authenticated absence semantics and D7's fence cutoff. Platform/storage
must supply O1/O2 proof, complete inventory schema and anchor failure-domain/
throughput evidence. Privacy/product must settle lifecycle variants, unresolved
retention and coverage; operator/custodian/billing must name responsible people
and approve any later resources/drill scope. O4 source-loss resolution remains open.

Record each genuine acceptance with named reviewer/role, decision IDs, source/
proposal/evidence hashes, exact accepted assumptions, amendments and approval
reference. Explicit user implementation authorization is a separate prerequisite.
No row is accepted by this review; no B4/B5 implementation readiness, O11 sign-off,
provider qualification, physical-device qualification or Phase 0 exit is claimed.
No commit, push, PR, merge, deployment, provider change, external review message
or hosted drill was performed.
